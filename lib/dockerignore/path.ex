defmodule Dockerignore.Path do
  @moduledoc "Provides host-independent POSIX path cleaning and parent generation."

  @doc "Cleans a path using POSIX filepath.Clean semantics."
  @spec clean(binary()) :: binary()
  def clean(path) when is_binary(path) do
    rooted? = starts_with_slash?(path)
    segments = path |> :binary.split("/", [:global]) |> normalize_segments(rooted?, [])

    case {rooted?, segments} do
      {true, []} -> "/"
      {true, segments} -> "/" <> Enum.join(segments, "/")
      {false, []} -> "."
      {false, segments} -> Enum.join(segments, "/")
    end
  end

  @doc "Returns proper path prefixes from shallowest to deepest."
  @spec parents(binary()) :: [binary()]
  def parents(path) when is_binary(path) do
    path
    |> clean()
    |> :binary.split("/", [:global])
    |> Enum.reject(&(&1 == <<>>))
    |> prefixes()
  end

  defp starts_with_slash?(<<"/", _::binary>>), do: true
  defp starts_with_slash?(_path), do: false

  defp normalize_segments([], _rooted?, acc), do: Enum.reverse(acc)

  defp normalize_segments([segment | rest], rooted?, acc) do
    next_acc =
      cond do
        segment in ["", "."] -> acc
        segment == ".." and acc != [] and hd(acc) != ".." -> tl(acc)
        segment == ".." and rooted? -> acc
        true -> [segment | acc]
      end

    normalize_segments(rest, rooted?, next_acc)
  end

  defp prefixes(segments) do
    segments
    |> Enum.scan([], fn segment, prefix -> prefix ++ [segment] end)
    |> Enum.drop(-1)
    |> Enum.map(&Enum.join(&1, "/"))
  end
end
