use std::io;
#[cfg(unix)]
use std::{
    io::{Read, Write},
    os::fd::{AsFd, AsRawFd},
    os::unix::net::UnixStream,
};

pub struct Wakeup {
    #[cfg(unix)]
    reader: UnixStream,
    #[cfg(unix)]
    writer: UnixStream,
}

impl Wakeup {
    pub fn new() -> io::Result<Self> {
        #[cfg(unix)]
        {
            let (reader, writer) = UnixStream::pair()?;
            reader.set_nonblocking(true)?;
            writer.set_nonblocking(true)?;
            Ok(Self { reader, writer })
        }
        #[cfg(not(unix))]
        {
            Ok(Self {})
        }
    }

    pub fn notify(&self) -> io::Result<()> {
        #[cfg(unix)]
        {
            let mut writer = &self.writer;
            loop {
                match writer.write(&[1]) {
                    Ok(_) => return Ok(()),
                    Err(error) if error.kind() == io::ErrorKind::Interrupted => continue,
                    Err(error) if error.kind() == io::ErrorKind::WouldBlock => return Ok(()),
                    Err(error) => return Err(error),
                }
            }
        }
        #[cfg(not(unix))]
        {
            Ok(())
        }
    }

    #[cfg(unix)]
    pub fn wait(&self, socket: &impl AsFd) -> io::Result<()> {
        let mut descriptors = [
            libc::pollfd {
                fd: socket.as_fd().as_raw_fd(),
                events: libc::POLLIN,
                revents: 0,
            },
            libc::pollfd {
                fd: self.reader.as_raw_fd(),
                events: libc::POLLIN,
                revents: 0,
            },
        ];
        loop {
            // SAFETY: both descriptors stay borrowed and the array remains valid throughout poll.
            let result = unsafe {
                libc::poll(
                    descriptors.as_mut_ptr(),
                    descriptors.len() as libc::nfds_t,
                    -1,
                )
            };
            if result < 0 {
                let error = io::Error::last_os_error();
                if error.kind() == io::ErrorKind::Interrupted {
                    continue;
                }
                return Err(error);
            }
            if descriptors
                .iter()
                .any(|descriptor| descriptor.revents & libc::POLLNVAL != 0)
            {
                return Err(io::Error::new(
                    io::ErrorKind::InvalidInput,
                    "invalid IPC descriptor",
                ));
            }
            if descriptors[1].revents != 0 {
                self.drain()?;
            }
            if result != 0 {
                return Ok(());
            }
        }
    }

    #[cfg(unix)]
    fn drain(&self) -> io::Result<()> {
        let mut reader = &self.reader;
        let mut bytes = [0; 128];
        loop {
            match reader.read(&mut bytes) {
                Ok(0) => return Ok(()),
                Ok(_) => continue,
                Err(error) if error.kind() == io::ErrorKind::Interrupted => continue,
                Err(error) if error.kind() == io::ErrorKind::WouldBlock => return Ok(()),
                Err(error) => return Err(error),
            }
        }
    }
}

#[cfg(all(test, unix))]
mod tests {
    use super::*;
    use std::{
        sync::{mpsc, Arc},
        thread,
        time::Duration,
    };

    fn waiter(
        wakeup: Arc<Wakeup>,
        stream: UnixStream,
    ) -> (mpsc::Receiver<io::Result<()>>, thread::JoinHandle<()>) {
        let (done, completed) = mpsc::channel();
        let worker = thread::spawn(move || {
            done.send(wakeup.wait(&stream)).unwrap();
        });
        (completed, worker)
    }

    #[test]
    fn idle_reader_waits_until_data_is_ready() {
        let wakeup = Arc::new(Wakeup::new().unwrap());
        let (stream, mut peer) = UnixStream::pair().unwrap();
        let (done, worker) = waiter(wakeup, stream);
        assert!(done.recv_timeout(Duration::from_millis(80)).is_err());
        peer.write_all(b"x").unwrap();
        done.recv_timeout(Duration::from_secs(1)).unwrap().unwrap();
        worker.join().unwrap();
    }

    #[test]
    fn stop_wakes_an_idle_reader_without_a_peer_message() {
        let wakeup = Arc::new(Wakeup::new().unwrap());
        let (stream, _peer) = UnixStream::pair().unwrap();
        let (done, worker) = waiter(Arc::clone(&wakeup), stream);
        assert!(done.recv_timeout(Duration::from_millis(80)).is_err());
        wakeup.notify().unwrap();
        done.recv_timeout(Duration::from_secs(1)).unwrap().unwrap();
        worker.join().unwrap();
    }

    #[test]
    fn a_notification_before_wait_is_not_lost_or_left_pending() {
        let wakeup = Arc::new(Wakeup::new().unwrap());
        let (stream, peer) = UnixStream::pair().unwrap();
        wakeup.notify().unwrap();
        wakeup.wait(&stream).unwrap();
        let (done, worker) = waiter(Arc::clone(&wakeup), stream);
        assert!(done.recv_timeout(Duration::from_millis(80)).is_err());
        drop(peer);
        done.recv_timeout(Duration::from_secs(1)).unwrap().unwrap();
        worker.join().unwrap();
    }

    #[test]
    fn repeated_notifications_coalesce_without_blocking() {
        let wakeup = Wakeup::new().unwrap();
        for _ in 0..100000 {
            wakeup.notify().unwrap();
        }
        let (stream, _peer) = UnixStream::pair().unwrap();
        wakeup.wait(&stream).unwrap();
    }
}
