defmodule Dockerignore.Pattern do
  @moduledoc """
  Describes a parsed and compiled `.dockerignore` rule.

  `compiled` is private implementation state. It is not part of the supported
  data contract and may change between releases.
  """

  @enforce_keys [:source, :line, :pattern, :negated?, :match_type, :compiled]
  defstruct [:source, :line, :pattern, :negated?, :match_type, :regex_source, :compiled]

  @type match_type :: :exact | :prefix | :suffix | :regexp

  @type compiled :: term()

  @type t :: %__MODULE__{
          source: binary(),
          line: pos_integer(),
          pattern: binary(),
          negated?: boolean(),
          match_type: match_type(),
          regex_source: binary() | nil,
          compiled: compiled()
        }
end
