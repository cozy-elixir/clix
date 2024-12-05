defmodule CLIX.Parser do
  @moduledoc """
  Command line arguments parser.
  """

  alias CLIX.Spec

  @opt_terminator "--"
  @short_opt_prefix "-"
  @long_opt_prefix "--"

  @typedoc """
  The list of command line arguments to be parsed.

  In general, it's obtained by calling `System.argv/0`.
  """
  @type argv :: [String.t()]

  @typedoc "The result of parsing."
  @type result :: {parsed_args(), parsed_opts(), errors()}
  @type parsed_args :: %{atom() => any()}
  @type parsed_opts :: %{atom() => any()}
  @type errors :: [error()]
  @type error :: any()

  @doc """
  Parses `argv` with given `spec`.

  Generally, `argv` is fetched by `System.argv()`.
  """
  @spec parse(Spec.t(), argv()) :: result()
  def parse(spec, argv) do
    config = build_config(spec)
    do_parse(config, argv, {%{}, %{}, []})
  end

  defp build_config({cmd_name, cmd_spec}) do
    %{args: args, opts: opts} = cmd_spec
    pos_specs = build_pos_specs(args)
    {short_opt_specs, long_opt_specs} = build_opt_specs(opts)

    cmd_path = [cmd_name]

    %{
      cmd_path: cmd_path,
      pos_specs: pos_specs,
      short_opt_specs: short_opt_specs,
      long_opt_specs: long_opt_specs
    }
  end

  defp build_config(config, {cmd_name, cmd_spec}) do
    %{args: args, opts: opts} = cmd_spec
    new_pos_specs = build_pos_specs(args)
    {new_short_opt_specs, new_long_opt_specs} = build_opt_specs(opts)

    cmd_path = config.cmd_path ++ [cmd_name]
    pos_specs = config.pos_specs ++ new_pos_specs
    short_opt_specs = Map.merge(config.short_opt_specs, new_short_opt_specs)
    long_opt_specs = Map.merge(config.long_opt_specs, new_long_opt_specs)

    %{
      config
      | cmd_path: cmd_path,
        pos_specs: pos_specs,
        short_opt_specs: short_opt_specs,
        long_opt_specs: long_opt_specs
    }
  end

  defp build_pos_specs(args) do
    Enum.map(args, fn {key, spec} -> Map.put(spec, :key, key) end)
  end

  defp build_opt_specs(opts) do
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

  defp do_parse(config, [], {pos_args, opt_args, errors}) do
    {pos_args, new_errors} = normalize_pos_args(config, pos_args)
    errors = [new_errors | errors] |> List.flatten() |> Enum.reverse()
    {pos_args, opt_args, errors}
  end

  defp do_parse(config, argv, {_, _, _} = result) do
    {pos_argv, rest_argv} = split_hd_pos_argv(config, argv)

    {config, result} = parse_pos_argv(config, pos_argv, result)
    {config, rest_argv, result} = parse_opt_argv(config, rest_argv, result)

    do_parse(config, rest_argv, result)
  end

  defp split_hd_pos_argv(config, argv) do
    {argv, pos_argv} = split_hd_pos_argv(config, argv, [])
    {Enum.reverse(pos_argv), argv}
  end

  defp split_hd_pos_argv(config, argv, pos_argv)

  defp split_hd_pos_argv(_, [], pos_argv), do: {[], pos_argv}

  defp split_hd_pos_argv(_, [@opt_terminator | rest_argv], pos_argv),
    do: {[], Enum.reverse(rest_argv, pos_argv)}

  defp split_hd_pos_argv(_, [@long_opt_prefix <> opt | _] = argv, pos_argv) when opt != "",
    do: {argv, pos_argv}

  defp split_hd_pos_argv(config, [@short_opt_prefix <> opt_str | rest_argv] = argv, pos_argv)
       when opt_str != "" do
    {name, _} = split_opt_str(opt_str)

    case tag_opt(config, {:short, name}) do
      {:ok, _, _} ->
        {argv, pos_argv}

      :error ->
        pos_arg = @short_opt_prefix <> opt_str
        split_hd_pos_argv(config, rest_argv, [pos_arg | pos_argv])
    end
  end

  defp split_hd_pos_argv(config, [pos_arg | rest_argv], pos_argv) do
    split_hd_pos_argv(config, rest_argv, [pos_arg | pos_argv])
  end

  def parse_pos_argv(config, pos_argv, {pos_args, opt_args, errors}) do
    %{pos_specs: pos_specs} = config

    rules = assign_pos_argv(pos_argv, pos_specs)

    new_config = Map.update!(config, :pos_specs, &Enum.drop(&1, length(rules)))

    {new_pos_args, new_errors} = consume_pos_argv(pos_argv, rules)
    new_result = {Map.merge(pos_args, new_pos_args), opt_args, [new_errors | errors]}

    {new_config, new_result}
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

  defp consume_pos_argv(pos_argv, rules),
    do: consume_pos_argv(rules, pos_argv, %{}, [])

  defp consume_pos_argv([], rest_argv, pos_args, errors) do
    new_errors = Enum.map(rest_argv, &{:unknown_arg, &1})
    {pos_args, [Enum.reverse(new_errors) | errors]}
  end

  defp consume_pos_argv([{pos_spec, count} | rest_rules], pos_argv, pos_args, errors) do
    %{key: key, type: type, default: default, nargs: nargs} = pos_spec

    {argv, rest_argv} = Enum.split(pos_argv, count)

    {values, bad_argv} = cast_pos_argv(type, argv)

    new_pos_args =
      if bad_argv == [] do
        value = unwrap_pos_values(nargs, values, default)
        Map.put(pos_args, key, value)
      else
        pos_args
      end

    new_errors = Enum.map(bad_argv, &{:invalid_arg, key, &1})

    consume_pos_argv(rest_rules, rest_argv, new_pos_args, [new_errors | errors])
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

  defp parse_opt_argv(config, [] = rest_argv, result), do: {config, rest_argv, result}

  # Handles --flag, --option value, --option=value
  defp parse_opt_argv(
         config,
         [@long_opt_prefix <> opt_str | rest_argv],
         {pos_args, opt_args, errors}
       )
       when opt_str != "" do
    {name, value} = split_opt_str(opt_str)
    orig_opt = @long_opt_prefix <> name

    case tag_opt(config, {:long, name}) do
      {:ok, name, attrs} ->
        %{key: key, type: type, action: action} = attrs

        case take_opt_value(type, value, rest_argv) do
          {:ok, value, rest_argv} ->
            case cast_value(type, value) do
              {:ok, value} ->
                new_opt_args = store_opt_arg(opt_args, action, key, value)
                {config, rest_argv, {pos_args, new_opt_args, errors}}

              :error ->
                error = {:invalid_opt_value, orig_opt, value}
                {config, rest_argv, {pos_args, opt_args, [error | errors]}}
            end

          :error ->
            error = {:missing_opt_value, orig_opt}
            {config, rest_argv, {pos_args, opt_args, [error | errors]}}
        end

      :error ->
        error = {:unknown_opt, orig_opt}
        {config, rest_argv, {pos_args, opt_args, [error | errors]}}
    end
  end

  # Handles -f, -o value, -o=value
  defp parse_opt_argv(
         config,
         [@short_opt_prefix <> opt_str | rest_argv],
         {pos_args, opt_args, errors}
       )
       when opt_str != "" do
    {name, value} = split_opt_str(opt_str)
    prefixed_opt_name = @short_opt_prefix <> name

    case tag_opt(config, {:short, name}) do
      {:ok, name, attrs} ->
        %{key: key, type: type, action: action} = attrs

        case take_opt_value(type, value, rest_argv) do
          {:ok, value, rest_argv} ->
            case cast_value(type, value) do
              {:ok, value} ->
                new_opt_args = store_opt_arg(opt_args, action, key, value)
                {config, rest_argv, {pos_args, new_opt_args, errors}}

              :error ->
                error = {:invalid_opt_value, prefixed_opt_name, value}
                {config, rest_argv, {pos_args, opt_args, [error | errors]}}
            end

          :error ->
            error = {:missing_opt_value, prefixed_opt_name}
            {config, rest_argv, {pos_args, opt_args, [error | errors]}}
        end

      :error ->
        error = {:unknown_opt, prefixed_opt_name}
        result = {pos_args, opt_args, [error | errors]}
        {config, rest_argv, result}
    end
  end

  defp split_opt_str(opt_str) do
    case :binary.split(opt_str, "=") do
      [name] -> {name, nil}
      [name, ""] -> {name, nil}
      [name, value] -> {name, value}
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

  defp normalize_pos_args(config, pos_args) do
    %{pos_specs: pos_specs} = config

    Enum.reduce(pos_specs, {pos_args, []}, fn pos_spec, {pos_args, errors} ->
      %{key: key, default: default} = pos_spec

      cond do
        not Map.has_key?(pos_args, key) && required_pos_spec?(pos_spec) ->
          {pos_args, [{:missing_arg, key} | errors]}

        not Map.has_key?(pos_args, key) ->
          {Map.put(pos_args, key, default), errors}

        true ->
          {pos_args, errors}
      end
    end)
  end

  defp required_pos_spec?(%{nargs: nil}), do: true
  defp required_pos_spec?(%{nargs: :"?"}), do: false
  defp required_pos_spec?(%{nargs: :*}), do: false
  defp required_pos_spec?(%{nargs: :+}), do: true

  @doc false
  def format_errors(config, [_ | _] = errors) do
    error_count = length(errors)
    error = if error_count == 1, do: "error", else: "errors"

    "#{error_count} #{error} found!\n" <>
      Enum.map_join(errors, "\n", &format_error(&1, config))
  end

  defp format_error({:unknown_opt, _opt_id, orig_opt}, _config) do
    "#{orig_opt}: unrecognized arguments"
  end

  defp format_error({:invalid_opt, opt_id, orig_opt, nil}, config) do
    type = get_opt_type(opt_id, config)
    "#{orig_opt}: missing value of type #{type}"
  end

  defp format_error({:invalid_opt, opt_id, orig_opt, value}, config) do
    type = get_opt_type(opt_id, config)
    "#{orig_opt}: expected value of type #{type}, got #{inspect(value)}"
  end

  defp get_opt_type({:long, name}, config),
    do: config.long_opt_args |> Map.fetch!(name) |> Map.fetch!(:type)

  defp get_opt_type({:short, name}, config),
    do: config.short_opt_args |> Map.fetch!(name) |> Map.fetch!(:type)
end
