package main

import (
	"encoding/json"

	"github.com/metacubex/mihomo/config"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
)

const globalProxyName = "GLOBAL"

type proxyIdentity struct {
	Name string `json:"name"`
	Type string `json:"type"`
}

type proxyGroupSnapshot struct {
	proxyIdentity
	All     json.RawMessage `json:"all"`
	Now     string          `json:"now,omitempty"`
	TestURL string          `json:"testUrl"`
	Hidden  bool            `json:"hidden"`
	Icon    string          `json:"icon"`
}

type proxySnapshot struct {
	proxy constant.Proxy
}

func (snapshot proxySnapshot) MarshalJSON() ([]byte, error) {
	proxy := snapshot.proxy
	identity := proxyIdentity{Name: proxy.Name(), Type: proxy.Type().String()}
	if !isProxyGroupType(proxy.Type()) {
		data := make([]byte, 0, len(identity.Name)+len(identity.Type)+21)
		data = append(data, `{"name":`...)
		data = appendJSONString(data, identity.Name)
		data = append(data, `,"type":`...)
		data = appendJSONString(data, identity.Type)
		return append(data, '}'), nil
	}
	data, err := proxy.Adapter().MarshalJSON()
	if err != nil {
		return nil, err
	}
	group := proxyGroupSnapshot{proxyIdentity: identity}
	if err := json.Unmarshal(data, &group); err != nil {
		return nil, err
	}
	return json.Marshal(group)
}

func isProxyGroupType(adapterType constant.AdapterType) bool {
	switch adapterType {
	case constant.Selector, constant.URLTest, constant.Fallback, constant.Relay, constant.LoadBalance:
		return true
	default:
		return false
	}
}

func proxyGroupNames(
	nameList []string,
	typeOf func(name string) (constant.AdapterType, bool),
) []string {
	hasGlobal := false
	names := make([]string, 0, len(nameList)+1)

	for _, name := range nameList {
		if name == globalProxyName {
			hasGlobal = true
		}
		adapterType, ok := typeOf(name)
		if !ok || !isProxyGroupType(adapterType) {
			continue
		}
		names = append(names, name)
	}

	if !hasGlobal {
		if adapterType, ok := typeOf(globalProxyName); ok && isProxyGroupType(adapterType) {
			names = append([]string{globalProxyName}, names...)
		}
	}

	return names
}

func handleGetProxies() ProxiesData {
	proxies := tunnel.AllProxies()
	allNames := proxyGroupNames(config.GetProxyNameList(), func(name string) (constant.AdapterType, bool) {
		p, ok := proxies[name]
		if !ok || p == nil {
			return 0, false
		}
		return p.Type(), true
	})
	snapshots := make(map[string]proxySnapshot, len(proxies))
	for name, proxy := range proxies {
		if proxy != nil {
			snapshots[name] = proxySnapshot{proxy: proxy}
		}
	}
	return ProxiesData{All: allNames, Proxies: snapshots}
}
