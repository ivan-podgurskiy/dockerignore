defmodule Dockerignore.GlobTest do
  use ExUnit.Case, async: true

  alias Dockerignore.{Glob, Unicode15}

  defp compile!(source) do
    assert {:ok, program} = Glob.compile(source)
    program
  end

  test "keeps anchors scoped to their alternation branches and accepts early" do
    program = compile!("^a[^/]*|b$")

    assert Glob.match?(program, "ax")
    assert Glob.match?(program, "prefix-b")
    refute Glob.match?(program, "prefix-c")
  end

  test "parses counted repetitions and their lazy suffixes" do
    assert Glob.match?(compile!("^a{2}$"), "aa")
    assert Glob.match?(compile!("^a{2,}$"), "aaa")
    assert Glob.match?(compile!("^a{2,3}$"), "aaa")
    assert Glob.match?(compile!("^a{2,3}?$"), "aaa")
  end

  test "rejects invalid counted and stacked repetitions" do
    for source <- ["{2}", "^a|{2}$", "^a{1001}$", "^a{2,1}$", "^[^/]*{2}$", "^a**$"] do
      assert {:error, :invalid_pattern} = Glob.compile(source), source
    end

    assert Glob.match?(compile!("^a{01}$"), "a{01}")
  end

  test "handles empty alternates and RE2 character-class edge grammar" do
    assert Glob.match?(compile!("^a|$"), "")
    assert Glob.match?(compile!("^a|$"), "a")
    assert Glob.match?(compile!("^[a-]$"), "-")
    assert Glob.match?(compile!("^[-a]$"), "-")
    assert Glob.match?(compile!("^[]]$"), "]")
    assert Glob.match?(compile!("^[[:digit:]-]$"), "-")
    assert {:error, :invalid_pattern} = Glob.compile("^[\\b]$")
  end

  test "falls back to a literal inner bracket without a POSIX terminator" do
    assert Glob.match?(compile!("^[[:x]]$"), "x]")
    assert {:error, :invalid_pattern} = Glob.compile("^[[:unknown:]]$")
  end

  test "parses assertions, escapes, and ASCII Perl classes" do
    assert Glob.match?(compile!("\\Afoo\\z"), "foo")
    refute Glob.match?(compile!("\\Afoo\\z"), "xfoo")
    assert Glob.match?(compile!("^\\bword\\B_$"), "word_")
    assert Glob.match?(compile!("^\\Q.a+?\\E$"), ".a+?")
    assert Glob.match?(compile!("^\\x{1FF}$"), <<0x1FF::utf8>>)
    assert Glob.match?(compile!("^\\777$"), <<0x1FF::utf8>>)
    assert Glob.match?(compile!("^\\D$"), <<255>>)
    refute Glob.match?(compile!("^\\s$"), <<11>>)
  end

  test "accepts every generated Go 1.26 category, script, and alias name" do
    for name <- Unicode15.class_names() do
      assert {:ok, _program} = Glob.compile("^\\p{#{name}}$"), name
    end
  end

  test "canonicalizes Unicode property names like Go regexp/syntax" do
    for name <- Unicode15.class_names() do
      canonical_variant = name |> String.downcase() |> String.replace("_", "-")

      assert {:ok, _program} = Glob.compile("^\\p{#{canonical_variant}}$"), canonical_variant
    end

    assert Unicode15.provenance() == %{go: "1.26.0", unicode: "15.0.0"}
  end

  test "uses Go's reachable script-name map after canonicalization" do
    assert {:ok, _program} = Glob.compile("^\\p{deseret}$")

    for source <- ["^\\p{Old_Italic}$", "^\\p{old-italic}$"] do
      assert {:error, :invalid_pattern} = Glob.compile(source), source
    end
  end

  test "uses Unicode 15 tables for controller new codepoints" do
    assert Glob.match?(compile!("^\\pL$"), <<0x1E4D0::utf8>>)
    assert Glob.match?(compile!("^\\pL$"), <<0x1E290::utf8>>)
    assert Glob.match?(compile!("^\\pN$"), <<0x11F50::utf8>>)
  end
end
