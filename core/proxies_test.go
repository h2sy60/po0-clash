package main

import (
	"encoding/json"
	"fmt"
	"reflect"
	"testing"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/outboundgroup"
	"github.com/metacubex/mihomo/adapter/provider"
	"github.com/metacubex/mihomo/config"
	"github.com/metacubex/mihomo/constant"
	cp "github.com/metacubex/mihomo/constant/provider"
	"github.com/metacubex/mihomo/tunnel"
)

func snapshotGroup(t testing.TB, groupType constant.AdapterType, count int) constant.Proxy {
	t.Helper()
	members := make([]constant.Proxy, count)
	for i := range members {
		members[i] = namedProxy(fmt.Sprintf("node-%04d", i))
	}
	health := provider.NewHealthCheck(members, "", 0, 0, true, nil)
	pd, err := provider.NewCompatibleProvider("subscription", members, health)
	if err != nil {
		t.Fatal(err)
	}
	options := outboundgroup.GroupCommonOption{
		Name: "subscription", URL: "https://example.test/delay", Hidden: true, Icon: "icon.svg",
	}
	providers := []cp.ProxyProvider{pd}
	fallback := namedProxy("DIRECT")
	var group constant.ProxyAdapter
	switch groupType {
	case constant.Selector:
		group, err = outboundgroup.NewSelector(options, outboundgroup.SelectorOption{DefaultSelected: "node-0001"}, fallback, providers)
	case constant.URLTest:
		group, err = outboundgroup.NewURLTest(options, outboundgroup.URLTestOption{}, fallback, providers)
	case constant.Fallback:
		group, err = outboundgroup.NewFallback(options, outboundgroup.FallbackOption{}, fallback, providers)
	case constant.LoadBalance:
		group, err = outboundgroup.NewLoadBalance(options, outboundgroup.LoadBalanceOption{}, fallback, providers)
	default:
		t.Fatalf("unsupported test group %s", groupType)
	}
	if err != nil {
		t.Fatal(err)
	}
	return adapter.NewProxy(group)
}

func TestProxySnapshotPreservesGroupDisplayFields(t *testing.T) {
	for _, groupType := range []constant.AdapterType{constant.Selector, constant.URLTest, constant.Fallback, constant.LoadBalance} {
		t.Run(groupType.String(), func(t *testing.T) {
			group := snapshotGroup(t, groupType, 2)
			original, err := group.MarshalJSON()
			if err != nil {
				t.Fatal(err)
			}
			compact, err := json.Marshal(proxySnapshot{proxy: group})
			if err != nil {
				t.Fatal(err)
			}
			var before, after map[string]any
			if err := json.Unmarshal(original, &before); err != nil {
				t.Fatal(err)
			}
			if err := json.Unmarshal(compact, &after); err != nil {
				t.Fatal(err)
			}
			for _, field := range []string{"name", "type", "all", "now", "testUrl", "hidden", "icon"} {
				if !reflect.DeepEqual(before[field], after[field]) {
					t.Errorf("%s = %v, want %v", field, after[field], before[field])
				}
			}
			for _, field := range []string{"history", "extra", "alive", "udp", "provider-name"} {
				if _, exists := after[field]; exists {
					t.Errorf("snapshot contains unused field %s", field)
				}
			}
		})
	}
}

func TestProxySnapshotKeepsDefaultAndChangedSelections(t *testing.T) {
	group := snapshotGroup(t, constant.Selector, 2)
	snapshot := proxySnapshot{proxy: group}
	readSelection := func() string {
		t.Helper()
		data, err := json.Marshal(snapshot)
		if err != nil {
			t.Fatal(err)
		}
		var result proxyGroupSnapshot
		if err := json.Unmarshal(data, &result); err != nil {
			t.Fatal(err)
		}
		return result.Now
	}
	if got := readSelection(); got != "node-0001" {
		t.Fatalf("default selection = %q", got)
	}
	group.Adapter().(outboundgroup.SelectAble).ForceSet("node-0000")
	if got := readSelection(); got != "node-0000" {
		t.Fatalf("changed selection = %q", got)
	}
}

func TestProxySnapshotOmitsUnusedLeafDetails(t *testing.T) {
	data, err := json.Marshal(proxySnapshot{proxy: namedProxy("leaf")})
	if err != nil {
		t.Fatal(err)
	}
	var fields map[string]any
	if err := json.Unmarshal(data, &fields); err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(fields, map[string]any{"name": "leaf", "type": "Direct"}) {
		t.Fatalf("leaf snapshot = %s", data)
	}
}

func BenchmarkProxySnapshot(b *testing.B) {
	group := snapshotGroup(b, constant.Selector, 1000)
	proxies := map[string]constant.Proxy{"subscription": group}
	for _, proxy := range group.Adapter().(outboundgroup.ProxyGroup).Proxies() {
		proxies[proxy.Name()] = proxy
	}
	tunnel.UpdateProxies(proxies, nil)
	b.Cleanup(func() { tunnel.UpdateProxies(nil, nil) })
	previousNames := config.GetProxyNameList()
	config.SetProxyNameList([]string{"subscription"})
	b.Cleanup(func() { config.SetProxyNameList(previousNames) })
	for _, compact := range []bool{false, true} {
		name := "full"
		if compact {
			name = "compact"
		}
		b.Run(name, func(b *testing.B) {
			b.ReportAllocs()
			for i := 0; i < b.N; i++ {
				var value any
				if compact {
					value = handleGetProxies()
				} else {
					value = struct {
						All     []string                  `json:"all"`
						Proxies map[string]constant.Proxy `json:"proxies"`
					}{All: []string{"subscription"}, Proxies: tunnel.AllProxies()}
				}
				data, err := json.Marshal(value)
				if err != nil {
					b.Fatal(err)
				}
				b.ReportMetric(float64(len(data)), "wire-B/op")
			}
		})
	}
}
