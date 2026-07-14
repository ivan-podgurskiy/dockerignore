defmodule Dockerignore.Compiler do
  @moduledoc false

  alias Dockerignore.{Error, Filepath, Glob, Parser, Path, Pattern, UTF8}

  @doc false
  @spec compile([Parser.Entry.t()]) :: {:ok, [Pattern.t()]} | {:error, Error.t()}
  def compile(entries) when is_list(entries) do
    entries
    |> Enum.reduce_while({:ok, []}, fn entry, {:ok, patterns} ->
      case compile_entry(entry) do
        :skip -> {:cont, {:ok, patterns}}
        {:ok, pattern} -> {:cont, {:ok, [pattern | patterns]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
    |> reverse_patterns()
  end

  defp reverse_patterns({:ok, patterns}), do: {:ok, Enum.reverse(patterns)}
  defp reverse_patterns(error), do: error

  defp compile_entry(%Parser.Entry{} = entry) do
    case matcher_pattern(entry) do
      :skip ->
        :skip

      {pattern, negated?} ->
        with :ok <- validate_exclusion(negated?, pattern),
             :ok <- Filepath.validate(pattern),
             {:ok, match_type, regex_source} <- translate(pattern),
             {:ok, compiled} <- compile_match(pattern, match_type, regex_source) do
          {:ok,
           %Pattern{
             source: entry.source,
             line: entry.line,
             pattern: pattern,
             negated?: negated?,
             match_type: match_type,
             regex_source: regex_source,
             compiled: compiled
           }}
        else
          {:error, reason} -> {:error, error(entry, reason)}
        end
    end
  end

  defp matcher_pattern(%Parser.Entry{negated?: negated?, pattern: pattern}) do
    pattern = if negated?, do: <<"!", pattern::binary>>, else: pattern
    pattern = UTF8.trim_space(pattern)

    if pattern == "" do
      :skip
    else
      pattern = Path.clean(pattern)

      if starts_with?(pattern, "!") do
        {binary_part(pattern, 1, byte_size(pattern) - 1), true}
      else
        {pattern, false}
      end
    end
  end

  defp validate_exclusion(true, ""), do: {:error, :illegal_exclusion}
  defp validate_exclusion(_negated?, _pattern), do: :ok

  # The scanner in patternmatcher turns each malformed UTF-8 byte into RuneError
  # while constructing a regexp. Filepath validation ran on raw bytes above.
  defp translate(pattern) do
    {regex, match_type} = translate_tokens(UTF8.decode_lossy(pattern), 0, "^", :exact)

    case match_type do
      :regexp -> {:ok, :regexp, regex <> "$"}
      type -> {:ok, type, nil}
    end
  end

  defp translate_tokens([], _index, regex, match_type), do: {regex, match_type}

  defp translate_tokens([?*, ?*, ?/ | rest], index, regex, match_type) do
    translate_double_star(rest, index, regex, match_type)
  end

  defp translate_tokens([?*, ?* | rest], index, regex, match_type) do
    translate_double_star(rest, index, regex, match_type)
  end

  defp translate_tokens([?* | rest], index, regex, _match_type) do
    translate_tokens(rest, index + 1, regex <> "[^/]*", :regexp)
  end

  defp translate_tokens([?? | rest], index, regex, _match_type) do
    translate_tokens(rest, index + 1, regex <> "[^/]", :regexp)
  end

  defp translate_tokens([?\\, escaped | rest], index, regex, _match_type) do
    translate_tokens(rest, index + 1, regex <> "\\" <> codepoint(escaped), :regexp)
  end

  defp translate_tokens([token | rest], index, regex, _match_type) when token in [?[, ?]] do
    translate_tokens(rest, index + 1, regex <> codepoint(token), :regexp)
  end

  defp translate_tokens([token | rest], index, regex, match_type) do
    regex =
      if should_escape?(token),
        do: regex <> "\\" <> codepoint(token),
        else: regex <> codepoint(token)

    translate_tokens(rest, index + 1, regex, match_type)
  end

  defp translate_double_star([], 0, regex, _match_type), do: {regex, :suffix}
  defp translate_double_star([], _index, regex, :exact), do: {regex, :prefix}
  defp translate_double_star([], _index, regex, _match_type), do: {regex <> ".*", :regexp}

  defp translate_double_star(rest, 0, regex, _match_type) do
    translate_tokens(rest, 1, regex <> "(.*/)?", :suffix)
  end

  defp translate_double_star(rest, index, regex, _match_type) do
    translate_tokens(rest, index + 1, regex <> "(.*/)?", :regexp)
  end

  defp compile_match(pattern, :exact, _regex_source), do: {:ok, {:exact, pattern}}

  defp compile_match(pattern, :prefix, _regex_source) do
    {:ok, {:prefix, binary_part(pattern, 0, byte_size(pattern) - 2)}}
  end

  defp compile_match(pattern, :suffix, _regex_source) do
    {:ok, {:suffix, binary_part(pattern, 2, byte_size(pattern) - 2)}}
  end

  defp compile_match(_pattern, :regexp, regex_source) do
    case Glob.compile(regex_source) do
      {:ok, program} -> {:ok, {:regexp, program}}
      {:error, :invalid_pattern} -> {:error, :invalid_pattern}
    end
  end

  # v0.6.1's eight-byte bitmap loses the high bits for |, {, and }; only these
  # five ASCII metacharacters survive it and must be escaped in emitted RE2.
  defp should_escape?(codepoint), do: codepoint in [?., ?+, ?(, ?), ?$]

  defp codepoint(codepoint), do: <<codepoint::utf8>>

  defp starts_with?(binary, prefix) when byte_size(binary) >= byte_size(prefix),
    do: binary_part(binary, 0, byte_size(prefix)) == prefix

  defp starts_with?(_binary, _prefix), do: false

  defp error(entry, reason), do: %Error{line: entry.line, pattern: entry.source, reason: reason}
end
