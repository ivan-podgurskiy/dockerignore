defmodule Dockerignore.Filepath do
  @moduledoc false

  alias Dockerignore.UTF8

  @spec validate(binary()) :: :ok | {:error, :trailing_escape | :invalid_character_class}
  def validate(pattern) when is_binary(pattern), do: scan(pattern)

  # This is the syntax-only portion of Go's POSIX filepath.Match. Patternmatcher
  # calls it before converting the pattern to RE2, so its byte-oriented class
  # grammar intentionally remains separate from Dockerignore.Glob.
  defp scan(<<>>), do: :ok
  defp scan(<<"\\">>), do: {:error, :trailing_escape}
  defp scan(<<"\\", _byte, rest::binary>>), do: scan(rest)

  defp scan(<<"[", rest::binary>>) do
    with {:ok, rest} <- parse_class(rest) do
      scan(rest)
    end
  end

  defp scan(<<_byte, rest::binary>>), do: scan(rest)

  defp parse_class(<<"^", rest::binary>>), do: parse_class_items(rest, 0)
  defp parse_class(rest), do: parse_class_items(rest, 0)

  defp parse_class_items(<<"]", rest::binary>>, count) when count > 0, do: {:ok, rest}

  defp parse_class_items(rest, count) do
    with {:ok, _codepoint, rest} <- get_escaped(rest),
         {:ok, rest} <- parse_range_end(rest) do
      parse_class_items(rest, count + 1)
    end
  end

  defp parse_range_end(<<"-", rest::binary>>) do
    with {:ok, _codepoint, rest} <- get_escaped(rest) do
      {:ok, rest}
    end
  end

  defp parse_range_end(rest), do: {:ok, rest}

  defp get_escaped(<<>>), do: {:error, :invalid_character_class}
  defp get_escaped(<<"-", _::binary>>), do: {:error, :invalid_character_class}
  defp get_escaped(<<"]", _::binary>>), do: {:error, :invalid_character_class}
  defp get_escaped(<<"\\">>), do: {:error, :trailing_escape}
  defp get_escaped(<<"\\", rest::binary>>), do: decode_class_rune(rest)
  defp get_escaped(rest), do: decode_class_rune(rest)

  defp decode_class_rune(binary) do
    case UTF8.decode_first_strict(binary) do
      {:ok, codepoint, size} ->
        <<_::binary-size(size), rest::binary>> = binary

        if rest == <<>> do
          {:error, :invalid_character_class}
        else
          {:ok, codepoint, rest}
        end

      :invalid ->
        {:error, :invalid_character_class}
    end
  end
end
