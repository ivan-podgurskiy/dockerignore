defmodule Dockerignore.PathTest do
  use ExUnit.Case, async: true

  alias Dockerignore.Path

  test "cleans paths with POSIX filepath.Clean semantics" do
    cases = [
      {"", "."},
      {".", "."},
      {"./a", "a"},
      {"a//b/", "a/b"},
      {"a/./b", "a/b"},
      {"a/b/..", "a"},
      {"a/../../b", "../b"},
      {"../../a", "../../a"},
      {"/a/../b", "/b"},
      {"/../../a", "/a"},
      {"/", "/"}
    ]

    for {input, expected} <- cases do
      assert Path.clean(input) == expected
    end
  end

  test "returns parent paths from shallowest to deepest" do
    assert Path.parents("file") == []
    assert Path.parents("a/b/c.txt") == ["a", "a/b"]
    assert Path.parents("../a/file") == ["..", "../a"]
  end
end
