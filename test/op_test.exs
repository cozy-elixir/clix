defmodule OPTest do
  use ExUnit.Case, async: true

  doctest OP

  test "parses --key value option" do
    assert OP.parse(["--source", "form_docs/", "other"], switches: [source: :string]) ==
             {[source: "form_docs/"], ["other"], []}
  end

  test "parses --key=value option" do
    assert OP.parse(["--source=form_docs/", "other"], switches: [source: :string]) ==
             {[source: "form_docs/"], ["other"], []}
  end

  test "parses overrides options by default" do
    assert OP.parse(
             ["--require", "foo", "--require", "bar", "baz"],
             switches: [require: :string]
           ) == {[require: "bar"], ["baz"], []}
  end

  test "parses multi-word option" do
    config = [switches: [hello_world: :boolean]]
    assert OP.next(["--hello-world"], config) == {:ok, :hello_world, true, []}
    assert OP.next(["--no-hello-world"], config) == {:ok, :hello_world, false, []}

    assert OP.next(["--no-hello-world"], strict: []) ==
             {:undefined, "--no-hello-world", nil, []}

    assert OP.next(["--no-hello_world"], strict: []) ==
             {:undefined, "--no-hello_world", nil, []}

    config = [strict: [hello_world: :boolean]]
    assert OP.next(["--hello-world"], config) == {:ok, :hello_world, true, []}
    assert OP.next(["--no-hello-world"], config) == {:ok, :hello_world, false, []}
    assert OP.next(["--hello_world"], config) == {:undefined, "--hello_world", nil, []}

    assert OP.next(["--no-hello_world"], config) ==
             {:undefined, "--no-hello_world", nil, []}
  end

  test "parses more than one key-value pair options using switches" do
    opts = [switches: [source: :string, docs: :string]]

    assert OP.parse(["--source", "from_docs/", "--docs", "show"], opts) ==
             {[source: "from_docs/", docs: "show"], [], []}

    assert OP.parse(["--source", "from_docs/", "--doc", "show"], opts) ==
             {[source: "from_docs/", doc: "show"], [], []}

    assert OP.parse(["--source", "from_docs/", "--doc=show"], opts) ==
             {[source: "from_docs/", doc: "show"], [], []}

    assert OP.parse(["--no-bool"], strict: []) == {[], [], [{"--no-bool", nil}]}
  end

  test "parses more than one key-value pair options using strict" do
    opts = [strict: [source: :string, docs: :string]]

    assert OP.parse(["--source", "from_docs/", "--docs", "show"], opts) ==
             {[source: "from_docs/", docs: "show"], [], []}

    assert OP.parse(["--source", "from_docs/", "--doc", "show"], opts) ==
             {[source: "from_docs/"], ["show"], [{"--doc", nil}]}

    assert OP.parse(["--source", "from_docs/", "--doc=show"], opts) ==
             {[source: "from_docs/"], [], [{"--doc", nil}]}

    assert OP.parse(["--no-bool"], strict: []) == {[], [], [{"--no-bool", nil}]}
  end

  test "collects multiple invalid options" do
    argv = ["--bad", "opt", "foo", "-o", "bad", "bar"]

    assert OP.parse(argv, switches: [bad: :integer]) ==
             {[], ["foo", "bar"], [{"--bad", "opt"}]}
  end

  test "parse/2 raises when using both options: switches and strict" do
    assert_raise ArgumentError, ":switches and :strict cannot be given together", fn ->
      OP.parse(["--elixir"], switches: [ex: :string], strict: [elixir: :string])
    end
  end

  test "parse/2 raises an exception on invalid switch types/modifiers" do
    assert_raise ArgumentError, "invalid switch types/modifiers: :bad", fn ->
      OP.parse(["--elixir"], switches: [ex: :bad])
    end

    assert_raise ArgumentError, "invalid switch types/modifiers: :bad, :bad_modifier", fn ->
      OP.parse(["--elixir"], switches: [ex: [:bad, :bad_modifier]])
    end
  end

  test "parse!/2 raises an exception for an unknown option using strict" do
    msg = "1 error found!\n--doc-bar : Unknown option. Did you mean --docs-bar?"

    assert_raise OP.ParseError, msg, fn ->
      argv = ["--source", "from_docs/", "--doc-bar", "show"]
      OP.parse!(argv, strict: [source: :string, docs_bar: :string])
    end

    assert_raise OP.ParseError, "1 error found!\n--foo : Unknown option", fn ->
      argv = ["--source", "from_docs/", "--foo", "show"]
      OP.parse!(argv, strict: [source: :string, docs: :string])
    end
  end

  test "parse!/2 raises an exception for an unknown option using strict when it is only off by underscores" do
    msg = "1 error found!\n--docs_bar : Unknown option. Did you mean --docs-bar?"

    assert_raise OP.ParseError, msg, fn ->
      argv = ["--source", "from_docs/", "--docs_bar", "show"]
      OP.parse!(argv, strict: [source: :string, docs_bar: :string])
    end
  end

  test "parse!/2 raises an exception when an option is of the wrong type" do
    assert_raise OP.ParseError, fn ->
      argv = ["--bad", "opt", "foo", "-o", "bad", "bar"]
      OP.parse!(argv, switches: [bad: :integer])
    end
  end

  describe "arguments" do
    test "parses until --" do
      assert OP.parse(
               ["--source", "foo", "--", "1", "2", "3"],
               switches: [source: :string]
             ) == {[source: "foo"], ["1", "2", "3"], []}

      assert OP.parse(
               ["--source", "foo", "bar", "--", "-x"],
               switches: [source: :string]
             ) == {[source: "foo"], ["bar", "-x"], []}
    end

    test "parses - as argument" do
      argv = ["--foo", "-", "-b", "-"]
      opts = [strict: [foo: :boolean, boo: :string], aliases: [b: :boo]]
      assert OP.parse(argv, opts) == {[foo: true, boo: "-"], ["-"], []}
    end
  end

  describe "aliases" do
    test "supports boolean aliases" do
      assert OP.parse(["-d"], aliases: [d: :docs], switches: [docs: :boolean]) ==
               {[docs: true], [], []}
    end

    test "supports non-boolean aliases" do
      assert OP.parse(
               ["-s", "from_docs/"],
               aliases: [s: :source],
               switches: [source: :string]
             ) == {[source: "from_docs/"], [], []}
    end

    test "supports --key=value aliases" do
      assert OP.parse(
               ["-s=from_docs/", "other"],
               aliases: [s: :source],
               switches: [source: :string]
             ) == {[source: "from_docs/"], ["other"], []}
    end

    test "parses -ab as -a -b" do
      opts = [aliases: [a: :first, b: :second], switches: [second: :integer]]
      assert OP.parse(["-ab=1"], opts) == {[first: true, second: 1], [], []}
      assert OP.parse(["-ab", "1"], opts) == {[first: true, second: 1], [], []}

      opts = [aliases: [a: :first, b: :second], switches: [first: :boolean, second: :boolean]]
      assert OP.parse(["-ab"], opts) == {[first: true, second: true], [], []}
      assert OP.parse(["-ab3"], opts) == {[first: true], [], [{"-b", "3"}]}
      assert OP.parse(["-ab=bar"], opts) == {[first: true], [], [{"-b", "bar"}]}
      assert OP.parse(["-ab3=bar"], opts) == {[first: true], [], [{"-b", "3=bar"}]}
      assert OP.parse(["-3ab"], opts) == {[], ["-3ab"], []}
    end
  end

  describe "types" do
    test "parses configured booleans" do
      assert OP.parse(["--docs=false"], switches: [docs: :boolean]) ==
               {[docs: false], [], []}

      assert OP.parse(["--docs=true"], switches: [docs: :boolean]) ==
               {[docs: true], [], []}

      assert OP.parse(["--docs=other"], switches: [docs: :boolean]) ==
               {[], [], [{"--docs", "other"}]}

      assert OP.parse(["--docs="], switches: [docs: :boolean]) ==
               {[], [], [{"--docs", ""}]}

      assert OP.parse(["--docs", "foo"], switches: [docs: :boolean]) ==
               {[docs: true], ["foo"], []}

      assert OP.parse(["--no-docs", "foo"], switches: [docs: :boolean]) ==
               {[docs: false], ["foo"], []}

      assert OP.parse(["--no-docs=foo", "bar"], switches: [docs: :boolean]) ==
               {[], ["bar"], [{"--no-docs", "foo"}]}

      assert OP.parse(["--no-docs=", "bar"], switches: [docs: :boolean]) ==
               {[], ["bar"], [{"--no-docs", ""}]}
    end

    test "does not set unparsed booleans" do
      assert OP.parse(["foo"], switches: [docs: :boolean]) == {[], ["foo"], []}
    end

    test "keeps options on configured keep" do
      argv = ["--require", "foo", "--require", "bar", "baz"]

      assert OP.parse(argv, switches: [require: :keep]) ==
               {[require: "foo", require: "bar"], ["baz"], []}

      assert OP.parse(["--require"], switches: [require: :keep]) ==
               {[], [], [{"--require", nil}]}
    end

    test "parses configured strings" do
      assert OP.parse(["--value", "1", "foo"], switches: [value: :string]) ==
               {[value: "1"], ["foo"], []}

      assert OP.parse(["--value=1", "foo"], switches: [value: :string]) ==
               {[value: "1"], ["foo"], []}

      assert OP.parse(["--value"], switches: [value: :string]) ==
               {[], [], [{"--value", nil}]}

      assert OP.parse(["--no-value"], switches: [value: :string]) ==
               {[no_value: true], [], []}
    end

    test "parses configured counters" do
      assert OP.parse(["--verbose"], switches: [verbose: :count]) ==
               {[verbose: 1], [], []}

      assert OP.parse(["--verbose", "--verbose"], switches: [verbose: :count]) ==
               {[verbose: 2], [], []}

      argv = ["--verbose", "-v", "-v", "--", "bar"]
      opts = [aliases: [v: :verbose], strict: [verbose: :count]]
      assert OP.parse(argv, opts) == {[verbose: 3], ["bar"], []}
    end

    test "parses configured integers" do
      assert OP.parse(["--value", "1", "foo"], switches: [value: :integer]) ==
               {[value: 1], ["foo"], []}

      assert OP.parse(["--value=1", "foo"], switches: [value: :integer]) ==
               {[value: 1], ["foo"], []}

      assert OP.parse(["--value", "WAT", "foo"], switches: [value: :integer]) ==
               {[], ["foo"], [{"--value", "WAT"}]}
    end

    test "parses configured integers with keep" do
      argv = ["--value", "1", "--value", "2", "foo"]

      assert OP.parse(argv, switches: [value: [:integer, :keep]]) ==
               {[value: 1, value: 2], ["foo"], []}

      argv = ["--value=1", "foo", "--value=2", "bar"]

      assert OP.parse(argv, switches: [value: [:integer, :keep]]) ==
               {[value: 1, value: 2], ["foo", "bar"], []}
    end

    test "parses configured floats" do
      assert OP.parse(["--value", "1.0", "foo"], switches: [value: :float]) ==
               {[value: 1.0], ["foo"], []}

      assert OP.parse(["--value=1.0", "foo"], switches: [value: :float]) ==
               {[value: 1.0], ["foo"], []}

      assert OP.parse(["--value", "WAT", "foo"], switches: [value: :float]) ==
               {[], ["foo"], [{"--value", "WAT"}]}
    end

    test "correctly handles negative integers" do
      opts = [switches: [option: :integer], aliases: [o: :option]]
      assert OP.parse(["arg1", "-o43"], opts) == {[option: 43], ["arg1"], []}
      assert OP.parse(["arg1", "-o", "-43"], opts) == {[option: -43], ["arg1"], []}
      assert OP.parse(["arg1", "--option=-43"], opts) == {[option: -43], ["arg1"], []}

      assert OP.parse(["arg1", "--option", "-43"], opts) ==
               {[option: -43], ["arg1"], []}
    end

    test "correctly handles negative floating-point numbers" do
      opts = [switches: [option: :float], aliases: [o: :option]]
      assert OP.parse(["arg1", "-o43.2"], opts) == {[option: 43.2], ["arg1"], []}
      assert OP.parse(["arg1", "-o", "-43.2"], opts) == {[option: -43.2], ["arg1"], []}

      assert OP.parse(["arg1", "--option=-43.2"], switches: [option: :float]) ==
               {[option: -43.2], ["arg1"], []}

      assert OP.parse(["arg1", "--option", "-43.2"], opts) ==
               {[option: -43.2], ["arg1"], []}
    end
  end

  describe "next" do
    test "with strict good options" do
      config = [strict: [str: :string, int: :integer, bool: :boolean]]
      assert OP.next(["--str", "hello", "..."], config) == {:ok, :str, "hello", ["..."]}
      assert OP.next(["--int=13", "..."], config) == {:ok, :int, 13, ["..."]}
      assert OP.next(["--bool=false", "..."], config) == {:ok, :bool, false, ["..."]}
      assert OP.next(["--no-bool", "..."], config) == {:ok, :bool, false, ["..."]}
      assert OP.next(["--bool", "..."], config) == {:ok, :bool, true, ["..."]}
      assert OP.next(["..."], config) == {:error, ["..."]}
    end

    test "with strict unknown options" do
      config = [strict: [bool: :boolean]]

      assert OP.next(["--str", "13", "..."], config) ==
               {:undefined, "--str", nil, ["13", "..."]}

      assert OP.next(["--int=hello", "..."], config) ==
               {:undefined, "--int", "hello", ["..."]}

      assert OP.next(["-no-bool=other", "..."], config) ==
               {:undefined, "-no-bool", "other", ["..."]}
    end

    test "with strict bad type" do
      config = [strict: [str: :string, int: :integer, bool: :boolean]]
      assert OP.next(["--str", "13", "..."], config) == {:ok, :str, "13", ["..."]}

      assert OP.next(["--int=hello", "..."], config) ==
               {:invalid, "--int", "hello", ["..."]}

      assert OP.next(["--int", "hello", "..."], config) ==
               {:invalid, "--int", "hello", ["..."]}

      assert OP.next(["--bool=other", "..."], config) ==
               {:invalid, "--bool", "other", ["..."]}
    end

    test "with strict missing value" do
      config = [strict: [str: :string, int: :integer, bool: :boolean]]
      assert OP.next(["--str"], config) == {:invalid, "--str", nil, []}
      assert OP.next(["--int"], config) == {:invalid, "--int", nil, []}
      assert OP.next(["--bool=", "..."], config) == {:invalid, "--bool", "", ["..."]}

      assert OP.next(["--no-bool=", "..."], config) ==
               {:invalid, "--no-bool", "", ["..."]}
    end
  end

  describe "to_argv" do
    test "converts options back to switches" do
      assert OP.to_argv(foo_bar: "baz") == ["--foo-bar", "baz"]

      assert OP.to_argv(bool: true, bool: false, discarded: nil) ==
               ["--bool", "--no-bool"]
    end

    test "handles :count switch type" do
      original = ["--counter", "--counter"]
      {opts, [], []} = OP.parse(original, switches: [counter: :count])
      assert original == OP.to_argv(opts, switches: [counter: :count])
    end
  end
