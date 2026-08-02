package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"os"
	"regexp"
	"strings"
)

// CriticMarkup CLI for agent/human review workflows.
// Spec: https://github.com/CriticMarkup/CriticMarkup-toolkit#the-basic-syntax
//
//	{++ addition ++}
//	{-- deletion --}
//	{~~ old ~> new ~~}
//	{>> comment <<}
//	{== highlight ==}{>> comment <<}

const usage = `cm — CriticMarkup helper for agents and humans

Usage:
  cm insert  --file PATH --at BYTE_OFFSET --text TEXT
  cm delete  --file PATH --start BYTE --end BYTE
  cm sub     --file PATH --start BYTE --end BYTE --text NEW
  cm comment --file PATH --start BYTE --end BYTE --text COMMENT
  cm highlight --file PATH --start BYTE --end BYTE [--text COMMENT]
  cm wrap-add  --file PATH --start BYTE --end BYTE
  cm wrap-del  --file PATH --start BYTE --end BYTE
  cm list    --file PATH [--json]
  cm accept  --file PATH --index N   (0-based mark index from list)
  cm reject  --file PATH --index N
  cm strip   --file PATH            (remove all marks; keep final text as accept-all)
  cm validate --file PATH

Byte offsets are 0-based into the UTF-8 file. Prefer list+index for accept/reject.
Logical chunks: call insert/delete once per reviewable unit (paragraph/hunk).
`

var (
	reAdd = regexp.MustCompile(`(?s)\{\+\+(.*?)\+\+\}`)
	reDel = regexp.MustCompile(`(?s)\{--(.*?)--\}`)
	reSub = regexp.MustCompile(`(?s)\{~~(.*?)~>(.*?)~~\}`)
	reCom = regexp.MustCompile(`(?s)\{>>(.*?)<<\}`)
	reHi  = regexp.MustCompile(`(?s)\{==(.*?)==\}`)
)

