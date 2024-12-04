defmodule CliaraTest do
  use ExUnit.Case, async: true

  doctest Cliara

  test "parses --key value option" do
    assert Cliara.parse(["--source", "form_docs/", "other"], strict: [source: :string]) ==
             {[source: "form_docs/"], ["other"], []}
  end

  test "parses --key=value option" do
    assert Cliara.parse(["--source=form_docs/", "other"], strict: [source: :string]) ==
             {[source: "form_docs/"], ["other"], []}
  end

  test "parses overrides options by default" do
    assert Cliara.parse(
             ["--require", "foo", "--require", "bar", "baz"],
             strict: [require: :string]
           ) == {[require: "bar"], ["baz"], []}
  end

  # test "parses multi-word option" do
  #   config = [strict: [hello_world: :boolean]]
  #   assert Cliara.next(["--hello-world"], config) == {:ok, :hello_world, true, []}
  #   assert Cliara.next(["--no-hello-world"], config) == {:ok, :hello_world, false, []}

  #   assert Cliara.next(["--no-hello-world"], strict: []) ==
  #            {:undefined, "--no-hello-world", nil, []}

  #   assert Cliara.next(["--no-hello_world"], strict: []) ==
  #            {:undefined, "--no-hello_world", nil, []}

  #   config = [strict: [hello_world: :boolean]]
  #   assert Cliara.next(["--hello-world"], config) == {:ok, :hello_world, true, []}
  #   assert Cliara.next(["--no-hello-world"], config) == {:ok, :hello_world, false, []}
  #   assert Cliara.next(["--hello_world"], config) == {:undefined, "--hello_world", nil, []}

  #   assert Cliara.next(["--no-hello_world"], config) ==
  #            {:undefined, "--no-hello_world", nil, []}
  # end

  test "parses more than one key-value pair options" do
    opts = [strict: [source: :string, docs: :string]]

    assert Cliara.parse(["--source", "from_docs/", "--docs", "show"], opts) ==
             {[source: "from_docs/", docs: "show"], [], []}

    assert Cliara.parse(["--source", "from_docs/", "--doc", "show"], opts) ==
             {[source: "from_docs/"], ["show"], [{"--doc", nil}]}

    assert Cliara.parse(["--source", "from_docs/", "--doc=show"], opts) ==
             {[source: "from_docs/"], [], [{"--doc", nil}]}

    assert Cliara.parse(["--no-bool"], strict: []) == {[], [], [{"--no-bool", nil}]}
  end

  test "collects multiple invalid options" do
    opts = [strict: [bad: :integer]]

    assert Cliara.parse(["--bad", "opt", "foo", "-o", "bad", "bar"], opts) ==
             {[], ["foo", "bar"], [{"--bad", "opt"}, {"-o", nil}]}
  end

  test "parse/2 raises an exception on invalid switch types/modifiers" do
    assert_raise ArgumentError, "invalid switch types/modifiers: :bad", fn ->
      Cliara.parse(["--elixir"], strict: [ex: :bad])
    end

    assert_raise ArgumentError, "invalid switch types/modifiers: :bad, :bad_modifier", fn ->
      Cliara.parse(["--elixir"], strict: [ex: [:bad, :bad_modifier]])
    end
  end

  test "parse!/2 raises an exception for an unknown option" do
    msg = "1 error found!\n--doc-bar : Unknown option. Did you mean --docs-bar?"

    assert_raise Cliara.ParseError, msg, fn ->
      argv = ["--source", "from_docs/", "--doc-bar", "show"]
      Cliara.parse!(argv, strict: [source: :string, docs_bar: :string])
    end

    assert_raise Cliara.ParseError, "1 error found!\n--foo : Unknown option", fn ->
      argv = ["--source", "from_docs/", "--foo", "show"]
      Cliara.parse!(argv, strict: [source: :string, docs: :string])
    end
  end

  test "parse!/2 raises an exception for an unknown option when it is only off by underscores" do
    msg = "1 error found!\n--docs_bar : Unknown option. Did you mean --docs-bar?"

    assert_raise Cliara.ParseError, msg, fn ->
      argv = ["--source", "from_docs/", "--docs_bar", "show"]
      Cliara.parse!(argv, strict: [source: :string, docs_bar: :string])
    end
  end

  test "parse!/2 raises an exception when an option is of the wrong type" do
    assert_raise Cliara.ParseError, fn ->
      argv = ["--bad", "opt", "foo", "-o", "bad", "bar"]
      Cliara.parse!(argv, strict: [bad: :integer])
    end
  end

  describe "arguments" do
    test "parses until --" do
      opts = [strict: [source: :string]]

      assert Cliara.parse(["--source", "foo", "--", "1", "2", "3"], opts) ==
               {[source: "foo"], ["1", "2", "3"], []}

      assert Cliara.parse(["--source", "foo", "bar", "--", "-x"], opts) ==
               {[source: "foo"], ["bar", "-x"], []}
    end

    test "parses - as argument" do
      argv = ["--foo", "-", "-b", "-"]
      opts = [strict: [foo: :boolean, boo: :string], aliases: [b: :boo]]
      assert Cliara.parse(argv, opts) == {[foo: true, boo: "-"], ["-"], []}
    end
  end

  describe "aliases" do
    test "supports boolean aliases" do
      opts = [strict: [docs: :boolean], aliases: [d: :docs]]
      assert Cliara.parse(["-d"], opts) == {[docs: true], [], []}
    end

    test "supports non-boolean aliases" do
      opts = [strict: [source: :string], aliases: [s: :source]]
      assert Cliara.parse(["-s", "from_docs/"], opts) == {[source: "from_docs/"], [], []}
    end

    test "supports --key=value aliases" do
      opts = [strict: [source: :string], aliases: [s: :source]]

      assert Cliara.parse(["-s=from_docs/", "other"], opts) ==
               {[source: "from_docs/"], ["other"], []}
    end

    test "parses -ab as -a -b" do
      opts = [strict: [first: :boolean, second: :integer], aliases: [a: :first, b: :second]]
      assert Cliara.parse(["-ab=1"], opts) == {[first: true, second: 1], [], []}
      assert Cliara.parse(["-ab", "1"], opts) == {[first: true, second: 1], [], []}

      opts = [strict: [first: :boolean, second: :boolean], aliases: [a: :first, b: :second]]
      assert Cliara.parse(["-ab"], opts) == {[first: true, second: true], [], []}
      assert Cliara.parse(["-ab3"], opts) == {[first: true], [], [{"-b", "3"}]}
      assert Cliara.parse(["-ab=bar"], opts) == {[first: true], [], [{"-b", "bar"}]}
      assert Cliara.parse(["-ab3=bar"], opts) == {[first: true], [], [{"-b", "3=bar"}]}
      assert Cliara.parse(["-3ab"], opts) == {[], ["-3ab"], []}
    end
  end

  describe "types" do
    test "parses configured booleans" do
      opts = [strict: [docs: :boolean]]
      assert Cliara.parse(["--docs=false"], opts) == {[docs: false], [], []}
      assert Cliara.parse(["--docs=true"], opts) == {[docs: true], [], []}
      assert Cliara.parse(["--docs=other"], opts) == {[], [], [{"--docs", "other"}]}
      assert Cliara.parse(["--docs="], opts) == {[], [], [{"--docs", ""}]}
      assert Cliara.parse(["--docs", "foo"], opts) == {[docs: true], ["foo"], []}
      assert Cliara.parse(["--no-docs", "foo"], opts) == {[docs: false], ["foo"], []}
      assert Cliara.parse(["--no-docs=foo", "bar"], opts) == {[], ["bar"], [{"--no-docs", "foo"}]}
      assert Cliara.parse(["--no-docs=", "bar"], opts) == {[], ["bar"], [{"--no-docs", ""}]}
    end

    test "does not set unparsed booleans" do
      opts = [strict: [docs: :boolean]]
      assert Cliara.parse(["foo"], opts) == {[], ["foo"], []}
    end

    test "keeps options on configured keep" do
      opts = [strict: [require: :keep]]

      assert Cliara.parse(["--require", "foo", "--require", "bar", "baz"], opts) ==
               {[require: "foo", require: "bar"], ["baz"], []}

      assert Cliara.parse(["--require"], opts) ==
               {[], [], [{"--require", nil}]}
    end

    test "parses configured strings" do
      opts = [strict: [value: :string]]

      assert Cliara.parse(["--value", "1", "foo"], opts) == {[value: "1"], ["foo"], []}
      assert Cliara.parse(["--value=1", "foo"], opts) == {[value: "1"], ["foo"], []}
      assert Cliara.parse(["--value"], opts) == {[], [], [{"--value", nil}]}
      assert Cliara.parse(["--no-value"], opts) == {[], [], [{"--no-value", nil}]}
    end

    test "parses configured counters" do
      opts = [strict: [verbose: :count], aliases: [v: :verbose]]
      assert Cliara.parse(["--verbose"], opts) == {[verbose: 1], [], []}
      assert Cliara.parse(["--verbose", "--verbose"], opts) == {[verbose: 2], [], []}

      assert Cliara.parse(["--verbose", "-v", "-v", "--", "bar"], opts) ==
               {[verbose: 3], ["bar"], []}
    end

    test "parses configured integers" do
      opts = [strict: [value: :integer]]

      assert Cliara.parse(["--value", "1", "foo"], opts) == {[value: 1], ["foo"], []}
      assert Cliara.parse(["--value=1", "foo"], opts) == {[value: 1], ["foo"], []}
      assert Cliara.parse(["--value", "WAT", "foo"], opts) == {[], ["foo"], [{"--value", "WAT"}]}
    end

    test "parses configured integers with keep" do
      opts = [strict: [value: [:integer, :keep]]]

      assert Cliara.parse(["--value", "1", "--value", "2", "foo"], opts) ==
               {[value: 1, value: 2], ["foo"], []}

      assert Cliara.parse(["--value=1", "foo", "--value=2", "bar"], opts) ==
               {[value: 1, value: 2], ["foo", "bar"], []}
    end

    test "parses configured floats" do
      opts = [strict: [value: :float]]
      assert Cliara.parse(["--value", "1.0", "foo"], opts) == {[value: 1.0], ["foo"], []}
      assert Cliara.parse(["--value=1.0", "foo"], opts) == {[value: 1.0], ["foo"], []}
      assert Cliara.parse(["--value", "WAT", "foo"], opts) == {[], ["foo"], [{"--value", "WAT"}]}
    end

    test "correctly handles negative integers" do
      opts = [strict: [option: :integer], aliases: [o: :option]]
      assert Cliara.parse(["arg1", "-o43"], opts) == {[option: 43], ["arg1"], []}
      assert Cliara.parse(["arg1", "-o", "-43"], opts) == {[option: -43], ["arg1"], []}
      assert Cliara.parse(["arg1", "--option=-43"], opts) == {[option: -43], ["arg1"], []}
      assert Cliara.parse(["arg1", "--option", "-43"], opts) == {[option: -43], ["arg1"], []}
    end

    test "correctly handles negative floating-point numbers" do
      opts = [strict: [option: :float], aliases: [o: :option]]
      assert Cliara.parse(["arg1", "-o43.2"], opts) == {[option: 43.2], ["arg1"], []}
      assert Cliara.parse(["arg1", "-o", "-43.2"], opts) == {[option: -43.2], ["arg1"], []}
      assert Cliara.parse(["arg1", "--option=-43.2"], opts) == {[option: -43.2], ["arg1"], []}
      assert Cliara.parse(["arg1", "--option", "-43.2"], opts) == {[option: -43.2], ["arg1"], []}
    end
  end

  # describe "next" do
  #   test "with strict good options" do
  #     config = [strict: [str: :string, int: :integer, bool: :boolean]]
  #     assert Cliara.next(["--str", "hello", "..."], config) == {:ok, :str, "hello", ["..."]}
  #     assert Cliara.next(["--int=13", "..."], config) == {:ok, :int, 13, ["..."]}
  #     assert Cliara.next(["--bool=false", "..."], config) == {:ok, :bool, false, ["..."]}
  #     assert Cliara.next(["--no-bool", "..."], config) == {:ok, :bool, false, ["..."]}
  #     assert Cliara.next(["--bool", "..."], config) == {:ok, :bool, true, ["..."]}
  #     assert Cliara.next(["..."], config) == {:error, ["..."]}
  #   end

  #   test "with strict unknown options" do
  #     config = [strict: [bool: :boolean]]

  #     assert Cliara.next(["--str", "13", "..."], config) ==
  #              {:undefined, "--str", nil, ["13", "..."]}

  #     assert Cliara.next(["--int=hello", "..."], config) ==
  #              {:undefined, "--int", "hello", ["..."]}

  #     assert Cliara.next(["-no-bool=other", "..."], config) ==
  #              {:undefined, "-no-bool", "other", ["..."]}
  #   end

  #   test "with strict bad type" do
  #     config = [strict: [str: :string, int: :integer, bool: :boolean]]
  #     assert Cliara.next(["--str", "13", "..."], config) == {:ok, :str, "13", ["..."]}

  #     assert Cliara.next(["--int=hello", "..."], config) ==
  #              {:invalid, "--int", "hello", ["..."]}

  #     assert Cliara.next(["--int", "hello", "..."], config) ==
  #              {:invalid, "--int", "hello", ["..."]}

  #     assert Cliara.next(["--bool=other", "..."], config) ==
  #              {:invalid, "--bool", "other", ["..."]}
  #   end

  #   test "with strict missing value" do
  #     config = [strict: [str: :string, int: :integer, bool: :boolean]]
  #     assert Cliara.next(["--str"], config) == {:invalid, "--str", nil, []}
  #     assert Cliara.next(["--int"], config) == {:invalid, "--int", nil, []}
  #     assert Cliara.next(["--bool=", "..."], config) == {:invalid, "--bool", "", ["..."]}

  #     assert Cliara.next(["--no-bool=", "..."], config) ==
  #              {:invalid, "--no-bool", "", ["..."]}
  #   end
  # end
