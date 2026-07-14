defmodule Dockerignore.CompilerTest do
  use ExUnit.Case, async: true

  alias Dockerignore.{Compiler, Parser}

  @compile_cases [
    {"*", :regexp, "^[^/]*$"},
    {"file*", :regexp, "^file[^/]*$"},
    {"a*/b", :regexp, "^a[^/]*/b$"},
    {"**", :suffix, nil},
    {"**/**", :regexp, "^(.*/)?.*$"},
    {"dir/**", :prefix, nil},
    {"**/dir", :suffix, nil},
    {"**/dir2/*", :regexp, "^(.*/)?dir2/[^/]*$"},
    {"**/dir2/**", :regexp, "^(.*/)?dir2/.*$"},
    {"a[b-d]e", :regexp, "^a[b-d]e$"},
    {"foo]bar", :regexp, "^foo]bar$"},
    {".*", :regexp, "^\\.[^/]*$"},
    {"abc.def", :exact, nil},
    {"abc?def", :regexp, "^abc[^/]def$"},
    {"**/foo/bar", :suffix, nil},
    {"a(b)c/def", :exact, nil},
    {"a.|)$(}+{bc", :exact, nil}
  ]

  test "assigns the same POSIX match modes and regex sources as v0.6.1" do
    for {source, match_type, regex_source} <- @compile_cases do
      assert {:ok, [pattern]} =
               source
               |> Parser.parse()
               |> then(fn {:ok, entries} -> Compiler.compile(entries) end)

      assert pattern.match_type == match_type
      assert pattern.regex_source == regex_source
    end
  end

  test "preserves Unicode prefixes for terminal double-star patterns" do
    assert {:ok, [pattern]} =
             "é/**" |> Parser.parse() |> then(fn {:ok, entries} -> Compiler.compile(entries) end)

    assert pattern.match_type == :prefix
    assert pattern.compiled == {:prefix, "é/"}
  end

  test "trims the reconstructed pattern before cleaning it" do
    source = "foo/../ **"

    assert {:ok, [pattern]} = Dockerignore.parse(source)
    assert pattern.match_type == :suffix
    assert pattern.regex_source == nil
    assert pattern.pattern == "**"

    assert Dockerignore.ignored?(Dockerignore.compile!(source), "README.md")
  end

  test "preserves v0.6.1 reachable RE2 source, including its bitmap escaping bug" do
    cases = [
      {"a*|b", "^a[^/]*|b$"},
      {"a?{2}", "^a[^/]{2}$"},
      {"\\p{Greek}", "^\\p{Greek}$"},
      {"\\pl", "^\\pl$"},
      {"[[:digit:]-]", "^[[:digit:]-]$"}
    ]

    for {source, regex_source} <- cases do
      assert {:ok, [pattern]} = Dockerignore.parse(source)
      assert pattern.match_type == :regexp
      assert pattern.regex_source == regex_source
    end
  end

  test "rejects reachable RE2 nested counted repetition" do
    assert {:error, %Dockerignore.Error{reason: :invalid_pattern}} = Dockerignore.compile("*{2}")
  end

  test "reports the first malformed pattern with source context" do
    for source <- ["[", "[^", "a[", "[-]", "[x-]", "[a-b-c]"] do
      assert {:ok, entries} = Parser.parse("ok\n#{source}\nlater")
      assert {:error, %Dockerignore.Error{line: 2, pattern: ^source}} = Compiler.compile(entries)
    end
  end

  test "rejects a lone exclusion and trailing escape" do
    assert {:ok, entries} = Parser.parse("!")
    assert {:error, %Dockerignore.Error{reason: :illegal_exclusion}} = Compiler.compile(entries)

    assert {:ok, entries} = Parser.parse("foo\\")
    assert {:error, %Dockerignore.Error{reason: :trailing_escape}} = Compiler.compile(entries)
  end

  test "rejects RE2-invalid escapes with source context" do
    source = "\\R"

    assert {:error, %Dockerignore.Error{line: 2, pattern: ^source}} =
             Dockerignore.compile("ok\n#{source}")
  end

  test "rejects a single octal digit as an unsupported RE2 backreference" do
    source = "\\1"

    assert {:error, %Dockerignore.Error{line: 2, pattern: ^source, reason: :invalid_pattern}} =
             Dockerignore.compile("ok\n#{source}")
  end

  test "accepts a braced hexadecimal surrogate as an unmatchable RE2 literal" do
    assert {:ok, matcher} = Dockerignore.compile("\\x{D800}")
    refute Dockerignore.ignored?(matcher, "")
  end

  for source <- ["!/", "! /"] do
    test "rejects post-preprocessing empty exclusion #{inspect(source)} with source context" do
      source = unquote(source)

      assert {:error, %Dockerignore.Error{line: 2, pattern: ^source, reason: :illegal_exclusion}} =
               Dockerignore.compile("ok\n#{source}")
    end
  end
end
