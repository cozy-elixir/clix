defmodule CLIX.Feedback do
  @moduledoc """
  The feedback generator.

  It's designed to generate clear and compact feedbacks.

  ## Quick start

      iex> # 1. build a spec
      iex> spec =
      iex>   CLIX.Spec.new(
      iex>     {:calc,
      iex>      %{
      iex>        summary: "A simple calculator.",
      iex>        description: \"""
      iex>        This calculator is for demostrating the funtionality of `CLIX.Feedback`.
      iex>        You can copy and play with it.
      iex>        \""",
      iex>        cmds: [
      iex>          add: %{
      iex>            summary: "Add two number.",
      iex>            help: "add two number",
      iex>            args: [
      iex>              left: %{type: :integer, help: "the left number"},
      iex>              right: %{type: :integer, help: "the right number"}
      iex>            ]
      iex>          },
      iex>          minus: %{
      iex>            summary: "Minus two number.",
      iex>            help: "minus two number",
      iex>            args: [
      iex>              left: %{type: :integer, help: "the left number"},
      iex>              right: %{type: :integer, help: "the right number"}
      iex>            ]
      iex>          }
      iex>        ],
      iex>        opts: [
      iex>          debug: %{
      iex>            short: "d",
      iex>            long: "debug",
      iex>            type: :boolean,
      iex>            help: "enable debug logging"
      iex>          },
      iex>          verbose: %{
      iex>            short: "v",
      iex>            long: "verbose",
      iex>            type: :boolean,
      iex>            action: :count,
      iex>            help: "specify verbose level"
      iex>          }
      iex>        ],
      iex>        epilogue: \"""
      iex>        For more help on how to use CLIX, head to https://hex.pm/packages/clix
      iex>        \"""
      iex>      }}
      iex>    )
      iex>
      iex> # 2. generate doc
      iex>
      iex> # for root command
      iex> CLIX.Feedback.help(spec)
      iex>
      iex> # for sub-command - add
      iex> CLIX.Feedback.help(spec, [:add])
      iex>
      iex> # for sub-command - minus
      iex> CLIX.Feedback.help(spec, [:minus])

  The output:

  <!-- tabs-open -->

  ### root command

  ```console
  A simple calculator.

  This calculator is for demostrating the funtionality of `CLIX.Feedback`.
  You can copy and play with it.

  Usage:
    calc <COMMAND> [OPTIONS]

  Commands:
    add    add two number
    minus  minus two number

  Options:
    -d, --debug       enable debug logging
    -v, --verbose...  specify verbose level

  For more help on how to use CLIX, head to https://hex.pm/packages/clix
  ```

  ### sub-command `add`

  ```console
  Add two number.

  Usage:
    calc add [OPTIONS] <LEFT> <RIGHT>

  Arguments:
    <LEFT>   the left number
    <RIGHT>  the right number

  Options:
    -d, --debug       enable debug logging
    -v, --verbose...  specify verbose level
  ```

  ### sub-command `minus`

  ```console
  Minus two number.

  Usage:
    calc minus [OPTIONS] <LEFT> <RIGHT>

  Arguments:
    <LEFT>   the left number
    <RIGHT>  the right number

  Options:
    -d, --debug       enable debug logging
    -v, --verbose...  specify verbose level
  ```

  <!-- tabs-close -->

  """

  alias CLIX.Spec
  alias CLIX.Parser
  alias __MODULE__.Formatter

  @left_padding_width 2
  @sep_width 2

  @type subcmd_path :: [Spec.cmd_name()]

  @doc """
  Generates comprehensive help.

  The structure of generated content:

  ```plain
  [summary]

  [description]

  [usage]

  [sub-commands]

  [positional arguments]

  [optional arguments]

  [epilogue]
  ```
  """
  @spec help(Spec.t(), subcmd_path()) :: String.t()
  def help(spec, subcmd_path \\ []) do
    {cmd_name, _cmd_spec} = spec
    width = width()

    cmd_path = [cmd_name | subcmd_path]
    cmd_spec = Spec.compact_cmd_spec(spec, subcmd_path)

    [
      build_summary(cmd_spec, width),
      build_description(cmd_spec, width),
      build_usage_section(cmd_spec, cmd_path),
      build_cmds_section(cmd_spec, width),
      build_args_section(cmd_spec, width),
      build_opts_section(cmd_spec, width),
      build_epilogue_section(cmd_spec, width)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.intersperse("\n\n")
    |> to_string()
  end

  defp build_summary(%{summary: nil}, _width), do: nil
  defp build_summary(%{summary: summary}, width), do: Formatter.format(summary, width)

  defp build_description(%{description: nil}, _width), do: nil
  defp build_description(%{description: description}, width), do: Formatter.format(description, width)

  defp build_usage_section(cmd_spec, cmd_path) do
    %{cmds: cmds, args: args, opts: opts} = cmd_spec

    header = "Usage:"

    content = ["#{cmd_path |> Enum.map_join(" ", &to_string/1)}"]
    content = if cmds != [], do: ["<COMMAND>" | content], else: content
    content = if opts != [], do: ["[OPTIONS]" | content], else: content
    content = Enum.reduce(args, content, fn arg, acc -> [build_arg_value_placeholder(arg) | acc] end)

    [
      header,
      "\n",
      String.duplicate(" ", @left_padding_width),
      content |> Enum.reverse() |> Enum.intersperse(" ")
    ]
  end

  defp build_cmds_section(%{cmds: []}, _width), do: nil

  defp build_cmds_section(%{cmds: cmds}, width) do
    header = "Commands:"

    rows =
      Enum.map(cmds, fn cmd ->
        {cmd_name, _} = cmd
        name = to_string(cmd_name)
        help = build_help(cmd)
        ["", name, "", help]
      end)

    names = Enum.map(rows, &Enum.at(&1, 1))

    names_width = names |> Enum.map(&String.length/1) |> Enum.max()
    help_width = width - @left_padding_width - names_width - @sep_width
    widths = [@left_padding_width, names_width, @sep_width, help_width]

    content =
      rows
      |> Enum.map(fn row -> Enum.zip(row, widths) |> Formatter.format_columns() end)
      |> Enum.intersperse("\n")

    [header, "\n", content]
  end

  defp build_args_section(%{args: []}, _width), do: nil

  defp build_args_section(%{args: args}, width) do
    header = "Arguments:"

    rows =
      Enum.map(args, fn arg ->
        placeholder = build_arg_value_placeholder(arg)
        help = build_help(arg)
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

  defp build_opts_section(%{opts: []}, _width), do: nil

  defp build_opts_section(%{opts: opts}, width) do
    header = "Options:"

    rows =
      Enum.map(opts, fn opt ->
        str = build_opt_str(opt)
        help = build_help(opt)
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

  defp build_arg_value_placeholder({_arg_name, %{value_name: value_name, nargs: nargs}}) do
    format_arg_value_name(value_name, nargs)
  end

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
        _ -> [" ", "<#{value_name}>"]
      end

    to_string([prefixed_opt_name, opt_name_suffix, opt_value])
  end

  defp build_help(any_spec)
  defp build_help({_, %{help: nil}}), do: ""
  defp build_help({_, %{help: help}}), do: String.trim_trailing(help)

  defp build_epilogue_section(%{epilogue: nil}, _width), do: nil
  defp build_epilogue_section(%{epilogue: epilogue}, width), do: Formatter.format(epilogue, width)

  @doc """
  Formats a parsing error.
  """
  @spec format_error(Parser.error()) :: String.t()
  def format_error(error)

  def format_error({:unknown_arg, raw_arg}) do
    "unrecognized argument '#{raw_arg}'"
  end

  def format_error({:missing_arg, arg_detail}) do
    %{value_name: value_name, nargs: nargs} = arg_detail
    "missing value for argument '#{format_arg_value_name(value_name, nargs)}'"
  end

  def format_error({:invalid_arg, %{message: nil} = arg_detail}) do
    %{value_name: value_name, nargs: nargs, value: value} = arg_detail
    "invalid value '#{value}' for argument '#{format_arg_value_name(value_name, nargs)}'"
  end

  def format_error({:invalid_arg, %{message: message} = arg_detail}) do
    %{value_name: value_name, nargs: nargs, value: value} = arg_detail
    "invalid value '#{value}' for argument '#{format_arg_value_name(value_name, nargs)}': #{message}"
  end

  def format_error({:unknown_opt, raw_arg}) do
    "unknown option '#{raw_arg}'"
  end

  def format_error({:missing_opt, opt_detail}) do
    %{prefixed_name: prefixed_name, value_name: value_name} = opt_detail
    "missing value for option '#{prefixed_name} #{format_opt_value_name(value_name)}'"
  end

  def format_error({:invalid_opt, %{message: nil} = opt_detail}) do
    %{prefixed_name: prefixed_name, value_name: value_name, value: value} = opt_detail
    "invalid value '#{value}' for option '#{prefixed_name} #{format_opt_value_name(value_name)}'"
  end

  def format_error({:invalid_opt, %{message: message} = opt_detail}) do
    %{prefixed_name: prefixed_name, value_name: value_name, value: value} = opt_detail
    "invalid value '#{value}' for option '#{prefixed_name} #{format_opt_value_name(value_name)}': #{message}"
  end

  defp format_arg_value_name(value_name, nargs)
  defp format_arg_value_name(value_name, nil), do: "<#{value_name}>"
  defp format_arg_value_name(value_name, :"?"), do: "[#{value_name}]"
  defp format_arg_value_name(value_name, :*), do: "[#{value_name}]..."
  defp format_arg_value_name(value_name, :+), do: "<#{value_name}>..."

  defp format_opt_value_name(value_name), do: "<#{value_name}>"

  defp width do
    case :io.columns() do
      {:ok, width} -> min(width, 98)
      _ -> 80
    end
  end
end