type mark struct {
	Index  int    `json:"index"`
	Kind   string `json:"kind"`
	Start  int    `json:"start"`
	End    int    `json:"end"`
	Old    string `json:"old,omitempty"`
	New    string `json:"new,omitempty"`
	Text   string `json:"text,omitempty"`
	Raw    string `json:"raw"`
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprint(os.Stderr, usage)
		os.Exit(2)
	}
	cmd := os.Args[1]
	args := os.Args[2:]
	var err error
	switch cmd {
	case "insert":
		err = cmdInsert(args)
	case "delete":
		err = cmdDelete(args)
	case "sub":
		err = cmdSub(args)
	case "comment":
		err = cmdComment(args)
	case "highlight":
		err = cmdHighlight(args)
	case "wrap-add":
		err = cmdWrap(args, "add")
	case "wrap-del":
		err = cmdWrap(args, "del")
	case "list":
		err = cmdList(args)
	case "accept":
		err = cmdAcceptReject(args, true)
	case "reject":
		err = cmdAcceptReject(args, false)
	case "strip":
		err = cmdStrip(args)
	case "validate":
		err = cmdValidate(args)
	case "help", "-h", "--help":
		fmt.Print(usage)
		return
	default:
		fmt.Fprintf(os.Stderr, "unknown command %q\n%s", cmd, usage)
		os.Exit(2)
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func flags(args []string) (*flag.FlagSet, *string, *int, *int, *int, *string, *bool) {
	fs := flag.NewFlagSet("cm", flag.ContinueOnError)
	fs.SetOutput(io.Discard)
	file := fs.String("file", "", "path")
	at := fs.Int("at", -1, "byte offset")
	start := fs.Int("start", -1, "start byte")
	end := fs.Int("end", -1, "end byte")
	text := fs.String("text", "", "text")
	asJSON := fs.Bool("json", false, "json output")
	index := fs.Int("index", -1, "mark index")
	_ = index
	_ = fs.Parse(args)
	// re-parse with index available to callers via second parse — keep simple:
	return fs, file, at, start, end, text, asJSON
}

func parseCommon(args []string) (file string, at, start, end, index int, text string, asJSON bool, err error) {
	fs := flag.NewFlagSet("cm", flag.ContinueOnError)
	fs.SetOutput(io.Discard)
	f := fs.String("file", "", "")
	a := fs.Int("at", -1, "")
	s := fs.Int("start", -1, "")
	e := fs.Int("end", -1, "")
	t := fs.String("text", "", "")
	j := fs.Bool("json", false, "")
	i := fs.Int("index", -1, "")
	if err = fs.Parse(args); err != nil {
		return
	}
	return *f, *a, *s, *e, *i, *t, *j, nil
}

func readFile(path string) ([]byte, error) {
	if path == "" {
		return nil, fmt.Errorf("--file required")
	}
	return os.ReadFile(path)
}

func writeFile(path string, b []byte) error {
	return os.WriteFile(path, b, 0o644)
}

func escapeCM(s string) string {
	// Avoid breaking delimiters inside content.
	s = strings.ReplaceAll(s, "++}", "+ +}")
	s = strings.ReplaceAll(s, "--}", "- -}")
	s = strings.ReplaceAll(s, "~~}", "~ ~}")
	s = strings.ReplaceAll(s, "<<}", "< <}")
	s = strings.ReplaceAll(s, "==}", "= =}")
	return s
}

func cmdInsert(args []string) error {
	file, at, _, _, _, text, _, err := parseCommon(args)
	if err != nil {
		return err
	}
	if at < 0 {
		return fmt.Errorf("--at required")
	}
	b, err := readFile(file)
	if err != nil {
		return err
	}
	if at > len(b) {
		return fmt.Errorf("--at %d past EOF %d", at, len(b))
	}
	mark := []byte("{++" + escapeCM(text) + "++}")
	out := append(append([]byte{}, b[:at]...), append(mark, b[at:]...)...)
	return writeFile(file, out)
}

func cmdDelete(args []string) error {
	file, _, start, end, _, _, _, err := parseCommon(args)
	if err != nil {
		return err
	}
	if start < 0 || end < start {
		return fmt.Errorf("--start/--end required")
	}
	b, err := readFile(file)
	if err != nil {
		return err
	}
	if end > len(b) {
		return fmt.Errorf("range past EOF")
	}
	chunk := string(b[start:end])
	mark := []byte("{--" + escapeCM(chunk) + "--}")
	out := append(append([]byte{}, b[:start]...), append(mark, b[end:]...)...)
	return writeFile(file, out)
}

func cmdSub(args []string) error {
	file, _, start, end, _, text, _, err := parseCommon(args)
	if err != nil {
		return err
	}
	if start < 0 || end < start {
		return fmt.Errorf("--start/--end required")
	}
	b, err := readFile(file)
	if err != nil {
		return err
	}
	if end > len(b) {
		return fmt.Errorf("range past EOF")
	}
	old := escapeCM(string(b[start:end]))
	mark := []byte("{~~" + old + "~>" + escapeCM(text) + "~~}")
	out := append(append([]byte{}, b[:start]...), append(mark, b[end:]...)...)
	return writeFile(file, out)
}

func cmdComment(args []string) error {
	file, _, start, end, _, text, _, err := parseCommon(args)
	if err != nil {
		return err
	}
	if start < 0 || end < start {
		return fmt.Errorf("--start/--end required")
	}
	b, err := readFile(file)
	if err != nil {
		return err
	}
	if end > len(b) {
		return fmt.Errorf("range past EOF")
	}
	// Highlight span + trailing comment (CriticMarkup highlight+comment pattern).
	span := string(b[start:end])
	mark := []byte("{==" + escapeCM(span) + "==}{>>" + escapeCM(text) + "<<}")
	out := append(append([]byte{}, b[:start]...), append(mark, b[end:]...)...)
	return writeFile(file, out)
}

func cmdHighlight(args []string) error {
	file, _, start, end, _, text, _, err := parseCommon(args)
	if err != nil {
		return err
	}
	if start < 0 || end < start {
		return fmt.Errorf("--start/--end required")
	}
	b, err := readFile(file)
	if err != nil {
		return err
	}
	if end > len(b) {
		return fmt.Errorf("range past EOF")
	}
	span := escapeCM(string(b[start:end]))
	var mark []byte
	if text != "" {
		mark = []byte("{==" + span + "==}{>>" + escapeCM(text) + "<<}")
	} else {
		mark = []byte("{==" + span + "==}")
	}
	out := append(append([]byte{}, b[:start]...), append(mark, b[end:]...)...)
	return writeFile(file, out)
}

func cmdWrap(args []string, kind string) error {
	file, _, start, end, _, _, _, err := parseCommon(args)
	if err != nil {
		return err
	}
	if start < 0 || end < start {
		return fmt.Errorf("--start/--end required")
	}
	b, err := readFile(file)
	if err != nil {
		return err
	}
	if end > len(b) {
		return fmt.Errorf("range past EOF")
	}
	span := escapeCM(string(b[start:end]))
	var mark []byte
	if kind == "add" {
		mark = []byte("{++" + span + "++}")
	} else {
		mark = []byte("{--" + span + "--}")
	}
	out := append(append([]byte{}, b[:start]...), append(mark, b[end:]...)...)
	return writeFile(file, out)
}

func findMarks(b []byte) []mark {
	s := string(b)
	type cand struct {
		kind, raw, old, neu, text string
		start, end                int
	}
	var cs []cand
	addAll := func(re *regexp.Regexp, kind string, mapg func([]string) (old, neu, text string)) {
		for _, loc := range re.FindAllStringSubmatchIndex(s, -1) {
			raw := s[loc[0]:loc[1]]
			var groups []string
			for i := 0; i < len(loc)/2; i++ {
				if loc[2*i] >= 0 {
					groups = append(groups, s[loc[2*i]:loc[2*i+1]])
				} else {
					groups = append(groups, "")
				}
			}
			old, neu, text := mapg(groups)
			cs = append(cs, cand{kind: kind, raw: raw, old: old, neu: neu, text: text, start: loc[0], end: loc[1]})
		}
	}
	addAll(reAdd, "addition", func(g []string) (string, string, string) {
		if len(g) > 1 {
			return "", g[1], g[1]
		}
		return "", "", ""
	})
	addAll(reDel, "deletion", func(g []string) (string, string, string) {
		if len(g) > 1 {
			return g[1], "", g[1]
		}
		return "", "", ""
	})
	addAll(reSub, "substitution", func(g []string) (string, string, string) {
		if len(g) > 2 {
			return g[1], g[2], g[1] + " -> " + g[2]
		}
		return "", "", ""
	})
	addAll(reHi, "highlight", func(g []string) (string, string, string) {
		if len(g) > 1 {
			return g[1], g[1], g[1]
		}
		return "", "", ""
	})
	addAll(reCom, "comment", func(g []string) (string, string, string) {
		if len(g) > 1 {
			return "", "", g[1]
		}
		return "", "", ""
	})
	// sort by start
	for i := 0; i < len(cs); i++ {
		for j := i + 1; j < len(cs); j++ {
			if cs[j].start < cs[i].start {
				cs[i], cs[j] = cs[j], cs[i]
			}
		}
	}
	out := make([]mark, 0, len(cs))
	for i, c := range cs {
		out = append(out, mark{
			Index: i, Kind: c.kind, Start: c.start, End: c.end,
			Old: c.old, New: c.neu, Text: c.text, Raw: c.raw,
		})
	}
	return out
}

func cmdList(args []string) error {
	file, _, _, _, _, _, asJSON, err := parseCommon(args)
	if err != nil {
		return err
	}
	b, err := readFile(file)
	if err != nil {
		return err
	}
	marks := findMarks(b)
	if asJSON {
		enc := json.NewEncoder(os.Stdout)
		enc.SetIndent("", "  ")
		return enc.Encode(marks)
	}
	w := bufio.NewWriter(os.Stdout)
	for _, m := range marks {
		fmt.Fprintf(w, "%d\t%s\t%d-%d\t%q\n", m.Index, m.Kind, m.Start, m.End, trunc(m.Raw, 80))
	}
	return w.Flush()
}

func trunc(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n] + "…"
}

