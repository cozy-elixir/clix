defmodule CLIX.Spec do
  @moduledoc """
  The spec builder.

  A spec is the basis for parsing, feedback generation, etc.
  """

  @typedoc "The spec."
  @type t :: {cmd_name(), cmd_spec()}

  @typedoc """
  The name of a command.

  The top-level cmd_name is the program name. If you name your CLI app as *example*,
  then you should set the top-level cmd_name as `:example`.
  """
  @type cmd_name :: atom()

  @typedoc """
  The parsing spec of a command.

  If the `:help` option isn't set, it will default to the value of `:summary`
  option.
  """
  @type cmd_spec :: %{
          help: String.t() | nil,
          summary: String.t() | nil,
          description: String.t() | nil,
          cmds: [{cmd_name(), cmd_spec()}],
          args: [{arg_name(), arg_spec()}],
          opts: [{opt_name(), opt_spec()}],
          epilogue: String.t() | nil
        }

  @typedoc "The type which the argument will be parsed as."
  @type type ::
          :string
          | :boolean
          | :integer
          | :float
          | custom_type()

  @typedoc """
  Custom type.
  """
  @type custom_type :: {
          :custom,
          (raw_value :: String.t() -> {:ok, value :: term()} | {:error, reason :: String.t()})
        }

  @typedoc """
  The number of arguments that should be consumed.

    * `nil` - consume one argument.
    * `:"?"` - consume zero or one argument.
    * `:*` - consume zero or more arguments.
    * `:+` - consume one or more arguments.

  """
  @type nargs :: nil | :"?" | :* | :+

  @type action :: :store | :count | :append

  @typedoc "The name of a positional argument."
  @type arg_name :: atom()

  @typedoc "The parsing spec of positional argument."
  @type arg_spec :: %{
          optional(:type) => type(),
          optional(:nargs) => nargs(),
          optional(:default) => any(),
          optional(:value_name) => value_name(),
          optional(:help) => String.t() | nil
        }

  @typedoc "The name of an optional argument."
  @type opt_name :: atom()
  @typedoc "The parsing spec of optional argument."
  @type opt_spec :: %{
          optional(:short) => String.t() | nil,
          optional(:long) => String.t() | nil,
          optional(:type) => type(),
          optional(:action) => action(),
          optional(:default) => any(),
          optional(:value_name) => value_name(),
          optional(:help) => String.t() | nil
        }

  @type value_name :: String.t() | nil

  @doc """
  Builds a spec from raw spec.

  It will cast and validate the raw spec.
  """
  @spec new(raw_spec :: {cmd_name(), cmd_spec()}) :: t()
  def new({cmd_name, cmd_spec}) when is_atom(cmd_name) and is_map(cmd_spec) do
    cmd_path = []

    {cmd_name, cmd_spec}
    |> cast_cmd_pair()
    |> validate_cmd_pair!(cmd_path)
  end

  defp cast_cmd_pair({cmd_name, cmd_spec}) do
    default_cmd_spec = %{
      summary: nil,
      description: nil,
      cmds: [],
      args: [],
      opts: [],
      epilogue: nil
    }

    cmd_spec =
      default_cmd_spec
      |> Map.merge(cmd_spec)
      |> put_cmd_default_help()

    cmd_spec =
      cmd_spec
      |> Map.update!(:args, fn args -> Enum.map(args, &cast_arg_pair(&1)) end)
      |> Map.update!(:opts, fn opts -> Enum.map(opts, &cast_opt_pair(&1)) end)
      |> Map.update!(:cmds, fn cmds -> Enum.map(cmds, &cast_cmd_pair(&1)) end)

    {cmd_name, cmd_spec}
  end

  defp put_cmd_default_help(%{help: _} = cmd_spec), do: cmd_spec
  defp put_cmd_default_help(cmd_spec), do: Map.put(cmd_spec, :help, cmd_spec.summary)

  defp cast_arg_pair({arg_name, arg_spec}) when is_atom(arg_name) and is_map(arg_spec) do
    default_arg_spec = %{
      type: :string,
      nargs: nil,
      value_name: nil,
      help: nil
    }

    arg_spec =
      default_arg_spec
      |> Map.merge(arg_spec)
      |> put_arg_default()
      |> put_arg_value_name(arg_name)

    {arg_name, arg_spec}
  end

  defp put_arg_default(%{default: _} = arg_spec), do: arg_spec
  defp put_arg_default(%{nargs: nil} = arg_spec), do: Map.put(arg_spec, :default, nil)
  defp put_arg_default(%{nargs: :"?"} = arg_spec), do: Map.put(arg_spec, :default, nil)
  defp put_arg_default(%{nargs: :*} = arg_spec), do: Map.put(arg_spec, :default, [])
  defp put_arg_default(%{nargs: :+} = arg_spec), do: Map.put(arg_spec, :default, [])

  defp put_arg_value_name(%{value_name: value_name} = arg_spec, _arg_name) when value_name !== nil do
    arg_spec
  end

  defp put_arg_value_name(arg_spec, arg_name) do
    value_name = arg_name |> to_string() |> String.upcase()
    Map.put(arg_spec, :value_name, value_name)
  end

  defp cast_opt_pair({opt_name, opt_spec}) when is_atom(opt_name) and is_map(opt_spec) do
    default_opt_spec = %{
      short: nil,
      long: nil,
      type: :string,
      action: :store,
      help: nil
    }

    opt_spec =
      default_opt_spec
      |> Map.merge(opt_spec)
      |> put_opt_default()
      |> put_opt_value_name(opt_name)

    {opt_name, opt_spec}
  end

  defp put_opt_default(%{default: _} = opt_spec), do: opt_spec
  defp put_opt_default(%{action: :store, type: :boolean} = opt_spec), do: Map.put(opt_spec, :default, false)
  defp put_opt_default(%{action: :store, type: _} = opt_spec), do: Map.put(opt_spec, :default, nil)
  defp put_opt_default(%{action: :count, type: _} = opt_spec), do: Map.put(opt_spec, :default, 0)
  defp put_opt_default(%{action: :append, type: _} = opt_spec), do: Map.put(opt_spec, :default, [])

  defp put_opt_value_name(%{value_name: value_name} = opt_spec, _opt_name) when value_name !== nil do
    opt_spec
  end

  defp put_opt_value_name(opt_spec, opt_name) do
    value_name = opt_name |> to_string() |> String.upcase()
    Map.put(opt_spec, :value_name, value_name)
  end

  # It validates the constaints of values, instead of the types, which should be done by Dialyzer.
  defp validate_cmd_pair!({cmd_name, cmd_spec}, cmd_path) do
    Enum.each(cmd_spec.args, fn {arg_name, arg_spec} ->
      validate_arg_pair!({arg_name, arg_spec}, [cmd_name | cmd_path])
    end)

    Enum.each(cmd_spec.opts, fn {opt_name, opt_spec} ->
      validate_opt_pair!({opt_name, opt_spec}, [cmd_name | cmd_path])
    end)

    Enum.each(cmd_spec.cmds, fn {sub_cmd_name, sub_cmd_spec} ->
      validate_cmd_pair!({sub_cmd_name, sub_cmd_spec}, [sub_cmd_name | cmd_path])
    end)

    {cmd_name, cmd_spec}
  end

  defp validate_arg_pair!({_arg_name, _arg_spec}, _cmd_path) do
    # nothing to do for now
  end

  defp validate_opt_pair!({opt_name, opt_spec}, cmd_path) do
    %{short: short, long: long} = opt_spec

    if short == nil and long == nil do
      raise ArgumentError,
            location(cmd_path, {:opt, opt_name}) <>
              "expected :short or :long to be set"
    end

    if short && String.length(short) !== 1 do
      raise ArgumentError,
            location(cmd_path, {:opt, opt_name}) <>
              "expected :short to be an one-char string, got: #{inspect(short)}"
    end

    if long && String.length(long) == 1 do
      raise ArgumentError,
            location(cmd_path, {:opt, opt_name}) <>
              "expected :long to be a multi-chars string, got: #{inspect(long)}"
    end
  end

  defp location(cmd_path, {:opt, opt_name}) when is_list(cmd_path) do
    "opt #{inspect(opt_name)} under the cmd path #{inspect(Enum.reverse(cmd_path))} - "
  end

  @doc false
  @spec compact_cmd_spec(t(), [atom()]) :: cmd_spec()
  def compact_cmd_spec({_cmd_name, cmd_spec}, subcmd_path) do
    do_compact_cmd_spec(cmd_spec, subcmd_path, {[], []})
  end

  defp do_compact_cmd_spec(cmd_spec, [], {args, opts}) do
    %{args: new_args, opts: new_opts} = cmd_spec
    args = [new_args | args]
    opts = [new_opts | opts]

    cmd_spec
    |> Map.put(:args, args |> Enum.reverse() |> List.flatten())
    |> Map.put(:opts, opts |> Enum.reverse() |> List.flatten())
  end

  defp do_compact_cmd_spec(cmd_spec, [subcmd | rest], {args, opts}) do
    %{args: new_args, opts: new_opts} = cmd_spec
    args = [new_args | args]
    opts = [new_opts | opts]
    subcmd_spec = cmd_spec |> Map.fetch!(:cmds) |> Keyword.fetch!(subcmd)
    do_compact_cmd_spec(subcmd_spec, rest, {args, opts})
  end
end
