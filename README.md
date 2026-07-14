# Dockerignore

`dockerignore` parses `.dockerignore` sources and matches relative build-context
paths using POSIX semantics. Version 0.1.0 targets the observable behavior of
`moby/patternmatcher` v0.6.1, including its `ignorefile` preprocessing.

The compatibility boundary is the same source and the same relative,
slash-delimited path producing the same kept or ignored decision. The upstream
v0.6.1 implementation is the contract for supported inputs; this library does
not copy Go's internal mutability or platform-dependent path behavior.

Regexp-mode compatibility is pinned to the Go 1.26.0 RE2 controller. The
package embeds compact Unicode 15.0.0 category, script, and alias tables
generated from that controller, so applications do not need Go or a runtime
regular-expression dependency.

See the exact [moby/patternmatcher v0.6.1 tag](https://github.com/moby/patternmatcher/tree/v0.6.1)
and this project's [v0.6.1 conformance test](https://github.com/ivan-podgurskiy/dockerignore/blob/main/test/patternmatcher_conformance_test.exs).

## Installation

Add `dockerignore` to your dependencies:

```elixir
def deps do
  [
    {:dockerignore, "~> 0.1.0"}
  ]
end
```

The package has zero runtime dependencies. Its development and test tooling is
not required by applications using it.

## Public API

All examples use paths relative to the Docker build-context root.

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
returns the matcher or raises `Dockerignore.Error`. Compile once and share the
matcher between processes; matching does not mutate it or lazily add state.

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

## Paths And Errors

Matching paths are relative to the build-context root and must use `/` as the
separator. Repeated separators, `.` segments, `..` segments, and trailing
separators are cleaned with host-independent POSIX rules. The library does not
walk the filesystem, resolve symlinks, expand paths, or consult the host OS.
The cleaned path `.` is always kept.

Patterns are processed in source order. Normal rules ignore matching paths; when
a normal rule matches an ancestor, its descendants are ignored too. A later `!`
rule can re-include a matching path, including a path below a parent rule,
following the upstream matcher behavior.

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

## Dockerignore And Gitignore

`dockerignore` is intentionally not a `.gitignore` implementation. The table
shows the important dialect differences for this library and Git's pattern
rules:

| Rule | `.dockerignore` | `.gitignore` |
| --- | --- | --- |
| Root anchoring | Patterns are relative to the build-context root; a bare `logs` rule matches root `logs` and its descendants, not `src/logs`. | A pattern without `/` can match a name at any directory level; `logs` can match `src/logs`. |
| `*` | Matches characters within a path segment and never crosses `/`; `*.log` matches root-level log paths in this dialect. | Also does not cross `/`, but a pattern without `/` is applied at every directory level. |
| `**` | Uses the v0.6.1 recursive wildcard behavior; `**/*.log` matches `app.log` and `logs/app.log`. | Has Git-specific recursive wildcard forms and anchoring rules; its behavior is not a compatibility target here. |
| Parent matching | A matching parent directory affects descendants, and a later `!` rule can re-include a matching descendant. | An ignored parent prevents Git from traversing to re-include a child with `!`. |
| `!` re-inclusion | Ordered exclusion rules change state in source order; a lone `!` is invalid. | Negates a pattern, subject to Git's directory traversal and parent-exclusion rules. |

## Non-goals

Version 0.1 does not:

* walk a filesystem or construct a Docker build-context archive;
* reproduce Docker CLI rules that always transmit special files;
* discover per-Dockerfile ignore files;
* support Windows separator semantics;
* provide `.gitignore` compatibility; or
* publish the package to Hex as part of this implementation cycle.

## License And Attribution

The package code is MIT licensed. Matcher semantics and adapted conformance
data derive from Docker's `moby/patternmatcher` v0.6.1 and are attributed under
Apache-2.0 in [NOTICE](NOTICE) and [LICENSES/Apache-2.0.txt](LICENSES/Apache-2.0.txt).
The embedded Go 1.26.0 Unicode 15.0.0 tables are attributed under BSD-3-Clause
in [NOTICE](NOTICE) and [LICENSES/BSD-3-Clause-Go.txt](LICENSES/BSD-3-Clause-Go.txt).
