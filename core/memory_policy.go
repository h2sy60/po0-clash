package main

import (
	"os"
	"runtime/debug"
)

func init() {
	if os.Getenv("GOMEMLIMIT") == "" {
		debug.SetMemoryLimit(32 << 20)
	}
	if os.Getenv("GOGC") == "" {
		debug.SetGCPercent(50)
	}
}
