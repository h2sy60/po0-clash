package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/json"
	"math"
	"math/rand"
	"net/netip"
	"reflect"
	"testing"
	"time"

	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/log"
	"github.com/metacubex/mihomo/tunnel/statistic"
)

func assertFastBatchMatchesMarshal(t testing.TB, messages []Message) {
	t.Helper()
	want, err := json.Marshal(messageBatchCall{Method: messageMethod, Arguments: messages})
	got, ok := appendMessageBatchJSON(nil, messages)
	if err != nil {
		if ok {
			t.Fatalf("fast encoder accepted a batch rejected by Marshal: %v", err)
		}
		return
	}
	if !ok {
		t.Fatal("fast encoder rejected a supported event")
	}
	if !bytes.Equal(got, want) {
		t.Fatalf("event JSON differs:\ngot  %s\nwant %s", got, want)
	}
}

func populatedRequestInfo(value string) *statistic.TrackerInfo {
	info := new(statistic.TrackerInfo)
	digest := sha256.Sum256([]byte(value))
	copy(info.UUID[:], digest[:16])
	info.Metadata = &constant.Metadata{
		NetWork: constant.UDP, Type: constant.TUN,
		SrcIP: netip.MustParseAddr("::ffff:192.0.2.1"), DstIP: netip.MustParseAddr("2001:db8::1").WithZone("eth\"0\\中文\u2028"),
		SrcGeoIP: []string{}, DstGeoIP: []string{value}, SrcIPASN: value, DstIPASN: value,
		SrcPort: 1, DstPort: 65535, InIP: netip.MustParseAddr("192.0.2.2"), InPort: 1080,
		InName: value, InUser: value, RematchName: value, Host: value, DNSMode: constant.DNSFakeIP,
		Uid: math.MaxUint32, Process: value, ProcessPath: value, SpecialProxy: value,
		SpecialRules: value, RemoteDst: value, DSCP: 255, SniffHost: value,
	}
	info.UploadTotal.Store(math.MinInt64)
	info.DownloadTotal.Store(math.MaxInt64)
	info.Start = time.Date(2026, 10, 25, 4, 5, 6, 123456789, time.FixedZone("offset", -19823))
	info.Chain, info.ProviderChain = []string{value, "节点"}, []string{}
	info.Rule, info.RulePayload = value, value
	return info
}

func TestFastEventJSONMatchesEveryFieldAndNilForm(t *testing.T) {
	text := "\x00\b\f\n\r\t\"\\<>&\u2028\u2029中文🚀\xff"
	info := populatedRequestInfo(text)
	assertFastBatchMatchesMarshal(t, []Message{
		{Type: LogMessage, Data: log.Event{LogLevel: log.WARNING, Payload: text}},
		{Type: LogMessage, Data: &log.Event{LogLevel: log.LogLevel(-1), Payload: text}},
		{Type: DelayMessage, Data: Delay{Url: text, Name: text, Value: math.MinInt32}},
		{Type: DelayMessage, Data: &Delay{Url: text, Name: text, Value: math.MaxInt32}},
		{Type: LoadedMessage, Data: text},
		{Type: RequestMessage, Data: info},
		{Type: GeoUpdateMessage, Data: GeoUpdateStatus{Type: text}},
		{Type: GeoUpdateMessage, Data: &GeoUpdateStatus{Type: text, Updating: true, Skipped: true, Error: text}},
		{Type: "nil", Data: nil},
		{Type: "nil", Data: (*log.Event)(nil)},
		{Type: "nil", Data: (*Delay)(nil)},
		{Type: "nil", Data: (*GeoUpdateStatus)(nil)},
		{Type: "nil", Data: (*statistic.TrackerInfo)(nil)},
	})
	info.Metadata = nil
	info.Chain, info.ProviderChain = nil, nil
	assertFastBatchMatchesMarshal(t, []Message{{Type: RequestMessage, Data: info}})
	info = &statistic.TrackerInfo{Metadata: &constant.Metadata{}}
	assertFastBatchMatchesMarshal(t, []Message{{Type: RequestMessage, Data: info}})
	assertFastBatchMatchesMarshal(t, nil)
	assertFastBatchMatchesMarshal(t, []Message{})
}

func TestFastRequestJSONPreservesTimeValidationAndLiveCounters(t *testing.T) {
	info := populatedRequestInfo("example.test")
	for _, start := range []time.Time{
		{}, time.Now(),
		time.Date(0, 1, 1, 0, 0, 0, 0, time.UTC),
		time.Date(9999, 12, 31, 23, 59, 59, 999999999, time.UTC),
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.FixedZone("east", 86399)),
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.FixedZone("west", -86399)),
		time.Date(-1, 1, 1, 0, 0, 0, 0, time.UTC),
		time.Date(10000, 1, 1, 0, 0, 0, 0, time.UTC),
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.FixedZone("invalid", 86400)),
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.FixedZone("invalid", -86400)),
	} {
		info.Start = start
		info.UploadTotal.Add(1)
		info.DownloadTotal.Add(-1)
		assertFastBatchMatchesMarshal(t, []Message{{Type: RequestMessage, Data: info}})
	}
}

