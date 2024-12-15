# Practices

## Collect multiple values by optional arguments

You might have noticed that `t:CLIX.Spec.opt_spec/0` does not support `:nargs`.
This is intentional.

If you want to collect multiple values by optional arguments, try following
workarounds:

- use a delimiter to seperate multiple values, like `pgrep` did - `ps -s 123,456 ...`.
- repeat an option mulitple times, like `grep` did - `grep -e pattern1 -e pattern2 ...`.
