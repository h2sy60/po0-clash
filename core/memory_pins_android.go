//go:build android && cgo

package main

/*
#cgo LDFLAGS: -ldl
#include <dlfcn.h>
#include <stdlib.h>
*/
import "C"

import "unsafe"

func pinReclaimLibraries() (map[string]bool, func()) {
	libraries := map[string]bool{"libclash.so": true}
	var handles []unsafe.Pointer
	for _, name := range []string{"libapp.so", "libflutter.so"} {
		value := C.CString(name)
		handle := C.dlopen(value, C.RTLD_NOW|C.RTLD_NOLOAD)
		C.free(unsafe.Pointer(value))
		if handle != nil {
			libraries[name] = true
			handles = append(handles, handle)
		}
	}
	return libraries, func() {
		for _, handle := range handles {
			C.dlclose(handle)
		}
	}
}
