use super::frame;
use std::io::{self, Write};
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
use std::sync::mpsc::{self, SyncSender, TrySendError};
use std::sync::Arc;
use std::thread;
use std::time::{Duration, Instant};

pub const MAX_PENDING_MESSAGES: usize = 256;
// The slot count alone bounds nothing: 256 slots times the frame ceiling is
// gigabytes. Real frames are control messages of a few KB, so cap the queue by
// bytes too and let the message count stay generous for fan-out bursts.
const MAX_PENDING_BYTES: usize = 16 * 1024 * 1024;
// Callers fan out: a group delay test issues one request per proxy at once, so
// a full queue means the writer is behind, not that the message is surplus.
// Wait it out, but never past this deadline, so a wedged peer still surfaces.
pub const SEND_QUEUE_TIMEOUT: Duration = Duration::from_secs(5);
const SEND_RETRY_INTERVAL: Duration = Duration::from_millis(2);

#[derive(Clone)]
pub struct MessageSender {
    tx: SyncSender<OutgoingMessage>,
    pending_bytes: Arc<AtomicUsize>,
}

#[derive(Debug, PartialEq)]
pub enum OutgoingMessage {
    Data(Vec<u8>),
    Close,
}

impl MessageSender {
    pub fn channel(capacity: usize) -> (Self, mpsc::Receiver<OutgoingMessage>, Arc<AtomicUsize>) {
        let (tx, rx) = mpsc::sync_channel(capacity);
        let pending_bytes = Arc::new(AtomicUsize::new(0));
        let sender = Self {
            tx,
            pending_bytes: Arc::clone(&pending_bytes),
        };
        (sender, rx, pending_bytes)
    }

    pub fn close(&self) {
        // A full queue already wakes the writer; callers clear the running flag first.
        let _ = self.tx.try_send(OutgoingMessage::Close);
    }

    // An empty queue always accepts, even past the budget: a lone frame may be
    // larger than the budget, and refusing it would stall forever with nothing
    // draining ahead of it.
    fn try_reserve(&self, len: usize) -> bool {
        self.pending_bytes
            .fetch_update(Ordering::SeqCst, Ordering::SeqCst, |pending| {
                let next = pending.checked_add(len)?;
                (pending == 0 || next <= MAX_PENDING_BYTES).then_some(next)
            })
            .is_ok()
    }

    fn release(&self, len: usize) {
        self.pending_bytes.fetch_sub(len, Ordering::SeqCst);
    }
}

pub fn enqueue_message(
    sender: &MessageSender,
    data: Vec<u8>,
    timeout: Duration,
    running: &AtomicBool,
) -> Result<(), String> {
    let deadline = Instant::now() + timeout;
    let len = data.len();
    let mut pending = OutgoingMessage::Data(data);
    loop {
        if sender.try_reserve(len) {
            match sender.tx.try_send(pending) {
                Ok(()) => return Ok(()),
                Err(TrySendError::Disconnected(_)) => {
                    sender.release(len);
                    return Err("IPC client is disconnected".into());
                }
                Err(TrySendError::Full(rejected)) => {
                    sender.release(len);
                    pending = rejected;
                }
            }
        }
        if !running.load(Ordering::SeqCst) {
            return Err("IPC server is stopped".into());
        }
        if Instant::now() >= deadline {
            return Err("IPC send queue is full".into());
        }
        thread::sleep(SEND_RETRY_INTERVAL);
    }
}

