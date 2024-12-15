defmodule CLIX.Doc do
  @moduledoc """
  The doc generator.

  It's designed to generate clear and compact docs.
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

  # @doc false
  # def format_errors(config, [_ | _] = errors) do
  #   error_count = length(errors)
  #   error = if error_count == 1, do: "error", else: "errors"

  #   "#{error_count} #{error} found!\n" <>
  #     Enum.map_join(errors, "\n", &format_error(&1, config))
  # end

  # defp format_error({:unknown_opt, _opt_id, orig_opt}, _config) do
  #   "#{orig_opt}: unrecognized arguments"
  # end

  # defp format_error({:invalid_opt, opt_id, orig_opt, nil}, config) do
  #   type = get_opt_type(opt_id, config)
  #   "#{orig_opt}: missing value of type #{type}"
  # end

  # defp format_error({:invalid_opt, opt_id, orig_opt, value}, config) do
  #   type = get_opt_type(opt_id, config)
  #   "#{orig_opt}: expected value of type #{type}, got #{inspect(value)}"
  # end

  # defp get_opt_type({:long, name}, config),
  #   do: config.long_opt_args |> Map.fetch!(name) |> Map.fetch!(:type)

  # defp get_opt_type({:short, name}, config),
  #   do: config.short_opt_args |> Map.fetch!(name) |> Map.fetch!(:type)
end
