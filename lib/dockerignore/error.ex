defmodule Dockerignore.Error do
  @moduledoc "Represents an invalid `.dockerignore` source pattern."

  defexception [:line, :pattern, :reason]

  @type reason ::
          :illegal_exclusion
          | :trailing_escape
          | :invalid_character_class
          | :invalid_pattern

  @type t :: %__MODULE__{
          line: pos_integer() | nil,
          pattern: binary(),
          reason: reason()
        }

  @reason_labels %{
    illegal_exclusion: "illegal exclusion",
    trailing_escape: "trailing escape",
    invalid_character_class: "invalid character class",
    invalid_pattern: "invalid pattern"
  }

  @impl true
  def message(%__MODULE__{line: nil, pattern: pattern, reason: reason}) do
    "invalid .dockerignore pattern: #{inspect(pattern)} (#{reason_label(reason)})"
  end

  def message(%__MODULE__{line: line, pattern: pattern, reason: reason}) do
    "invalid .dockerignore pattern on line #{line}: #{inspect(pattern)} (#{reason_label(reason)})"
  end

  defp reason_label(reason), do: Map.get(@reason_labels, reason, inspect(reason))
end
