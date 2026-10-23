//go:build !(android && cgo)

package main

import (
	"bytes"
	"encoding/binary"
	"encoding/json"
	"testing"
)

func framedPayload(payload []byte) []byte {
	frame := make([]byte, 4+len(payload))
	binary.LittleEndian.PutUint32(frame, uint32(len(payload)))
	copy(frame[4:], payload)
	return frame
}

func TestIPCReaderArgumentsSurviveBufferReuse(t *testing.T) {
	reader := ipcFrameReader{}
	data, err := reader.read(bytes.NewReader(framedPayload([]byte(`{"id":"first","method":"changeProxy","arguments":{"groupName":"test","proxyName":"original"}}`))))
	if err != nil {
		t.Fatal(err)
	}
	var call MethodCall
	if err := json.Unmarshal(data, &call); err != nil {
		t.Fatal(err)
	}
	arguments := string(call.Arguments)
	if _, err := reader.read(bytes.NewReader(framedPayload(bytes.Repeat([]byte{'x'}, len(data))))); err != nil {
		t.Fatal(err)
	}
	if call.ID != "first" || string(call.Arguments) != arguments {
		t.Fatal("asynchronous dispatch retained the reused receive buffer")
	}
}

func TestIPCReaderBoundsRetainedMemory(t *testing.T) {
	reader := ipcFrameReader{}
	for _, size := range []int{32, maxRetainedIPCFrameSize, maxRetainedIPCFrameSize * 2, 8, 0} {
		payload := bytes.Repeat([]byte{'x'}, size)
		data, err := reader.read(bytes.NewReader(framedPayload(payload)))
		if err != nil {
			t.Fatal(err)
		}
		if !bytes.Equal(data, payload) {
			t.Fatalf("incorrect payload for size %d", size)
		}
		if cap(reader.buffer) > maxRetainedIPCFrameSize {
			t.Fatalf("retained a %d byte buffer", cap(reader.buffer))
		}
	}
}

func TestIPCReaderRejectsOversizedFrameBeforeAllocation(t *testing.T) {
	reader := ipcFrameReader{}
	header := make([]byte, 4)
	binary.LittleEndian.PutUint32(header, maxIPCFrameSize+1)
	if _, err := reader.read(bytes.NewReader(header)); err == nil {
		t.Fatal("accepted an oversized frame")
	}
	if cap(reader.buffer) != 0 {
		t.Fatal("allocated memory for an invalid frame")
	}
}

func BenchmarkIPCReadFresh(b *testing.B) {
	payload := framedPayload(bytes.Repeat([]byte{'x'}, 1024))
	source := bytes.NewReader(payload)
	b.ReportAllocs()
	b.SetBytes(1024)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		source.Reset(payload)
		if _, err := readFrame(source); err != nil {
			b.Fatal(err)
		}
	}
}

func BenchmarkIPCReadReused(b *testing.B) {
	payload := framedPayload(bytes.Repeat([]byte{'x'}, 1024))
	source := bytes.NewReader(payload)
	reader := ipcFrameReader{}
	b.ReportAllocs()
	b.SetBytes(1024)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		source.Reset(payload)
		if _, err := reader.read(source); err != nil {
			b.Fatal(err)
		}
	}
}
