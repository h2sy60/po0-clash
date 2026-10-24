package main

import (
	"encoding/hex"
	"net/netip"
	"strconv"
	"time"
	"unicode/utf8"

	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/log"
	"github.com/metacubex/mihomo/tunnel/statistic"
)

func appendMessageBatchJSON(data []byte, messages []Message) ([]byte, bool) {
	data = append(data, `{"method":"message","arguments":`...)
	if messages == nil {
		return append(data, `null}`...), true
	}
	data = append(data, '[')
	for index, message := range messages {
		if index != 0 {
			data = append(data, ',')
		}
		data = append(data, `{"type":`...)
		data = appendJSONString(data, string(message.Type))
		data = append(data, `,"data":`...)
		var ok bool
		data, ok = appendEventJSON(data, message.Data)
		if !ok {
			return data, false
		}
		data = append(data, '}')
	}
	return append(data, ']', '}'), true
}

func appendEventJSON(data []byte, value any) ([]byte, bool) {
	switch value := value.(type) {
	case nil:
		return append(data, "null"...), true
	case string:
		return appendJSONString(data, value), true
	case log.Event:
		data = append(data, `{"LogLevel":`...)
		data = appendJSONString(data, value.LogLevel.String())
		data = append(data, `,"Payload":`...)
		return append(appendJSONString(data, value.Payload), '}'), true
	case *log.Event:
		if value != nil {
			return appendEventJSON(data, *value)
		}
	case Delay:
		data = append(data, `{"url":`...)
		data = appendJSONString(data, value.Url)
		data = append(data, `,"name":`...)
		data = appendJSONString(data, value.Name)
		data = append(data, `,"value":`...)
		return append(strconv.AppendInt(data, int64(value.Value), 10), '}'), true
	case *Delay:
		if value != nil {
			return appendEventJSON(data, *value)
		}
	case GeoUpdateStatus:
		data = append(data, `{"type":`...)
		data = appendJSONString(data, value.Type)
		data = append(data, `,"updating":`...)
		data = strconv.AppendBool(data, value.Updating)
		if value.Skipped {
			data = append(data, `,"skipped":true`...)
		}
		if value.Error != "" {
			data = append(data, `,"error":`...)
			data = appendJSONString(data, value.Error)
		}
		return append(data, '}'), true
	case *GeoUpdateStatus:
		if value != nil {
			return appendEventJSON(data, *value)
		}
	case *statistic.TrackerInfo:
		if value != nil {
			return appendRequestJSON(data, value)
		}
	default:
		return data, false
	}
	return append(data, "null"...), true
}

func appendRequestJSON(data []byte, info *statistic.TrackerInfo) ([]byte, bool) {
	var id [36]byte
	hex.Encode(id[:8], info.UUID[:4])
	hex.Encode(id[9:13], info.UUID[4:6])
	hex.Encode(id[14:18], info.UUID[6:8])
	hex.Encode(id[19:23], info.UUID[8:10])
	hex.Encode(id[24:], info.UUID[10:])
	id[8], id[13], id[18], id[23] = '-', '-', '-', '-'
	data = append(data, `{"id":"`...)
	data = append(data, id[:]...)
	data = append(data, `","metadata":`...)
	data = appendMetadataJSON(data, info.Metadata)
	data = append(data, `,"upload":`...)
	data = strconv.AppendInt(data, info.UploadTotal.Load(), 10)
	data = append(data, `,"download":`...)
	data = strconv.AppendInt(data, info.DownloadTotal.Load(), 10)
	data = append(data, `,"start":`...)
	var ok bool
	data, ok = appendJSONTime(data, info.Start)
	if !ok {
		return data, false
	}
	data = append(data, `,"chains":`...)
	data = appendJSONStrings(data, info.Chain)
	data = append(data, `,"providerChains":`...)
	data = appendJSONStrings(data, info.ProviderChain)
	data = append(data, `,"rule":`...)
	data = appendJSONString(data, info.Rule)
	data = append(data, `,"rulePayload":`...)
	return append(appendJSONString(data, info.RulePayload), '}'), true
}

func appendJSONTime(data []byte, value time.Time) ([]byte, bool) {
	data = append(data, '"')
	start := len(data)
	data = value.AppendFormat(data, time.RFC3339Nano)
	if data[start+4] != '-' {
		return data, false
	}
	if data[len(data)-1] != 'Z' {
		zone := data[len(data)-6:]
		if (zone[0] != '+' && zone[0] != '-') || zone[1] > '2' || (zone[1] == '2' && zone[2] > '3') {
			return data, false
		}
	}
	return append(data, '"'), true
}

