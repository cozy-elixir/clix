defmodule CLIX do
  @moduledoc """
  A utility-first, composable CLI framework.

  Before we begin, let's first talk about the terminology and conventions used
  in CLIX.

  ## The flow of CLIX

    1. use `CLIX.Spec` to build a spec.
    2. use `CLIX.Parser` to parse argv with the built spec.
    3. use `CLIX.Feedback` to generate user-faced feedbacks with the built spec.

  ## About arguments

  The arguments is the abbrev of "command line arguments", which is the main
  thing handled by a CLI framework.

  ### Positional arguments

  In general, positional arguments are the ones which are not prefixed with
  `-` or `--`.

  > Negative number(like `-3`, `-3.14`) is a special case, but CLIX's parser
  > can handle it properly.

  ### Optional arguments

  In general, optional arguments are the ones prefixed with `-` or `--`:

    * POSIX syntax - `-` followed by a single letter indicating an option.
    * GNU-extended syntax - `--` followed by a long name indicating an option.

  > CLIX doesn't plan to support special prefixes, such as `/` or `+`, so we
  > ignore them.

  In practice, optional arguments are often used to implement options. For
  options, there is a further level of classification:

    * options which require subsequent arguments, such as `-o value` or `--option value`.
    * options which don't require subsequent arguments, such as `-o` or `--option`.
      They are commonly referred to as flags, because they represent boolean states.

  > CLIX doesn't explicitly distinguish between flags and options, as a flag is
  > simply a special type of option.

  #### Option terminator

  The option terminator is `--`. When it is used, all the arguments after it are
  considered as positional arguments.

  ### The optionality of arguments

  In CLIX, we think:

    * positional arguments are required by default, but can be made optional.
    * optional arguments are always optional, and this is unchangeable.

  In other implementations, optional arguments can be made required. Personally,
  I don't think that's a good design. You can try to say "The optional argument
  is required", then you might feel it's a bit counterintuitive. That's because
  the name (optional argument) does not match its description (requried).

  ## Conventions

  ### Abbreviations

  To make the code or doc more compact, we use some abbreviations to describe
  positional arguments and optional arguments.

  At the implementation level, which the CLIX's developers should care about:

    * `pos_args` - refers to positional arguments
    * `opt_args` - refers to optional arguments

  At the interface level, which the CLIX's users should care about:

    * `args` - refers to positional arguments
    * `opts` - refers to optional arguments

  And, when you see a standalone "arguments", it means arguments in the general sense.

  ### The structure of an option

  |                    | option prefix | option string    | option name | option value |
  | ------------------ | ------------- | ---------------- | ----------- | ------------ |
  | `-o <value>`       | `-`           | `o`              | `o`         | `<value>`    |
  | `-o<value>`        | `-`           | `o<value>`       | `o`         | `<value>`    |
  | `--option <value>` | `--`          | `option`         | `option`    | `<value>`    |
  | `--option=<value>` | `--`          | `option=<value>` | `option`    | `<value>`    |

  > This is a convention used in CLIX, not a standard widely accepted.

  """
end
