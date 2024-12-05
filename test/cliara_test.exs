defmodule CLIXTest do
  use ExUnit.Case, async: true

  doctest CLIX

  describe "syntax" do
    test "parses grouped flags" do
      opts = [
        strict: [debug: :boolean, verbose: :boolean, help: :boolean, src: :string, num: :integer],
        aliases: [x: :debug, v: :verbose, h: :help, s: :src, n: :num]
      ]

      assert CLIX.parse(["-xh"], opts) == {[debug: true, help: true], [], []}
      assert CLIX.parse(["-dh"], opts) == {[help: true], [], [{"-d", nil}]}

      assert CLIX.parse(["-xsval"], opts) ==
               {[debug: true, verbose: true], [], [{"-s", nil}, {"-a", nil}, {"-l", nil}]}

      assert CLIX.parse(["-xs=val"], opts) == {[debug: true, src: "val"], [], []}
      # assert CLIX.parse(["-xn=1"], opts) == {[debug: true, num: 1], [], []}
      # assert CLIX.parse(["-xn", "1"], opts) == {[debug: true, num: 1], [], []}

      assert CLIX.parse(["-xn1"], opts) == {[debug: true, num: 1], [], []}
      assert CLIX.parse(["-xn=1"], opts) == {[debug: true, num: 1], [], []}
      assert CLIX.parse(["-xn", "1"], opts) == {[debug: true, num: 1], [], []}
    end
  end

  test "parses complicated line" do
    opts = [
      strict: [src: :string, dst: :string, debug: :boolean, verbose: :boolean, help: :boolean],
      aliases: [s: :src, d: :dst, x: :debug, v: :verbose, h: :help]
    ]

    assert CLIX.parse(
             ["--src", "src-value", "--dst", "dst-value", "--debug", "--no-verbose", "-h"],
             opts
           ) ==
             {[
                src: "src-value",
                dst: "dst-value",
                debug: true,
                verbose: false,
                help: true
              ], [], []}

    assert CLIX.parse(
             ["--src", "src-value", "--dst", "dst-value", "-xvh"],
             opts
           ) ==
             {[
                src: "src-value",
                dst: "dst-value",
                debug: true,
                verbose: true,
                help: true
              ], [], []}
  end

  test "parses overrides options by default" do
    assert CLIX.parse(
             ["--require", "foo", "--require", "bar", "baz"],
             strict: [require: :string]
           ) == {[require: "bar"], ["baz"], []}
  end

  # TODO

  test "collects multiple invalid options" do
    opts = [strict: [bad: :integer]]

    assert CLIX.parse(["--bad", "opt", "foo", "-o", "bad", "bar"], opts) ==
             {[], ["foo", "bad", "bar"], [{"--bad", "opt"}, {"-o", nil}]}
  end

  test "parse/2 raises an exception on invalid switch types/modifiers" do
    assert_raise ArgumentError, "invalid switch types/modifiers: :bad", fn ->
      CLIX.parse(["--elixir"], strict: [ex: :bad])
    end

    assert_raise ArgumentError, "invalid switch types/modifiers: :bad, :bad_modifier", fn ->
      CLIX.parse(["--elixir"], strict: [ex: [:bad, :bad_modifier]])
    end
  end

  test "parse!/2 raises an exception for an unknown option" do
    msg = "1 error found!\n--doc-bar : Unknown option. Did you mean --docs-bar?"

    assert_raise CLIX.ParseError, msg, fn ->
      argv = ["--source", "from_docs/", "--doc-bar", "show"]
      CLIX.parse!(argv, strict: [source: :string, docs_bar: :string])
    end

    assert_raise CLIX.ParseError, "1 error found!\n--foo : Unknown option", fn ->
      argv = ["--source", "from_docs/", "--foo", "show"]
      CLIX.parse!(argv, strict: [source: :string, docs: :string])
    end
  end

  test "parse!/2 raises an exception when an option is of the wrong type" do
    assert_raise CLIX.ParseError, fn ->
      argv = ["--bad", "opt", "foo", "-o", "bad", "bar"]
      CLIX.parse!(argv, strict: [bad: :integer])
    end
  end

  describe "types - todo" do
    test "keeps options on configured keep" do
      opts = [strict: [require: :keep]]

      assert CLIX.parse(["--require", "foo", "--require", "bar", "baz"], opts) ==
               {[require: "foo", require: "bar"], ["baz"], []}

      assert CLIX.parse(["--require"], opts) ==
               {[], [], [{"--require", nil}]}
    end

    test "parses configured counters" do
      opts = [strict: [verbose: :count], aliases: [v: :verbose]]
      assert CLIX.parse(["--verbose"], opts) == {[verbose: 1], [], []}
      assert CLIX.parse(["--verbose", "--verbose"], opts) == {[verbose: 2], [], []}

      assert CLIX.parse(["--verbose", "-v", "-v", "--", "bar"], opts) ==
               {[verbose: 3], ["bar"], []}
    end
  end
end
