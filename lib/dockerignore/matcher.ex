defmodule Dockerignore.Matcher do
  @moduledoc "Evaluates immutable compiled .dockerignore patterns against paths."

  alias Dockerignore.{Glob, Path}

  @enforce_keys [:patterns]
  defstruct [:patterns]

  @type t :: %__MODULE__{patterns: [Dockerignore.Pattern.t()]}

  @spec ignored?(t(), binary()) :: boolean()
  def ignored?(matcher, path), do: match?({:ignored, _}, explain(matcher, path))

  @spec explain(t(), binary()) ::
          {:ignored, Dockerignore.Pattern.t()} | {:kept, Dockerignore.Pattern.t() | :no_match}
  def explain(%__MODULE__{patterns: patterns}, path) do
    path
    |> Path.clean()
    |> explain_path(patterns)
  end

  defp explain_path(".", _patterns), do: {:kept, :no_match}

  defp explain_path(cleaned_path, patterns) do
    candidates = [cleaned_path | Path.parents(cleaned_path)]

    {ignored?, deciding_pattern} =
      Enum.reduce(patterns, {false, nil}, fn pattern, state ->
        reduce_pattern(pattern, state, candidates)
      end)

    explain_result(ignored?, deciding_pattern)
  end

  defp reduce_pattern(pattern, {ignored?, _deciding_pattern} = state, candidates) do
    if pattern.negated? != ignored? do
      state
    else
      update_decision(pattern, state, candidates)
    end
  end

  defp update_decision(pattern, state, candidates) do
    if Enum.any?(candidates, &pattern_match?(pattern.compiled, &1)) do
      {not pattern.negated?, pattern}
    else
      state
    end
  end

  defp explain_result(true, pattern), do: {:ignored, pattern}
  defp explain_result(false, nil), do: {:kept, :no_match}
  defp explain_result(false, pattern), do: {:kept, pattern}

  defp pattern_match?({:exact, value}, path), do: path == value
  defp pattern_match?({:prefix, value}, path), do: starts_with?(path, value)

  defp pattern_match?({:suffix, value}, path) do
    ends_with?(path, value) or
      (starts_with?(value, "/") and path == binary_part(value, 1, byte_size(value) - 1))
  end

  defp pattern_match?({:regexp, program}, path), do: Glob.match?(program, path)

  defp starts_with?(binary, prefix) when byte_size(binary) >= byte_size(prefix),
    do: binary_part(binary, 0, byte_size(prefix)) == prefix

  defp starts_with?(_binary, _prefix), do: false

  defp ends_with?(binary, suffix) when byte_size(binary) >= byte_size(suffix) do
    binary_part(binary, byte_size(binary) - byte_size(suffix), byte_size(suffix)) == suffix
  end

  defp ends_with?(_binary, _suffix), do: false
end
