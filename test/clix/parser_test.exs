defmodule CLIX.ParserTest do
  use ExUnit.Case, async: true

  alias CLIX.Spec
  alias CLIX.Parser

  doctest Parser

  describe "args - :type attr" do
    test "default to :string" do
      spec = new_spec(%{args: [arg: %{}]})
      assert Parser.parse(spec, ["a"]) == {[], %{arg: "a"}, %{}, []}
    end

    test ":string" do
      spec = new_spec(%{args: [arg: %{type: :string}]})
      assert Parser.parse(spec, ["a"]) == {[], %{arg: "a"}, %{}, []}
    end

    test ":boolean" do
      spec = new_spec(%{args: [arg: %{type: :boolean}]})
      assert Parser.parse(spec, ["true"]) == {[], %{arg: true}, %{}, []}
      assert Parser.parse(spec, ["false"]) == {[], %{arg: false}, %{}, []}

      assert Parser.parse(spec, ["other"]) ==
               {[], %{}, %{},
                [
                  {:invalid_arg, %{message: nil, type: :boolean, value: "other", nargs: nil, value_name: "ARG"}},
                  {:missing_arg, %{message: nil, type: :boolean, value: nil, nargs: nil, value_name: "ARG"}}
                ]}
    end

    test ":integer" do
      spec = new_spec(%{args: [arg: %{type: :integer}]})
      assert Parser.parse(spec, ["0"]) == {[], %{arg: 0}, %{}, []}
      assert Parser.parse(spec, ["1"]) == {[], %{arg: 1}, %{}, []}

      assert Parser.parse(spec, ["-1"]) ==
               {[], %{}, %{},
                [{:unknown_opt, "-1"}, {:missing_arg, %{message: nil, type: :integer, value: nil, nargs: nil, value_name: "ARG"}}]}

      assert Parser.parse(spec, ["other"]) ==
               {[], %{}, %{},
                [
                  {:invalid_arg, %{message: nil, type: :integer, value: "other", nargs: nil, value_name: "ARG"}},
                  {:missing_arg, %{message: nil, type: :integer, value: nil, nargs: nil, value_name: "ARG"}}
                ]}
    end

    test ":float" do
      spec = new_spec(%{args: [arg: %{type: :float}]})
      assert Parser.parse(spec, ["0.0"]) == {[], %{arg: 0}, %{}, []}
      assert Parser.parse(spec, ["1.1"]) == {[], %{arg: 1.1}, %{}, []}

      assert Parser.parse(spec, ["-1.1"]) ==
               {[], %{}, %{},
                [{:unknown_opt, "-1"}, {:missing_arg, %{message: nil, type: :float, value: nil, nargs: nil, value_name: "ARG"}}]}

      assert Parser.parse(spec, ["other"]) ==
               {[], %{}, %{},
                [
                  {:invalid_arg, %{message: nil, type: :float, value: "other", nargs: nil, value_name: "ARG"}},
                  {:missing_arg, %{message: nil, type: :float, value: nil, nargs: nil, value_name: "ARG"}}
                ]}
    end

    test ":custom" do
      spec =
        new_spec(%{
          args: [
            arg: %{
              type:
                {:custom,
                 fn string ->
                   case Date.from_iso8601(string) do
                     {:ok, _} = ok_tuple -> ok_tuple
                     {:error, _} -> {:error, "invalid date"}
                   end
                 end}
            }
          ]
        })

      assert Parser.parse(spec, ["2015-01-23"]) == {[], %{arg: ~D[2015-01-23]}, %{}, []}

      assert Parser.parse(spec, ["bad_date"]) ==
               {[], %{}, %{},
                [
                  {:invalid_arg, %{message: "invalid date", type: :custom, value: "bad_date", nargs: nil, value_name: "ARG"}},
                  {:missing_arg, %{message: nil, type: :custom, value: nil, nargs: nil, value_name: "ARG"}}
                ]}
    end
  end

  describe "args - :nargs attr" do
    test "nil" do
      spec = new_spec(%{args: [arg: %{nargs: nil}]})

      assert Parser.parse(spec, []) ==
               {[], %{}, %{}, [{:missing_arg, %{message: nil, type: :string, value: nil, nargs: nil, value_name: "ARG"}}]}

      assert Parser.parse(spec, ["a"]) == {[], %{arg: "a"}, %{}, []}
      assert Parser.parse(spec, ["a", "b"]) == {[], %{arg: "a"}, %{}, [{:unknown_arg, "b"}]}
    end

    test inspect(:"?") do
      spec = new_spec(%{args: [arg: %{nargs: :"?"}]})

      assert Parser.parse(spec, []) == {[], %{arg: nil}, %{}, []}
      assert Parser.parse(spec, ["a"]) == {[], %{arg: "a"}, %{}, []}
      assert Parser.parse(spec, ["a", "b"]) == {[], %{arg: "a"}, %{}, [{:unknown_arg, "b"}]}
    end

    test ":*" do
      spec = new_spec(%{args: [arg: %{nargs: :*}]})

      assert Parser.parse(spec, []) == {[], %{arg: []}, %{}, []}
      assert Parser.parse(spec, ["a"]) == {[], %{arg: ["a"]}, %{}, []}
      assert Parser.parse(spec, ["a", "b"]) == {[], %{arg: ["a", "b"]}, %{}, []}
    end

    test ":+" do
      spec = new_spec(%{args: [arg: %{nargs: :+}]})

      assert Parser.parse(spec, []) ==
               {[], %{}, %{},
                [
                  {:missing_arg, %{message: nil, type: :string, value: nil, nargs: :+, value_name: "ARG"}}
                ]}

      assert Parser.parse(spec, ["a", "b"]) == {[], %{arg: ["a", "b"]}, %{}, []}
    end
  end

  describe "args - :default attr" do
    test "for nargs #{inspect(nil)}" do
      # no test for it, because it means the argument is required
    end

    test "for :nargs - #{inspect(:"?")}" do
      spec = new_spec(%{args: [arg: %{nargs: :"?", default: "x"}]})
      assert Parser.parse(spec, []) == {[], %{arg: "x"}, %{}, []}
      assert Parser.parse(spec, ["a"]) == {[], %{arg: "a"}, %{}, []}
    end

    test "for :nargs - #{inspect(:*)}" do
      spec = new_spec(%{args: [arg: %{nargs: :*, default: ["x"]}]})
      assert Parser.parse(spec, []) == {[], %{arg: ["x"]}, %{}, []}
      assert Parser.parse(spec, ["a"]) == {[], %{arg: ["a"]}, %{}, []}
    end

    test "for :nargs - #{inspect(:+)}" do
      # no test for it, because it means the argument is required
    end

    test "isn't checked to match the :type attr" do
      spec = new_spec(%{args: [arg: %{type: :boolean, nargs: :"?", default: "A"}]})
      assert Parser.parse(spec, []) == {[], %{arg: "A"}, %{}, []}
    end
  end

  describe "args - errors" do
    test "generate {:unknown_arg, arg} error where there're remaining arguments" do
      spec = new_spec(%{})
      assert Parser.parse(spec, ["a", "b"]) == {[], %{}, %{}, [{:unknown_arg, "a"}, {:unknown_arg, "b"}]}
    end

    test "generate {:missing_arg, key} error when required args are missing" do
      spec = new_spec(%{args: [arg: %{}]})

      assert Parser.parse(spec, []) ==
               {[], %{}, %{},
                [
                  {:missing_arg, %{message: nil, type: :string, value: nil, nargs: nil, value_name: "ARG"}}
                ]}
    end

    test "generate {:invalid_arg, key, arg} error" do
      spec = new_spec(%{args: [arg: %{type: :integer}]})

      assert Parser.parse(spec, ["not-integer"]) ==
               {[], %{}, %{},
                [
                  {:invalid_arg, %{message: nil, type: :integer, value: "not-integer", nargs: nil, value_name: "ARG"}},
                  {:missing_arg, %{message: nil, type: :integer, value: nil, nargs: nil, value_name: "ARG"}}
                ]}
    end
  end

  describe "opts - syntax" do
    test "--flag" do
      spec = new_spec(%{opts: [flag: %{long: "flag", type: :boolean}]})
      assert Parser.parse(spec, ["--flag"]) == {[], %{}, %{flag: true}, []}
    end

    test "--opt <value>" do
      spec = new_spec(%{opts: [opt: %{long: "opt", type: :string}]})
      assert Parser.parse(spec, ["--opt", "value"]) == {[], %{}, %{opt: "value"}, []}
    end

    test "--opt=<value>" do
      spec = new_spec(%{opts: [opt: %{long: "opt", type: :string}]})
      assert Parser.parse(spec, ["--opt=value"]) == {[], %{}, %{opt: "value"}, []}
    end

    test "-f" do
      spec = new_spec(%{opts: [flag: %{short: "f", type: :boolean}]})
      assert Parser.parse(spec, ["-f"]) == {[], %{}, %{flag: true}, []}
    end

    test "-o <value>" do
      spec = new_spec(%{opts: [opt: %{short: "o", type: :string}]})
      assert Parser.parse(spec, ["-o", "value"]) == {[], %{}, %{opt: "value"}, []}
    end

    test "-o<value>" do
      spec = new_spec(%{opts: [opt: %{short: "o", type: :string}]})
      assert Parser.parse(spec, ["-ovalue"]) == {[], %{}, %{opt: "value"}, []}
    end

    test "-abc" do
      spec =
        new_spec(%{
          opts: [
            flag_a: %{short: "a", type: :boolean},
            flag_b: %{short: "b", type: :boolean},
            flag_c: %{short: "c", type: :boolean}
          ]
        })

      assert Parser.parse(spec, ["-abc"]) == {[], %{}, %{flag_a: true, flag_b: true, flag_c: true}, []}
      assert Parser.parse(spec, ["-aXbc"]) == {[], %{}, %{flag_a: true, flag_b: false, flag_c: false}, [{:unknown_opt, "-X"}]}
    end

    test "-abco <value>" do
      spec =
        new_spec(%{
          opts: [
            flag_a: %{short: "a", type: :boolean},
            flag_b: %{short: "b", type: :boolean},
            flag_c: %{short: "c", type: :boolean},
            opt: %{short: "o", type: :string}
          ]
        })

      assert Parser.parse(spec, ["-abco", "value"]) == {[], %{}, %{flag_a: true, flag_b: true, flag_c: true, opt: "value"}, []}

      assert Parser.parse(spec, ["-aXbco", "value"]) ==
               {[], %{}, %{flag_a: true, flag_b: false, flag_c: false, opt: nil}, [{:unknown_opt, "-X"}, {:unknown_arg, "value"}]}
    end

    test "-abco<value>" do
      spec =
        new_spec(%{
          opts: [
            flag_a: %{short: "a", type: :boolean},
            flag_b: %{short: "b", type: :boolean},
            flag_c: %{short: "c", type: :boolean},
            opt: %{short: "o", type: :string}
          ]
        })

      assert Parser.parse(spec, ["-abcovalue"]) == {[], %{}, %{flag_a: true, flag_b: true, flag_c: true, opt: "value"}, []}

      assert Parser.parse(spec, ["-aXbcovalue"]) ==
               {[], %{}, %{flag_a: true, flag_b: false, flag_c: false, opt: nil}, [{:unknown_opt, "-X"}]}
    end

    test ":intermixed mode vs. :strict mode" do
      spec =
        new_spec(%{
          args: [
            arg: %{nargs: :*}
          ],
          opts: [
            flag: %{short: "f", type: :boolean},
            opt: %{short: "o", type: :string}
          ]
        })

      assert Parser.parse(spec, ["-f", "arg1", "-o", "value", "arg2"]) ==
               {[], %{arg: ["arg1", "arg2"]}, %{flag: true, opt: "value"}, []}

      assert Parser.parse(spec, ["-f", "arg1", "-o", "value", "arg2"], mode: :intermixed) ==
               {[], %{arg: ["arg1", "arg2"]}, %{flag: true, opt: "value"}, []}

      assert Parser.parse(spec, ["-f", "arg1", "-o", "value", "arg2"], mode: :strict) ==
               {[], %{arg: ["arg1", "-o", "value", "arg2"]}, %{flag: true, opt: nil}, []}
    end
  end

  describe "opts - syntax - handle '-' carefully" do
    test "there's no negative number like option" do
      spec = new_spec(%{args: [arg: %{nargs: :*}], opts: [opt: %{short: "o"}]})
      assert Parser.parse(spec, ["-o", "-1"]) == {[], %{arg: []}, %{opt: "-1"}, []}
      assert Parser.parse(spec, ["-o", "-1", "-1"]) == {[], %{arg: []}, %{opt: "-1"}, [{:unknown_opt, "-1"}]}
      assert Parser.parse(spec, ["-o", "-1.1"]) == {[], %{arg: []}, %{opt: "-1.1"}, []}
      assert Parser.parse(spec, ["-o", "-1.1", "-1.1"]) == {[], %{arg: []}, %{opt: "-1.1"}, [{:unknown_opt, "-1"}]}
    end

    test "there's negative number like flag" do
      spec = new_spec(%{args: [arg: %{nargs: :*}], opts: [opt: %{short: "1", type: :boolean}]})
      assert Parser.parse(spec, ["-5"]) == {[], %{arg: []}, %{opt: false}, [{:unknown_opt, "-5"}]}
      assert Parser.parse(spec, ["-1", "X"]) == {[], %{arg: ["X"]}, %{opt: true}, []}
      assert Parser.parse(spec, ["-1", "X", "-1"]) == {[], %{arg: ["X"]}, %{opt: true}, []}
      assert Parser.parse(spec, ["-1", "-1"]) == {[], %{arg: []}, %{opt: true}, []}
    end

    test "there's negative number like option" do
      spec = new_spec(%{args: [arg: %{nargs: :*}], opts: [opt: %{short: "1"}]})
      assert Parser.parse(spec, ["-5"]) == {[], %{arg: []}, %{opt: nil}, [{:unknown_opt, "-5"}]}
      assert Parser.parse(spec, ["-1", "X"]) == {[], %{arg: []}, %{opt: "X"}, []}

      assert Parser.parse(spec, ["-1", "X", "-1"]) ==
               {[], %{arg: []}, %{opt: "X"},
                [
                  {:missing_opt, %{message: nil, type: :string, value: nil, action: :store, value_name: "OPT", prefixed_opt_name: "-1"}}
                ]}

      assert Parser.parse(spec, ["-1", "-1"]) == {[], %{arg: []}, %{opt: "-1"}, []}
    end
  end

  describe "opts - :short, :long attr" do
    test ":short" do
      spec = new_spec(%{opts: [opt: %{short: "o"}]})
      assert Parser.parse(spec, ["-o", "value"]) == {[], %{}, %{opt: "value"}, []}
    end

    test ":long" do
      spec = new_spec(%{opts: [opt: %{long: "opt"}]})
      assert Parser.parse(spec, ["--opt", "value"]) == {[], %{}, %{opt: "value"}, []}
    end

    test ":short and :long" do
      spec = new_spec(%{opts: [opt: %{short: "o", long: "opt"}]})
      assert Parser.parse(spec, ["-o", "value"]) == {[], %{}, %{opt: "value"}, []}
      assert Parser.parse(spec, ["--opt", "value"]) == {[], %{}, %{opt: "value"}, []}
    end
  end

  describe "opts - :type attr" do
    test "default to :string" do
      spec = new_spec(%{opts: [opt: %{short: "o", long: "opt"}]})
      assert Parser.parse(spec, ["-o", "value"]) == {[], %{}, %{opt: "value"}, []}
    end

    test ":string" do
      spec = new_spec(%{opts: [opt: %{short: "o", long: "opt", type: :string}]})
      assert Parser.parse(spec, ["--opt", "value"]) == {[], %{}, %{opt: "value"}, []}
      assert Parser.parse(spec, ["--opt=value"]) == {[], %{}, %{opt: "value"}, []}

      assert Parser.parse(spec, ["--opt="]) ==
               {[], %{}, %{opt: nil},
                [
                  {:missing_opt, %{message: nil, type: :string, value: nil, action: :store, value_name: "OPT", prefixed_opt_name: "--opt"}}
                ]}

      assert Parser.parse(spec, ["--no-opt="]) == {[], %{}, %{opt: nil}, [{:unknown_opt, "--no-opt"}]}
    end

    test ":boolean" do
      spec = new_spec(%{opts: [opt: %{short: "o", long: "opt", type: :boolean}]})

      assert Parser.parse(spec, ["--opt"]) == {[], %{}, %{opt: true}, []}
      assert Parser.parse(spec, ["--opt", "true"]) == {[], %{}, %{opt: true}, [{:unknown_arg, "true"}]}
      assert Parser.parse(spec, ["--opt", "false"]) == {[], %{}, %{opt: true}, [{:unknown_arg, "false"}]}
      assert Parser.parse(spec, ["--opt", "other"]) == {[], %{}, %{opt: true}, [{:unknown_arg, "other"}]}

      assert Parser.parse(spec, ["--opt="]) == {[], %{}, %{opt: true}, []}
      assert Parser.parse(spec, ["--opt=true"]) == {[], %{}, %{opt: true}, []}
      assert Parser.parse(spec, ["--opt=false"]) == {[], %{}, %{opt: false}, []}

      assert Parser.parse(spec, ["--opt=other"]) ==
               {[], %{}, %{opt: false},
                [
                  {:invalid_opt,
                   %{message: nil, type: :boolean, value: "other", action: :store, value_name: "OPT", prefixed_opt_name: "--opt"}}
                ]}

      assert Parser.parse(spec, ["--no-opt"]) == {[], %{}, %{opt: false}, []}
      assert Parser.parse(spec, ["--no-opt", "true"]) == {[], %{}, %{opt: false}, [{:unknown_arg, "true"}]}
      assert Parser.parse(spec, ["--no-opt", "false"]) == {[], %{}, %{opt: false}, [{:unknown_arg, "false"}]}
      assert Parser.parse(spec, ["--no-opt", "other"]) == {[], %{}, %{opt: false}, [{:unknown_arg, "other"}]}

      assert Parser.parse(spec, ["--no-opt="]) == {[], %{}, %{opt: false}, []}

      assert Parser.parse(spec, ["--no-opt=true"]) ==
               {[], %{}, %{opt: false},
                [
                  {:invalid_opt,
                   %{
                     message: nil,
                     type: {:boolean, :negated},
                     value: "true",
                     action: :store,
                     value_name: "OPT",
                     prefixed_opt_name: "--no-opt"
                   }}
                ]}

      assert Parser.parse(spec, ["--no-opt=false"]) ==
               {[], %{}, %{opt: false},
                [
                  {:invalid_opt,
                   %{
                     message: nil,
                     type: {:boolean, :negated},
                     value: "false",
                     action: :store,
                     value_name: "OPT",
                     prefixed_opt_name: "--no-opt"
                   }}
                ]}

      assert Parser.parse(spec, ["--no-opt=other"]) ==
               {[], %{}, %{opt: false},
                [
                  {:invalid_opt,
                   %{
                     message: nil,
                     type: {:boolean, :negated},
                     value: "other",
                     action: :store,
                     value_name: "OPT",
                     prefixed_opt_name: "--no-opt"
                   }}
                ]}
    end

    test ":integer" do
      spec = new_spec(%{opts: [opt: %{short: "o", long: "opt", type: :integer}]})

      assert Parser.parse(spec, ["--opt"]) ==
               {[], %{}, %{opt: nil},
                [{:missing_opt, %{message: nil, type: :integer, value: nil, action: :store, value_name: "OPT", prefixed_opt_name: "--opt"}}]}

      assert Parser.parse(spec, ["--opt", "30"]) == {[], %{}, %{opt: 30}, []}
      assert Parser.parse(spec, ["--opt", "-30"]) == {[], %{}, %{opt: -30}, []}

      assert Parser.parse(spec, ["--opt", "other"]) ==
               {[], %{}, %{opt: nil},
                [
                  invalid_opt: %{
                    message: nil,
                    type: :integer,
                    value: "other",
                    action: :store,
                    value_name: "OPT",
                    prefixed_opt_name: "--opt"
                  }
                ]}

      assert Parser.parse(spec, ["--opt="]) ==
               {[], %{}, %{opt: nil},
                [missing_opt: %{message: nil, type: :integer, value: nil, action: :store, value_name: "OPT", prefixed_opt_name: "--opt"}]}

      assert Parser.parse(spec, ["--opt=30"]) == {[], %{}, %{opt: 30}, []}
      assert Parser.parse(spec, ["--opt=-30"]) == {[], %{}, %{opt: -30}, []}

      assert Parser.parse(spec, ["--opt=other"]) ==
               {[], %{}, %{opt: nil},
                [
                  invalid_opt: %{
                    message: nil,
                    type: :integer,
                    value: "other",
                    action: :store,
                    value_name: "OPT",
                    prefixed_opt_name: "--opt"
                  }
                ]}

      assert Parser.parse(spec, ["--no-opt="]) == {[], %{}, %{opt: nil}, [{:unknown_opt, "--no-opt"}]}

      assert Parser.parse(spec, ["-o"]) ==
               {[], %{}, %{opt: nil},
                [
                  missing_opt: %{message: nil, type: :integer, value: nil, action: :store, value_name: "OPT", prefixed_opt_name: "-o"}
                ]}

      assert Parser.parse(spec, ["-o", "30"]) == {[], %{}, %{opt: 30}, []}
      assert Parser.parse(spec, ["-o", "-30"]) == {[], %{}, %{opt: -30}, []}

      assert Parser.parse(spec, ["-o", "other"]) ==
               {[], %{}, %{opt: nil},
                [
                  invalid_opt: %{message: nil, type: :integer, value: "other", action: :store, value_name: "OPT", prefixed_opt_name: "-o"}
                ]}

      assert Parser.parse(spec, ["-o30"]) == {[], %{}, %{opt: 30}, []}
      assert Parser.parse(spec, ["-o-30"]) == {[], %{}, %{opt: -30}, []}
    end

    test ":float" do
      spec = new_spec(%{opts: [opt: %{short: "o", long: "opt", type: :float}]})

      assert Parser.parse(spec, ["--opt"]) ==
               {[], %{}, %{opt: nil},
                [
                  missing_opt: %{message: nil, type: :float, value: nil, action: :store, value_name: "OPT", prefixed_opt_name: "--opt"}
                ]}

      assert Parser.parse(spec, ["--opt", "30.0"]) == {[], %{}, %{opt: 30.0}, []}
      assert Parser.parse(spec, ["--opt", "-30.0"]) == {[], %{}, %{opt: -30.0}, []}

      assert Parser.parse(spec, ["--opt", "other"]) ==
               {[], %{}, %{opt: nil},
                [
                  invalid_opt: %{message: nil, type: :float, value: "other", action: :store, value_name: "OPT", prefixed_opt_name: "--opt"}
                ]}

      assert Parser.parse(spec, ["--opt="]) ==
               {[], %{}, %{opt: nil},
                [
                  missing_opt: %{message: nil, type: :float, value: nil, action: :store, value_name: "OPT", prefixed_opt_name: "--opt"}
                ]}

      assert Parser.parse(spec, ["--opt=30.0"]) == {[], %{}, %{opt: 30.0}, []}
      assert Parser.parse(spec, ["--opt=-30.0"]) == {[], %{}, %{opt: -30.0}, []}

      assert Parser.parse(spec, ["--opt=other"]) ==
               {[], %{}, %{opt: nil},
                [
                  invalid_opt: %{message: nil, type: :float, value: "other", action: :store, value_name: "OPT", prefixed_opt_name: "--opt"}
                ]}

      assert Parser.parse(spec, ["--no-opt="]) == {[], %{}, %{opt: nil}, [{:unknown_opt, "--no-opt"}]}

      assert Parser.parse(spec, ["-o"]) ==
               {[], %{}, %{opt: nil},
                [
                  missing_opt: %{message: nil, type: :float, value: nil, action: :store, value_name: "OPT", prefixed_opt_name: "-o"}
                ]}

      assert Parser.parse(spec, ["-o", "30.0"]) == {[], %{}, %{opt: 30.0}, []}
      assert Parser.parse(spec, ["-o", "-30.0"]) == {[], %{}, %{opt: -30.0}, []}

      assert Parser.parse(spec, ["-o", "other"]) ==
               {[], %{}, %{opt: nil},
                [
                  {:invalid_opt, %{message: nil, type: :float, value: "other", action: :store, value_name: "OPT", prefixed_opt_name: "-o"}}
                ]}

      assert Parser.parse(spec, ["-o30.0"]) == {[], %{}, %{opt: 30.0}, []}
      assert Parser.parse(spec, ["-o-30.0"]) == {[], %{}, %{opt: -30.0}, []}
    end
  end

  describe "opts - :action attr" do
    test "default to :store" do
      spec = new_spec(%{opts: [opt: %{short: "o"}]})
      assert Parser.parse(spec, ["-o", "value1", "-o", "value2"]) == {[], %{}, %{opt: "value2"}, []}

      spec = new_spec(%{opts: [opt: %{short: "o", type: :boolean}]})
      assert Parser.parse(spec, ["-o", "-o"]) == {[], %{}, %{opt: true}, []}

      spec = new_spec(%{opts: [opt: %{short: "o", long: "opt", type: :boolean}]})
      assert Parser.parse(spec, ["-o", "--no-opt"]) == {[], %{}, %{opt: false}, []}
    end

    test ":store" do
      spec = new_spec(%{opts: [opt: %{short: "o", action: :store}]})
      assert Parser.parse(spec, ["-o", "value1", "-o", "value2"]) == {[], %{}, %{opt: "value2"}, []}

      spec = new_spec(%{opts: [opt: %{short: "o", type: :boolean, action: :store}]})
      assert Parser.parse(spec, ["-o", "-o"]) == {[], %{}, %{opt: true}, []}

      spec = new_spec(%{opts: [opt: %{short: "o", long: "opt", type: :boolean, action: :store}]})
      assert Parser.parse(spec, ["-o", "--no-opt"]) == {[], %{}, %{opt: false}, []}
    end

    test ":count" do
      spec = new_spec(%{opts: [opt: %{short: "o", action: :count}]})
      assert Parser.parse(spec, ["-o", "value", "-o", "value"]) == {[], %{}, %{opt: 2}, []}

      spec = new_spec(%{opts: [opt: %{short: "o", type: :boolean, action: :count}]})
      assert Parser.parse(spec, ["-o", "-o"]) == {[], %{}, %{opt: 2}, []}
    end

    test ":append" do
      spec = new_spec(%{opts: [opt: %{short: "o", action: :append}]})
      assert Parser.parse(spec, ["-o", "value", "-o", "value"]) == {[], %{}, %{opt: ["value", "value"]}, []}

      spec = new_spec(%{opts: [opt: %{short: "o", type: :boolean, action: :append}]})
      assert Parser.parse(spec, ["-o", "-o"]) == {[], %{}, %{opt: [true, true]}, []}
    end
  end

  describe "opts - :default attr" do
  end

  test "collects multiple errors" do
    spec =
      new_spec(%{
        args: [
          born: %{}
        ],
        opts: [
          name: %{short: "n", long: "name"},
          age: %{short: "a", long: "age", type: :integer},
          city: %{short: "c", long: "city"}
        ]
      })

    assert Parser.parse(spec, ["--unknown1", "--unknown2", "--name", "Joe", "--age", "forever", "--city"]) ==
             {[], %{}, %{age: nil, city: nil, name: "Joe"},
              [
                unknown_opt: "--unknown1",
                unknown_opt: "--unknown2",
                invalid_opt: %{
                  message: nil,
                  type: :integer,
                  value: "forever",
                  action: :store,
                  value_name: "AGE",
                  prefixed_opt_name: "--age"
                },
                missing_opt: %{message: nil, type: :string, value: nil, action: :store, value_name: "CITY", prefixed_opt_name: "--city"},
                missing_arg: %{message: nil, type: :string, value: nil, nargs: nil, value_name: "BORN"}
              ]}
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

    assert Parser.parse(spec, ["-", "-i", "-"]) == {[], %{all: ["-"]}, %{input: "-"}, []}
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

    assert Parser.parse(spec, ["a1", "a2", "-d"]) == {[], %{all: ["a1", "a2"]}, %{debug: true, single: false}, []}
    assert Parser.parse(spec, ["a1", "a2", "--", "-d"]) == {[], %{all: ["a1", "a2", "-d"]}, %{debug: false, single: false}, []}
    assert Parser.parse(spec, ["a1", "a2", "-1"]) == {[], %{all: ["a1", "a2"]}, %{debug: false, single: true}, []}
    assert Parser.parse(spec, ["a1", "a2", "--", "-1"]) == {[], %{all: ["a1", "a2", "-1"]}, %{debug: false, single: false}, []}
  end

  defp new_spec(cmd_spec), do: Spec.new({:example, cmd_spec})
end
