defmodule Dockerignore.MatcherTest do
  use ExUnit.Case, async: true

  alias Dockerignore.{Compiler, Matcher, Parser}

  defp matcher(source) do
    {:ok, entries} = Parser.parse(source)
    {:ok, patterns} = Compiler.compile(entries)
    %Matcher{patterns: patterns}
  end

  test "normal rules ignore and negated rules re-include in source order" do
    matcher = matcher("**\n!util/docker/web\nutil/docker/web/private")

    assert Matcher.ignored?(matcher, "other/file")
    refute Matcher.ignored?(matcher, "util/docker/web/file")
    assert Matcher.ignored?(matcher, "util/docker/web/private/key")
  end

  test "a directory match applies to descendants and can be re-included" do
    matcher = matcher("docs\n!docs/README.md")

    assert Matcher.ignored?(matcher, "docs/guides/start.md")
    refute Matcher.ignored?(matcher, "docs/README.md")
  end

  test "leading double star suffix patterns match at root" do
    matcher = matcher("**/foo/bar")

    assert Matcher.ignored?(matcher, "foo/bar")
    assert Matcher.ignored?(matcher, "one/two/foo/bar")
  end

  test "explain returns the state-changing pattern" do
    matcher = matcher("*.log\n!important.log")

    assert {:ignored, %{source: "*.log"}} = Matcher.explain(matcher, "debug.log")
    assert {:kept, %{source: "!important.log"}} = Matcher.explain(matcher, "important.log")
    assert {:kept, :no_match} = Matcher.explain(matcher, "README.md")
    assert {:kept, :no_match} = Matcher.explain(matcher, ".")
  end

  test "explain preserves ordered parent-aware state changes" do
    matcher = matcher("docs\n!docs/README.md\ndocs/README.md/private")

    assert {:ignored, %{source: "docs"}} =
             Matcher.explain(matcher, "docs/guides/start.md")

    assert {:kept, %{source: "!docs/README.md"}} =
             Matcher.explain(matcher, "docs/README.md")

    assert {:ignored, %{source: "docs/README.md/private"}} =
             Matcher.explain(matcher, "docs/README.md/private/key")
  end

  test "uses RE2 ASCII whitespace semantics inside character classes" do
    matcher = matcher("[\\s]")

    for whitespace <- ["\t", "\n", <<12>>, "\r", " "] do
      assert Matcher.ignored?(matcher, whitespace)
    end

    refute Matcher.ignored?(matcher, <<11>>)
  end

  test "uses RE2 octal escapes through U+01FF" do
    assert Matcher.ignored?(matcher("\\777"), <<0x1FF::utf8>>)
  end

  test "generated dot tokens do not match newlines" do
    refute Matcher.ignored?(matcher("a**/target"), "a\n/target")
    refute Matcher.ignored?(matcher("a*/**"), "a/\n")
  end

  @tag timeout: 7_000
  test "matches repeated globstars without backtracking across path segments" do
    matcher = matcher(String.duplicate("**/", 8) <> "target")
    path = List.duplicate("segment", 60) |> Enum.join("/")

    {microseconds, ignored?} = :timer.tc(fn -> Matcher.ignored?(matcher, path) end)

    refute ignored?
    assert microseconds < 1_000_000, "expected under 1s, got #{microseconds / 1_000}ms"
  end
end
