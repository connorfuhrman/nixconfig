package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestAcceptAll(t *testing.T) {
	in := "Hello{++ world++}{-- x--} {~~old~>new~~} {==hi==}{>>note<<}"
	out := acceptAll(in)
	if !strings.Contains(out, "Hello world") {
		t.Fatalf("missing addition: %q", out)
	}
	if strings.Contains(out, " x") && strings.Contains(out, "{--") {
		t.Fatalf("deletion not stripped: %q", out)
	}
	if !strings.Contains(out, "new") || strings.Contains(out, "old") {
		t.Fatalf("sub failed: %q", out)
	}
	if !strings.Contains(out, "hi") || strings.Contains(out, "{>>") {
		t.Fatalf("highlight/comment: %q", out)
	}
}

func TestInsertRoundTrip(t *testing.T) {
	dir := t.TempDir()
	p := filepath.Join(dir, "f.md")
	if err := os.WriteFile(p, []byte("ab"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := cmdInsert([]string{"--file", p, "--at", "1", "--text", "X"}); err != nil {
		t.Fatal(err)
	}
	b, _ := os.ReadFile(p)
	if string(b) != "a{++X++}b" {
		t.Fatalf("got %q", b)
	}
	marks := findMarks(b)
	if len(marks) != 1 || marks[0].Kind != "addition" {
		t.Fatalf("marks %#v", marks)
	}
	if err := cmdAcceptReject([]string{"--file", p, "--index", "0"}, true); err != nil {
		t.Fatal(err)
	}
	b, _ = os.ReadFile(p)
	if string(b) != "aXb" {
		t.Fatalf("accept got %q", b)
	}
}
