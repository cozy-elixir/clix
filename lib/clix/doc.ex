defmodule CLIX.Doc do
  @moduledoc """
  The doc generator.

  It's designed to generate clear and compact docs.
  """

  alias CLIX.Spec
  alias __MODULE__.Formatter

  @left_padding_width 2
  @sep_width 2

  @doc """
  Generates comprehensive help, which includes the sections of usage, subcommands
  , positional arguments and optional arguments.

  ## The structure of generated doc

  ```plain
  [summary]

  [description]

  [usage]

  [subcommands]

  [positional arguments]

  [optional arguments]
  ```

  """
  @spec help(Spec.t()) :: String.t()
  def help(spec, cmd_path \\ []) do
    {_, cmd_spec} = spec

    width = width()

    [
      build_summary(cmd_spec, width),
      build_description(cmd_spec, width),
      build_usage_line(spec, cmd_path),
      build_args_section(cmd_spec, width),
      build_opts_section(cmd_spec, width)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.intersperse("\n\n")
    |> to_string()
  end

  defp build_summary(%{summary: nil}, _width), do: nil
  defp build_summary(%{summary: summary}, width), do: Formatter.format(summary, width)

  defp build_description(%{description: nil}, _width), do: nil
  defp build_description(%{description: description}, width), do: Formatter.format(description, width)

  defp build_usage_line(spec, cmd_path) do
    {cmd_name, cmd_spec} = spec
    %{cmds: cmds, args: args, opts: opts} = cmd_spec

    header = "Usage: #{cmd_name}"

    parts = [header]
    parts = if cmds != [], do: ["<COMMAND>" | parts], else: parts
    parts = if opts != [], do: ["[OPTIONS]" | parts], else: parts
    parts = Enum.reduce(args, parts, fn arg, acc -> [build_arg_value_placeholder(arg) | acc] end)

    parts |> Enum.reverse() |> Enum.intersperse(" ")
  end

  defp build_args_section(cmd_spec, width) do
    %{args: args} = cmd_spec

    header = "Arguments:"

    rows =
      Enum.map(args, fn arg ->
        placeholder = build_arg_value_placeholder(arg)
        help = build_arg_help(arg)
        ["", placeholder, "", help]
      end)

    placeholders = Enum.map(rows, &Enum.at(&1, 1))

    placeholder_width = placeholders |> Enum.map(&String.length/1) |> Enum.max()
    help_width = width - @left_padding_width - placeholder_width - @sep_width
    widths = [@left_padding_width, placeholder_width, @sep_width, help_width]

    content =
      rows
      |> Enum.map(fn row -> Enum.zip(row, widths) |> Formatter.format_columns() end)
      |> Enum.intersperse("\n")

    [header, "\n", content]
  end

  defp build_opts_section(cmd_spec, width) do
    %{opts: opts} = cmd_spec

    header = "Options:"

    rows =
      Enum.map(opts, fn opt ->
        str = build_opt_str(opt)
        help = build_opt_help(opt)
        ["", str, "", help]
      end)

    strs = Enum.map(rows, &Enum.at(&1, 1))

    str_width = strs |> Enum.map(&String.length/1) |> Enum.max()
    help_width = width - @left_padding_width - str_width - @sep_width
    widths = [@left_padding_width, str_width, @sep_width, help_width]

    content =
      rows
      |> Enum.map(fn row -> Enum.zip(row, widths) |> Formatter.format_columns() end)
      |> Enum.intersperse("\n")

    [header, "\n", content]
  end

  defp build_arg_value_placeholder({_arg_name, %{nargs: nil, value_name: value_name}}) do
    "<#{value_name}>"
  end

  defp build_arg_value_placeholder({_arg_name, %{nargs: :"?", value_name: value_name}}) do
    "[#{value_name}]"
  end

  defp build_arg_value_placeholder({_arg_name, %{nargs: :*, value_name: value_name}}) do
    "[#{value_name}]..."
  end

  defp build_arg_value_placeholder({_arg_name, %{nargs: :+, value_name: value_name}}) do
    "<#{value_name}>..."
  end

  defp build_arg_help({_arg_name, %{help: nil}}), do: ""
  defp build_arg_help({_arg_name, %{help: help}}), do: String.trim_trailing(help)

  defp build_opt_str({_opt_name, opt_spec}) do
    %{short: short, long: long, type: type, action: action, value_name: value_name} = opt_spec

    prefixed_opt_name =
      cond do
        short && long ->
          "-#{short}, --#{long}"

        short ->
          "-#{short}"

        long ->
          "    --#{long}"
      end

    opt_name_suffix =
      case {type, action} do
        {:boolean, :count} -> "..."
        _ -> ""
      end

    opt_value =
      case type do
        :boolean -> ""
        _ -> "<#{value_name}>"
      end

    to_string([prefixed_opt_name, opt_name_suffix, " ", opt_value])
  end

  defp build_opt_help({_opt_name, %{help: nil}}), do: ""
  defp build_opt_help({_opt_name, %{help: help}}), do: String.trim_trailing(help)

  defp width do
    case :io.columns() do
      {:ok, width} -> min(width, 98)
      _ -> 80
    end
  end

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
