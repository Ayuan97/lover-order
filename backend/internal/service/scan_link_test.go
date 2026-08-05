package service

import "testing"

func TestParseScanLinkTypedOnly(t *testing.T) {
	k, c := ParseScanLink("lo://home/ABC12XYZ")
	if k != ScanHome || c != "ABC12XYZ" {
		t.Fatalf("home: got %v %q", k, c)
	}
	k, c = ParseScanLink("lo://room/123456")
	if k != ScanRoom || c != "123456" {
		t.Fatalf("room: got %v %q", k, c)
	}
	// 裸码必须拒绝——无兼容路径
	k, c = ParseScanLink("123456")
	if k != ScanUnknown || c != "" {
		t.Fatalf("bare digits must be unknown, got %v %q", k, c)
	}
	k, c = ParseScanLink("INVITE8")
	if k != ScanUnknown || c != "" {
		t.Fatalf("bare invite must be unknown, got %v %q", k, c)
	}
	k, _ = ParseScanLink("lo://home/")
	if k != ScanUnknown {
		t.Fatal("empty home code unknown")
	}
}
