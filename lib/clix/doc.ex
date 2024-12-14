defmodule CLIX.Doc do
  @moduledoc """
  Generates clear and compact docs.

  """

  # ** (CLIX.ParseError) 1 error found!
  # --limit : Expected type integer, got "xyz"
  #
  # iex> CLIX.parse!(["--unknown", "xyz"], strict: [])
  # ** (CLIX.ParseError) 1 error found!
  # --unknown : Unknown option
  #
  # ** (CLIX.ParseError) 2 errors found!
  # -l : Expected type integer, got "xyz"
  # -f : Expected type integer, got "bar"
end
