//go:build (linux && !android) || (android && !cgo)

package main

func pinReclaimLibraries() (map[string]bool, func()) {
	return coreMappingLibraries, func() {}
}
