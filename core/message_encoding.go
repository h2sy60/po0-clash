package main

import (
	"bytes"
	"encoding/json"
)

const maxRetainedMessageBatchSize = 256 * 1024

type messageBatchCall struct {
	Method    CoreMethod `json:"method"`
	Arguments []Message  `json:"arguments"`
}

type messageBatchSender struct {
	buffer   []byte
	fallback bytes.Buffer
	encoder  *json.Encoder
	call     messageBatchCall
	deliver  func([]byte)
}

// The batcher owns this sender; deliver must consume its borrowed bytes synchronously.
func newMessageBatchSender(deliver func([]byte)) *messageBatchSender {
	sender := &messageBatchSender{
		call:    messageBatchCall{Method: messageMethod},
		deliver: deliver,
	}
	sender.encoder = json.NewEncoder(&sender.fallback)
	return sender
}

func (sender *messageBatchSender) send(messages []Message) {
	data, encoded := appendMessageBatchJSON(sender.buffer[:0], messages)
	var err error
	if !encoded {
		sender.fallback = *bytes.NewBuffer(data[:0])
		sender.call.Arguments = messages
		err = sender.encoder.Encode(&sender.call)
		sender.call.Arguments = nil
		data = sender.fallback.Bytes()
		sender.fallback = bytes.Buffer{}
		if err == nil {
			data = data[:len(data)-1]
		}
	}
	sender.buffer = data
	if err != nil {
		logError("Message batch marshal error: %v", err)
	} else {
		sender.deliver(data)
	}
	if cap(sender.buffer) > maxRetainedMessageBatchSize {
		sender.buffer = nil
	}
}
