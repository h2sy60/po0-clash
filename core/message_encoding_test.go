package main

import (
	"bytes"
	"encoding/json"
	"runtime"
	"strings"
	"testing"
	"time"

	"github.com/metacubex/mihomo/log"
)

func TestMessageBatchSenderMatchesMarshal(t *testing.T) {
	for _, test := range []struct {
		name     string
		messages []Message
	}{
		{name: "nil"},
		{name: "empty", messages: []Message{}},
		{
			name: "mixed events and escaping",
			messages: []Message{
				{Type: LogMessage, Data: map[string]any{"payload": "<tag>&\n\"\\\u2028\u2029中文\xff"}},
				{Type: DelayMessage, Data: Delay{Url: "https://example.test/?a=1&b=2", Name: "节点", Value: -1}},
				requestMessage(newBufferedTracker()),
				{Type: LoadedMessage, Data: "subscription"},
				{Type: GeoUpdateMessage, Data: GeoUpdateStatus{Type: "geoip", Updating: false, Error: "<failed>"}},
			},
		},
	} {
		t.Run(test.name, func(t *testing.T) {
			want, err := json.Marshal(messageBatchCall{Method: messageMethod, Arguments: test.messages})
			if err != nil {
				t.Fatal(err)
			}
			delivered := false
			sender := newMessageBatchSender(func(data []byte) {
				delivered = true
				if !bytes.Equal(data, want) {
					t.Fatalf("batch encoding changed: got %s, want %s", data, want)
				}
			})
			sender.send(test.messages)
			if !delivered {
				t.Fatal("encoded batch was not delivered")
			}
		})
	}
}

func TestMessageBatchSenderRecoversAfterEncodeFailure(t *testing.T) {
	var batches [][]byte
	sender := newMessageBatchSender(func(data []byte) {
		batches = append(batches, bytes.Clone(data))
	})
	sender.send([]Message{{Type: LoadedMessage, Data: "before"}})
	sender.send([]Message{{Type: LogMessage, Data: make(chan int)}})
	sender.send([]Message{{Type: LoadedMessage, Data: "after"}})
	if len(batches) != 2 {
		t.Fatalf("delivered %d batches, want 2 valid batches", len(batches))
	}
	want := `{"method":"message","arguments":[{"type":"loaded","data":"after"}]}`
	if string(batches[1]) != want {
		t.Fatalf("failed encode contaminated the next batch: %s", batches[1])
	}
}

func TestMessageBatchSenderReusesAndBoundsBuffer(t *testing.T) {
	var first *byte
	var delivered int
	sender := newMessageBatchSender(func(data []byte) {
		delivered++
		if !json.Valid(data) {
			t.Fatal("delivered invalid JSON")
		}
		if delivered == 1 {
			first = &data[0]
		} else if delivered == 2 && first != &data[0] {
			t.Error("ordinary batches did not reuse encoding storage")
		}
	})
	small := []Message{{Type: LogMessage, Data: strings.Repeat("x", 1024)}}
	sender.send(small)
	sender.send(small)
	if cap(sender.buffer) == 0 {
		t.Fatal("ordinary batch storage was discarded")
	}
	sender.send([]Message{{Type: LogMessage, Data: strings.Repeat("x", maxRetainedMessageBatchSize)}})
	if cap(sender.buffer) != 0 {
		t.Fatalf("retained an oversized encoding buffer: %d bytes", cap(sender.buffer))
	}
	sender.send(small)
	if delivered != 4 {
		t.Fatalf("delivered %d batches, want 4", delivered)
	}
	if cap(sender.buffer) > maxRetainedMessageBatchSize {
		t.Fatal("small batches retained oversized storage")
	}
}

func encodeFinalizedTracker(sender *messageBatchSender) <-chan struct{} {
	collected := make(chan struct{})
	tracker := newBufferedTracker()
	runtime.SetFinalizer(tracker, func(*bufferedTracker) { close(collected) })
	sender.send([]Message{{Type: RequestMessage, Data: tracker}})
	return collected
}

func TestMessageBatchSenderDoesNotRetainEncodedEvents(t *testing.T) {
	sender := newMessageBatchSender(func([]byte) {})
	collected := encodeFinalizedTracker(sender)
	runtime.GC()
	select {
	case <-collected:
	case <-time.After(5 * time.Second):
		t.Fatal("idle encoder retained a delivered event and its transport")
	}
	runtime.KeepAlive(sender)
}

func BenchmarkMessageBatchEncoding(b *testing.B) {
	for _, name := range []string{"logs", "requests", "requests_unicode", "delays", "delay_pointers"} {
		messages := make([]Message, messageBatchSize)
		for index := range messages {
			switch name {
			case "logs":
				messages[index] = Message{Type: LogMessage, Data: log.Event{LogLevel: log.INFO, Payload: "[TCP] 127.0.0.1:443 --> example.test:443 match MATCH using group[node]"}}
			case "requests":
				messages[index] = requestMessage(newBufferedTracker())
			case "requests_unicode":
				messages[index] = Message{Type: RequestMessage, Data: populatedRequestInfo("🇯🇵 日本节点 <group>\\\"\u2028")}
			case "delays":
				messages[index] = Message{Type: DelayMessage, Data: Delay{Url: defaultTestURL, Name: "node", Value: 123}}
			case "delay_pointers":
				messages[index] = Message{Type: DelayMessage, Data: &Delay{Url: defaultTestURL, Name: "节点🚀", Value: 123}}
			}
		}
		b.Run(name+"/marshal", func(b *testing.B) {
			var delivered int
			b.ReportAllocs()
			for index := 0; index < b.N; index++ {
				data, err := json.Marshal(messageBatchCall{Method: messageMethod, Arguments: messages})
				if err != nil {
					b.Fatal(err)
				}
				delivered += len(data)
			}
			if delivered == 0 {
				b.Fatal("encoded no event data")
			}
		})
		b.Run(name+"/reused", func(b *testing.B) {
			var delivered int
			sender := newMessageBatchSender(func(data []byte) { delivered += len(data) })
			sender.send(messages)
			delivered = 0
			b.ReportAllocs()
			b.ResetTimer()
			for index := 0; index < b.N; index++ {
				sender.send(messages)
			}
			if delivered == 0 {
				b.Fatal("encoded no event data")
			}
		})
	}
}
