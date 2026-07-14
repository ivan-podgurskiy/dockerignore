defmodule DockerignoreTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  doctest Dockerignore

  test "parses and compiles source" do
    source = "_build/\ndeps/\n*.log\n!important.log"

    assert {:ok, patterns} = Dockerignore.parse(source)
    assert Enum.map(patterns, & &1.pattern) == ["_build", "deps", "*.log", "important.log"]

    assert {:ok, matcher} = Dockerignore.compile(source)
    assert Dockerignore.ignored?(matcher, "_build/prod/app.beam")
    refute Dockerignore.ignored?(matcher, "important.log")
  end

  test "skips positive patterns emptied by the matcher trim pass" do
    assert {:ok, []} = Dockerignore.parse("foo/../ /.")
  end

  test "bang variants raise the source-aware error" do
    assert_raise Dockerignore.Error, ~r/line 2/, fn ->
      Dockerignore.compile!("ok\n[")
    end

    assert_raise Dockerignore.Error, fn -> Dockerignore.parse!("!") end
  end

  test "filter preserves order and duplicates" do
    matcher = Dockerignore.compile!("*.log\n!important.log")
    paths = ["debug.log", "README.md", "important.log", "README.md"]

    assert Dockerignore.filter(matcher, paths) == ["README.md", "important.log", "README.md"]
  end

  test "filter accepts streams" do
    matcher = Dockerignore.compile!("*.log\n!important.log")
    paths = Stream.map(["debug.log", "README.md", "important.log", "README.md"], & &1)

    assert Dockerignore.filter(matcher, paths) == ["README.md", "important.log", "README.md"]
  end

  property "filter returns an order-preserving subsequence" do
    check all(paths <- list_of(string(:alphanumeric), max_length: 40)) do
      matcher = Dockerignore.compile!("tmp*")
      filtered = Dockerignore.filter(matcher, paths)

      assert filtered == Enum.reject(paths, &Dockerignore.ignored?(matcher, &1))
    end
  end

  property "explain and ignored? agree" do
    check all(path <- string(:printable, min_length: 1, max_length: 80)) do
      matcher = Dockerignore.compile!("**\n!important")

      assert Dockerignore.ignored?(matcher, path) ==
               match?({:ignored, _pattern}, Dockerignore.explain(matcher, path))
    end
  end

  property "adding a non-negated rule cannot keep an already ignored path" do
    check all(
            source_patterns <-
              list_of(member_of(["*", "tmp*", "logs", "**/*.beam"]), min_length: 1),
            path <- string(:alphanumeric, min_length: 1, max_length: 80)
          ) do
      source = Enum.join(source_patterns, "\n")
      matcher = Dockerignore.compile!(source)

      if Dockerignore.ignored?(matcher, path) do
        extended = Dockerignore.compile!(source <> "\nextra*")
        assert Dockerignore.ignored?(extended, path)
      end
    end
  end
end
