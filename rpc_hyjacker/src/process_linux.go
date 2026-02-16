//go:build linux

package listener

import (
	"fmt"
	"os"
	"path/filepath"
)

// GetProcessName returns the executable name for a given PID on Linux.
// compared to windows this is a breeeze
func GetProcessName(pid int) string {
	// /proc/{pid}/exe is a symlink to the actual executable
	exePath := fmt.Sprintf("/proc/%d/exe", pid)
	
	fullPath, err := os.Readlink(exePath)
	if err != nil {
		// Fallback: try reading /proc/{pid}/comm (limited to 15 chars)
		commPath := fmt.Sprintf("/proc/%d/comm", pid)
		data, err := os.ReadFile(commPath)
		if err != nil {
			return "Unknown"
		}
		// comm has a trailing newline
		name := string(data)
		if len(name) > 0 && name[len(name)-1] == '\n' {
			name = name[:len(name)-1]
		}
		return name
	}

	return filepath.Base(fullPath)
}
