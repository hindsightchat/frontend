//go:build darwin

package listener

/*
#include <libproc.h>
*/
import "C"

import (
	"path/filepath"
	"unsafe"
)

// GetProcessName returns the executable name for a given PID on macOS.
func GetProcessName(pid int) string {
	const maxPathLen = C.PROC_PIDPATHINFO_MAXSIZE

	buf := make([]byte, maxPathLen)
	ret, err := C.proc_pidpath(C.int(pid), unsafe.Pointer(&buf[0]), C.uint32_t(maxPathLen))

	if ret <= 0 || err != nil {
		return "Unknown"
	}

	// Find the null terminator
	fullPath := string(buf[:ret])

	return filepath.Base(fullPath)
}
