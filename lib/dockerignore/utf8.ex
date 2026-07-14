defmodule Dockerignore.UTF8 do
  @moduledoc false

  import Bitwise

  alias Dockerignore.Unicode15

  @replacement 0xFFFD

  @spec decode_strict(binary()) :: {:ok, [non_neg_integer()]} | :error
  def decode_strict(binary) when is_binary(binary), do: decode_strict(binary, [])

  @spec decode_lossy(binary()) :: [non_neg_integer()]
  def decode_lossy(binary) when is_binary(binary), do: decode_lossy(binary, [])

  @spec decode_first_strict(binary()) :: {:ok, non_neg_integer(), pos_integer()} | :invalid
  def decode_first_strict(binary) when is_binary(binary) and byte_size(binary) > 0,
    do: next(binary)

  @spec trim_space(binary()) :: binary()
  def trim_space(binary) when is_binary(binary) do
    binary
    |> decode_spans(0, [])
    |> trim_spans(binary)
  end

  defp decode_strict(<<>>, acc), do: {:ok, Enum.reverse(acc)}

  defp decode_strict(binary, acc) do
    case next(binary) do
      {:ok, codepoint, size} ->
        <<_::binary-size(size), rest::binary>> = binary
        decode_strict(rest, [codepoint | acc])

      :invalid ->
        :error
    end
  end

  defp decode_lossy(<<>>, acc), do: Enum.reverse(acc)

  defp decode_lossy(binary, acc) do
    case next(binary) do
      {:ok, codepoint, size} ->
        <<_::binary-size(size), rest::binary>> = binary
        decode_lossy(rest, [codepoint | acc])

      :invalid ->
        <<_byte, rest::binary>> = binary
        decode_lossy(rest, [@replacement | acc])
    end
  end

  defp decode_spans(<<>>, _offset, acc), do: Enum.reverse(acc)

  defp decode_spans(binary, offset, acc) do
    case next(binary) do
      {:ok, codepoint, size} ->
        <<_::binary-size(size), rest::binary>> = binary
        decode_spans(rest, offset + size, [{codepoint, offset, size} | acc])

      :invalid ->
        <<_byte, rest::binary>> = binary
        decode_spans(rest, offset + 1, [{@replacement, offset, 1} | acc])
    end
  end

  defp trim_spans([], _binary), do: ""

  defp trim_spans(spans, binary) do
    kept = Enum.drop_while(spans, fn {codepoint, _offset, _size} -> space?(codepoint) end)

    case Enum.reverse(
           Enum.drop_while(Enum.reverse(kept), fn {codepoint, _offset, _size} ->
             space?(codepoint)
           end)
         ) do
      [] ->
        ""

      [{_first, first_offset, _first_size} | _] = trimmed ->
        {_last, last_offset, last_size} = List.last(trimmed)
        binary_part(binary, first_offset, last_offset + last_size - first_offset)
    end
  end

  defp space?(codepoint) when codepoint in [9, 10, 11, 12, 13, 32], do: true
  defp space?(codepoint), do: Unicode15.space?(codepoint)

  defp next(<<byte, _::binary>>) when byte < 0x80, do: {:ok, byte, 1}

  defp next(<<byte1, byte2, _rest::binary>>) when byte1 in 0xC2..0xDF and byte2 in 0x80..0xBF do
    {:ok, (byte1 &&& 0x1F) <<< 6 ||| (byte2 &&& 0x3F), 2}
  end

  defp next(<<0xE0, byte2, byte3, _::binary>>)
       when byte2 in 0xA0..0xBF and byte3 in 0x80..0xBF do
    {:ok, ((byte2 &&& 0x3F) <<< 6) + (byte3 &&& 0x3F), 3}
  end

  defp next(<<byte1, byte2, byte3, _::binary>>)
       when byte1 in 0xE1..0xEC and byte2 in 0x80..0xBF and byte3 in 0x80..0xBF do
    {:ok, ((byte1 &&& 0x0F) <<< 12) + ((byte2 &&& 0x3F) <<< 6) + (byte3 &&& 0x3F), 3}
  end

  defp next(<<0xED, byte2, byte3, _::binary>>)
       when byte2 in 0x80..0x9F and byte3 in 0x80..0xBF do
    {:ok, ((0xED &&& 0x0F) <<< 12) + ((byte2 &&& 0x3F) <<< 6) + (byte3 &&& 0x3F), 3}
  end

  defp next(<<byte1, byte2, byte3, _::binary>>)
       when byte1 in 0xEE..0xEF and byte2 in 0x80..0xBF and byte3 in 0x80..0xBF do
    {:ok, ((byte1 &&& 0x0F) <<< 12) + ((byte2 &&& 0x3F) <<< 6) + (byte3 &&& 0x3F), 3}
  end

  defp next(<<0xF0, byte2, byte3, byte4, _::binary>>)
       when byte2 in 0x90..0xBF and byte3 in 0x80..0xBF and byte4 in 0x80..0xBF do
    {:ok, ((byte2 &&& 0x3F) <<< 12) + ((byte3 &&& 0x3F) <<< 6) + (byte4 &&& 0x3F), 4}
  end

  defp next(<<byte1, byte2, byte3, byte4, _::binary>>)
       when byte1 in 0xF1..0xF3 and byte2 in 0x80..0xBF and byte3 in 0x80..0xBF and
              byte4 in 0x80..0xBF do
    {:ok,
     ((byte1 &&& 0x07) <<< 18) + ((byte2 &&& 0x3F) <<< 12) + ((byte3 &&& 0x3F) <<< 6) +
       (byte4 &&& 0x3F), 4}
  end

  defp next(<<0xF4, byte2, byte3, byte4, _::binary>>)
       when byte2 in 0x80..0x8F and byte3 in 0x80..0xBF and byte4 in 0x80..0xBF do
    {:ok,
     ((0xF4 &&& 0x07) <<< 18) + ((byte2 &&& 0x3F) <<< 12) + ((byte3 &&& 0x3F) <<< 6) +
       (byte4 &&& 0x3F), 4}
  end

  defp next(_binary), do: :invalid
end
