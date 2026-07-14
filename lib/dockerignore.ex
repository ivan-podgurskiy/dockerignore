defmodule Dockerignore do
  alias Dockerignore.{Compiler, Error, Matcher, Parser}

  @moduledoc """
  A `.dockerignore` matcher for Elixir with semantics pinned to
  [moby/patternmatcher](https://github.com/moby/patternmatcher) v0.6.1.

  ## Examples

      iex> source = "_build/\\n*.log\\n!important.log"
      iex> {:ok, patterns} = Dockerignore.parse(source)
      iex> Enum.map(patterns, & &1.pattern)
      ["_build", "*.log", "important.log"]
      iex> matcher = Dockerignore.compile!(source)
      iex> Dockerignore.ignored?(matcher, "_build/app.beam")
      true
      iex> Dockerignore.ignored?(matcher, "important.log")
      false
  """

  @spec parse(binary()) :: {:ok, [Dockerignore.Pattern.t()]} | {:error, Error.t()}
  def parse(source) when is_binary(source) do
    with {:ok, entries} <- Parser.parse(source) do
      Compiler.compile(entries)
    end
  end

  @spec parse!(binary()) :: [Dockerignore.Pattern.t()]
  def parse!(source) when is_binary(source) do
    case parse(source) do
      {:ok, patterns} -> patterns
      {:error, %Error{} = error} -> raise error
    end
  end

  @spec compile(binary()) :: {:ok, Matcher.t()} | {:error, Error.t()}
  def compile(source) when is_binary(source) do
    with {:ok, patterns} <- parse(source) do
      {:ok, %Matcher{patterns: patterns}}
    end
  end

  @spec compile!(binary()) :: Matcher.t()
  def compile!(source) when is_binary(source) do
    case compile(source) do
      {:ok, matcher} -> matcher
      {:error, %Error{} = error} -> raise error
    end
  end

  @spec ignored?(Matcher.t(), binary()) :: boolean()
  def ignored?(%Matcher{} = matcher, path) when is_binary(path) do
    Matcher.ignored?(matcher, path)
  end

  @spec explain(Matcher.t(), binary()) ::
          {:ignored, Dockerignore.Pattern.t()}
          | {:kept, Dockerignore.Pattern.t() | :no_match}
  def explain(%Matcher{} = matcher, path) when is_binary(path) do
    Matcher.explain(matcher, path)
  end

  @spec filter(Matcher.t(), Enumerable.t()) :: [binary()]
  def filter(%Matcher{} = matcher, paths) do
    Enum.reject(paths, &ignored?(matcher, &1))
  end
end
