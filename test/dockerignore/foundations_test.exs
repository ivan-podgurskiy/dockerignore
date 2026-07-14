defmodule Dockerignore.FoundationsTest do
  use ExUnit.Case, async: true

  alias Dockerignore.{Error, Matcher, Pattern}

  test "formats source-aware pattern errors" do
    error = %Error{line: 4, pattern: "[abc", reason: :invalid_character_class}

    assert Exception.message(error) ==
             ~s(invalid .dockerignore pattern on line 4: "[abc" \(invalid character class\))
  end

  test "stores compiled patterns in an immutable matcher" do
    pattern = %Pattern{
      source: "docs",
      line: 1,
      pattern: "docs",
      negated?: false,
      match_type: :exact,
      regex_source: nil,
      compiled: {:exact, "docs"}
    }

    assert %Matcher{patterns: [^pattern]} = %Matcher{patterns: [pattern]}
  end

  test "publishes the error type referenced by public specs" do
    assert {:ok, types} = Code.Typespec.fetch_types(Error)
    assert Enum.any?(types, &match?({:type, {:t, _, _}}, &1))
  end
end
