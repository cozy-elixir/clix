defmodule OP do
  @moduledoc """
  A simple CLI framework.

  When calling a command, it's possible to pass command line options
  to modify what the command does. In this documentation, those are
  called "switches", in other situations they may be called "flags"
  or simply "options". A switch can be given a value, also called an
  "argument".

  The main function in this module is `parse/2`, which parses a list
  of command line options and arguments into a keyword list:

      iex> OP.parse(["--debug"], strict: [debug: :boolean])
      {[debug: true], [], []}

  `OP` provides some conveniences out of the box,
  such as aliases and automatic handling of negation switches.

  The `parse_head/2` function is an alternative to `parse/2`
  which stops parsing as soon as it finds a value that is not
  a switch nor a value for a previous switch.

  This module also provides low-level functions, such as `next/2`,
  for parsing switches manually, as well as `split/1` and `to_argv/1`
  for parsing from and converting switches to strings.
  """

  @type argv :: [String.t()]
  @type parsed :: keyword
  @type errors :: [{String.t(), String.t() | nil}]
  @type options :: [
          strict: keyword,
          aliases: keyword,
          return_separator: boolean
        ]

  defmodule ParseError do
    @moduledoc """
    An exception raised when parsing option fails.

    For example, see `OP.parse!/2`.
    """

    defexception [:message]
  end

  @doc """
  Parses `argv` into a keyword list.

  It returns a three-element tuple with the form `{parsed, args, invalid}`, where:

    * `parsed` is a keyword list of parsed switches with `{switch_name, value}`
      tuples in it; `switch_name` is the atom representing the switch name while
      `value` is the value for that switch parsed according to `opts` (see the
      "Examples" section for more information)
    * `args` is a list of the remaining arguments in `argv` as strings
    * `invalid` is a list of invalid options as `{option_name, value}` where
      `option_name` is the raw option and `value` is `nil` if the option wasn't
      expected or the string value if the value didn't have the expected type for
      the corresponding option

  Elixir converts switches to underscored atoms, so `--source-path` becomes
  `:source_path`. This is done to better suit Elixir conventions. However, this
  means that switches can't contain underscores and switches that do contain
  underscores are always returned in the list of invalid switches.

  When parsing, it is common to list switches and their expected types:

      iex> OP.parse(["--debug"], strict: [debug: :boolean])
      {[debug: true], [], []}

      iex> OP.parse(["--source", "lib"], strict: [source: :string])
      {[source: "lib"], [], []}

      iex> OP.parse(
      ...>   ["--source-path", "lib", "test/enum_test.exs", "--verbose"],
      ...>   strict: [source_path: :string, verbose: :boolean]
      ...> )
      {[source_path: "lib", verbose: true], ["test/enum_test.exs"], []}

  We will explore the valid switches and operation modes of option parser below.

  ## Options

  The following options are supported:

    * `:switches` or `:strict` - see the "Switch definitions" section below
    * `:aliases` - see the "Aliases" section below
    * `:return_separator` - see the "Return separator" section below

  ## Switch definitions

  Switches can be specified via one of two options:

    * `:strict` - defines strict switches and their types. Any switch
      in `argv` that is not specified in the list is returned in the
      invalid options list. This is the preferred way to parse options.

    * `:switches` - defines switches and their types. This function
      still attempts to parse switches that are not in this list.

  Both these options accept a keyword list where the key is an atom
  defining the name of the switch and value is the `type` of the
  switch (see the "Types" section below for more information).

  Note that you should only supply the `:switches` or the `:strict` option.
  If you supply both, an `ArgumentError` exception will be raised.

  ### Types

  Switches parsed by `OP` may take zero or one arguments.

  The following switches types take no arguments:

    * `:boolean` - sets the value to `true` when given (see also the
      "Negation switches" section below)
    * `:count` - counts the number of times the switch is given

  The following switches take one argument:

    * `:integer` - parses the value as an integer
    * `:float` - parses the value as a float
    * `:string` - parses the value as a string

  If a switch can't be parsed according to the given type, it is
  returned in the invalid options list.

  ### Modifiers

  Switches can be specified with modifiers, which change how
  they behave. The following modifiers are supported:

    * `:keep` - keeps duplicate elements instead of overriding them;
      works with all types except `:count`. Specifying `switch_name: :keep`
      assumes the type of `:switch_name` will be `:string`.

  To use `:keep` with a type other than `:string`, use a list as the type
  for the switch. For example: `[foo: [:integer, :keep]]`.

  ### Negation switches

  In case a switch `SWITCH` is specified to have type `:boolean`, it may be
  passed as `--no-SWITCH` as well which will set the option to `false`:

      iex> OP.parse(["--no-op", "path/to/file"], strict: [op: :boolean])
      {[op: false], ["path/to/file"], []}

  ### Parsing unknown options

  `OP` doesn't attempt to parse unknown options.

      iex> OP.parse(["--debug"], strict: [])
      {[], [], [{"--debug", nil}]}

  ## Aliases

  A set of aliases can be specified in the `:aliases` option:

      iex> OP.parse(["-d"], aliases: [d: :debug], strict: [debug: :boolean])
      {[debug: true], [], []}

  ## Examples

  Here are some examples of working with different types and modifiers:

      iex> OP.parse(["--unlock", "path/to/file"], strict: [unlock: :boolean])
      {[unlock: true], ["path/to/file"], []}

      iex> OP.parse(
      ...>   ["--unlock", "--limit", "0", "path/to/file"],
      ...>   strict: [unlock: :boolean, limit: :integer]
      ...> )
      {[unlock: true, limit: 0], ["path/to/file"], []}

      iex> OP.parse(["--limit", "3"], strict: [limit: :integer])
      {[limit: 3], [], []}

      iex> OP.parse(["--limit", "xyz"], strict: [limit: :integer])
      {[], [], [{"--limit", "xyz"}]}

      iex> OP.parse(["--verbose"], strict: [verbose: :count])
      {[verbose: 1], [], []}

      iex> OP.parse(["-v", "-v"], aliases: [v: :verbose], strict: [verbose: :count])
      {[verbose: 2], [], []}

      iex> OP.parse(["--unknown", "xyz"], strict: [])
      {[], ["xyz"], [{"--unknown", nil}]}

      iex> OP.parse(
      ...>   ["--limit", "3", "--unknown", "xyz"],
      ...>   strict: [limit: :integer]
      ...> )
      {[limit: 3], ["xyz"], [{"--unknown", nil}]}

      iex> OP.parse(
      ...>   ["--unlock", "path/to/file", "--unlock", "path/to/another/file"],
      ...>   strict: [unlock: :keep]
      ...> )
      {[unlock: "path/to/file", unlock: "path/to/another/file"], [], []}

  ## Return separator

  The separator `--` implies options should no longer be processed.
  By default, the separator is not returned as parts of the arguments,
  but that can be changed via the `:return_separator` option:

      iex> OP.parse(["--", "lib"], return_separator: true, strict: [])
      {[], ["--", "lib"], []}

      iex> OP.parse(
      ...>   ["--no-halt", "--", "lib"],
      ...>   return_separator: true,
      ...>   strict: [halt: :boolean]
      ...> )
      {[halt: false], ["--", "lib"], []}

      iex> OP.parse(
      ...>   ["script.exs", "--no-halt", "--", "foo"],
      ...>   return_separator: true,
      ...>   strict: [halt: :boolean]
      ...> )
      {[{:halt, false}], ["script.exs", "--", "foo"], []}

  """
  @spec parse(argv, options) :: {parsed, argv, errors}
  def parse(argv, opts \\ []) when is_list(argv) and is_list(opts) do
    do_parse({argv, build_config(opts), {[], [], []}})
  end

  @doc """
  The same as `parse/2` but raises an `OP.ParseError`
  exception if any invalid options are given.

  If there are no errors, returns a `{parsed, rest}` tuple where:

    * `parsed` is the list of parsed switches (same as in `parse/2`)
    * `rest` is the list of arguments (same as in `parse/2`)

  ## Examples

      iex> OP.parse!(["--debug", "path/to/file"], strict: [debug: :boolean])
      {[debug: true], ["path/to/file"]}

      iex> OP.parse!(["--limit", "xyz"], strict: [limit: :integer])
      ** (OP.ParseError) 1 error found!
      --limit : Expected type integer, got "xyz"

      iex> OP.parse!(["--unknown", "xyz"], strict: [])
      ** (OP.ParseError) 1 error found!
      --unknown : Unknown option

      iex> OP.parse!(
      ...>   ["-l", "xyz", "-f", "bar"],
      ...>   strict: [limit: :integer, foo: :integer],
      ...>   aliases: [l: :limit, f: :foo]
      ...> )
      ** (OP.ParseError) 2 errors found!
      -l : Expected type integer, got "xyz"
      -f : Expected type integer, got "bar"

  """
  @spec parse!(argv, options) :: {parsed, argv}
  def parse!(argv, opts \\ []) when is_list(argv) and is_list(opts) do
    case parse(argv, opts) do
      {parsed, args, []} -> {parsed, args}
      {_, _, errors} -> raise ParseError, format_errors(errors, opts)
    end
  end

  # @doc """
  # Low-level function that parses one option.
  #
  # It accepts the same options as `parse/2` and `parse_head/2`
  # as both functions are built on top of this function. This function
  # may return:
  #
  #   * `{:ok, key, value, rest}` - the option `key` with `value` was
  #     successfully parsed
  #
  #   * `{:invalid, key, value, rest}` - the option `key` is invalid with `value`
  #     (returned when the value cannot be parsed according to the switch type)
  #
  #   * `{:undefined, key, value, rest}` - the option `key` is undefined
  #     (returned in strict mode when the switch is unknown or on nonexistent atoms)
  #
  #   * `{:error, rest}` - there are no switches at the head of the given `argv`
  #
  # """
  # @spec next(argv, options) ::
  #         {:ok, key :: atom, value :: term, argv}
  #         | {:invalid, String.t(), String.t() | nil, argv}
  #         | {:undefined, String.t(), String.t() | nil, argv}
  #         | {:error, argv}

  defp do_parse({[], _config, {opts, args, errors}}) do
    {Enum.reverse(opts), Enum.reverse(args), Enum.reverse(errors)}
  end

  defp do_parse({_argv, _config, {_opts, _args, _errors}} = state) do
    steps = [&parse_sep/1, &parse_dash/1, &parse_opt/1, &parse_arg/1, &fallback/1]
    reduce_steps(steps, state)
  end

  def reduce_steps([], state), do: do_parse(state)

  def reduce_steps([step | rest], state) do
    case step.(state) do
      {:ok, final_state} -> do_parse(final_state)
      :error -> reduce_steps(rest, state)
    end
  end

  defp parse_sep({["--" | rest] = argv, config, {opts, args, errors}}) do
    args =
      if config.return_separator?,
        do: Enum.reverse(argv, args),
        else: Enum.reverse(rest, args)

    {:ok, {[], config, {opts, args, errors}}}
  end

  defp parse_sep({_, _, _}), do: :error

  defp parse_dash({["-" = arg | rest], config, {opts, args, errors}}),
    do: {:ok, {rest, config, {opts, [arg | args], errors}}}

  defp parse_dash({_, _, _}), do: :error

  # Handles --foo or --foo=bar
  defp parse_opt({["--" <> opt | rest], config, {opts, args, errors}}) do
    {name, value} = split_opt(opt)

    if String.contains?(name, ["_"]) do
      {:undefined, "--" <> name, value, rest}
    else
      tagged = tag_option(name, config)
      next_tagged(tagged, value, "--" <> name, rest, config)
    end
    |> case do
      {:ok, name, value, rest} ->
        # the option exists and it was successfully parsed
        kinds = List.wrap(Keyword.get(config.switches, name))
        new_opts = store_option(opts, name, value, kinds)
        {:ok, {rest, config, {new_opts, args, errors}}}

      {:invalid, option, value, rest} ->
        # the option exist but it has wrong value
        {:ok, {rest, config, {opts, args, [{option, value} | errors]}}}

      {:undefined, option, _value, rest} ->
        {:ok, {rest, config, {opts, args, [{option, nil} | errors]}}}
    end
  end

  # Handles -a, -abc, -abc=something, -n2
  defp parse_opt({["-" <> opt | rest] = argv, config, {opts, args, errors}}) do
    {name, value} = split_opt(opt)
    original = "-" <> name

    cond do
      is_nil(value) and starts_with_number?(name) ->
        {:error, argv}

      String.contains?(name, ["-", "_"]) ->
        {:undefined, original, value, rest}

      String.length(name) == 1 ->
        # We have a regular one-letter alias here
        tagged = tag_oneletter_alias(name, config)
        next_tagged(tagged, value, original, rest, config)

      true ->
        key = get_option_key(name)
        option_key = config.aliases[key]

        if key && option_key do
          IO.warn("multi-letter aliases are deprecated, got: #{inspect(key)}")
          next_tagged({:default, option_key}, value, original, rest, config)
        else
          parse_opt({expand_multiletter_alias(name, value) ++ rest, config, {opts, args, errors}})
        end
    end
    |> case do
      {:ok, state} ->
        {:ok, state}

      {:ok, name, value, rest} ->
        # the option exists and it was successfully parsed
        kinds = List.wrap(Keyword.get(config.switches, name))
        new_opts = store_option(opts, name, value, kinds)
        {:ok, {rest, config, {new_opts, args, errors}}}

      {:invalid, option, value, rest} ->
        # the option exist but it has wrong value
        {:ok, {rest, config, {opts, args, [{option, value} | errors]}}}

      {:undefined, option, _value, rest} ->
        {:ok, {rest, config, {opts, args, [{option, nil} | errors]}}}

      {:error, [arg | rest]} ->
        # there is no option
        {:ok, {rest, config, {opts, [arg | args], errors}}}
    end
  end

  defp parse_opt({_, _, _}), do: :error

  defp parse_arg({[arg | rest], config, {opts, args, errors}}),
    do: {:ok, {rest, config, {opts, [arg | args], errors}}}

  defp fallback({[arg | rest], config, {opts, args, errors}}),
    do: {:ok, {rest, config, {opts, args, [arg | errors]}}}

  defp next_tagged(:unknown, value, original, rest, _) do
    {value, _kinds, rest} = normalize_value(value, [], rest)
    {:undefined, original, value, rest}
  end

  defp next_tagged({tag, option}, value, original, rest, %{switches: switches, strict?: strict?}) do
    if strict? and not Keyword.has_key?(switches, option) do
      {:undefined, original, value, rest}
    else
      {kinds, value} = normalize_tag(tag, option, value, switches)
      {value, kinds, rest} = normalize_value(value, kinds, rest)

      case validate_option(value, kinds) do
        {:ok, new_value} -> {:ok, option, new_value, rest}
        :invalid -> {:invalid, original, value, rest}
      end
    end
  end

  ## Helpers

  defp build_config(opts) do
    {switches, strict?} =
      cond do
        opts[:switches] && opts[:strict] ->
          raise ArgumentError, ":switches and :strict cannot be given together"

        switches = opts[:strict] ->
          validate_switches(switches)
          {switches, true}

        true ->
          IO.warn("not passing the :strict option to OP is deprecated")
          {[], false}
      end

    %{
      aliases: opts[:aliases] || [],
      return_separator?: opts[:return_separator] || false,
      strict?: strict?,
      switches: switches
    }
  end

  defp validate_switches(switches) do
    Enum.map(switches, &validate_switch/1)
  end

  defp validate_switch({_name, type_or_type_and_modifiers}) do
    valid = [:boolean, :count, :integer, :float, :string, :keep]
    invalid = List.wrap(type_or_type_and_modifiers) -- valid

    if invalid != [] do
      raise ArgumentError,
            "invalid switch types/modifiers: " <> Enum.map_join(invalid, ", ", &inspect/1)
    end
  end

  defp validate_option(value, kinds) do
    {invalid?, value} =
      cond do
        :invalid in kinds ->
          {true, value}

        :boolean in kinds ->
          case value do
            t when t in [true, "true"] -> {false, true}
            f when f in [false, "false"] -> {false, false}
            _ -> {true, value}
          end

        :count in kinds ->
          case value do
            nil -> {false, 1}
            _ -> {true, value}
          end

        :integer in kinds ->
          case Integer.parse(value) do
            {value, ""} -> {false, value}
            _ -> {true, value}
          end

        :float in kinds ->
          case Float.parse(value) do
            {value, ""} -> {false, value}
            _ -> {true, value}
          end

        true ->
          {false, value}
      end

    if invalid? do
      :invalid
    else
      {:ok, value}
    end
  end

  defp store_option(dict, option, value, kinds) do
    cond do
      :count in kinds ->
        Keyword.update(dict, option, value, &(&1 + 1))

      :keep in kinds ->
        [{option, value} | dict]

      true ->
        [{option, value} | Keyword.delete(dict, option)]
    end
  end

  defp tag_option("no-" <> option = original, config) do
    %{switches: switches} = config

    cond do
      (negated = get_option_key(option)) &&
          :boolean in List.wrap(switches[negated]) ->
        {:negated, negated}

      option_key = get_option_key(original) ->
        {:default, option_key}

      true ->
        :unknown
    end
  end

  defp tag_option(option, _config) do
    if option_key = get_option_key(option) do
      {:default, option_key}
    else
      :unknown
    end
  end

  defp tag_oneletter_alias(alias, config) when is_binary(alias) do
    %{aliases: aliases} = config

    if option_key = aliases[to_existing_key(alias)] do
      {:default, option_key}
    else
      :unknown
    end
  end

  defp expand_multiletter_alias(options, value) do
    {options, maybe_integer} =
      options
      |> String.to_charlist()
      |> Enum.split_while(&(&1 not in ?0..?9))

    {last, expanded} =
      options
      |> List.to_string()
      |> String.graphemes()
      |> Enum.map(&("-" <> &1))
      |> List.pop_at(-1)

    expanded ++
      [
        last <>
          if(maybe_integer != [], do: "=#{maybe_integer}", else: "") <>
          if(value, do: "=#{value}", else: "")
      ]
  end

  defp normalize_tag(:negated, option, value, switches) do
    if value do
      {[:invalid], value}
    else
      {List.wrap(switches[option]), false}
    end
  end

  defp normalize_tag(:default, option, value, switches) do
    {List.wrap(switches[option]), value}
  end

  defp normalize_value(nil, kinds, t) do
    cond do
      :boolean in kinds ->
        {true, kinds, t}

      :count in kinds ->
        {nil, kinds, t}

      value_in_tail?(t) ->
        [h | t] = t
        {h, kinds, t}

      kinds == [] ->
        {true, kinds, t}

      true ->
        {nil, [:invalid], t}
    end
  end

  defp normalize_value(value, kinds, t) do
    {value, kinds, t}
  end

  defp value_in_tail?(["-" | _]), do: true
  defp value_in_tail?(["- " <> _ | _]), do: true
  defp value_in_tail?(["-" <> arg | _]), do: starts_with_number?(arg)
  defp value_in_tail?([]), do: false
  defp value_in_tail?(_), do: true

  defp split_opt(opt) do
    case :binary.split(opt, "=") do
      [name] -> {name, nil}
      [name, value] -> {name, value}
    end
  end

  defp to_underscore(option), do: to_underscore(option, <<>>)
  defp to_underscore("-" <> rest, acc), do: to_underscore(rest, acc <> "_")
  defp to_underscore(<<c>> <> rest, acc), do: to_underscore(rest, <<acc::binary, c>>)
  defp to_underscore(<<>>, acc), do: acc

  defp get_option_key(option) do
    option
    |> to_underscore()
    |> to_existing_key()
  end

  defp to_existing_key(option) do
    try do
      String.to_existing_atom(option)
    rescue
      ArgumentError -> nil
    end
  end

  defp starts_with_number?(<<char, _::binary>>) when char in ?0..?9, do: true
  defp starts_with_number?(_), do: false

  defp format_errors([_ | _] = errors, opts) do
    types = opts[:switches] || opts[:strict]
    error_count = length(errors)
    error = if error_count == 1, do: "error", else: "errors"

    "#{error_count} #{error} found!\n" <>
      Enum.map_join(errors, "\n", &format_error(&1, opts, types))
  end

  defp format_error({option, nil}, opts, types) do
    if type = get_type(option, opts, types) do
      if String.contains?(option, "_") do
        msg = "#{option} : Unknown option"

        msg <> ". Did you mean #{String.replace(option, "_", "-")}?"
      else
        "#{option} : Missing argument of type #{type}"
      end
    else
      msg = "#{option} : Unknown option"

      case did_you_mean(option, types) do
        {similar, score} when score > 0.8 ->
          msg <> ". Did you mean --#{similar}?"

        _ ->
          msg
      end
    end
  end

  defp format_error({option, value}, opts, types) do
    type = get_type(option, opts, types)
    "#{option} : Expected type #{type}, got #{inspect(value)}"
  end

  defp get_type(option, opts, types) do
    key = option |> String.trim_leading("-") |> get_option_key()

    if option_key = opts[:aliases][key] do
      types[option_key]
    else
      types[key]
    end
  end

  defp did_you_mean(option, types) do
    key = option |> String.trim_leading("-") |> String.replace("-", "_")
    Enum.reduce(types, {nil, 0}, &max_similar(&1, key, &2))
  end

  defp max_similar({source, _}, target, {_, current} = best) do
    source = Atom.to_string(source)

    score = String.jaro_distance(source, target)
    option = String.replace(source, "_", "-")
    if score < current, do: best, else: {option, score}
  end
end
