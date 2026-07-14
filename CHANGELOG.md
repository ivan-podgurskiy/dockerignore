# Changelog

## v0.1.0 - 2026-07-14

First public release of a dependency-free `.dockerignore` parser and matcher
for Elixir, compatible with the observable behavior of
`moby/patternmatcher` v0.6.1.

### Added

- Added `Dockerignore.parse/1` and `parse!/1` for preprocessing and validating
  `.dockerignore` sources while retaining original source lines and one-based
  line numbers.
- Added `Dockerignore.compile/1` and `compile!/1` for building immutable
  matchers that can be compiled once and shared safely between processes.
- Added `Dockerignore.ignored?/2` for kept-or-ignored decisions and
  `Dockerignore.filter/2` for eagerly retaining paths from any enumerable while
  preserving order and duplicates.
- Added `Dockerignore.explain/2` for returning the final state together with the
  last rule that changed it, including matches inherited from parent paths.
- Added source-aware `Dockerignore.Error` exceptions for malformed exclusions,
  character classes, escapes, and other invalid patterns.
- Added host-independent POSIX path cleaning for relative build-context paths,
  including repeated separators, `.` segments, `..` segments, and trailing
  separators.

### PatternMatcher compatibility

- Implemented Docker `ignorefile` preprocessing for byte-order marks, comments,
  blank lines, whitespace trimming, path cleaning, leading separators, and
  ordered `!` exclusions.
- Implemented source-order matching in which normal rules ignore paths, parent
  directory matches affect descendants, and later exclusions can re-include
  matching paths according to `moby/patternmatcher` v0.6.1 behavior.
- Implemented exact, prefix, suffix, and regexp matching modes, including the
  pinned recursive `**` behavior and v0.6.1 edge semantics.
- Added a bounded Thompson-style matcher for the reachable Go RE2 syntax rather
  than delegating pattern execution to Erlang PCRE. This avoids catastrophic
  backtracking while preserving the pinned matcher contract.
- Embedded dependency-free Unicode 15.0.0 category, script, alias, and whitespace
  tables generated from Go 1.26.0.
- Matched the pinned Go implementation's handling of malformed UTF-8: regexp
  mode uses replacement-rune decoding, while exact and affix modes retain their
  byte-oriented behavior.

### Verification

- Added an adapted conformance corpus containing the upstream PatternMatcher
  decision and compile-error cases plus review-derived differential edge cases.
- Added a development-only Go oracle pinned to `moby/patternmatcher` v0.6.1 and
  Go 1.26.0. The initial release verifies 140 path decisions and 24 compile
  errors with zero mismatches.
- Added regression coverage for parser preprocessing, POSIX path cleaning,
  ordered parent semantics, invalid UTF-8, RE2 character classes and Unicode
  properties, public API consistency, package contents, and oracle protocol
  integrity.
- Added strict Credo, Dialyzer, ExDoc, package-build, and CI verification.

### Packaging and attribution

- Shipped with zero runtime dependencies. StreamData, ExDoc, Credo, and Dialyxir
  are development and test dependencies only.
- Added Hex package metadata and publication-ready documentation for version
  0.1.0.
- Added Apache-2.0 attribution for semantics and adapted fixtures derived from
  `moby/patternmatcher` v0.6.1.
- Added BSD-3-Clause attribution for Unicode data generated from the Go standard
  library.

### Boundaries

- The compatibility target is `moby/patternmatcher` v0.6.1, not arbitrary future
  PatternMatcher versions or the complete Docker CLI build-context pipeline.
- The package evaluates paths supplied by callers. It does not walk filesystems,
  resolve symlinks, build context archives, apply Docker CLI special-file rules,
  or discover Dockerfile-specific ignore files.
- Matching paths use host-independent `/` separators; Windows separator
  semantics are not part of v0.1.0.
