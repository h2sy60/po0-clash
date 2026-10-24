package main

import "github.com/metacubex/mihomo/tunnel/statistic"

func requestMessage(tracker statistic.Tracker) Message {
	return Message{Type: RequestMessage, Data: tracker.Info()}
}
