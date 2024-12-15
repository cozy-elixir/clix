# credo:disable-for-this-file Credo.Check.Refactor.Nesting

defmodule CLIX.Parser do
  @moduledoc """
  The command line arguments parser.

  It designed to:

    * parse both positional arguments, optional arguments and subcommands
    * pepare read-to-use result

  ## Quick start

      iex> # 1. build a spec
      iex> spec = CLIX.Spec.new({:hello, %{
      iex>   args: [
      iex>     msg: %{}
      iex>   ],
      iex>   opts: [
      iex>     debug: %{short: "d", long: "debug", type: :boolean},
      iex>     verbose: %{short: "v", long: "verbose", type: :boolean, action: :count},
      iex>     to: %{short: "t", long: "to", type: :string, action: :append}
      iex>   ]
      iex> }})
      iex>
      iex> # 2. parse argv with spec
      iex>
      iex> # bad argv
      iex> CLIX.Parser.parse(spec, [])
      {%{}, %{debug: false, verbose: 0, to: []}, [missing_arg: :msg]}
      iex>
      iex> # good argv in strict order
      iex> CLIX.Parser.parse(spec, ["--debug", "-vvvv", "-t", "John", "-t", "Dave", "aloha"])
      {%{msg: "aloha"}, %{debug: true, to: ["John", "Dave"], verbose: 4}, []}
      iex>
      iex> # good argv in intermixed order
      iex> CLIX.Parser.parse(spec, ["--debug", "-vvvv", "aloha", "-t", "John", "-t", "Dave", ])
      {%{msg: "aloha"}, %{debug: true, to: ["John", "Dave"], verbose: 4}, []}

  Read the doc of `CLIX.Spec` and `CLIX.Parser` for more information.

  ## The parsing of positional arguments

  The key part here is how to allocate a limited number of arguments to as many
  different positional arguments as possible. With the design of `t:CLIX.Spec.nargs/0`,
  we can easily achieve it.

  An example cloning `cp` (`cp <SRC>... <DST>`):

      iex> spec = CLIX.Spec.new({:cp, %{args: [
      iex>   src: %{nargs: :+},
      iex>    dst: %{}
      iex> ]}})
      iex>
      iex> CLIX.Parser.parse(spec, [])
      {%{}, %{}, [{:missing_arg, :src}, {:missing_arg, :dst}]}
      iex>
      iex> CLIX.Parser.parse(spec, ["src1"])
      {%{src: ["src1"]}, %{}, [{:missing_arg, :dst}]}
      iex>
      iex> CLIX.Parser.parse(spec, ["src1", "dst"])
      {%{src: ["src1"], dst: "dst"}, %{}, []}
      iex>
      iex> CLIX.Parser.parse(spec, ["src1", "src2", "dst"])
      {%{src: ["src1", "src2"], dst: "dst"}, %{}, []}

  Or, an example cloning `httpie` (`httpie [METHOD] <URL> [REQUEST_ITEM]`):

      iex> spec = CLIX.Spec.new({:httpie, %{args: [
      iex>   method: %{nargs: :"?", default: "GET"},
      iex>   url: %{},
      iex>   request_items: %{nargs: :*}
      iex> ]}})
      iex>
      iex> CLIX.Parser.parse(spec, ["https://example.com"])
      {%{method: "GET", url: "https://example.com", request_items: []}, %{}, []}
      iex>
      iex> CLIX.Parser.parse(spec, ["POST", "https://example.com"])
      {%{method: "POST", url: "https://example.com", request_items: []}, %{}, []}
      iex>
      iex> CLIX.Parser.parse(spec, ["POST", "https://example.com", "name=Joe", "email=Joe@example.com"])
      {%{method: "POST", url: "https://example.com", request_items: ["name=Joe", "email=Joe@example.com"]}, %{}, []}

  > The algo is borrowed from
  > Python's [argparse](https://github.com/python/cpython/blob/3.13/Lib/argparse.py).

  ## The parsing of optional arguments

  ### Supported syntax

  The syntax of GNU's getopt (implicitly involves POSIX's getopt) is supported.

  ```plain
  # short opts
  -f
  -o <value>
  -o<value>     # equals to -o <value>
  -abc          # equals to -a -b -c
  -abco<value>  # equals to -a -b -c -o <value>

  # long opts
  --flag
  --option <value>
  --option=<value>
  ```

  ## The parsing modes

  ### `:intermixed` mode

  This's the GNU's way of parsing optional arguments.
  The positional arguments and optional arguments can be intermixed.

  For example:

  ```console
  program arg1 -f arg2 -o value arg3
  # equals to 'program -f -o value arg1 arg2 arg3'
  ```

  ### `:strict` mode

  This's the POSIX's way of parsing optional arguments:

    * requires all optional arguments to appear before positional arguments.
    * any optional arguments after the first positional arguments are treated
      as positiontal arguments.

  > It equals to set `POSIXLY_CORRECT` env for GNU's getopt.

  For example:

  ```console
  program -f -o value arg1 arg2 arg3

  program -f arg1 -o value arg2 arg3
  # equals to 'program -f -- arg1 -o value arg2 arg3'
  ```

  ## About the internal

  It would be helpful to give you (the possible contributor) some information about the internal.

  ### Overview

  When parsing command line arguments, it processes them in 2 stages.

    * stage 1 - parse optional arguments and collecting positional arguments.
    * stage 2 - parse args.

  ### Variable names

    * For argument specs, use `pos_specs`, `opt_specs`.
    * For raw arguments, use `pos_argv`, `opt_argv`.
    * For parsed arguments, use `pos_args`, `opt_args`.

  ### Verify compatibility with GNU's getopt

  I'm using [jamesodhunt/test-getopt](https://github.com/jamesodhunt/test-getopt).
  """

  alias CLIX.Spec

  @opt_end "--"
  @short_opt_prefix "-"
  @long_opt_prefix "--"

  @typedoc """
  The list of command line arguments to be parsed.

  In general, it's obtained by calling `System.argv/0`.
  """
  @type argv :: [String.t()]

  @typedoc """
  The options of parsing.
  """
  @type opts :: [opt()]
  @type opt :: {:mode, :intermixed | :strict}

  @typedoc "The result of parsing."
  @type result :: {parsed_args(), parsed_opts(), errors()}
  @type parsed_args :: %{atom() => any()}
  @type parsed_opts :: %{atom() => any()}
  @type errors :: [error()]
  @type error :: any()

  @doc """
  Parses `argv` with given `spec`.

  Available opts:

    * `:mode` - `:intermixed` (default) / `:strict`

  """
  @spec parse(Spec.t(), argv(), opts()) :: result()
  def parse(spec, argv, opts \\ []) do
    mode = Keyword.get(opts, :mode, :intermixed)

    config = build_config(spec)
    {pos_argv, {opt_args, opt_errors}} = parse_stage1(mode, config, argv)
    {pos_args, pos_errors} = parse_stage2(config, pos_argv)

    errors = List.flatten([opt_errors, pos_errors])
    {pos_args, opt_args, errors}
  end

  defp build_config({cmd_name, cmd_spec}) do
    %{args: args, opts: opts} = cmd_spec
    pos_specs = build_pos_specs(args)
    opt_specs = build_opt_specs(opts)
    {short_opt_specs, long_opt_specs} = group_opt_specs(opts)

    cmd_path = [cmd_name]

    %{
      cmd_path: cmd_path,
      pos_specs: pos_specs,
      opt_specs: opt_specs,
      short_opt_specs: short_opt_specs,
      long_opt_specs: long_opt_specs
    }
  end

  # defp build_config(config, {cmd_name, cmd_spec}) do
  #   %{args: args, opts: opts} = cmd_spec
  #   new_pos_specs = build_pos_specs(args)
  #   new_opt_specs = build_opt_specs(opts)
  #   {new_short_opt_specs, new_long_opt_specs} = group_opt_specs(opts)

  #   cmd_path = config.cmd_path ++ [cmd_name]
  #   pos_specs = config.pos_specs ++ new_pos_specs
  #   opt_specs = Map.merge(config.opt_specs, new_opt_specs)
  #   short_opt_specs = Map.merge(config.short_opt_specs, new_short_opt_specs)
  #   long_opt_specs = Map.merge(config.long_opt_specs, new_long_opt_specs)

  #   %{
  #     cmd_path: cmd_path,
  #     pos_specs: pos_specs,
  #     opt_specs: opt_specs,
  #     short_opt_specs: short_opt_specs,
  #     long_opt_specs: long_opt_specs
  #   }
  # end

  defp build_pos_specs(args) do
    Enum.map(args, fn {key, spec} -> Map.put(spec, :key, key) end)
  end

  defp build_opt_specs(opts) do
    Enum.into(opts, %{})
  end

  defp group_opt_specs(opts) do
    Enum.reduce(opts, {%{}, %{}}, fn {key, spec}, {shorts, longs} ->
      attrs =
        spec
        |> Map.drop([:short, :long])
        |> Map.put(:key, key)

      shorts =
        if short = spec[:short],
          do: Map.put(shorts, short, attrs),
          else: shorts

      longs =
        if long = spec[:long],
          do: Map.put(longs, long, attrs),
          else: longs

      {shorts, longs}
    end)
  end

  defp parse_stage1(mode, config, argv) do
    {pos_argv, {opt_args, opt_errors}} = parse_stage1(mode, config, argv, [], {%{}, []})
    {opt_args, extra_opt_errors} = normalize_opt_args(config, opt_args)
    opt_errors = [extra_opt_errors | opt_errors] |> List.flatten() |> Enum.reverse()
    {pos_argv, {opt_args, opt_errors}}
  end

  defp parse_stage1(_mode, _config, [], pos_argv, {opt_args, opt_errors}) do
    pos_argv = Enum.reverse(pos_argv)
    {pos_argv, {opt_args, opt_errors}}
  end

  # Handles --
  defp parse_stage1(mode, config, [@opt_end | rest_argv], pos_argv, {opt_args, opt_errors}) do
    parse_stage1(mode, config, [], Enum.reverse(rest_argv, pos_argv), {opt_args, opt_errors})
  end

  # Handles --flag, --option <value>, --option=<value>
  defp parse_stage1(mode, config, [@long_opt_prefix <> opt_str | rest_argv], pos_argv, {opt_args, opt_errors})
       when opt_str != "" do
    {name, value} = split_long_opt_str(opt_str)
    prefixed_opt_name = @long_opt_prefix <> name

    case tag_opt(config, {:long, name}) do
      {:ok, _name, attrs} ->
        %{key: key, type: type, action: action} = attrs

        case take_opt_value(type, value, rest_argv) do
          {:ok, value, rest_argv} ->
            case cast_value(type, value) do
              {:ok, value} ->
                opt_args = store_opt_arg(opt_args, action, key, value)
                parse_stage1(mode, config, rest_argv, pos_argv, {opt_args, opt_errors})

              :error ->
                error = {:invalid_opt_value, prefixed_opt_name, value}
                parse_stage1(mode, config, rest_argv, pos_argv, {opt_args, [error | opt_errors]})
            end

          :error ->
            error = {:missing_opt_value, prefixed_opt_name}
            parse_stage1(mode, config, rest_argv, pos_argv, {opt_args, [error | opt_errors]})
        end

      :error ->
        error = {:unknown_opt, prefixed_opt_name}
        parse_stage1(mode, config, rest_argv, pos_argv, {opt_args, [error | opt_errors]})
    end
  end

  # Handles -f, -o <value>
  defp parse_stage1(mode, config, [<<@short_opt_prefix, name_cp::utf8>> | rest_argv], pos_argv, {opt_args, opt_errors}) do
    name = <<name_cp::utf8>>
    prefixed_opt_name = @short_opt_prefix <> name

    case tag_opt(config, {:short, name}) do
      {:ok, _name, attrs} ->
        %{key: key, type: type, action: action} = attrs

        case take_opt_value(type, rest_argv) do
          {:ok, value, rest_argv} ->
            case cast_value(type, value) do
              {:ok, value} ->
                opt_args = store_opt_arg(opt_args, action, key, value)
                parse_stage1(mode, config, rest_argv, pos_argv, {opt_args, opt_errors})

              :error ->
                error = {:invalid_opt_value, prefixed_opt_name, value}
                parse_stage1(mode, config, rest_argv, pos_argv, {opt_args, [error | opt_errors]})
            end

          :error ->
            error = {:missing_opt_value, prefixed_opt_name}
            parse_stage1(mode, config, rest_argv, pos_argv, {opt_args, [error | opt_errors]})
        end

      :error ->
        error = {:unknown_opt, prefixed_opt_name}
        parse_stage1(mode, config, rest_argv, pos_argv, {opt_args, [error | opt_errors]})
    end
  end

  # Handles -o<value>, -abc, -abco<value>
  defp parse_stage1(mode, config, [<<@short_opt_prefix, char::utf8>> <> rest | rest_argv], pos_argv, {opt_args, opt_errors}) do
    opt_str = <<char::utf8>> <> rest

    {expanded, errors} =
      reduce_short_opt_str(opt_str, {[], []}, fn {opt_name, rest}, {expanded, errors} ->
        case tag_opt(config, {:short, opt_name}) do
          {:ok, _, attrs} ->
            %{type: type} = attrs
            prefixed_opt_name = @short_opt_prefix <> opt_name

            if require_opt_value?(type) && rest !== "",
              do: {:halt, {[rest, prefixed_opt_name | expanded], errors}},
              else: {:cont, {[prefixed_opt_name | expanded], errors}}

          :error ->
            prefixed_opt_name = @short_opt_prefix <> opt_name
            error = {:unknown_opt, prefixed_opt_name}
            {:halt, {expanded, [error | errors]}}
        end
      end)

    parse_stage1(mode, config, Enum.reverse(expanded, rest_argv), pos_argv, {opt_args, [errors | opt_errors]})
  end

  defp parse_stage1(:strict = mode, config, rest_argv, pos_argv, {opt_args, opt_errors}) do
    parse_stage1(mode, config, [], Enum.reverse(rest_argv, pos_argv), {opt_args, opt_errors})
  end

  defp parse_stage1(:intermixed = mode, config, [pos_arg | rest_argv], pos_argv, {opt_args, opt_errors}) do
    parse_stage1(mode, config, rest_argv, [pos_arg | pos_argv], {opt_args, opt_errors})
  end

  defp split_long_opt_str(opt_str) do
    case :binary.split(opt_str, "=") do
      [name] -> {name, nil}
      [name, ""] -> {name, nil}
      [name, value] -> {name, value}
    end
  end

  defp reduce_short_opt_str(opt_str, acc, fun)

  defp reduce_short_opt_str("", acc, _fun), do: acc

  defp reduce_short_opt_str(<<opt_name_cp::utf8>> <> rest, acc, fun) do
    opt_name = <<opt_name_cp::utf8>>

    case fun.({opt_name, rest}, acc) do
      {:cont, new_acc} -> reduce_short_opt_str(rest, new_acc, fun)
      {:halt, acc} -> acc
    end
  end

  defp tag_opt(config, {:long, "no-" <> name = maybe_name}) do
    %{long_opt_specs: long_opt_specs} = config

    cond do
      (attrs = Map.get(long_opt_specs, name)) && attrs.type == :boolean ->
        attrs = Map.put(attrs, :type, {:boolean, :negated})
        {:ok, name, attrs}

      attrs = Map.get(long_opt_specs, maybe_name) ->
        {:ok, name, attrs}

      true ->
        :error
    end
  end

  defp tag_opt(config, {:long, name}) do
    %{long_opt_specs: long_opt_specs} = config

    if attrs = Map.get(long_opt_specs, name) do
      {:ok, name, attrs}
    else
      :error
    end
  end

  defp tag_opt(config, {:short, name}) do
    %{short_opt_specs: short_opt_specs} = config

    if attrs = Map.get(short_opt_specs, name) do
      {:ok, name, attrs}
    else
      :error
    end
  end

  defp require_opt_value?(type)
  defp require_opt_value?(:boolean), do: false
  defp require_opt_value?(_type), do: true

  defp take_opt_value(type, argv), do: take_opt_value(type, nil, argv)

  defp take_opt_value(type, value, argv)

  defp take_opt_value(:boolean, value, argv), do: {:ok, value, argv}
  defp take_opt_value({:boolean, :negated}, value, argv), do: {:ok, value, argv}

  defp take_opt_value(_type, nil, []), do: :error
  defp take_opt_value(_type, nil, [value | rest]), do: {:ok, value, rest}
  defp take_opt_value(_type, value, argv), do: {:ok, value, argv}

  defp store_opt_arg(opt_args, :store, key, value), do: Map.put(opt_args, key, value)

  defp store_opt_arg(opt_args, :count, key, _value), do: Map.update(opt_args, key, 1, &(&1 + 1))

  defp store_opt_arg(opt_args, :append, key, value),
    do: Map.update(opt_args, key, [value], &(&1 ++ [value]))

  defp normalize_opt_args(config, opt_args) do
    %{opt_specs: opt_specs} = config

    Enum.reduce(opt_specs, {opt_args, []}, fn {key, opt_spec}, {opt_args, opt_errors} ->
      if Map.has_key?(opt_args, key) do
        {opt_args, opt_errors}
      else
        {Map.put(opt_args, key, opt_spec.default), opt_errors}
      end
    end)
  end

  defp parse_stage2(config, pos_argv) do
    %{pos_specs: pos_specs} = config

    rules = assign_pos_argv(pos_argv, pos_specs)
    {pos_args, pos_errors} = consume_pos_argv(pos_argv, rules)
    {pos_args, extra_pos_errors} = normalize_pos_args(config, pos_args)
    pos_errors = [extra_pos_errors | pos_errors] |> List.flatten() |> Enum.reverse()
    {pos_args, pos_errors}
  end

  # It build a list of rules in form of [{pos_spec, count}, ...], which specifies the number of
  # arguments to be consumed by each pos_spec.
  defp assign_pos_argv(pos_argv, pos_specs) do
    pos_argv_pattern = build_pos_argv_pattern(pos_argv)
    pos_nargs_pattern = build_pos_nargs_pattern(pos_specs)

    case Regex.run(pos_nargs_pattern, pos_argv_pattern, capture: :all_but_first) do
      nil ->
        narrowed_pos_specs = Enum.drop(pos_specs, -1)
        assign_pos_argv(pos_argv, narrowed_pos_specs)

      matched ->
        counts = matched |> trim_trailing(&(&1 == "")) |> Enum.map(&String.length/1)
        Enum.zip_with(pos_specs, counts, fn pos_spec, count -> {pos_spec, count} end)
    end
  end

  defp build_pos_argv_pattern(pos_argv) do
    String.duplicate("A", length(pos_argv))
  end

  defp build_pos_nargs_pattern(pos_specs) do
    pos_specs
    |> Enum.map(fn spec ->
      case spec.nargs do
        nil -> "([A])"
        :"?" -> "(A?)"
        :* -> "(A*)"
        :+ -> "(A+)"
      end
    end)
    |> to_string()
    |> Regex.compile!()
  end

  defp consume_pos_argv(pos_argv, rules) do
    consume_pos_argv(rules, pos_argv, %{}, [])
  end

  defp consume_pos_argv([], rest_argv, pos_args, pos_errors) do
    errors = Enum.map(rest_argv, &{:unknown_arg, &1})
    {pos_args, Enum.reverse(errors, pos_errors)}
  end

  defp consume_pos_argv([{pos_spec, count} | rest_rules], pos_argv, pos_args, pos_errors) do
    %{key: key, type: type, default: default, nargs: nargs} = pos_spec

    {argv, rest_argv} = Enum.split(pos_argv, count)

    {values, bad_argv} = cast_pos_argv(type, argv)

    pos_args =
      if bad_argv == [] do
        value = unwrap_pos_values(nargs, values, default)
        Map.put(pos_args, key, value)
      else
        pos_args
      end

    errors = Enum.map(bad_argv, &{:invalid_arg, key, &1})

    consume_pos_argv(rest_rules, rest_argv, pos_args, Enum.reverse(errors, pos_errors))
  end

  defp cast_pos_argv(type, argv) when is_list(argv) do
    {values, bad_argv} =
      Enum.reduce(argv, {[], []}, fn arg, {values, bad_argv} ->
        case cast_value(type, arg) do
          {:ok, value} -> {[value | values], bad_argv}
          :error -> {values, [arg | bad_argv]}
        end
      end)

    {Enum.reverse(values), bad_argv}
  end

  defp unwrap_pos_values(nargs, values, default)
  defp unwrap_pos_values(nil, [value], _default), do: value
  defp unwrap_pos_values(:"?", [], default), do: default
  defp unwrap_pos_values(:"?", [value], _default), do: value
  defp unwrap_pos_values(:*, [], default), do: default
  defp unwrap_pos_values(:*, values, _default), do: values
  defp unwrap_pos_values(:+, values, _default), do: values

  defp trim_trailing(list, fun) when is_list(list) and is_function(fun, 1) do
    list
    |> Enum.reverse()
    |> Enum.drop_while(&fun.(&1))
    |> Enum.reverse()
  end

  defp normalize_pos_args(config, pos_args) do
    %{pos_specs: pos_specs} = config

    Enum.reduce(pos_specs, {pos_args, []}, fn pos_spec, {pos_args, pos_errors} ->
      %{key: key, default: default} = pos_spec

      cond do
        not Map.has_key?(pos_args, key) && required_pos_spec?(pos_spec) ->
          error = {:missing_arg, key}
          {pos_args, [error | pos_errors]}

        not Map.has_key?(pos_args, key) ->
          {Map.put(pos_args, key, default), pos_errors}

        true ->
          {pos_args, pos_errors}
      end
    end)
  end

  defp required_pos_spec?(%{nargs: nil}), do: true
  defp required_pos_spec?(%{nargs: :"?"}), do: false
  defp required_pos_spec?(%{nargs: :*}), do: false
  defp required_pos_spec?(%{nargs: :+}), do: true

  defp cast_value(type, value)

  defp cast_value(:string, value), do: {:ok, value}

  defp cast_value(:boolean, nil), do: {:ok, true}
  defp cast_value(:boolean, "true"), do: {:ok, true}
  defp cast_value(:boolean, "false"), do: {:ok, false}
  defp cast_value(:boolean, "t"), do: {:ok, true}
  defp cast_value(:boolean, "f"), do: {:ok, false}
  defp cast_value(:boolean, "yes"), do: {:ok, true}
  defp cast_value(:boolean, "no"), do: {:ok, false}
  defp cast_value(:boolean, "y"), do: {:ok, true}
  defp cast_value(:boolean, "n"), do: {:ok, false}
  defp cast_value(:boolean, "on"), do: {:ok, true}
  defp cast_value(:boolean, "off"), do: {:ok, false}
  defp cast_value(:boolean, "enabled"), do: {:ok, true}
  defp cast_value(:boolean, "disabled"), do: {:ok, false}
  defp cast_value(:boolean, "1"), do: {:ok, true}
  defp cast_value(:boolean, "0"), do: {:ok, false}
  defp cast_value(:boolean, _), do: :error

  defp cast_value({:boolean, :negated}, nil), do: {:ok, false}
  defp cast_value({:boolean, :negated}, _), do: :error

  defp cast_value(:integer, value) do
    case Integer.parse(value) do
      {value, ""} -> {:ok, value}
      _ -> :error
    end
  end

  defp cast_value(:float, value) do
    case Float.parse(value) do
      {value, ""} -> {:ok, value}
      _ -> :error
    end
  end

  defp cast_value({:custom, fun}, value) when is_function(fun, 1) do
    case fun.(value) do
      {:ok, value} -> {:ok, value}
      :error -> :error
    end
  end
end
