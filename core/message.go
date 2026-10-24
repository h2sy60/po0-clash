package main

import "time"

const (
	messageBatchInterval = 16 * time.Millisecond
	messageBatchSize     = 32
	messageQueueSize     = 256
	messagePriorityBurst = 8
	messageEvictAttempts = 4
)

var (
	stateMessageQueue    = make(chan Message, messageQueueSize)
	priorityMessageQueue = make(chan Message, messageQueueSize)
	bulkMessageQueue     = make(chan Message, messageQueueSize)
)

func init() {
	sender := newMessageBatchSender(deliverEvent)
	go runMessageBatcher(stateMessageQueue, priorityMessageQueue, bulkMessageQueue, sender.send)
}

type messageClass int

const (
	stateMessageClass messageClass = iota
	priorityMessageClass
	bulkMessageClass
)

func classOfMessage(message Message) messageClass {
	switch message.Type {
	case LoadedMessage, GeoUpdateMessage:
		return stateMessageClass
	case LogMessage, RequestMessage:
		return bulkMessageClass
	default:
		return priorityMessageClass
	}
}

func sendMessage(message Message) {
	switch classOfMessage(message) {
	case stateMessageClass:
		enqueueState(stateMessageQueue, message)
	case bulkMessageClass:
		enqueueLatest(bulkMessageQueue, message)
	default:
		enqueueLatest(priorityMessageQueue, message)
	}
}

func enqueueState(queue chan Message, message Message) {
	select {
	case queue <- message:
	default:
	}
}

func enqueueLatest(queue chan Message, message Message) {
	for attempt := 0; attempt < messageEvictAttempts; attempt++ {
		select {
		case queue <- message:
			return
		default:
		}

		select {
		case <-queue:
		default:
		}
	}
}

// send consumes a borrowed batch synchronously; it must not retain the slice.
func runMessageBatcher(
	stateMessages <-chan Message,
	priorityMessages <-chan Message,
	bulkMessages <-chan Message,
	send func([]Message),
) {
	timer := time.NewTimer(messageBatchInterval)
	if !timer.Stop() {
		<-timer.C
	}
	defer timer.Stop()

	var deadline <-chan time.Time
	batch := make([]Message, 0, messageBatchSize)

	flush := func() {
		if len(batch) == 0 {
			return
		}
		if !timer.Stop() {
			select {
			case <-timer.C:
			default:
			}
		}
		deadline = nil
		send(batch)
		clear(batch)
		batch = batch[:0]
	}
	appendMessage := func(message Message) {
		if len(batch) == 0 {
			timer.Reset(messageBatchInterval)
			deadline = timer.C
		}
		batch = append(batch, message)
		if len(batch) >= messageBatchSize {
			flush()
		}
	}

	priorityBurst := 0
	for stateMessages != nil || priorityMessages != nil || bulkMessages != nil {
		select {
		case message, ok := <-stateMessages:
			if !ok {
				stateMessages = nil
			} else {
				appendMessage(message)
			}
			continue
		default:
		}

		// Give bulk events one guaranteed opportunity after a bounded priority
		// burst, while retaining priority preference under ordinary load.
		if priorityBurst >= messagePriorityBurst && bulkMessages != nil {
			select {
			case message, ok := <-bulkMessages:
				if !ok {
					bulkMessages = nil
				} else {
					appendMessage(message)
				}
				priorityBurst = 0
				continue
			default:
				priorityBurst = 0
			}
		}

		select {
		case message, ok := <-priorityMessages:
			if !ok {
				priorityMessages = nil
			} else {
				appendMessage(message)
				priorityBurst++
			}
			continue
		default:
		}

		select {
		case message, ok := <-stateMessages:
			if !ok {
				stateMessages = nil
			} else {
				appendMessage(message)
			}
		case message, ok := <-priorityMessages:
			if !ok {
				priorityMessages = nil
			} else {
				appendMessage(message)
				priorityBurst++
			}
		case message, ok := <-bulkMessages:
			if !ok {
				bulkMessages = nil
			} else {
				appendMessage(message)
			}
			priorityBurst = 0
		case <-deadline:
			flush()
		}
	}
	flush()
}
