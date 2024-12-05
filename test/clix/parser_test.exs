defmodule CLIX.ParserTest do
  use ExUnit.Case, async: true

  alias CLIX.Spec
  alias CLIX.Parser

  describe "args - :type attr" do
    test "default to :string" do
      spec = new_spec(%{args: [arg1: %{}]})
      assert Parser.parse(spec, ["a"]) == {%{arg1: "a"}, %{}, []}
    end

    test ":string" do
      spec = new_spec(%{args: [arg1: %{type: :string}]})
      assert Parser.parse(spec, ["a"]) == {%{arg1: "a"}, %{}, []}
    end

    test ":boolean" do
      spec = new_spec(%{args: [arg1: %{type: :boolean}]})
      assert Parser.parse(spec, ["true"]) == {%{arg1: true}, %{}, []}
      assert Parser.parse(spec, ["false"]) == {%{arg1: false}, %{}, []}
      assert Parser.parse(spec, ["other"]) == {%{}, %{}, [{:invalid_arg, :arg1, "other"}]}
    end

    test ":integer" do
      spec = new_spec(%{args: [arg1: %{type: :integer}]})
      assert Parser.parse(spec, ["0"]) == {%{arg1: 0}, %{}, []}
      assert Parser.parse(spec, ["1"]) == {%{arg1: 1}, %{}, []}
      assert Parser.parse(spec, ["-1"]) == {%{arg1: -1}, %{}, []}
      assert Parser.parse(spec, ["other"]) == {%{}, %{}, [{:invalid_arg, :arg1, "other"}]}
    end

    test ":float" do
      spec = new_spec(%{args: [arg1: %{type: :float}]})
      assert Parser.parse(spec, ["0.0"]) == {%{arg1: 0}, %{}, []}
      assert Parser.parse(spec, ["1.1"]) == {%{arg1: 1.1}, %{}, []}
      assert Parser.parse(spec, ["-1.1"]) == {%{arg1: -1.1}, %{}, []}
      assert Parser.parse(spec, ["other"]) == {%{}, %{}, [{:invalid_arg, :arg1, "other"}]}
    end
  end

  describe "args - :nargs attr" do
    test "nil" do
      spec = new_spec(%{args: [arg1: %{nargs: nil}]})

      assert Parser.parse(spec, []) == {%{}, %{}, [{:missing_arg, :arg1}]}
      assert Parser.parse(spec, ["a"]) == {%{arg1: "a"}, %{}, []}
      assert Parser.parse(spec, ["a", "b"]) == {%{arg1: "a"}, %{}, [{:unknown_arg, "b"}]}
    end

    test inspect(:"?") do
      spec = new_spec(%{args: [arg1: %{nargs: :"?"}]})

      assert Parser.parse(spec, []) == {%{arg1: nil}, %{}, []}
      assert Parser.parse(spec, ["a"]) == {%{arg1: "a"}, %{}, []}
      assert Parser.parse(spec, ["a", "b"]) == {%{arg1: "a"}, %{}, [{:unknown_arg, "b"}]}
    end

    test ":*" do
      spec = new_spec(%{args: [arg1: %{nargs: :*}]})

      assert Parser.parse(spec, []) == {%{arg1: []}, %{}, []}
      assert Parser.parse(spec, ["a"]) == {%{arg1: ["a"]}, %{}, []}
      assert Parser.parse(spec, ["a", "b"]) == {%{arg1: ["a", "b"]}, %{}, []}
    end

    test ":+" do
      spec = new_spec(%{args: [arg1: %{nargs: :+}]})

      assert Parser.parse(spec, []) == {%{}, %{}, [{:missing_arg, :arg1}]}
      assert Parser.parse(spec, ["a", "b"]) == {%{arg1: ["a", "b"]}, %{}, []}
    end

    test "example (cp) - <SRC>... <DST>" do
      spec =
        new_spec(%{
          args: [
            src: %{nargs: :+},
            dst: %{}
          ]
        })

      assert Parser.parse(spec, []) ==
               {%{}, %{}, [{:missing_arg, :src}, {:missing_arg, :dst}]}

      assert Parser.parse(spec, ["src1"]) ==
               {%{src: ["src1"]}, %{}, [{:missing_arg, :dst}]}

      assert Parser.parse(spec, ["src1", "dst"]) ==
               {%{src: ["src1"], dst: "dst"}, %{}, []}

      assert Parser.parse(spec, ["src1", "src2", "dst"]) ==
               {%{src: ["src1", "src2"], dst: "dst"}, %{}, []}
    end

    test "example (httpie) - [METHOD] <URL> [REQUEST_ITEM]" do
      spec =
        new_spec(%{
          args: [
            method: %{nargs: :"?", default: "GET"},
            url: %{},
            request_items: %{nargs: :*}
          ]
        })

      assert Parser.parse(spec, ["https://example.com"]) ==
               {%{
                  method: "GET",
                  url: "https://example.com",
                  request_items: []
                }, %{}, []}

      assert Parser.parse(spec, ["POST", "https://example.com"]) ==
               {%{
                  method: "POST",
                  url: "https://example.com",
                  request_items: []
                }, %{}, []}

      assert Parser.parse(spec, [
               "POST",
               "https://example.com",
               "name=Joe",
               "email=Joe@example.org"
             ]) ==
               {%{
                  method: "POST",
                  url: "https://example.com",
                  request_items: ["name=Joe", "email=Joe@example.org"]
                }, %{}, []}
    end
  end

  describe "args - :default attr" do
    test "for nargs #{inspect(nil)}" do
      # no test for it, because it means the argument is required
    end

    test "for :nargs - #{inspect(:"?")}" do
      spec = new_spec(%{args: [arg1: %{nargs: :"?", default: "x"}]})
      assert Parser.parse(spec, []) == {%{arg1: "x"}, %{}, []}
      assert Parser.parse(spec, ["a"]) == {%{arg1: "a"}, %{}, []}
    end

    test "for :nargs - #{inspect(:*)}" do
      spec = new_spec(%{args: [arg1: %{nargs: :*, default: ["x"]}]})
      assert Parser.parse(spec, []) == {%{arg1: ["x"]}, %{}, []}
      assert Parser.parse(spec, ["a"]) == {%{arg1: ["a"]}, %{}, []}
    end

    test "for :nargs - #{inspect(:+)}" do
      # no test for it, because it means the argument is required
    end

    test "isn't checked to match the :type attr" do
      spec = new_spec(%{args: [arg1: %{type: :boolean, nargs: :"?", default: "A"}]})
      assert Parser.parse(spec, []) == {%{arg1: "A"}, %{}, []}
    end
  end

  describe "args - errors" do
    test "generate {:unknown_arg, arg} error where there're remaining arguments" do
      spec = new_spec(%{})

      assert Parser.parse(spec, ["a", "b"]) ==
               {%{}, %{}, [{:unknown_arg, "a"}, {:unknown_arg, "b"}]}
    end

    test "generate {:missing_arg, key} error when required args are missing" do
      spec = new_spec(%{args: [arg1: %{}]})
      assert Parser.parse(spec, []) == {%{}, %{}, [{:missing_arg, :arg1}]}
    end

    test "generate {:invalid_arg, key, arg} error" do
      spec = new_spec(%{args: [arg1: %{type: :integer}]})

      assert Parser.parse(spec, ["not-integer"]) ==
               {%{}, %{}, [{:invalid_arg, :arg1, "not-integer"}]}
    end
  end

  describe "opts - syntax" do
    test "--flag" do
      spec = new_spec(%{opts: [flag: %{long: "flag", type: :boolean}]})
      assert Parser.parse(spec, ["--flag"]) == {%{}, %{flag: true}, []}
    end

    test "--opt <value>" do
      spec = new_spec(%{opts: [opt: %{long: "opt", type: :string}]})
      assert Parser.parse(spec, ["--opt", "value"]) == {%{}, %{opt: "value"}, []}
    end

    test "--opt=<value>" do
      spec = new_spec(%{opts: [opt: %{long: "opt", type: :string}]})
      assert Parser.parse(spec, ["--opt=value"]) == {%{}, %{opt: "value"}, []}
    end

    test "-f" do
      spec = new_spec(%{opts: [flag: %{short: "f", type: :boolean}]})
      assert Parser.parse(spec, ["-f"]) == {%{}, %{flag: true}, []}
    end

    test "-o <value>" do
      spec = new_spec(%{opts: [opt: %{short: "o", type: :string}]})
      assert Parser.parse(spec, ["-o", "value"]) == {%{}, %{opt: "value"}, []}
    end

    test "-o=<value>" do
      spec = new_spec(%{opts: [opt: %{short: "o", type: :string}]})
      assert Parser.parse(spec, ["-o=value"]) == {%{}, %{opt: "value"}, []}
    end

    # TODO
    # test "-o<value>" do
    #   spec = new_spec(%{opts: [opt: %{short: "o", type: :string}]})
    #   assert Parser.parse(spec, ["-ovalue"]) == {%{}, %{opt: "value"}, []}
    # end

    # TODO
    # test "-abc" do
    #   spec =
    #     new_spec(%{
    #       opts: [
    #         flag_a: %{short: "a", type: :boolean},
    #         flag_b: %{short: "b", type: :boolean},
    #         flag_b: %{short: "c", type: :boolean}
    #       ]
    #     })

    #   assert Parser.parse(spec, ["-abc"]) ==
    #            {%{}, %{flag_a: true, flag_b: true, flag_c: true}, []}
    # end

    # TODO
    # test "-abco<value>" do
    #   spec =
    #     new_spec(%{
    #       opts: [
    #         flag_a: %{short: "a", type: :boolean},
    #         flag_b: %{short: "b", type: :boolean},
    #         flag_b: %{short: "c", type: :boolean},
    #         opt: %{short: "o", type: :string}
    #       ]
    #     })

    #   assert Parser.parse(spec, ["-abcovalue"]) ==
    #            {%{}, %{flag_a: true, flag_b: true, flag_c: true, opt: "value"}, []}
    # end
  end

  describe "opts - syntax - handle '-' carefully" do
    test "there's no negative number like option" do
      spec = new_spec(%{args: [arg: %{nargs: :"?"}], opts: [opt: %{short: "o"}]})
      assert Parser.parse(spec, ["-o", "-1"]) == {%{arg: nil}, %{opt: "-1"}, []}
      assert Parser.parse(spec, ["-o", "-1", "-1"]) == {%{arg: "-1"}, %{opt: "-1"}, []}
      assert Parser.parse(spec, ["-o", "-1.1"]) == {%{arg: nil}, %{opt: "-1.1"}, []}
      assert Parser.parse(spec, ["-o", "-1.1", "-1.1"]) == {%{arg: "-1.1"}, %{opt: "-1.1"}, []}
    end

    test "there's negative number like option" do
      spec = new_spec(%{args: [arg: %{nargs: :"?"}], opts: [opt: %{short: "1"}]})

      assert Parser.parse(spec, ["-5"]) == {%{arg: "-5"}, %{}, []}

      assert Parser.parse(spec, ["-1", "X"]) == {%{arg: nil}, %{opt: "X"}, []}

      assert Parser.parse(spec, ["-1", "X", "-1"]) ==
               {%{arg: nil}, %{opt: "X"}, [{:missing_opt_value, "-1"}]}

      # TODO
      # assert Parser.parse(spec, ["-1", "-1"]) ==
      #          {%{}, %{}, [{:missing_opt_value, "-1"}, {:missing_opt_value, "-1"}]}
    end
  end

  describe "opts - :short, :long attr" do
    test ":short" do
      spec = new_spec(%{opts: [opt: %{short: "o"}]})
      assert Parser.parse(spec, ["-o", "value"]) == {%{}, %{opt: "value"}, []}
    end

    test ":long" do
      spec = new_spec(%{opts: [opt: %{long: "opt"}]})
      assert Parser.parse(spec, ["--opt", "value"]) == {%{}, %{opt: "value"}, []}
    end

    test ":short and :long" do
      spec = new_spec(%{opts: [opt: %{short: "o", long: "opt"}]})
      assert Parser.parse(spec, ["-o", "value"]) == {%{}, %{opt: "value"}, []}
      assert Parser.parse(spec, ["--opt", "value"]) == {%{}, %{opt: "value"}, []}
    end
  end

  describe "opts - :type attr" do
    test "default to :string" do
      spec = new_spec(%{opts: [opt: %{short: "o", long: "opt"}]})
      assert Parser.parse(spec, ["-o", "value"]) == {%{}, %{opt: "value"}, []}
    end

    test ":string" do
      spec = new_spec(%{opts: [opt: %{short: "o", long: "opt", type: :string}]})

      assert Parser.parse(spec, ["--opt", "value"]) == {%{}, %{opt: "value"}, []}
      assert Parser.parse(spec, ["--opt=value"]) == {%{}, %{opt: "value"}, []}

      assert Parser.parse(spec, ["--opt="]) ==
               {%{}, %{}, [{:missing_opt_value, "--opt"}]}

      assert Parser.parse(spec, ["--no-opt="]) ==
               {%{}, %{}, [{:unknown_opt, "--no-opt"}]}
    end

    test ":boolean" do
      spec = new_spec(%{opts: [opt: %{short: "o", long: "opt", type: :boolean}]})

      assert Parser.parse(spec, ["--opt"]) ==
               {%{}, %{opt: true}, []}

      assert Parser.parse(spec, ["--opt", "true"]) ==
               {%{}, %{opt: true}, [{:unknown_arg, "true"}]}

      assert Parser.parse(spec, ["--opt", "false"]) ==
               {%{}, %{opt: true}, [{:unknown_arg, "false"}]}

      assert Parser.parse(spec, ["--opt", "other"]) ==
               {%{}, %{opt: true}, [{:unknown_arg, "other"}]}

      assert Parser.parse(spec, ["--opt="]) ==
               {%{}, %{opt: true}, []}

      assert Parser.parse(spec, ["--opt=true"]) ==
               {%{}, %{opt: true}, []}

      assert Parser.parse(spec, ["--opt=false"]) ==
               {%{}, %{opt: false}, []}

      assert Parser.parse(spec, ["--opt=other"]) ==
               {%{}, %{}, [{:invalid_opt_value, "--opt", "other"}]}

      assert Parser.parse(spec, ["--no-opt"]) ==
               {%{}, %{opt: false}, []}

      assert Parser.parse(spec, ["--no-opt", "true"]) ==
               {%{}, %{opt: false}, [{:unknown_arg, "true"}]}

      assert Parser.parse(spec, ["--no-opt", "false"]) ==
               {%{}, %{opt: false}, [{:unknown_arg, "false"}]}

      assert Parser.parse(spec, ["--no-opt", "other"]) ==
               {%{}, %{opt: false}, [{:unknown_arg, "other"}]}

      assert Parser.parse(spec, ["--no-opt="]) ==
               {%{}, %{opt: false}, []}

      assert Parser.parse(spec, ["--no-opt=true"]) ==
               {%{}, %{}, [{:invalid_opt_value, "--no-opt", "true"}]}

      assert Parser.parse(spec, ["--no-opt=false"]) ==
               {%{}, %{}, [{:invalid_opt_value, "--no-opt", "false"}]}

      assert Parser.parse(spec, ["--no-opt=other"]) ==
               {%{}, %{}, [{:invalid_opt_value, "--no-opt", "other"}]}
    end

    test ":integer" do
      spec = new_spec(%{opts: [opt: %{short: "o", long: "opt", type: :integer}]})

      assert Parser.parse(spec, ["--opt"]) ==
               {%{}, %{}, [{:missing_opt_value, "--opt"}]}

      assert Parser.parse(spec, ["--opt", "30"]) ==
               {%{}, %{opt: 30}, []}

      assert Parser.parse(spec, ["--opt", "-30"]) ==
               {%{}, %{opt: -30}, []}

      assert Parser.parse(spec, ["--opt", "other"]) ==
               {%{}, %{}, [{:invalid_opt_value, "--opt", "other"}]}

      assert Parser.parse(spec, ["--opt="]) ==
               {%{}, %{}, [{:missing_opt_value, "--opt"}]}

      assert Parser.parse(spec, ["--opt=30"]) ==
               {%{}, %{opt: 30}, []}

      assert Parser.parse(spec, ["--opt=-30"]) ==
               {%{}, %{opt: -30}, []}

      assert Parser.parse(spec, ["--opt=other"]) ==
               {%{}, %{}, [{:invalid_opt_value, "--opt", "other"}]}

      assert Parser.parse(spec, ["--no-opt="]) ==
               {%{}, %{}, [{:unknown_opt, "--no-opt"}]}

      assert Parser.parse(spec, ["-o"]) ==
               {%{}, %{}, [{:missing_opt_value, "-o"}]}

      assert Parser.parse(spec, ["-o", "30"]) ==
               {%{}, %{opt: 30}, []}

      assert Parser.parse(spec, ["-o", "-30"]) ==
               {%{}, %{opt: -30}, []}

      assert Parser.parse(spec, ["-o", "other"]) ==
               {%{}, %{}, [{:invalid_opt_value, "-o", "other"}]}

      # TODO
      # assert Parser.parse(spec, ["-o30"]) ==
      #          {%{}, %{opt: 30}, []}

      # TODO
      # assert Parser.parse(spec, ["-o-30"]) ==
      #          {%{}, %{opt: -30}, []}
    end

    test ":float" do
      # TODO: copy the test of :integer, and modify it.
    end
  end

  describe "opts - :action attr" do
    test "default to :store" do
      spec = new_spec(%{opts: [opt: %{short: "o"}]})
      assert Parser.parse(spec, ["-o", "value1", "-o", "value2"]) == {%{}, %{opt: "value2"}, []}

      spec = new_spec(%{opts: [opt: %{short: "o", type: :boolean}]})
      assert Parser.parse(spec, ["-o", "-o"]) == {%{}, %{opt: true}, []}

      spec = new_spec(%{opts: [opt: %{short: "o", long: "opt", type: :boolean}]})
      assert Parser.parse(spec, ["-o", "--no-opt"]) == {%{}, %{opt: false}, []}
    end

    test ":store" do
      spec = new_spec(%{opts: [opt: %{short: "o", action: :store}]})
      assert Parser.parse(spec, ["-o", "value1", "-o", "value2"]) == {%{}, %{opt: "value2"}, []}

      spec = new_spec(%{opts: [opt: %{short: "o", type: :boolean, action: :store}]})
      assert Parser.parse(spec, ["-o", "-o"]) == {%{}, %{opt: true}, []}

      spec = new_spec(%{opts: [opt: %{short: "o", long: "opt", type: :boolean, action: :store}]})
      assert Parser.parse(spec, ["-o", "--no-opt"]) == {%{}, %{opt: false}, []}
    end

    test ":count" do
      spec = new_spec(%{opts: [opt: %{short: "o", action: :count}]})
      assert Parser.parse(spec, ["-o", "value", "-o", "value"]) == {%{}, %{opt: 2}, []}

      spec = new_spec(%{opts: [opt: %{short: "o", type: :boolean, action: :count}]})
      assert Parser.parse(spec, ["-o", "-o"]) == {%{}, %{opt: 2}, []}
    end

    test ":append" do
      spec = new_spec(%{opts: [opt: %{short: "o", action: :append}]})

      assert Parser.parse(spec, ["-o", "value", "-o", "value"]) ==
               {%{}, %{opt: ["value", "value"]}, []}

      spec = new_spec(%{opts: [opt: %{short: "o", type: :boolean, action: :append}]})

      assert Parser.parse(spec, ["-o", "-o"]) ==
               {%{}, %{opt: [true, true]}, []}
    end
  end

  describe "opts - :default attr" do
  end

  test "single '-' is handled as a normal argument" do
    spec =
      new_spec(%{
        args: [
          all: %{nargs: :*}
        ],
        opts: [
          input: %{short: "i"}
        ]
      })

    assert Parser.parse(spec, ["-", "-i", "-"]) == {%{all: ["-"]}, %{input: "-"}, []}
  end

  test "single '--' is handled as option terminator" do
    spec =
      new_spec(%{
        args: [
          all: %{nargs: :*}
        ],
        opts: [
          debug: %{short: "d", type: :boolean},
          single: %{short: "1", type: :boolean}
        ]
      })

    assert Parser.parse(spec, ["a1", "a2", "-d"]) ==
             {%{all: ["a1", "a2"]}, %{debug: true}, []}

    assert Parser.parse(spec, ["a1", "a2", "--", "-d"]) ==
             {%{all: ["a1", "a2", "-d"]}, %{}, []}

    assert Parser.parse(spec, ["a1", "a2", "-1"]) ==
             {%{all: ["a1", "a2"]}, %{single: true}, []}

    assert Parser.parse(spec, ["a1", "a2", "--", "-1"]) ==
             {%{all: ["a1", "a2", "-1"]}, %{}, []}
  end

  defp new_spec(cmd_spec), do: Spec.new({:example, cmd_spec})
end
