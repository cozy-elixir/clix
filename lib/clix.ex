defmodule CLIX do
  @moduledoc """
  A utility-first CLI framework.

  ## Key modules

  * `CLIX.Spec`
  * `CLIX.Parser`

  ## Basics

  Before using CLIX, let's first go over some basic knowledge and the conventions used in CLIX.

  ### The types of arguments

  #### Positional arguments

  In general, positional arguments are the ones which are not prefixed with `-` or `--`.

  > Negative number(like `-3`, `-3.14`) is a special case, but CLIX's parser can handle it
  > properly.

  #### Optional arguments

  In general, optional arguments are the ones prefixed with `-` or `--`:

  * POSIX syntax - `-` followed by a single letter indicating an option.
  * GNU syntax - `--` followed by a long name indicating an option.

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

  ### The abbrevations of arguments

  In CLIX, to describe the types of arguments more simply and clearly, we will adhere to
  following convention.

    * *args* refers to positional arguments.
    * *opts* refers to optional arguments.
    * *arguments* refers to arguments in a broad sense.

  ## Usage

  1. create a spec
  2. parse argv with the spec.
  3. ...

  """
end