pub fn write_messages(
    writer: &mut impl Write,
    receiver: &mpsc::Receiver<OutgoingMessage>,
    pending_bytes: &AtomicUsize,
    is_running: &impl Fn() -> bool,
) -> io::Result<()> {
    while is_running() {
        match receiver.recv() {
            Ok(OutgoingMessage::Data(data)) => {
                pending_bytes.fetch_sub(data.len(), Ordering::SeqCst);
                frame::write_frame(writer, &data, is_running)?;
            }
            Ok(OutgoingMessage::Close) | Err(_) => break,
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn receive_data(receiver: &mpsc::Receiver<OutgoingMessage>) -> Vec<u8> {
        match receiver.recv().unwrap() {
            OutgoingMessage::Data(data) => data,
            OutgoingMessage::Close => panic!("unexpected close"),
        }
    }

    #[test]
    fn close_wakes_an_idle_writer_even_with_a_retained_sender() {
        let (sender, receiver, pending) = MessageSender::channel(8);
        let retained = sender.clone();
        let (done, completed) = mpsc::channel();
        let writer = thread::spawn(move || {
            let mut bytes = Vec::new();
            write_messages(&mut bytes, &receiver, &pending, &|| true).unwrap();
            done.send(bytes).unwrap();
        });
        assert!(completed.recv_timeout(Duration::from_millis(30)).is_err());
        sender.close();
        assert!(completed
            .recv_timeout(Duration::from_secs(1))
            .unwrap()
            .is_empty());
        drop(retained);
        writer.join().unwrap();
    }

    #[test]
    fn writer_preserves_frame_order_and_does_not_transmit_close() {
        let (sender, receiver, pending) = MessageSender::channel(8);
        let running = AtomicBool::new(true);
        enqueue_message(&sender, b"first".to_vec(), Duration::from_secs(1), &running).unwrap();
        enqueue_message(&sender, b"next".to_vec(), Duration::from_secs(1), &running).unwrap();
        sender.close();
        let mut bytes = Vec::new();
        write_messages(&mut bytes, &receiver, &pending, &|| true).unwrap();
        assert_eq!(bytes, b"\x05\x00\x00\x00first\x04\x00\x00\x00next");
        assert_eq!(pending.load(Ordering::SeqCst), 0);
    }

    #[test]
    fn a_full_queue_can_close_after_the_connection_is_stopped() {
        let (sender, receiver, pending) = MessageSender::channel(1);
        enqueue_message(
            &sender,
            b"queued".to_vec(),
            Duration::from_secs(1),
            &AtomicBool::new(true),
        )
        .unwrap();
        let writer = thread::spawn(move || {
            let mut bytes = Vec::new();
            write_messages(&mut bytes, &receiver, &pending, &|| false).unwrap();
            bytes
        });
        sender.close();
        assert!(writer.join().unwrap().is_empty());
    }

    #[test]
    fn closing_a_full_queue_does_not_wait_for_the_writer_to_start() {
        let (sender, receiver, pending) = MessageSender::channel(1);
        enqueue_message(
            &sender,
            b"queued".to_vec(),
            Duration::from_secs(1),
            &AtomicBool::new(true),
        )
        .unwrap();
        let (done, completed) = mpsc::channel();
        let closer = thread::spawn(move || {
            sender.close();
            done.send(()).unwrap();
        });
        completed.recv_timeout(Duration::from_secs(1)).unwrap();
        let mut bytes = Vec::new();
        write_messages(&mut bytes, &receiver, &pending, &|| false).unwrap();
        assert!(bytes.is_empty());
        closer.join().unwrap();
    }

    #[test]
    fn enqueue_message_waits_for_a_draining_writer() {
        let (sender, rx, _) = MessageSender::channel(1);
        enqueue_message(
            &sender,
            b"first".to_vec(),
            Duration::from_secs(5),
            &AtomicBool::new(true),
        )
        .unwrap();
        let writer = thread::spawn(move || {
            thread::sleep(Duration::from_millis(30));
            (receive_data(&rx), receive_data(&rx))
        });

        enqueue_message(
            &sender,
            b"second".to_vec(),
            Duration::from_secs(5),
            &AtomicBool::new(true),
        )
        .unwrap();

        assert_eq!(
            writer.join().unwrap(),
            (b"first".to_vec(), b"second".to_vec())
        );
    }

    #[test]
    fn enqueue_message_gives_up_on_a_writer_that_never_drains() {
        let (sender, _rx, _) = MessageSender::channel(1);
        sender
            .tx
            .send(OutgoingMessage::Data(b"first".to_vec()))
            .unwrap();

        assert_eq!(
            enqueue_message(
                &sender,
                b"second".to_vec(),
                Duration::from_millis(20),
                &AtomicBool::new(true),
            )
            .unwrap_err(),
            "IPC send queue is full"
        );
    }

    #[test]
    fn enqueue_message_stops_waiting_once_the_server_is_stopped() {
        let (sender, _rx, _) = MessageSender::channel(1);
        sender
            .tx
            .send(OutgoingMessage::Data(b"first".to_vec()))
            .unwrap();
        let running = Arc::new(AtomicBool::new(true));
        let stopper = Arc::clone(&running);
        thread::spawn(move || {
            thread::sleep(Duration::from_millis(20));
            stopper.store(false, Ordering::SeqCst);
        });

        let started = Instant::now();
        let error = enqueue_message(
            &sender,
            b"second".to_vec(),
            Duration::from_secs(30),
            &running,
        )
        .unwrap_err();

        assert_eq!(error, "IPC server is stopped");
        assert!(started.elapsed() < Duration::from_secs(5));
    }

    #[test]
    fn enqueue_message_reports_a_gone_writer_without_waiting() {
        let (sender, rx, _) = MessageSender::channel(1);
        drop(rx);

        assert_eq!(
            enqueue_message(
                &sender,
                b"first".to_vec(),
                Duration::from_secs(30),
                &AtomicBool::new(true),
            )
            .unwrap_err(),
            "IPC client is disconnected"
        );
    }

    #[test]
    fn enqueue_message_caps_the_queue_by_bytes_before_the_slot_count() {
        let (sender, _rx, pending_bytes) = MessageSender::channel(MAX_PENDING_MESSAGES);
        enqueue_message(
            &sender,
            vec![0u8; MAX_PENDING_BYTES],
            Duration::from_secs(5),
            &AtomicBool::new(true),
        )
        .unwrap();

        assert_eq!(pending_bytes.load(Ordering::SeqCst), MAX_PENDING_BYTES);
        assert_eq!(
            enqueue_message(
                &sender,
                b"overflow".to_vec(),
                Duration::from_millis(20),
                &AtomicBool::new(true),
            )
            .unwrap_err(),
            "IPC send queue is full"
        );
        assert_eq!(pending_bytes.load(Ordering::SeqCst), MAX_PENDING_BYTES);
    }

    #[test]
    fn enqueue_message_admits_a_lone_frame_larger_than_the_budget() {
        let (sender, rx, pending_bytes) = MessageSender::channel(MAX_PENDING_MESSAGES);
        let len = MAX_PENDING_BYTES + 1;

        enqueue_message(
            &sender,
            vec![0u8; len],
            Duration::from_millis(20),
            &AtomicBool::new(true),
        )
        .unwrap();

        assert_eq!(pending_bytes.load(Ordering::SeqCst), len);
        assert_eq!(receive_data(&rx).len(), len);
    }

    #[test]
    fn draining_a_message_frees_its_share_of_the_budget() {
        let (sender, rx, pending_bytes) = MessageSender::channel(MAX_PENDING_MESSAGES);
        enqueue_message(
            &sender,
            vec![0u8; MAX_PENDING_BYTES],
            Duration::from_secs(5),
            &AtomicBool::new(true),
        )
        .unwrap();

        let drained = receive_data(&rx);
        pending_bytes.fetch_sub(drained.len(), Ordering::SeqCst);

        assert_eq!(pending_bytes.load(Ordering::SeqCst), 0);
        enqueue_message(
            &sender,
            b"next".to_vec(),
            Duration::from_millis(20),
            &AtomicBool::new(true),
        )
        .unwrap();
    }
}
