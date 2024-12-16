defmodule CLIX.FeedbackTest do
  use ExUnit.Case, async: true

  alias CLIX.Feedback

  doctest Feedback

  describe "help/_" do
    setup do
      spec =
        CLIX.Spec.new(
          {:calc,
           %{
             summary: "A simple calculator.",
             description: "This calculator is for demostrating the funtionality of `CLIX.Feedback`.",
             cmds: [
               add: %{
                 summary: "Add numbers.",
                 help: "add numbers",
                 args: [
                   numbers: %{type: :integer, nargs: :+, help: "the numbers"}
                 ]
               },
               minus: %{
                 summary: "Minus two number.",
                 help: "minus two number",
                 args: [
                   left: %{type: :integer, help: "the left number"},
                   right: %{type: :integer, help: "the right number"}
                 ]
               }
             ],
             opts: [
               mode: %{
                 short: "m",
                 long: "mode",
                 help: "specify the mode. Available modes: simple, science"
               },
               debug: %{
                 short: "d",
                 long: "debug",
                 type: :boolean,
                 help: "enable debug logging"
               },
               verbose: %{
                 short: "v",
                 long: "verbose",
                 type: :boolean,
                 action: :count,
                 help: "specify verbose level"
               }
             ],
             epilogue: """
             For more help on how to use CLIX, head to https://hex.pm/packages/clix
             """
           }}
        )

      [spec: spec]
    end

    test "help/1", %{spec: spec} do
      assert Feedback.help(spec) ==
               """
               A simple calculator.

               This calculator is for demostrating the funtionality of `CLIX.Feedback`.

               Usage:
                 calc <COMMAND> [OPTIONS]

               Commands:
                 add    add numbers
                 minus  minus two number

               Options:
                 -m, --mode <MODE>  specify the mode. Available modes: simple, science
                 -d, --debug        enable debug logging
                 -v, --verbose...   specify verbose level

               For more help on how to use CLIX, head to https://hex.pm/packages/clix\
               """

      assert Feedback.help(spec, [:add]) == """
             Add numbers.

             Usage:
               calc add [OPTIONS] <NUMBERS>...

             Arguments:
               <NUMBERS>...  the numbers

             Options:
               -m, --mode <MODE>  specify the mode. Available modes: simple, science
               -d, --debug        enable debug logging
               -v, --verbose...   specify verbose level\
             """

      assert Feedback.help(spec, [:minus]) == """
             Minus two number.

             Usage:
               calc minus [OPTIONS] <LEFT> <RIGHT>

             Arguments:
               <LEFT>   the left number
               <RIGHT>  the right number

             Options:
               -m, --mode <MODE>  specify the mode. Available modes: simple, science
               -d, --debug        enable debug logging
               -v, --verbose...   specify verbose level\
             """
    end
  end

  describe "format_error/1" do
    test "unknown arg" do
      assert Feedback.format_error({:unknown_arg, "joe"}) == "unrecognized argument 'joe'"
    end

    test "missing arg" do
      assert Feedback.format_error({:missing_arg, %{message: nil, type: :string, value: nil, nargs: nil, value_name: "NAME"}}) ==
               "missing value for argument '<NAME>'"
    end

    test "invalid arg" do
      assert Feedback.format_error({:invalid_arg, %{message: nil, type: :string, value: "joe", nargs: nil, value_name: "NAME"}}) ==
               "invalid value 'joe' for argument '<NAME>'"

      assert Feedback.format_error({:invalid_arg, %{message: nil, type: :string, value: "joe", nargs: :"?", value_name: "NAME"}}) ==
               "invalid value 'joe' for argument '[NAME]'"

      assert Feedback.format_error({:invalid_arg, %{message: nil, type: :string, value: "joe", nargs: :*, value_name: "NAME"}}) ==
               "invalid value 'joe' for argument '[NAME]...'"

      assert Feedback.format_error({:invalid_arg, %{message: nil, type: :string, value: "joe", nargs: :+, value_name: "NAME"}}) ==
               "invalid value 'joe' for argument '<NAME>...'"

      assert Feedback.format_error({:invalid_arg, %{message: "invalid name", type: :string, value: "joe", nargs: :+, value_name: "NAME"}}) ==
               "invalid value 'joe' for argument '<NAME>...': invalid name"
    end

    test "unknown opt" do
      assert Feedback.format_error({:unknown_opt, "--unknown"}) ==
               "unknown option '--unknown'"
    end

    test "missing opt value" do
      assert Feedback.format_error({
               :missing_opt,
               %{message: nil, type: :string, value: nil, action: :store, value_name: "NAME", prefixed_name: "--name"}
             }) == "missing value for option '--name <NAME>'"
    end

    test "invalid opt value" do
      assert Feedback.format_error({
               :invalid_opt,
               %{message: nil, type: :string, value: "bad_name", action: :store, value_name: "NAME", prefixed_name: "--name"}
             }) == "invalid value 'bad_name' for option '--name <NAME>'"

      assert Feedback.format_error({
               :invalid_opt,
               %{message: "invalid format", type: :string, value: "bad_name", action: :store, value_name: "NAME", prefixed_name: "--name"}
             }) == "invalid value 'bad_name' for option '--name <NAME>': invalid format"
    end
  end
end
