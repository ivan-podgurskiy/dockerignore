defmodule Dockerignore.RE2RegressionTest do
  use ExUnit.Case, async: true

  @controller_cases [
    %{source: "a*|b", path: "ax", expected: true},
    %{source: "a?{2}", path: "abc", expected: true},
    %{source: "*{2}", path: "aa{2}", expected: :error},
    %{source: "\\p{Greek}", path: <<0x03B1::utf8>>, expected: true},
    %{source: "[\\b]", path: <<8>>, expected: :error},
    %{source: "[[:digit:]-]", path: "-", expected: true},
    %{source: "\\pl", path: "A", expected: true},
    %{source: "\\pL", path: <<0x1E4D0::utf8>>, expected: true},
    %{source: "\\pL", path: <<0x1E290::utf8>>, expected: true},
    %{source: "\\pN", path: <<0x11F50::utf8>>, expected: true},
    %{source: "\\D", path: <<255>>, expected: true},
    %{source: <<"[", 255, "]">>, path: <<255>>, expected: :error},
    %{source: <<"*", 255>>, path: <<"x", 254>>, expected: true}
  ]

  test "matches every controller-confirmed reachable RE2 regression" do
    for %{source: source, path: path, expected: expected} <- @controller_cases do
      result =
        case Dockerignore.compile(source) do
          {:ok, matcher} -> Dockerignore.ignored?(matcher, path)
          {:error, _error} -> :error
        end

      assert result == expected,
             "source=#{inspect(source)} path=#{inspect(path)} expected=#{inspect(expected)} actual=#{inspect(result)}"
    end
  end

  test "keeps byte semantics for optimized exact, prefix, and suffix patterns" do
    exact = Dockerignore.compile!(<<255>>)
    assert Dockerignore.ignored?(exact, <<255>>)
    refute Dockerignore.ignored?(exact, <<0xFFFD::utf8>>)

    prefix = Dockerignore.compile!(<<255, "/**">>)
    assert Dockerignore.ignored?(prefix, <<255, "/child">>)

    suffix = Dockerignore.compile!(<<"**", 255>>)
    assert Dockerignore.ignored?(suffix, <<"child", 255>>)
  end

  test "keeps every public call total for binary inputs" do
    assert {:ok, [pattern]} = Dockerignore.parse(<<255>>)
    assert [^pattern] = Dockerignore.parse!(<<255>>)

    assert {:ok, matcher} = Dockerignore.compile(<<255>>)
    assert %Dockerignore.Matcher{} = Dockerignore.compile!(<<255>>)
    assert Dockerignore.ignored?(matcher, <<255>>)
    assert {:ignored, ^pattern} = Dockerignore.explain(matcher, <<255>>)
    assert Dockerignore.filter(matcher, [<<255>>, <<254>>]) == [<<254>>]
  end

  test "retains the earlier RE2 error and escape regressions" do
    assert {:error, %Dockerignore.Error{}} = Dockerignore.compile("\\R")
    assert {:error, %Dockerignore.Error{}} = Dockerignore.compile("\\1")
    assert {:error, %Dockerignore.Error{}} = Dockerignore.compile("!/")

    assert Dockerignore.ignored?(Dockerignore.compile!("\\777"), <<0x1FF::utf8>>)
    refute Dockerignore.ignored?(Dockerignore.compile!("\\x{D800}"), "")
    refute Dockerignore.ignored?(Dockerignore.compile!("a**/target"), "a\n/target")
    refute Dockerignore.ignored?(Dockerignore.compile!("[\\s]"), <<11>>)
  end
end
