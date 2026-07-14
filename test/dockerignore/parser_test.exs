defmodule Dockerignore.ParserTest do
  use ExUnit.Case, async: true

  alias Dockerignore.Parser

  test "matches ignorefile v0.6.1 preprocessing" do
    source =
      Enum.join(
        [
          "test1",
          "/test2",
          "/a/file/here",
          "",
          "lastfile",
          "# this is a comment",
          "! /inverted/abs/path",
          "!",
          "! "
        ],
        "\n"
      )

    assert {:ok, entries} = Parser.parse(source)

    assert Enum.map(entries, &{&1.pattern, &1.negated?}) == [
             {"test1", false},
             {"test2", false},
             {"a/file/here", false},
             {"lastfile", false},
             {"inverted/abs/path", true},
             {"", true},
             {"", true}
           ]
  end

  test "strips only an initial BOM and detects comments before trimming" do
    source = <<0xEF, 0xBB, 0xBF, "# comment\n  #literal\n/#root\r\nfoo/\n">>

    assert {:ok, entries} = Parser.parse(source)

    assert Enum.map(entries, &{&1.line, &1.source, &1.pattern}) == [
             {2, "  #literal", "#literal"},
             {3, "/#root", "#root"},
             {4, "foo/", "foo"}
           ]
  end

  test "cleans negated patterns after removing the marker" do
    assert {:ok, [entry]} = Parser.parse("! /foo/../bar/ ")
    assert entry.pattern == "bar"
    assert entry.negated?
    assert entry.line == 1
  end
end
