# Dockerignore

[![CI](https://github.com/ivan-podgurskiy/dockerignore/actions/workflows/ci.yml/badge.svg)](https://github.com/ivan-podgurskiy/dockerignore/actions/workflows/ci.yml)
[![Hex pm](https://img.shields.io/hexpm/v/dockerignore.svg)](https://hex.pm/packages/dockerignore)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Parse and match `.dockerignore` files in Elixir with Docker-compatible
semantics.

`Dockerignore` answers whether a relative path should be kept in or excluded
from a Docker build context. It implements ordered rules, negation,
parent-directory matching, recursive `**` patterns, Docker's ignore-file
preprocessing, and source-aware validation errors.

Use it when an Elixir application needs to make the same `.dockerignore`
path-selection decisions as Docker tooling, including:

- build-context archive generators and remote builders;
- CI pipelines, deployment tools, and repository scanners;
- developer tools that preview or validate Docker build contexts;
- AI coding agents and MCP servers that must avoid ignored build artifacts; and
- any service that accepts `.dockerignore` content and evaluates paths without
  shelling out to Docker or Go.

Compile a source once and reuse the immutable matcher across processes. The
core package does not walk the filesystem and has zero runtime dependencies.

Matcher behavior is differentially verified against
[`moby/patternmatcher`](https://github.com/moby/patternmatcher) v0.6.1. Moby,
Docker, and Go are not runtime dependencies.

## Why not glob?

`.dockerignore` is an ordered rule language, not a list of independent glob
patterns. A generic matcher can produce a different build context from Docker.

| Feature | Generic glob | `Dockerignore` |
| --- | --- | --- |
| Comments, blank lines, whitespace, and path cleaning | Usually caller-defined | PatternMatcher-compatible preprocessing |
| Negation with `!` | Usually unavailable | Ordered exclusion and re-inclusion |
| Parent-directory decisions | Pattern-only | Matching parents affect descendants |
| Recursive `**` | Library-specific | `moby/patternmatcher` v0.6.1 behavior |
| Invalid patterns | Often fail during matching or silently miss | Validated during compilation with source line context |
| Compatibility evidence | Implementation-specific | Differentially verified against the pinned Go matcher |

This matters for tooling: an approximate matcher can send unnecessary build
artifacts, omit required files, or report a context that disagrees with Docker.

## Installation

Add `dockerignore` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:dockerignore, "~> 0.1"}
  ]
end
```

To use the repository version before or between Hex releases:

```elixir
{:dockerignore, git: "https://github.com/ivan-podgurskiy/dockerignore.git"}
```

## Quick start

```elixir
source = """
_build/
*.log
!important.log
"""

matcher = Dockerignore.compile!(source)

Dockerignore.ignored?(matcher, "_build/prod/lib/app.beam")
#=> true

Dockerignore.ignored?(matcher, "debug.log")
#=> true

Dockerignore.ignored?(matcher, "important.log")
#=> false

Dockerignore.filter(matcher, ["debug.log", "README.md", "important.log"])
#=> ["README.md", "important.log"]

Dockerignore.explain(matcher, "important.log")
#=> {:kept, %Dockerignore.Pattern{source: "!important.log", line: 3, ...}}
```

All paths passed to the matcher are relative to the Docker build-context root
and use `/` as the separator.

## Public API

### Parse

`parse/1` preprocesses and validates a source, returning compiled public pattern
data in source order. `parse!/1` returns the same list or raises
`Dockerignore.Error`.

```elixir
source = "_build/\n*.log\n!important.log"

{:ok, patterns} = Dockerignore.parse(source)
Enum.map(patterns, &{&1.pattern, &1.negated?})
#=> [{"_build", false}, {"*.log", false}, {"important.log", true}]

patterns = Dockerignore.parse!(source)
length(patterns)
#=> 3
```

### Compile

`compile/1` parses the source and builds an immutable matcher. `compile!/1`
returns the matcher or raises `Dockerignore.Error`. Matching does not mutate the
matcher or lazily add state, so it can be shared between processes.

```elixir
{:ok, matcher} = Dockerignore.compile(source)
%Dockerignore.Matcher{patterns: patterns} = matcher

matcher = Dockerignore.compile!(source)
is_struct(matcher, Dockerignore.Matcher)
#=> true
```

### Match

`ignored?/2` cleans the path with pure POSIX path rules and returns whether the
path is ignored. A compiled matcher cannot produce a pattern error during
matching.

```elixir
Dockerignore.ignored?(matcher, "_build/prod/lib/app.beam")
#=> true

Dockerignore.ignored?(matcher, "important.log")
#=> false
```

### Filter

`filter/2` accepts any enumerable and eagerly returns only kept paths. It
preserves input order and duplicate entries.

```elixir
paths = ["debug.log", "README.md", "important.log", "README.md"]
Dockerignore.filter(matcher, paths)
#=> ["README.md", "important.log", "README.md"]

Dockerignore.filter(matcher, Stream.map(paths, & &1))
#=> ["README.md", "important.log", "README.md"]
```

### Explain

`explain/2` returns the final state and the last rule that changed it. The rule
may have matched the path itself or one of its parent directories.

```elixir
Dockerignore.explain(matcher, "debug.log")
#=> {:ignored, %Dockerignore.Pattern{source: "*.log", ...}}

Dockerignore.explain(matcher, "important.log")
#=> {:kept, %Dockerignore.Pattern{source: "!important.log", ...}}

Dockerignore.explain(matcher, "README.md")
#=> {:kept, :no_match}
```

The possible results are `{:ignored, pattern}`, `{:kept, pattern}`, and
`{:kept, :no_match}`. `%Dockerignore.Pattern{}` exposes the original source
line, one-based line number, cleaned pattern, negation flag, match type, and
generated regular-expression source when applicable.

## Paths and errors

Matching paths are relative to the build-context root and must use `/` as the
separator. Repeated separators, `.` segments, `..` segments, and trailing
separators are cleaned with host-independent POSIX rules. The library does not
walk the filesystem, resolve symlinks, expand paths, or consult the host OS.
The cleaned path `.` is always kept.

Patterns are processed in source order. Normal rules ignore matching paths;
when a normal rule matches an ancestor, its descendants are ignored too. A
later `!` rule can re-include a matching path, including a path below a parent
rule, following the upstream matcher behavior.

Invalid content is rejected before matching and retains original source line
context, including comments and blank lines:

```elixir
{:error, error} = Dockerignore.compile("ok\n[")
error.line
#=> 2

Exception.message(error)
#=> "invalid .dockerignore pattern on line 2: \"[\" (invalid character class)"

Dockerignore.compile!("ok\n[")
# raises Dockerignore.Error with the same line context
```

## Compatibility and verification

Version 0.1.0 targets the observable behavior of
[`moby/patternmatcher` v0.6.1](https://github.com/moby/patternmatcher/tree/v0.6.1),
including its `ignorefile` preprocessing. The compatibility boundary is the
same source and the same relative, slash-delimited path producing the same kept
or ignored decision.

Regexp-mode behavior is pinned to the Go 1.26.0 RE2 controller. The package
embeds Unicode 15.0.0 category, script, and alias tables generated from that
controller, so applications do not need Go or a runtime regular-expression
dependency.

The conformance suite includes the upstream decision and error cases plus
differential edge cases. The development oracle currently verifies **140 match
decisions and 24 compile errors with zero mismatches** against the pinned Go
implementation. See the
[conformance test](test/patternmatcher_conformance_test.exs) and
[oracle](scripts/oracle/check.exs).

The upstream implementation is the contract for supported inputs. This library
does not copy Go's internal mutability or platform-dependent path behavior.

## Roadmap

- Publish and maintain the v0.1 line on Hex and HexDocs.
- Evaluate future `moby/patternmatcher` releases as explicit compatibility
  targets before changing matcher semantics.
- Expand differential fixtures when new upstream edge cases are identified.
- Evaluate optional helpers for Dockerfile-specific ignore discovery and build
  context assembly while keeping the core matcher independent from filesystem
  I/O.
- Add repeatable performance and memory benchmarks for representative build
  contexts.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release history. Version 0.1.0 introduces
the parser, immutable matcher, public decision APIs, bounded RE2-compatible
engine, embedded Unicode tables, and the pinned PatternMatcher conformance
suite.

## Non-goals

Version 0.1 does not:

- walk a filesystem or construct a Docker build-context archive;
- reproduce Docker CLI rules that always transmit special files;
- discover per-Dockerfile ignore files;
- support Windows separator semantics; or
- claim compatibility with PatternMatcher versions other than v0.6.1.

## License and attribution

The package code is MIT licensed. Matcher semantics and adapted conformance
data derive from Docker's `moby/patternmatcher` v0.6.1 and are attributed under
Apache-2.0 in [NOTICE](NOTICE) and
[LICENSES/Apache-2.0.txt](LICENSES/Apache-2.0.txt).

The embedded Go 1.26.0 Unicode 15.0.0 tables are attributed under BSD-3-Clause
in [NOTICE](NOTICE) and
[LICENSES/BSD-3-Clause-Go.txt](LICENSES/BSD-3-Clause-Go.txt).
