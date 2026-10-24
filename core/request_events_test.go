package main

import (
	"bytes"
	"encoding/json"
	"runtime"
	"testing"
	"time"

	"github.com/metacubex/mihomo/common/atomic"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel/statistic"
)

type bufferedTracker struct {
	*statistic.TrackerInfo
	transport []byte
}

func (tracker *bufferedTracker) ID() string                     { return tracker.UUID.String() }
func (tracker *bufferedTracker) Close() error                   { return nil }
func (tracker *bufferedTracker) Info() *statistic.TrackerInfo   { return tracker.TrackerInfo }
func (tracker *bufferedTracker) Chains() constant.Chain         { return tracker.Chain }
func (tracker *bufferedTracker) ProviderChains() constant.Chain { return tracker.ProviderChain }
func (tracker *bufferedTracker) AppendToChains(adapter constant.ProxyAdapter) {
	tracker.Chain = append(tracker.Chain, adapter.Name())
}
func (tracker *bufferedTracker) RemoteDestination() string { return "example.test:443" }

func newBufferedTracker() *bufferedTracker {
	return &bufferedTracker{
		TrackerInfo: &statistic.TrackerInfo{
			Metadata:      &constant.Metadata{Host: "example.test", DstPort: 443, Process: "test"},
			UploadTotal:   atomic.NewInt64(123),
			DownloadTotal: atomic.NewInt64(456),
			Start:         time.Unix(1700000000, 0).UTC(),
			Chain:         constant.Chain{"node", "group"},
			ProviderChain: constant.Chain{"subscription"},
			Rule:          "MATCH",
			RulePayload:   "example.test",
		},
		transport: make([]byte, 64*1024),
	}
}

func TestRequestMessageKeepsWireFieldsAndLiveCounters(t *testing.T) {
	tracker := newBufferedTracker()
	message := requestMessage(tracker)
	tracker.UploadTotal.Add(17)
	want, err := json.Marshal(Message{Type: RequestMessage, Data: tracker})
	if err != nil {
		t.Fatal(err)
	}
	got, err := json.Marshal(message)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(got, want) {
		t.Fatalf("request payload changed: got %s, want %s", got, want)
	}
	if message.Data != tracker.Info() {
		t.Fatal("request event did not retain the tracker's display information")
	}
}

func finalizedRequest() (Message, <-chan struct{}) {
	collected := make(chan struct{})
	tracker := newBufferedTracker()
	runtime.SetFinalizer(tracker, func(*bufferedTracker) { close(collected) })
	return requestMessage(tracker), collected
}

func TestQueuedRequestDoesNotRetainTheTransport(t *testing.T) {
	message, collected := finalizedRequest()
	runtime.GC()
	select {
	case <-collected:
	case <-time.After(5 * time.Second):
		t.Fatal("pending request retained the transport after its owner released it")
	}
	runtime.KeepAlive(message)
}

func BenchmarkRequestQueueRetention(b *testing.B) {
	for _, detach := range []bool{false, true} {
		name := "transport"
		if detach {
			name = "info"
		}
		b.Run(name, func(b *testing.B) {
			for i := 0; i < b.N; i++ {
				runtime.GC()
				var before runtime.MemStats
				runtime.ReadMemStats(&before)
				pending := make([]Message, messageQueueSize)
				for index := range pending {
					tracker := newBufferedTracker()
					if detach {
						pending[index] = requestMessage(tracker)
					} else {
						pending[index] = Message{Type: RequestMessage, Data: tracker}
					}
				}
				runtime.GC()
				var after runtime.MemStats
				runtime.ReadMemStats(&after)
				if after.HeapAlloc > before.HeapAlloc {
					b.ReportMetric(float64(after.HeapAlloc-before.HeapAlloc), "retained-B/queue")
				}
				runtime.KeepAlive(pending)
			}
		})
	}
}
