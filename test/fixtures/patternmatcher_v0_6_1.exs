# Adapted from moby/patternmatcher v0.6.1 (Apache-2.0),
# commit 5a6d8429a19bb6948a372ff19e86fe83599a04b7.

%{
  matches: [
    # patternmatcher_test.go: named exclusion, folder, and empty-pattern tests.
    %{source: "!fileutils.go\n*.go", path: "fileutils.go", ignored: true},
    %{source: "docs\n!docs/README.md", path: "docs/README.md", ignored: false},
    %{source: "docs/\n!docs/README.md", path: "docs/README.md", ignored: false},
    %{source: "docs/*\n!docs/README.md", path: "docs/README.md", ignored: false},
    %{source: "*.go\n!fileutils.go", path: "fileutils.go", ignored: false},
    %{source: "*.go", path: ".", ignored: false},
    %{source: "", path: "/any/path/there", ignored: false},

    # patternmatcher_test.go: TestMatches (67 table rows plus the POSIX escape row).
    %{source: "**", path: "file", ignored: true},
    %{source: "**", path: "file/", ignored: true},
    %{source: "**/", path: "file", ignored: true},
    %{source: "**/", path: "file/", ignored: true},
    %{source: "**", path: "/", ignored: true},
    %{source: "**/", path: "/", ignored: true},
    %{source: "**", path: "dir/file", ignored: true},
    %{source: "**/", path: "dir/file", ignored: true},
    %{source: "**", path: "dir/file/", ignored: true},
    %{source: "**/", path: "dir/file/", ignored: true},
    %{source: "**/**", path: "dir/file", ignored: true},
    %{source: "**/**", path: "dir/file/", ignored: true},
    %{source: "dir/**", path: "dir/file", ignored: true},
    %{source: "dir/**", path: "dir/file/", ignored: true},
    %{source: "dir/**", path: "dir/dir2/file", ignored: true},
    %{source: "dir/**", path: "dir/dir2/file/", ignored: true},
    %{source: "**/dir", path: "dir", ignored: true},
    %{source: "**/dir", path: "dir/file", ignored: true},
    %{source: "**/dir2/*", path: "dir/dir2/file", ignored: true},
    %{source: "**/dir2/*", path: "dir/dir2/file/", ignored: true},
    %{source: "**/dir2/**", path: "dir/dir2/dir3/file", ignored: true},
    %{source: "**/dir2/**", path: "dir/dir2/dir3/file/", ignored: true},
    %{source: "**file", path: "file", ignored: true},
    %{source: "**file", path: "dir/file", ignored: true},
    %{source: "**/file", path: "dir/file", ignored: true},
    %{source: "**file", path: "dir/dir/file", ignored: true},
    %{source: "**/file", path: "dir/dir/file", ignored: true},
    %{source: "**/file*", path: "dir/dir/file", ignored: true},
    %{source: "**/file*", path: "dir/dir/file.txt", ignored: true},
    %{source: "**/file*txt", path: "dir/dir/file.txt", ignored: true},
    %{source: "**/file*.txt", path: "dir/dir/file.txt", ignored: true},
    %{source: "**/file*.txt*", path: "dir/dir/file.txt", ignored: true},
    %{source: "**/**/*.txt", path: "dir/dir/file.txt", ignored: true},
    %{source: "**/**/*.txt2", path: "dir/dir/file.txt", ignored: false},
    %{source: "**/*.txt", path: "file.txt", ignored: true},
    %{source: "**/**/*.txt", path: "file.txt", ignored: true},
    %{source: "a**/*.txt", path: "a/file.txt", ignored: true},
    %{source: "a**/*.txt", path: "a/dir/file.txt", ignored: true},
    %{source: "a**/*.txt", path: "a/dir/dir/file.txt", ignored: true},
    %{source: "a/*.txt", path: "a/dir/file.txt", ignored: false},
    %{source: "a/*.txt", path: "a/file.txt", ignored: true},
    %{source: "a/*.txt**", path: "a/file.txt", ignored: true},
    %{source: "a[b-d]e", path: "ae", ignored: false},
    %{source: "a[b-d]e", path: "ace", ignored: true},
    %{source: "a[b-d]e", path: "aae", ignored: false},
    %{source: "a[^b-d]e", path: "aze", ignored: true},
    %{source: ".*", path: ".foo", ignored: true},
    %{source: ".*", path: "foo", ignored: false},
    %{source: "abc.def", path: "abcdef", ignored: false},
    %{source: "abc.def", path: "abc.def", ignored: true},
    %{source: "abc.def", path: "abcZdef", ignored: false},
    %{source: "abc?def", path: "abcZdef", ignored: true},
    %{source: "abc?def", path: "abcdef", ignored: false},
    %{source: "a\\\\", path: "a\\", ignored: true},
    %{source: "**/foo/bar", path: "foo/bar", ignored: true},
    %{source: "**/foo/bar", path: "dir/foo/bar", ignored: true},
    %{source: "**/foo/bar", path: "dir/dir2/foo/bar", ignored: true},
    %{source: "abc/**", path: "abc", ignored: false},
    %{source: "abc/**", path: "abc/def", ignored: true},
    %{source: "abc/**", path: "abc/def/ghi", ignored: true},
    %{source: "**/.foo", path: ".foo", ignored: true},
    %{source: "**/.foo", path: "bar.foo", ignored: false},
    %{source: "a(b)c/def", path: "a(b)c/def", ignored: true},
    %{source: "a(b)c/def", path: "a(b)c/xyz", ignored: false},
    %{source: "a.|)$(}+{bc", path: "a.|)$(}+{bc", ignored: true},
    %{
      source: "dist/proxy.py-2.4.0rc3.dev36+g08acad9-py3-none-any.whl",
      path: "dist/proxy.py-2.4.0rc3.dev36+g08acad9-py3-none-any.whl",
      ignored: true
    },
    %{
      source: "dist/*.whl",
      path: "dist/proxy.py-2.4.0rc3.dev36+g08acad9-py3-none-any.whl",
      ignored: true
    },
    %{source: "a\\*b", path: "a*b", ignored: true},

    # patternmatcher_test.go: multiPatternTests (source order retained as lines).
    %{source: "**\n!util/docker/web", path: "util/docker/web/foo", ignored: false},
    %{
      source: "**\n!util/docker/web\nutil/docker/web/foo",
      path: "util/docker/web/foo",
      ignored: true
    },
    %{
      source: "**\n!dist/proxy.py-2.4.0rc3.dev36+g08acad9-py3-none-any.whl",
      path: "dist/proxy.py-2.4.0rc3.dev36+g08acad9-py3-none-any.whl",
      ignored: false
    },
    %{
      source: "**\n!dist/*.whl",
      path: "dist/proxy.py-2.4.0rc3.dev36+g08acad9-py3-none-any.whl",
      ignored: false
    },

    # patternmatcher_test.go: matchTests with a nil error (39 filepath cases).
    %{source: "abc", path: "abc", ignored: true},
    %{source: "*", path: "abc", ignored: true},
    %{source: "*c", path: "abc", ignored: true},
    %{source: "a*", path: "a", ignored: true},
    %{source: "a*", path: "abc", ignored: true},
    %{source: "a*", path: "ab/c", ignored: true},
    %{source: "a*/b", path: "abc/b", ignored: true},
    %{source: "a*/b", path: "a/c/b", ignored: false},
    %{source: "a*b*c*d*e*/f", path: "axbxcxdxe/f", ignored: true},
    %{source: "a*b*c*d*e*/f", path: "axbxcxdxexxx/f", ignored: true},
    %{source: "a*b*c*d*e*/f", path: "axbxcxdxe/xxx/f", ignored: false},
    %{source: "a*b*c*d*e*/f", path: "axbxcxdxexxx/fff", ignored: false},
    %{source: "a*b?c*x", path: "abxbbxdbxebxczzx", ignored: true},
    %{source: "a*b?c*x", path: "abxbbxdbxebxczzy", ignored: false},
    %{source: "ab[c]", path: "abc", ignored: true},
    %{source: "ab[b-d]", path: "abc", ignored: true},
    %{source: "ab[e-g]", path: "abc", ignored: false},
    %{source: "ab[^c]", path: "abc", ignored: false},
    %{source: "ab[^b-d]", path: "abc", ignored: false},
    %{source: "ab[^e-g]", path: "abc", ignored: true},
    %{source: "a\\*b", path: "a*b", ignored: true},
    %{source: "a\\*b", path: "ab", ignored: false},
    %{source: "a?b", path: "a☺b", ignored: true},
    %{source: "a[^a]b", path: "a☺b", ignored: true},
    %{source: "a???b", path: "a☺b", ignored: false},
    %{source: "a[^a][^a][^a]b", path: "a☺b", ignored: false},
    %{source: "[a-ζ]*", path: "α", ignored: true},
    %{source: "*[a-ζ]", path: "A", ignored: false},
    %{source: "a?b", path: "a/b", ignored: false},
    %{source: "a*b", path: "a/b", ignored: false},
    %{source: "[\\]a]", path: "]", ignored: true},
    %{source: "[\\-]", path: "-", ignored: true},
    %{source: "[x\\-]", path: "x", ignored: true},
    %{source: "[x\\-]", path: "-", ignored: true},
    %{source: "[x\\-]", path: "z", ignored: false},
    %{source: "[\\-x]", path: "x", ignored: true},
    %{source: "[\\-x]", path: "-", ignored: true},
    %{source: "[\\-x]", path: "a", ignored: false},
    %{source: "*x", path: "xxx", ignored: true}
  ],
  errors: [
    # patternmatcher_test.go: named malformed-pattern tests.
    %{source: "!", error: true},
    %{source: "[", error: true},

    # patternmatcher_test.go: matchTests with filepath.ErrBadPattern (15 cases).
    %{source: "[]a]", error: true},
    %{source: "[-]", error: true},
    %{source: "[x-]", error: true},
    %{source: "[x-]", error: true},
    %{source: "[x-]", error: true},
    %{source: "[-x]", error: true},
    %{source: "[-x]", error: true},
    %{source: "[-x]", error: true},
    %{source: "\\", error: true},
    %{source: "[a-b-c]", error: true},
    %{source: "[", error: true},
    %{source: "[^", error: true},
    %{source: "[^bc", error: true},
    %{source: "a[", error: true},
    %{source: "a[", error: true}
  ],
  compile: [
    # patternmatcher_test.go: compileTests (21 POSIX rows).
    %{source: "*", match_type: :regexp, regex_source: "^[^/]*$"},
    %{source: "file*", match_type: :regexp, regex_source: "^file[^/]*$"},
    %{source: "*file", match_type: :regexp, regex_source: "^[^/]*file$"},
    %{source: "a*/b", match_type: :regexp, regex_source: "^a[^/]*/b$"},
    %{source: "**", match_type: :suffix, regex_source: nil},
    %{source: "**/**", match_type: :regexp, regex_source: "^(.*/)?.*$"},
    %{source: "dir/**", match_type: :prefix, regex_source: nil},
    %{source: "**/dir", match_type: :suffix, regex_source: nil},
    %{source: "**/dir2/*", match_type: :regexp, regex_source: "^(.*/)?dir2/[^/]*$"},
    %{source: "**/dir2/**", match_type: :regexp, regex_source: "^(.*/)?dir2/.*$"},
    %{source: "**file", match_type: :suffix, regex_source: nil},
    %{source: "**/file*txt", match_type: :regexp, regex_source: "^(.*/)?file[^/]*txt$"},
    %{source: "**/**/*.txt", match_type: :regexp, regex_source: "^(.*/)?(.*/)?[^/]*\\.txt$"},
    %{source: "a[b-d]e", match_type: :regexp, regex_source: "^a[b-d]e$"},
    %{source: ".*", match_type: :regexp, regex_source: "^\\.[^/]*$"},
    %{source: "abc.def", match_type: :exact, regex_source: nil},
    %{source: "abc?def", match_type: :regexp, regex_source: "^abc[^/]def$"},
    %{source: "**/foo/bar", match_type: :suffix, regex_source: nil},
    %{source: "a(b)c/def", match_type: :exact, regex_source: nil},
    %{source: "a.|)$(}+{bc", match_type: :exact, regex_source: nil},
    %{
      source: "dist/proxy.py-2.4.0rc3.dev36+g08acad9-py3-none-any.whl",
      match_type: :exact,
      regex_source: nil
    }
  ],
  # Final-review regressions are deliberately separate from the upstream corpus.
  differential: [
    %{id: "re2-invalid-R", source: "\\R", path: "path", expected: :error},
    %{id: "empty-exclusion-slash", source: "!/", path: "", expected: :error},
    %{id: "empty-exclusion-space-slash", source: "! /", path: "", expected: :error},
    %{id: "re2-whitespace-vertical-tab", source: "[\\s]", path: <<11>>, expected: false},
    %{id: "re2-single-octal-backreference", source: "\\1", path: <<1>>, expected: :error},
    %{id: "re2-octal-777", source: "\\777", path: <<0x1FF::utf8>>, expected: true},
    %{id: "re2-surrogate-hex", source: "\\x{D800}", path: "", expected: false},
    %{id: "re2-dot-globstar-newline", source: "a**/target", path: "a\n/target", expected: false},

    # Corrective review regressions, verified against the Go 1.26.0 controller.
    %{id: "review-alt-anchor-precedence", source: "a*|b", path: "ax", expected: true},
    %{id: "review-counted-repetition", source: "a?{2}", path: "abc", expected: true},
    %{id: "review-nested-repetition-error", source: "*{2}", path: "aa{2}", expected: :error},
    %{
      id: "review-greek-script-property",
      source: "\\p{Greek}",
      path: <<0x03B1::utf8>>,
      expected: true
    },
    %{id: "review-class-backspace-error", source: "[\\b]", path: <<8>>, expected: :error},
    %{
      id: "review-posix-class-trailing-hyphen",
      source: "[[:digit:]-]",
      path: "-",
      expected: true
    },
    %{id: "review-canonical-one-letter-property", source: "\\pl", path: "A", expected: true},
    %{
      id: "review-unicode15-nag-mundari-letter",
      source: "\\pL",
      path: <<0x1E4D0::utf8>>,
      expected: true
    },
    %{
      id: "review-unicode15-toto-letter",
      source: "\\pL",
      path: <<0x1E290::utf8>>,
      expected: true
    },
    %{
      id: "review-unicode15-kawi-number",
      source: "\\pN",
      path: <<0x11F50::utf8>>,
      expected: true
    },
    %{id: "review-invalid-utf8-regexp-path", source: "\\D", path: <<255>>, expected: true},
    %{
      id: "review-invalid-utf8-source-class",
      source: <<"[", 255, "]">>,
      path: <<255>>,
      expected: :error
    },
    %{
      id: "review-invalid-utf8-source-literal",
      source: <<"*", 255>>,
      path: <<"x", 254>>,
      expected: true
    },
    %{id: "review-clean-after-trim", source: "foo/../ **", path: "README.md", expected: true},
    %{id: "review-posix-class-literal-fallback", source: "[[:x]]", path: "x]", expected: true},

    # Deterministic Go 1.26 Unicode property differential sample.
    %{
      id: "unicode-property-canonical-alias",
      source: "\\p{cased-letter}",
      path: "A",
      expected: true
    },
    %{
      id: "unicode-property-category-alias",
      source: "\\p{Lowercase_Letter}",
      path: "a",
      expected: true
    },
    %{
      id: "unicode-property-canonical-script",
      source: "\\p{deseret}",
      path: <<0x10400::utf8>>,
      expected: true
    },
    %{id: "unicode-property-inverted-braced", source: "\\p{^Greek}", path: "A", expected: true},
    %{id: "unicode-property-inverted-upper", source: "\\P{Greek}", path: "A", expected: true},
    %{id: "unicode-property-assigned-special", source: "\\p{Assigned}", path: "A", expected: true}
  ]
}
