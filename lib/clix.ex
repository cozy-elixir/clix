defmodule CLIX do
  @moduledoc """
  An user-friendly CLI framework.

  ## Features

    * parses both positional and optional arguments
    * produces informative usage messages

  ## Basics

  Before using CLIX, let's first go over some basic knowledge and the conventions used in CLIX.

  ## The types of arguments

  ### Positional arguments

  In general, positional arguments are not prefixed with `-` or `--`.

  > Negative number(like `-3`, `-3.14`) is a special case, but CLIX's parser can handle it
  > correctly.

  ### Optional arguments

  In general, optional arguments are prefixed with `-` or `--`:

    * POSIX syntax - `-` followed by a single letter indicating an option.
    * GNU-extended syntax - `--` followed by a long name indicating an option.

  > CLIX's parser doesn't plan to support special prefixes, such as `/` or `+`.

  In practice, optional arguments are often used to implement options. For options, there is
  a further level of classification:

    * options which require subsequent arguments, such as `-o value` or `--option value`.
    * options which don't require subsequent arguments, such as `-o` or `--option`. They are
      commonly referred to as flags, because they represent boolean states.

  > CLIX's parser doesn't explicitly distinguish between flags and options, as a flag is simply
  > a special type of option.

  And, there's a special case - `--`, which is considered as an option terminator. It means that
  all the arguments after it are considered as positional arguments.

  ## The abbrevations of arguments

  In CLIX, to describe the types of arguments more simply and clearly, we call:

    * positional arguments as *args*.
    * optional arguments as *opts*.

  In the following documentation, we will adhere to this convention.

  ## Syntax of opts

  Syntax are primarily defined by POSIX and GNU:

    * [POSIX - Utility Conventions](https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap12.html)
    * [GNU - Standards for Command Line Interfaces](https://www.gnu.org/prep/standards/html_node/Command_002dLine-Interfaces.html)

  Opts using POSIX syntax:

  ```plain
  -f
  -o <value>

  # space-ignored options
  -o<value>     # equals to -o <value>

  # compound options
  -abc          # equals to -a -b -c
  -abco<value>  # equals to -a -b -c -o <value>
  ```

  Opts using GNU-extended syntax:

  ```plain
  --flag
  --option <value>
  --option=<value>
  ```

  Opts using non-standard syntax:

  ```plain
  -o=<value>
  ```

  To summarize it up:

  ```
  # For short opts
  -f
  -o <value>
  -o=<value>

  -o<value>
  -abc
  -abco<value>

  # For long opts
  --flag
  --option <value>
  --option=<value>
  ```


  # --------------------------

  ## Features

    * command line arguments parser, which is desiged to pepare read-to-use parsed result.
    * help message generator, which is designed to generate clear and compact message.

  ## More

  When calling a command, it's possible to pass command line options
  to modify what the command does. In this documentation, those are
  called "switches", in other situations they may be called "flags"
  or simply "options". A switch can be given a value, also called an
  "argument".

  The main function in this module is `parse/2`, which parses a list
  of command line options and arguments into a keyword list:

      iex> CLIX.parse(["--debug"], strict: [debug: :boolean])
      {[debug: true], [], []}

  `CLIX` provides some conveniences out of the box,
  such as aliases and automatic handling of negation switches.

  The `parse_head/2` function is an alternative to `parse/2`
  which stops parsing as soon as it finds a value that is not
  a switch nor a value for a previous switch.

  This module also provides low-level functions, such as `next/2`,
  for parsing switches manually, as well as `split/1` and `to_argv/1`
  for parsing from and converting switches to strings.
  """

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

    For example, see `CLIX.parse!/2`.
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

      iex> CLIX.parse(["--debug"], strict: [debug: :boolean])
      {[debug: true], [], []}

      iex> CLIX.parse(["--source", "lib"], strict: [source: :string])
      {[source: "lib"], [], []}

      iex> CLIX.parse(
      ...>   ["--source-path", "lib", "test/enum_test.exs", "--verbose"],
      ...>   strict: [source_path: :string, verbose: :boolean]
      ...> )
      {[source_path: "lib", verbose: true], ["test/enum_test.exs"], []}

  We will explore the valid switches and operation modes of option parser below.

  ## Options

  The following options are supported:

    * `:switches` - see the "Switch definitions" section below
    * `:aliases` - see the "Aliases" section below
    * `:return_separator` - see the "Return separator" section below

  ## Switch definitions

  Switches can be specified via one of two options:

    * `:strict` - defines strict switches and their types. Any switch
      in `argv` that is not specified in the list is returned in the
      invalid options list. This is the preferred way to parse options.

  Both these options accept a keyword list where the key is an atom
  defining the name of the switch and value is the `type` of the
  switch (see the "Types" section below for more information).

  Note that you should only supply the `:switches` or the `:strict` option.
  If you supply both, an `ArgumentError` exception will be raised.

  ### Types

  Switches parsed by `CLIX` may take zero or one arguments.

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

      iex> CLIX.parse(["--no-op", "path/to/file"], strict: [op: :boolean])
      {[op: false], ["path/to/file"], []}

  ### Parsing unknown options

  `CLIX` doesn't attempt to parse unknown options.

      iex> CLIX.parse(["--debug"], strict: [])
      {[], [], [{"--debug", nil}]}

  ## Aliases

  A set of aliases can be specified in the `:aliases` option:

      iex> CLIX.parse(["-d"], aliases: [d: :debug], strict: [debug: :boolean])
      {[debug: true], [], []}

  ## Examples

  Here are some examples of working with different types and modifiers:

      iex> CLIX.parse(["--unlock", "path/to/file"], strict: [unlock: :boolean])
      {[unlock: true], ["path/to/file"], []}

      iex> CLIX.parse(
      ...>   ["--unlock", "--limit", "0", "path/to/file"],
      ...>   strict: [unlock: :boolean, limit: :integer]
      ...> )
      {[unlock: true, limit: 0], ["path/to/file"], []}

      iex> CLIX.parse(["--limit", "3"], strict: [limit: :integer])
      {[limit: 3], [], []}

      iex> CLIX.parse(["--limit", "xyz"], strict: [limit: :integer])
      {[], [], [{"--limit", "xyz"}]}

      iex> CLIX.parse(["--verbose"], strict: [verbose: :count])
      {[verbose: 1], [], []}

      iex> CLIX.parse(["-v", "-v"], aliases: [v: :verbose], strict: [verbose: :count])
      {[verbose: 2], [], []}

      iex> CLIX.parse(["--unknown", "xyz"], strict: [])
      {[], ["xyz"], [{"--unknown", nil}]}

      iex> CLIX.parse(
      ...>   ["--limit", "3", "--unknown", "xyz"],
      ...>   strict: [limit: :integer]
      ...> )
      {[limit: 3], ["xyz"], [{"--unknown", nil}]}

      iex> CLIX.parse(
      ...>   ["--unlock", "path/to/file", "--unlock", "path/to/another/file"],
      ...>   strict: [unlock: :keep]
      ...> )
      {[unlock: "path/to/file", unlock: "path/to/another/file"], [], []}

  ## Return separator

  The separator `--` implies options should no longer be processed.
  By default, the separator is not returned as parts of the arguments,
  but that can be changed via the `:return_separator` option:

      iex> CLIX.parse(["--", "lib"], return_separator: true, strict: [])
      {[], ["--", "lib"], []}

      iex> CLIX.parse(
      ...>   ["--no-halt", "--", "lib"],
      ...>   return_separator: true,
      ...>   strict: [halt: :boolean]
      ...> )
      {[halt: false], ["--", "lib"], []}

      iex> CLIX.parse(
      ...>   ["script.exs", "--no-halt", "--", "foo"],
      ...>   return_separator: true,
      ...>   strict: [halt: :boolean]
      ...> )
      {[{:halt, false}], ["script.exs", "--", "foo"], []}

  """

  # @spec parse(argv, options) :: {parsed, argv, errors}
  # def parse(argv, opts \\ []) when is_list(argv) and is_list(opts) do
  #   do_parse({argv, build_config(opts), {[], [], []}})
  # end

  @doc """
  The same as `parse/2` but raises an `CLIX.ParseError`
  exception if any invalid options are given.

  If there are no errors, returns a `{parsed, rest}` tuple where:

    * `parsed` is the list of parsed switches (same as in `parse/2`)
    * `rest` is the list of arguments (same as in `parse/2`)

  ## Examples

      iex> CLIX.parse!(["--debug", "path/to/file"], strict: [debug: :boolean])
      {[debug: true], ["path/to/file"]}

      iex> CLIX.parse!(["--limit", "xyz"], strict: [limit: :integer])
      ** (CLIX.ParseError) 1 error found!
      --limit : Expected type integer, got "xyz"

      iex> CLIX.parse!(["--unknown", "xyz"], strict: [])
      ** (CLIX.ParseError) 1 error found!
      --unknown : Unknown option

      iex> CLIX.parse!(
      ...>   ["-l", "xyz", "-f", "bar"],
      ...>   strict: [limit: :integer, foo: :integer],
      ...>   aliases: [l: :limit, f: :foo]
      ...> )
      ** (CLIX.ParseError) 2 errors found!
      -l : Expected type integer, got "xyz"
      -f : Expected type integer, got "bar"

  """

  # @spec parse!(argv, options) :: {parsed, argv}
  # def parse!(argv, opts \\ []) when is_list(argv) and is_list(opts) do
  #   case parse(argv, opts) do
  #     {parsed, args, []} -> {parsed, args}
  #     {_, _, errors} -> raise ParseError, format_errors(errors, opts)
  #   end
  # end

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

  # def parse(argv, spec, opts \\ []) do
  #   opts = opts |> Keyword.put_new_lazy(:progname, &default_progname/0)

  #   Parser.build_config()
  # end

  # defp default_progname do
  #   {:ok, [[progname]]} = :init.get_argument(:progname)
  #   to_string(progname)
  # end

  # -----------

  alias __MODULE__.Spec
  alias __MODULE__.Parser

  defdelegate spec(raw_spec), to: Spec, as: :new
end
