# Changelog

## 0.1.0 - 2026-07-13

Initial release candidate with:

* an `ignorefile`-compatible `.dockerignore` parser;
* an immutable, precompiled matcher with ordered parent-directory semantics;
* the public `explain/2` API for identifying the rule that changed a result;
* an adapted `moby/patternmatcher` v0.6.1 conformance corpus; and
* a development-only Go differential oracle pinned to `moby/patternmatcher`
  v0.6.1;
* a bounded RE2-compatible matcher pinned to Go 1.26.0 with embedded Unicode
  15.0.0 tables.