end

defmodule OptionsParserDeprecationsTest do
  use ExUnit.Case, async: true

  @warning ~r[not passing the :strict option to Cliara is deprecated]

  def assert_deprecated(fun) do
    assert ExUnit.CaptureIO.capture_io(:stderr, fun) =~ @warning
  end

  test "parses boolean option" do
    assert_deprecated(fn ->
      assert Cliara.parse(["--docs"]) == {[docs: true], [], []}
    end)
  end

  test "parses more than one boolean option" do
    assert_deprecated(fn ->
      assert Cliara.parse(["--docs", "--compile"]) == {[docs: true, compile: true], [], []}
    end)
  end

  test "parses more than one boolean options as the alias" do
    assert_deprecated(fn ->
      assert Cliara.parse(["-d", "--compile"], aliases: [d: :docs]) ==
               {[docs: true, compile: true], [], []}
    end)
  end

  test "parses --key value option" do
    assert_deprecated(fn ->
      assert Cliara.parse(["--source", "form_docs/"]) == {[source: "form_docs/"], [], []}
    end)
  end

  test "does not interpret undefined options with value as boolean" do
    assert_deprecated(fn ->
      assert Cliara.parse(["--no-bool"]) == {[no_bool: true], [], []}
    end)

    assert_deprecated(fn ->
      assert Cliara.parse(["--no-bool=...", "other"]) == {[no_bool: "..."], ["other"], []}
    end)
  end

  test "parses -ab as -a -b" do
    assert_deprecated(fn ->
      assert Cliara.parse(["-ab"], aliases: [a: :first, b: :second]) ==
               {[first: true, second: true], [], []}
    end)
  end

  test "parses mixed options" do
    argv = ["--source", "from_docs/", "--compile", "-x"]

    assert_deprecated(fn ->
      assert Cliara.parse(argv, aliases: [x: :x]) ==
               {[source: "from_docs/", compile: true, x: true], [], []}
    end)
  end

  test "parses more than one key-value pair options" do
    assert_deprecated(fn ->
      assert Cliara.parse(["--source", "from_docs/", "--docs", "show"]) ==
               {[source: "from_docs/", docs: "show"], [], []}
    end)
  end

  # test "multi-word option" do
  #   assert_deprecated(fn ->
  #     assert Cliara.next(["--hello-world"], []) == {:ok, :hello_world, true, []}
  #   end)

  #   assert_deprecated(fn ->
  #     assert Cliara.next(["--no-hello-world"], []) == {:ok, :no_hello_world, true, []}
  #   end)

  #   assert_deprecated(fn ->
  #     assert Cliara.next(["--hello_world"], []) == {:undefined, "--hello_world", nil, []}
  #   end)

  #   assert_deprecated(fn ->
  #     assert Cliara.next(["--no-hello_world"], []) ==
  #              {:undefined, "--no-hello_world", nil, []}
  #   end)
  # end
end