func cmdAcceptReject(args []string, accept bool) error {
	file, _, _, _, index, _, _, err := parseCommon(args)
	if err != nil {
		return err
	}
	if index < 0 {
		return fmt.Errorf("--index required")
	}
	b, err := readFile(file)
	if err != nil {
		return err
	}
	marks := findMarks(b)
	if index >= len(marks) {
		return fmt.Errorf("index %d out of range (0..%d)", index, len(marks)-1)
	}
	m := marks[index]
	var repl string
	switch m.Kind {
	case "addition":
		if accept {
			repl = m.New
		} else {
			repl = ""
		}
	case "deletion":
		if accept {
			repl = ""
		} else {
			repl = m.Old
		}
	case "substitution":
		if accept {
			repl = m.New
		} else {
			repl = m.Old
		}
	case "highlight", "comment":
		// Accept keeps text (strip mark); reject keeps text too for highlight body.
		if m.Kind == "highlight" {
			repl = m.Old
		} else {
			repl = ""
		}
	default:
		return fmt.Errorf("cannot accept/reject kind %s", m.Kind)
	}
	out := append(append([]byte{}, b[:m.Start]...), append([]byte(repl), b[m.End:]...)...)
	return writeFile(file, out)
}

func acceptAll(s string) string {
	s = reSub.ReplaceAllString(s, "$2")
	s = reAdd.ReplaceAllString(s, "$1")
	s = reDel.ReplaceAllString(s, "")
	s = reHi.ReplaceAllString(s, "$1")
	s = reCom.ReplaceAllString(s, "")
	return s
}

func cmdStrip(args []string) error {
	file, _, _, _, _, _, _, err := parseCommon(args)
	if err != nil {
		return err
	}
	b, err := readFile(file)
	if err != nil {
		return err
	}
	return writeFile(file, []byte(acceptAll(string(b))))
}

func cmdValidate(args []string) error {
	file, _, _, _, _, _, _, err := parseCommon(args)
	if err != nil {
		return err
	}
	b, err := readFile(file)
	if err != nil {
		return err
	}
	// Balanced-ish check: count open tokens vs findMarks coverage.
	s := string(b)
	opens := strings.Count(s, "{++") + strings.Count(s, "{--") + strings.Count(s, "{~~") + strings.Count(s, "{>>") + strings.Count(s, "{==")
	marks := findMarks(b)
	if opens != len(marks) {
		// highlight+comment pairs can double-count comments attached to highlights
		fmt.Fprintf(os.Stdout, "ok=false opens=%d marks=%d\n", opens, len(marks))
		return fmt.Errorf("unbalanced or nested critic marks (opens=%d marks=%d)", opens, len(marks))
	}
	fmt.Fprintf(os.Stdout, "ok=true marks=%d\n", len(marks))
	return nil
}

// silence unused in case of build tags
var _ = bytes.MinRead