func appendMetadataJSON(data []byte, metadata *constant.Metadata) []byte {
	if metadata == nil {
		return append(data, "null"...)
	}
	data = append(data, `{"network":`...)
	data = appendJSONString(data, metadata.NetWork.String())
	data = append(data, `,"type":`...)
	data = appendJSONString(data, metadata.Type.String())
	data = append(data, `,"sourceIP":`...)
	data = appendIPAddressJSON(data, metadata.SrcIP)
	data = append(data, `,"destinationIP":`...)
	data = appendIPAddressJSON(data, metadata.DstIP)
	data = append(data, `,"sourceGeoIP":`...)
	data = appendJSONStrings(data, metadata.SrcGeoIP)
	data = append(data, `,"destinationGeoIP":`...)
	data = appendJSONStrings(data, metadata.DstGeoIP)
	data = append(data, `,"sourceIPASN":`...)
	data = appendJSONString(data, metadata.SrcIPASN)
	data = append(data, `,"destinationIPASN":`...)
	data = appendJSONString(data, metadata.DstIPASN)
	data = append(data, `,"sourcePort":"`...)
	data = strconv.AppendUint(data, uint64(metadata.SrcPort), 10)
	data = append(data, `","destinationPort":"`...)
	data = strconv.AppendUint(data, uint64(metadata.DstPort), 10)
	data = append(data, `","inboundIP":`...)
	data = appendIPAddressJSON(data, metadata.InIP)
	data = append(data, `,"inboundPort":"`...)
	data = strconv.AppendUint(data, uint64(metadata.InPort), 10)
	data = append(data, `","inboundName":`...)
	data = appendJSONString(data, metadata.InName)
	data = append(data, `,"inboundUser":`...)
	data = appendJSONString(data, metadata.InUser)
	data = append(data, `,"rematchName":`...)
	data = appendJSONString(data, metadata.RematchName)
	data = append(data, `,"host":`...)
	data = appendJSONString(data, metadata.Host)
	data = append(data, `,"dnsMode":`...)
	data = appendJSONString(data, metadata.DNSMode.String())
	data = append(data, `,"uid":`...)
	data = strconv.AppendUint(data, uint64(metadata.Uid), 10)
	data = append(data, `,"process":`...)
	data = appendJSONString(data, metadata.Process)
	data = append(data, `,"processPath":`...)
	data = appendJSONString(data, metadata.ProcessPath)
	data = append(data, `,"specialProxy":`...)
	data = appendJSONString(data, metadata.SpecialProxy)
	data = append(data, `,"specialRules":`...)
	data = appendJSONString(data, metadata.SpecialRules)
	data = append(data, `,"remoteDestination":`...)
	data = appendJSONString(data, metadata.RemoteDst)
	data = append(data, `,"dscp":`...)
	data = strconv.AppendUint(data, uint64(metadata.DSCP), 10)
	data = append(data, `,"sniffHost":`...)
	return append(appendJSONString(data, metadata.SniffHost), '}')
}

func appendJSONStrings(data []byte, values []string) []byte {
	if values == nil {
		return append(data, "null"...)
	}
	data = append(data, '[')
	for index, value := range values {
		if index != 0 {
			data = append(data, ',')
		}
		data = appendJSONString(data, value)
	}
	return append(data, ']')
}

func appendIPAddressJSON(data []byte, address netip.Addr) []byte {
	data = append(data, '"')
	if address.IsValid() {
		if zone := address.Zone(); zone != "" {
			data = address.WithZone("").AppendTo(data)
			data = append(data, '%')
			data = appendJSONText(data, zone)
		} else {
			data = address.AppendTo(data)
		}
	}
	return append(data, '"')
}

func appendJSONString(data []byte, value string) []byte {
	if value == "" {
		return append(data, '"', '"')
	}
	data = append(data, '"')
	return append(appendJSONText(data, value), '"')
}

func appendJSONText(data []byte, value string) []byte {
	const digits = "0123456789abcdef"
	start := 0
	for index := 0; index < len(value); {
		character := value[index]
		if character >= utf8.RuneSelf {
			r, size := utf8.DecodeRuneInString(value[index:])
			if r == utf8.RuneError && size == 1 {
				data = append(data, value[start:index]...)
				data = append(data, `\ufffd`...)
				start = index + 1
			} else if r == '\u2028' || r == '\u2029' {
				data = append(data, value[start:index]...)
				data = append(data, '\\', 'u', '2', '0', '2', digits[r&15])
				start = index + size
			}
			index += size
			continue
		}
		if character >= ' ' && character != '"' && character != '\\' && character != '<' && character != '>' && character != '&' {
			index++
			continue
		}
		data = append(data, value[start:index]...)
		switch character {
		case '"', '\\':
			data = append(data, '\\', character)
		case '\n':
			data = append(data, `\n`...)
		case '\r':
			data = append(data, `\r`...)
		case '\t':
			data = append(data, `\t`...)
		case '\b':
			data = append(data, `\b`...)
		case '\f':
			data = append(data, `\f`...)
		default:
			data = append(data, '\\', 'u', '0', '0', digits[character>>4], digits[character&15])
		}
		index++
		start = index
	}
	return append(data, value[start:]...)
}
