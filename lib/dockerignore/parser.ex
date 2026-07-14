defmodule Dockerignore.Parser do
  @moduledoc false

  alias Dockerignore.{Path, UTF8}

  defmodule Entry do
    @moduledoc false

    @enforce_keys [:source, :line, :pattern, :negated?]
    defstruct [:source, :line, :pattern, :negated?]

    @type t :: %__MODULE__{
            source: binary(),
            line: pos_integer(),
            pattern: binary(),
            negated?: boolean()
          }
  end

  @doc false
  @spec parse(binary()) :: {:ok, [Entry.t()]}
  def parse(source) when is_binary(source) do
    entries =
      source
      |> :binary.split("\n", [:global])
      |> Enum.with_index(1)
      |> Enum.flat_map(&parse_line/1)

    {:ok, entries}
  end

  defp parse_line({line, line_number}) do
    source = line |> remove_trailing_carriage_return() |> remove_bom(line_number)

    cond do
      starts_with?(source, "#") -> []
      UTF8.trim_space(source) == "" -> []
      true -> [entry(source, line_number)]
    end
  end

  defp entry(source, line_number) do
    trimmed = UTF8.trim_space(source)
    negated? = starts_with?(trimmed, "!")

    pattern =
      if negated? do
        trimmed
        |> drop_first_byte()
        |> UTF8.trim_space()
      else
        trimmed
      end

    %Entry{
      source: source,
      line: line_number,
      pattern: clean_pattern(pattern),
      negated?: negated?
    }
  end

  defp clean_pattern(""), do: ""

  defp clean_pattern(pattern) do
    pattern
    |> Path.clean()
    |> remove_leading_slash()
  end

  defp remove_trailing_carriage_return(line) do
    if byte_size(line) > 0 and :binary.last(line) == ?\r do
      binary_part(line, 0, byte_size(line) - 1)
    else
      line
    end
  end

  defp remove_bom(line, 1) do
    bom = <<0xEF, 0xBB, 0xBF>>

    if starts_with?(line, bom) do
      binary_part(line, byte_size(bom), byte_size(line) - byte_size(bom))
    else
      line
    end
  end

  defp remove_bom(line, _line_number), do: line

  defp remove_leading_slash("/"), do: "/"
  defp remove_leading_slash(<<"/", rest::binary>>), do: rest
  defp remove_leading_slash(pattern), do: pattern

  defp starts_with?(binary, prefix) when byte_size(binary) >= byte_size(prefix),
    do: binary_part(binary, 0, byte_size(prefix)) == prefix

  defp starts_with?(_binary, _prefix), do: false

  defp drop_first_byte(<<_byte, rest::binary>>), do: rest
end
