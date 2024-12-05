# DESIGN

## The optionality of arguments

In CLIX, we think:

- positional arguments are required by default, but can be made optional.
- optional arguments are always optional, and this is unchangeable.

In some implementations, opt_args can be made required.

Personally, I don't think that's a good design. You can try to say "The optional argument is required", then you might feel it's a bit counterintuitive. That's because the name (optional argument) does not match its description (requried).

## The value of optional arguments

Optional arguments accept 0 or 1 following argument. They can accept multiple values

You might have noticed that `opt_spec()` does not support `:nargs`. This is intentional.

If you want to collect multiple values for an option, try following workarounds:

- use a delimiter to seperate multiple values, like `pgrep` did - `ps -s 123,456 ...`.
- repeat an option mulitple times, like `grep` did - `grep -e pattern1 -e pattern2 ...`.
