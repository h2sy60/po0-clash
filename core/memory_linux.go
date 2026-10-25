//go:build linux || android

package main

import (
	"bufio"
	"io"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
)

type cleanMapping struct {
	start, length uintptr
	eligible      bool
	resident      bool
	dirtySeen     bool
	anonymousSeen bool
	swapSeen      bool
	dirty         bool
	anonymous     bool
	swapped       bool
}

var coreMappingLibraries = map[string]bool{"libclash.so": true, "Po0ClashCore": true}

func (mapping cleanMapping) canRelease() bool {
	// RELRO can contain relocated pointers despite its read-only permissions.
	return mapping.eligible && mapping.resident && mapping.dirtySeen && mapping.anonymousSeen && mapping.swapSeen &&
		!mapping.dirty && !mapping.anonymous && !mapping.swapped
}

func releaseCleanMappings() {
	libraries, unpin := pinReclaimLibraries()
	defer unpin()
	file, err := os.Open("/proc/self/smaps")
	if err != nil {
		return
	}
	defer file.Close()
	visitPinnedCleanMappings(file, libraries, func(start, length uintptr) {
		_, _, _ = syscall.Syscall(syscall.SYS_MADVISE, start, length, syscall.MADV_DONTNEED)
	})
}

func visitCleanMappings(reader io.Reader, release func(uintptr, uintptr)) {
	visitPinnedCleanMappings(reader, coreMappingLibraries, release)
}

func visitPinnedCleanMappings(reader io.Reader, libraries map[string]bool, release func(uintptr, uintptr)) {
	var mapping cleanMapping
	flush := func() {
		if mapping.canRelease() {
			release(mapping.start, mapping.length)
		}
	}
	scanner := bufio.NewScanner(reader)
	for scanner.Scan() {
		fields := strings.Fields(scanner.Text())
		if len(fields) == 0 {
			continue
		}
		if strings.Contains(fields[0], "-") {
			flush()
			mapping = parseCleanMapping(fields, libraries)
			continue
		}
		if len(fields) < 2 {
			continue
		}
		switch fields[0] {
		case "Rss:", "Private_Dirty:", "Anonymous:", "Swap:":
		default:
			continue
		}
		value, err := strconv.ParseUint(fields[1], 10, 64)
		if err != nil {
			mapping.eligible = false
			continue
		}
		switch fields[0] {
		case "Rss:":
			mapping.resident = value > 0
		case "Private_Dirty:":
			mapping.dirtySeen = true
			mapping.dirty = value != 0
		case "Anonymous:":
			mapping.anonymousSeen = true
			mapping.anonymous = value != 0
		case "Swap:":
			mapping.swapSeen = true
			mapping.swapped = value != 0
		}
	}
	if scanner.Err() == nil {
		flush()
	}
}

func parseCleanMapping(fields []string, libraries map[string]bool) cleanMapping {
	if len(fields) < 6 || (fields[1] != "r--p" && fields[1] != "r-xp") || fields[4] == "0" {
		return cleanMapping{}
	}
	path := strings.Join(fields[5:], " ")
	if !filepath.IsAbs(path) {
		return cleanMapping{}
	}
	if !libraries[filepath.Base(path)] {
		return cleanMapping{}
	}
	addresses := strings.SplitN(fields[0], "-", 2)
	if len(addresses) != 2 {
		return cleanMapping{}
	}
	start, startErr := strconv.ParseUint(addresses[0], 16, strconv.IntSize)
	end, endErr := strconv.ParseUint(addresses[1], 16, strconv.IntSize)
	if startErr != nil || endErr != nil || end <= start {
		return cleanMapping{}
	}
	return cleanMapping{start: uintptr(start), length: uintptr(end - start), eligible: true}
}
