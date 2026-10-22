package main

import (
	"encoding/base64"
	"encoding/json"
	"testing"
)

const (
	vlessRealityLink = "vless://0f6b1c2e-6a3d-4b0e-9a51-3f2d9b1c7e10@203.0.113.7:443" +
		"?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.example.com" +
		"&fp=chrome&pbk=Zm9vYmFyYmF6cXV4cXV1eHF1dXhxdXV4cXV1eHF1dXg&sid=6ba85179&type=tcp#HK-01"
	trojanLink = "trojan://secret@node.example.com:8443?sni=node.example.com#JP-01"
)

func TestHandleConvertShareLinksParsesEachLine(t *testing.T) {
	proxies := handleConvertShareLinks(vlessRealityLink + "\n" + trojanLink + "\nnot a link\n")

	if len(proxies) != 2 {
		t.Fatalf("got %d proxies, want 2: %v", len(proxies), proxies)
	}
	if proxies[0]["name"] != "HK-01" || proxies[0]["type"] != "vless" {
		t.Errorf("first proxy = %v, want the vless node HK-01", proxies[0])
	}
	if _, ok := proxies[0]["reality-opts"]; !ok {
		t.Errorf("vless proxy lost its reality options: %v", proxies[0])
	}
	if proxies[1]["name"] != "JP-01" || proxies[1]["type"] != "trojan" {
		t.Errorf("second proxy = %v, want the trojan node JP-01", proxies[1])
	}
}

func TestHandleConvertShareLinksAcceptsABase64Body(t *testing.T) {
	body := base64.StdEncoding.EncodeToString([]byte(trojanLink))

	proxies := handleConvertShareLinks(body)

	if len(proxies) != 1 || proxies[0]["name"] != "JP-01" {
		t.Fatalf("proxies = %v, want the trojan node from the base64 body", proxies)
	}
}

func TestHandleConvertShareLinksEncodesNothingAsAnEmptyList(t *testing.T) {
	for name, input := range map[string]string{
		"empty":   "",
		"garbage": "https://example.com/subscription\nhello",
	} {
		t.Run(name, func(t *testing.T) {
			data, err := json.Marshal(handleConvertShareLinks(input))
			if err != nil {
				t.Fatalf("marshal: %v", err)
			}
			if string(data) != "[]" {
				t.Errorf("result = %s, want []", data)
			}
		})
	}
}
