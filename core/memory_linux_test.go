//go:build linux || android

package main

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"syscall"
	"testing"
)

func mappingRecord(permissions, path, dirty, anonymous string) string {
	return fmt.Sprintf("1000-3000 %s 0000 08:01 123 %s\nRss: 8 kB\nPrivate_Dirty: %s kB\nAnonymous: %s kB\nSwap: 0 kB\nVmFlags: rd ex mr mw me sd\n", permissions, path, dirty, anonymous)
}

func TestReclaimRequiresCleanImmutableApplicationMappings(t *testing.T) {
	for _, test := range []struct {
		name, record string
		want         bool
	}{
		{"code", mappingRecord("r-xp", "/app/libclash.so", "0", "0"), true},
		{"constants", mappingRecord("r--p", "/app/libclash.so", "0", "0"), true},
		{"flutter lifetime", mappingRecord("r-xp", "/app/libflutter.so", "0", "0"), false},
		{"dart lifetime", mappingRecord("r--p", "/app/libapp.so", "0", "0"), false},
		{"desktop", mappingRecord("r-xp", "/app/Po0ClashCore", "0", "0"), true},
		{"relocated pointers", mappingRecord("r--p", "/app/libclash.so", "4", "4"), false},
		{"anonymous pages", mappingRecord("r--p", "/app/libclash.so", "0", "4"), false},
		{"swapped relocations", strings.Replace(mappingRecord("r--p", "/app/libclash.so", "0", "0"), "Swap: 0", "Swap: 4", 1), false},
		{"mutable data", mappingRecord("rw-p", "/app/libclash.so", "0", "0"), false},
		{"shared mapping", mappingRecord("r--s", "/app/libclash.so", "0", "0"), false},
		{"system library", mappingRecord("r-xp", "/system/libc.so", "0", "0"), false},
		{"deleted library", mappingRecord("r--p", "/app/libclash.so (deleted)", "0", "0"), false},
		{"unknown dirty state", "1000-3000 r--p 0 08:01 123 /app/libclash.so\nRss: 8 kB\nAnonymous: 0 kB\nSwap: 0 kB\n", false},
		{"unknown anonymous state", "1000-3000 r--p 0 08:01 123 /app/libclash.so\nRss: 8 kB\nPrivate_Dirty: 0 kB\nSwap: 0 kB\n", false},
		{"unknown swap state", "1000-3000 r--p 0 08:01 123 /app/libclash.so\nRss: 8 kB\nPrivate_Dirty: 0 kB\nAnonymous: 0 kB\n", false},
	} {
		t.Run(test.name, func(t *testing.T) {
			calls := 0
			visitCleanMappings(strings.NewReader(test.record), func(start, length uintptr) {
				calls++
				if start != 0x1000 || length != 0x2000 {
					t.Fatalf("released mapping %#x/%#x", start, length)
				}
			})
			if (calls == 1) != test.want {
				t.Fatalf("release calls = %d, want eligible = %v", calls, test.want)
			}
		})
	}
}

func TestReclaimDoesNotCarryCleanStateAcrossMappings(t *testing.T) {
	input := mappingRecord("r-xp", "/app/libclash.so", "0", "0") +
		"3000-5000 r--p 0000 08:01 123 /app/libclash.so\nRss: 8 kB\n"
	calls := 0
	visitCleanMappings(strings.NewReader(input), func(uintptr, uintptr) { calls++ })
	if calls != 1 {
		t.Fatalf("release calls = %d, want only the complete mapping", calls)
	}
}

func TestUiMappingsRequireAPinnedLibrary(t *testing.T) {
	input := mappingRecord("r--p", "/app/libapp.so", "0", "0")
	for _, pinned := range []bool{false, true} {
		calls := 0
		visitPinnedCleanMappings(strings.NewReader(input), map[string]bool{"libapp.so": pinned}, func(uintptr, uintptr) { calls++ })
		if (calls == 1) != pinned {
			t.Fatalf("release calls = %d, pinned = %v", calls, pinned)
		}
	}
}

func TestReclaimPreservesFileBackedContents(t *testing.T) {
	contents := bytes.Repeat([]byte("mapped-library-contents"), 4096)
	path := filepath.Join(t.TempDir(), "libclash.so")
	if err := os.WriteFile(path, contents, 0600); err != nil {
		t.Fatal(err)
	}
	file, err := os.Open(path)
	if err != nil {
		t.Fatal(err)
	}
	defer file.Close()
	view, err := syscall.Mmap(int(file.Fd()), 0, len(contents), syscall.PROT_READ, syscall.MAP_PRIVATE)
	if err != nil {
		t.Fatal(err)
	}
	defer syscall.Munmap(view)
	if !bytes.Equal(view, contents) {
		t.Fatal("initial file mapping differs")
	}
	releaseCleanMappings()
	if !bytes.Equal(view, contents) {
		t.Fatal("file contents changed after reclaiming its pages")
	}
}
