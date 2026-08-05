package service

import (
	"strings"
)

// QR 深链前缀——与 iOS LoverScanLink 一致；不解析裸串
const (
	ScanHomePrefix = "lo://home/"
	ScanRoomPrefix = "lo://room/"
)

type ScanKind int

const (
	ScanUnknown ScanKind = iota
	ScanHome
	ScanRoom
)

// ParseScanLink 只接受 lo://home/ 与 lo://room/，裸码一律 unknown（无兼容）
func ParseScanLink(raw string) (kind ScanKind, code string) {
	s := strings.TrimSpace(raw)
	lower := strings.ToLower(s)
	if strings.HasPrefix(lower, ScanHomePrefix) {
		c := strings.TrimSpace(s[len(ScanHomePrefix):])
		if c == "" {
			return ScanUnknown, ""
		}
		return ScanHome, c
	}
	if strings.HasPrefix(lower, ScanRoomPrefix) {
		c := strings.TrimSpace(s[len(ScanRoomPrefix):])
		if c == "" {
			return ScanUnknown, ""
		}
		return ScanRoom, c
	}
	return ScanUnknown, ""
}
