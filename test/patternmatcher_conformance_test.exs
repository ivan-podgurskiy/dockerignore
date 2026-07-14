defmodule Dockerignore.PatternMatcherConformanceTest do
  use ExUnit.Case, async: true

  {fixture, _binding} = Code.eval_file("test/fixtures/patternmatcher_v0_6_1.exs")
  @matches fixture.matches
  @errors fixture.errors
  @compile fixture.compile

  test "matches every supported POSIX v0.6.1 decision" do
    for %{source: source, path: path, ignored: expected} <- @matches do
      matcher = Dockerignore.compile!(source)

      assert Dockerignore.ignored?(matcher, path) == expected,
             "source=#{inspect(source)} path=#{inspect(path)}"
    end
  end

  test "rejects every malformed v0.6.1 pattern" do
    for %{source: source} <- @errors do
      assert {:error, %Dockerignore.Error{}} = Dockerignore.compile(source)
    end
  end

  test "uses every POSIX v0.6.1 compile mode and regex source" do
    for %{source: source, match_type: match_type, regex_source: regex_source} <- @compile do
      assert [pattern] = Dockerignore.parse!(source)
      assert pattern.match_type == match_type
      assert pattern.regex_source == regex_source
    end
  end
end
