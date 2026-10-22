package main

import "github.com/metacubex/mihomo/common/convert"

func handleConvertShareLinks(data string) []map[string]any {
	proxies, err := convert.ConvertsV2Ray([]byte(data))
	if err != nil {
		return []map[string]any{}
	}
	return proxies
}

func init() {
	registerMethod(convertShareLinksMethod, withArguments(func(data *string, response MethodResponse) {
		response.success(handleConvertShareLinks(*data))
	}))
}
