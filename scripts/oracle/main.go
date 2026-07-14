package main

import (
	"bufio"
	"encoding/base64"
	"fmt"
	"os"
	"strings"

	"github.com/moby/patternmatcher"
	"github.com/moby/patternmatcher/ignorefile"
)

func main() {
	if len(os.Args) != 2 {
		fmt.Fprintln(os.Stderr, "usage: oracle <fixture-file>")
		os.Exit(2)
	}

	fixture, err := os.Open(os.Args[1])
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}
	defer fixture.Close()

	scanner := bufio.NewScanner(fixture)
	for scanner.Scan() {
		id, source, path, err := decodeRow(scanner.Text())
		if err != nil {
			fmt.Printf("%s\tE:%s\n", id, err)
			continue
		}

		patterns, err := ignorefile.ReadAll(strings.NewReader(source))
		if err != nil {
			fmt.Printf("%s\tE:%s\n", id, err)
			continue
		}

		matched, err := patternmatcher.MatchesOrParentMatches(path, patterns)
		if err != nil {
			fmt.Printf("%s\tE:%s\n", id, err)
			continue
		}

		if matched {
			fmt.Printf("%s\t1\n", id)
		} else {
			fmt.Printf("%s\t0\n", id)
		}
	}

	if err := scanner.Err(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}
}

func decodeRow(row string) (string, string, string, error) {
	fields := strings.Split(row, "\t")
	if len(fields) != 3 {
		return firstField(row), "", "", fmt.Errorf("invalid fixture row")
	}

	source, err := base64.StdEncoding.DecodeString(fields[1])
	if err != nil {
		return fields[0], "", "", err
	}

	path, err := base64.StdEncoding.DecodeString(fields[2])
	if err != nil {
		return fields[0], "", "", err
	}

	return fields[0], string(source), string(path), nil
}

func firstField(row string) string {
	if index := strings.IndexByte(row, '\t'); index >= 0 {
		return row[:index]
	}

	return row
}
