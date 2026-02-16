//go:build windows

package listener

import (
	"path/filepath"
	"syscall"
	"unsafe"
)

var (
	kernel32                       = syscall.NewLazyDLL("kernel32.dll")
	procOpenProcess                = kernel32.NewProc("OpenProcess")
	procCloseHandle                = kernel32.NewProc("CloseHandle")
	procQueryFullProcessImageNameW = kernel32.NewProc("QueryFullProcessImageNameW")
)

const (
	processQueryLimitedInformation = 0x1000
)

// GetProcessName retrieves the name of the process given its PID on Windows.
func GetProcessName(pid int) string {
	handle, _, _ := procOpenProcess.Call(
		uintptr(processQueryLimitedInformation),
		0,
		uintptr(pid),
	)
	if handle == 0 {
		return "Unknown"
	}
	defer procCloseHandle.Call(handle)

	var buf [512]uint16
	size := uint32(len(buf))

	// fuckery, thank you syscall mod on go <3

	ret, _, _ := procQueryFullProcessImageNameW.Call(
		handle,
		0,
		uintptr(unsafe.Pointer(&buf[0])),
		uintptr(unsafe.Pointer(&size)),
	)
	if ret == 0 {
		return "Unknown"
	}

	fullPath := syscall.UTF16ToString(buf[:size])
	return filepath.Base(fullPath)
}
