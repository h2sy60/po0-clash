//go:build !(android && cgo)

package main

import (
	"bytes"
	"io"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/metacubex/mihomo/log"
	"github.com/sirupsen/logrus"
)

func TestDesktopLoggingKeepsErrorDiagnosticsWithoutOrdinaryConsoleLogs(t *testing.T) {
	logger := logrus.New()
	configureDesktopLogging(logger, false)
	if logger.Out != os.Stderr {
		t.Fatal("diagnostics do not use the host's captured stderr stream")
	}
	var output bytes.Buffer
	logger.SetOutput(&output)
	logger.Debug("unused-debug")
	logger.Info("unused-info")
	logger.Warn("unused-warning")
	logger.Error("required-error")
	if strings.Contains(output.String(), "unused-") || !strings.Contains(output.String(), "required-error") {
		t.Fatalf("unexpected console diagnostics: %s", &output)
	}
	for _, level := range []logrus.Level{logrus.FatalLevel, logrus.PanicLevel} {
		if !logger.IsLevelEnabled(level) {
			t.Fatalf("fatal diagnostics were disabled: %s", level)
		}
	}
}

func TestDesktopDebugLoggingIncludesOrdinaryLogsOnStderr(t *testing.T) {
	logger := logrus.New()
	configureDesktopLogging(logger, true)
	if logger.Out != os.Stderr {
		t.Fatal("debug output does not use stderr")
	}
	var output bytes.Buffer
	logger.SetOutput(&output)
	logger.Debug("debug-detail")
	logger.Info("debug-info")
	logger.Warn("debug-warning")
	for _, message := range []string{"debug-detail", "debug-info", "debug-warning"} {
		if !strings.Contains(output.String(), message) {
			t.Fatalf("debug mode omitted %s: %s", message, &output)
		}
	}
}

func TestDesktopConsoleFilteringDoesNotSuppressLogEvents(t *testing.T) {
	logger := logrus.StandardLogger()
	previousOutput, previousLevel := logger.Out, logger.GetLevel()
	t.Cleanup(func() {
		logger.SetOutput(previousOutput)
		logger.SetLevel(previousLevel)
	})
	configureDesktopLogging(logger, false)
	subscriber := log.Subscribe()
	defer log.UnSubscribe(subscriber)
	const payload = "desktop-log-event-without-console-output"
	log.Infoln(payload)
	timeout := time.After(time.Second)
	for {
		select {
		case event := <-subscriber:
			if event.Payload == payload {
				if event.LogLevel != log.INFO {
					t.Fatalf("event level = %s, want info", event.LogLevel)
				}
				return
			}
		case <-timeout:
			t.Fatal("console filtering suppressed the application's log event")
		}
	}
}

func BenchmarkDesktopConsoleLog(b *testing.B) {
	for _, name := range []string{"ordinary_console", "errors_only"} {
		b.Run(name, func(b *testing.B) {
			logger := logrus.New()
			logger.SetFormatter(&logrus.TextFormatter{
				FullTimestamp:             true,
				TimestampFormat:           "2006-01-02T15:04:05.000000000Z07:00",
				EnvironmentOverrideColors: true,
			})
			if name == "errors_only" {
				configureDesktopLogging(logger, false)
			} else {
				logger.SetLevel(logrus.DebugLevel)
			}
			logger.SetOutput(io.Discard)
			b.ReportAllocs()
			b.ResetTimer()
			for index := 0; index < b.N; index++ {
				logger.Infoln("[TCP] 127.0.0.1:443 --> example.test:443 match MATCH using group[node]")
			}
		})
	}
}
