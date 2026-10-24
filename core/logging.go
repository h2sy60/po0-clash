//go:build !(android && cgo)

package main

import (
	"os"

	"github.com/sirupsen/logrus"
)

func configureDesktopLogging(logger *logrus.Logger, debug bool) {
	logger.SetOutput(os.Stderr)
	level := logrus.ErrorLevel
	if debug {
		level = logrus.DebugLevel
	}
	logger.SetLevel(level)
}