func TestFastJSONSchemaTracksUpstreamFields(t *testing.T) {
	for _, test := range []struct {
		value any
		tags  []string
	}{
		{Message{}, []string{"type", "data"}},
		{messageBatchCall{}, []string{"method", "arguments"}},
		{log.Event{}, []string{"LogLevel", "Payload"}},
		{Delay{}, []string{"url", "name", "value"}},
		{GeoUpdateStatus{}, []string{"type", "updating", "skipped,omitempty", "error,omitempty"}},
		{statistic.TrackerInfo{}, []string{"id", "metadata", "upload", "download", "start", "chains", "providerChains", "rule", "rulePayload"}},
		{constant.Metadata{}, []string{
			"network", "type", "sourceIP", "destinationIP", "sourceGeoIP", "destinationGeoIP", "sourceIPASN", "destinationIPASN",
			"sourcePort,string", "destinationPort,string", "inboundIP", "inboundPort,string", "inboundName", "inboundUser", "rematchName",
			"host", "dnsMode", "uid", "process", "processPath", "specialProxy", "specialRules", "remoteDestination", "dscp", "sniffHost",
		}},
	} {
		typeOf := reflect.TypeOf(test.value)
		var tags []string
		for index := 0; index < typeOf.NumField(); index++ {
			field := typeOf.Field(index)
			if field.PkgPath != "" || field.Tag.Get("json") == "-" {
				continue
			}
			tag := field.Tag.Get("json")
			if tag == "" {
				tag = field.Name
			}
			tags = append(tags, tag)
		}
		if !reflect.DeepEqual(tags, test.tags) {
			t.Errorf("%s wire fields changed: got %v, want %v; update the event encoder", typeOf, tags, test.tags)
		}
	}
}

func TestEventJSONFallbackStillUsesStandardMarshaling(t *testing.T) {
	for _, messages := range [][]Message{
		{{Type: LogMessage, Data: map[string]any{"nested": []any{"中文", nil, 1.25}}}},
		{{Type: RequestMessage, Data: populatedRequestInfo("example.test")}, {Type: "extension", Data: map[int]string{1: "value"}}},
	} {
		if _, ok := appendMessageBatchJSON(nil, messages); ok {
			t.Fatal("an unknown payload bypassed the standard encoder")
		}
		want, err := json.Marshal(messageBatchCall{Method: messageMethod, Arguments: messages})
		if err != nil {
			t.Fatal(err)
		}
		newMessageBatchSender(func(data []byte) {
			if !bytes.Equal(data, want) {
				t.Fatalf("fallback JSON differs: got %s, want %s", data, want)
			}
		}).send(messages)
	}
}

func TestFastEventJSONRandomDifferential(t *testing.T) {
	random := rand.New(rand.NewSource(20261025))
	for index := 0; index < 3000; index++ {
		payload := make([]byte, random.Intn(384))
		_, _ = random.Read(payload)
		value, seed := string(payload), random.Int63()
		if index&1 != 0 {
			seed = -seed
		}
		want, err := json.Marshal(value)
		if err != nil {
			t.Fatal(err)
		}
		if got := appendJSONString(nil, value); !bytes.Equal(got, want) {
			t.Fatalf("string escaping differs for %x: got %s, want %s", payload, got, want)
		}
		info := populatedRequestInfo(value)
		info.Start = time.Date(int(uint64(seed)%10000), 7, 15, 12, 34, 56, int(seed%1e9), time.FixedZone("random", int(seed%86400)))
		info.UploadTotal.Store(seed)
		info.DownloadTotal.Store(-seed)
		info.Metadata.NetWork = constant.NetWork(seed & 255)
		info.Metadata.Type = constant.Type(seed % 32)
		info.Metadata.DNSMode = constant.DNSMode((seed >> 8) & 15)
		info.Metadata.SrcPort = uint16(seed)
		info.Metadata.DstPort = uint16(seed >> 16)
		info.Metadata.Uid = uint32(seed)
		info.Metadata.DSCP = uint8(seed)
		assertFastBatchMatchesMarshal(t, []Message{
			{Type: MessageType(value), Data: info},
			{Type: LogMessage, Data: log.Event{LogLevel: log.LogLevel(seed % 8), Payload: value}},
			{Type: DelayMessage, Data: &Delay{Url: value, Name: value, Value: int32(seed)}},
			{Type: GeoUpdateMessage, Data: GeoUpdateStatus{Type: value, Updating: seed&1 != 0, Skipped: seed&2 != 0, Error: value}},
		})
	}
}
