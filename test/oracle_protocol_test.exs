defmodule Dockerignore.OracleProtocolTest do
  use ExUnit.Case, async: true

  {fixture, _binding} = Code.eval_file("test/fixtures/patternmatcher_v0_6_1.exs")
  @fixture fixture

  test "keeps final-review differential rows separate from the upstream corpus" do
    assert length(@fixture.matches) == 118
    assert length(@fixture.errors) == 17

    assert length(@fixture.differential) == 29

    assert Enum.take(@fixture.differential, 8) == [
             %{id: "re2-invalid-R", source: "\\R", path: "path", expected: :error},
             %{id: "empty-exclusion-slash", source: "!/", path: "", expected: :error},
             %{id: "empty-exclusion-space-slash", source: "! /", path: "", expected: :error},
             %{id: "re2-whitespace-vertical-tab", source: "[\\s]", path: <<11>>, expected: false},
             %{
               id: "re2-single-octal-backreference",
               source: "\\1",
               path: <<1>>,
               expected: :error
             },
             %{id: "re2-octal-777", source: "\\777", path: <<0x1FF::utf8>>, expected: true},
             %{id: "re2-surrogate-hex", source: "\\x{D800}", path: "", expected: false},
             %{
               id: "re2-dot-globstar-newline",
               source: "a**/target",
               path: "a\n/target",
               expected: false
             }
           ]

    assert Enum.map(Enum.drop(@fixture.differential, 8), & &1.id) == [
             "review-alt-anchor-precedence",
             "review-counted-repetition",
             "review-nested-repetition-error",
             "review-greek-script-property",
             "review-class-backspace-error",
             "review-posix-class-trailing-hyphen",
             "review-canonical-one-letter-property",
             "review-unicode15-nag-mundari-letter",
             "review-unicode15-toto-letter",
             "review-unicode15-kawi-number",
             "review-invalid-utf8-regexp-path",
             "review-invalid-utf8-source-class",
             "review-invalid-utf8-source-literal",
             "review-clean-after-trim",
             "review-posix-class-literal-fallback",
             "unicode-property-canonical-alias",
             "unicode-property-category-alias",
             "unicode-property-canonical-script",
             "unicode-property-inverted-braced",
             "unicode-property-inverted-upper",
             "unicode-property-assigned-special"
           ]
  end

  test "oracle protocol includes source-aware error rows and diagnostics" do
    checker = File.read!("scripts/oracle/check.exs")

    assert checker =~ "fixture.errors"
    assert checker =~ "path: \"\""
    assert checker =~ "source=\#{inspect(source)}"
    assert checker =~ "path=\#{inspect(path)}"
    assert checker =~ "decisions"
    assert checker =~ "errors"
  end
end