end

defmodule OptionsParserDeprecationsTest do
  use ExUnit.Case, async: true

  @warning ~r[not passing the :switches or :strict option to OP is deprecated]

  def assert_deprecated(fun) do
    assert ExUnit.CaptureIO.capture_io(:stderr, fun) =~ @warning
  end

  test "parses boolean option" do
    assert_deprecated(fn ->
      assert OP.parse(["--docs"]) == {[docs: true], [], []}
    end)
  end

  test "parses more than one boolean option" do
    assert_deprecated(fn ->
      assert OP.parse(["--docs", "--compile"]) == {[docs: true, compile: true], [], []}
    end)
  end

  test "parses more than one boolean options as the alias" do
    assert_deprecated(fn ->
      assert OP.parse(["-d", "--compile"], aliases: [d: :docs]) ==
               {[docs: true, compile: true], [], []}
    end)
  end

  test "parses --key value option" do
    assert_deprecated(fn ->
      assert OP.parse(["--source", "form_docs/"]) == {[source: "form_docs/"], [], []}
    end)
  end

  test "does not interpret undefined options with value as boolean" do
    assert_deprecated(fn ->
      assert OP.parse(["--no-bool"]) == {[no_bool: true], [], []}
    end)

    assert_deprecated(fn ->
      assert OP.parse(["--no-bool=...", "other"]) == {[no_bool: "..."], ["other"], []}
    end)
  end

  test "parses -ab as -a -b" do
    assert_deprecated(fn ->
      assert OP.parse(["-ab"], aliases: [a: :first, b: :second]) ==
               {[first: true, second: true], [], []}
    end)
  end

  test "parses mixed options" do
    argv = ["--source", "from_docs/", "--compile", "-x"]

    assert_deprecated(fn ->
      assert OP.parse(argv, aliases: [x: :x]) ==
               {[source: "from_docs/", compile: true, x: true], [], []}
    end)
  end

  test "parses more than one key-value pair options" do
    assert_deprecated(fn ->
      assert OP.parse(["--source", "from_docs/", "--docs", "show"]) ==
               {[source: "from_docs/", docs: "show"], [], []}
    end)
  end

  test "multi-word option" do
    assert_deprecated(fn ->
      assert OP.next(["--hello-world"], []) == {:ok, :hello_world, true, []}
    end)

    assert_deprecated(fn ->
      assert OP.next(["--no-hello-world"], []) == {:ok, :no_hello_world, true, []}
    end)

    assert_deprecated(fn ->
      assert OP.next(["--hello_world"], []) == {:undefined, "--hello_world", nil, []}
    end)

    assert_deprecated(fn ->
      assert OP.next(["--no-hello_world"], []) ==
               {:undefined, "--no-hello_world", nil, []}
    end)
  end
end
