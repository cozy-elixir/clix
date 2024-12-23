defmodule CLIX.Feedback.Formatter do
  @moduledoc false

  @doc """
  Formats string within given width.

  Trailing whitespaces will be removed.
  """
  @spec format(String.t(), pos_integer()) :: String.t()
  def format(string, width) when is_binary(string) and is_integer(width) do
    string
    |> wrap_string(width)
    |> Enum.intersperse("\n")
    |> to_string()
    |> String.trim_trailing()
  end

  @doc """
  Formats strings into columns, which have fixed widths.

  Trailing whitespaces will be removed.
  """
  @spec format_columns([{String.t(), width :: pos_integer()}]) :: String.t()
  def format_columns([{string, width} | _] = spec) when is_binary(string) and is_integer(width) do
    columns =
      Enum.map(spec, fn {string, width} ->
        lines = wrap_string(string, width)
        lines_count = Enum.count(lines)
        {width, lines, lines_count}
      end)

    required_lines_count = Enum.map(columns, fn {_, _, count} -> count end) |> Enum.max()

    filled_columns =
      Enum.map(columns, fn {width, lines, lines_count} ->
        filled_lines = Enum.map(lines, fn line -> String.pad_trailing(line, width) end)

        placeholder_lines_count = required_lines_count - lines_count
        placeholder_line = String.duplicate(" ", width)
        placeholder_lines = List.duplicate(placeholder_line, placeholder_lines_count)

        filled_lines ++ placeholder_lines
      end)

    filled_columns
    |> Enum.zip()
    |> Enum.map(&Tuple.to_list/1)
    |> Enum.map(fn line -> line |> to_string() |> String.trim_trailing() end)
    |> Enum.intersperse("\n")
    |> to_string()
    |> String.trim_trailing()
  end

  defp wrap_string(string, width) do
    string
    |> String.split("\n")
    |> Enum.map(fn string -> wrap_line(string, width) end)
    |> List.flatten()
  end

  defp wrap_line("", _max_width), do: [""]

  defp wrap_line(string, max_width), do: wrap_line(string, max_width, [])

  defp wrap_line("", _max_width, lines), do: Enum.reverse(lines)

  defp wrap_line(string, max_width, lines) do
    {current_line, rest} = split_string_sementically(string, max_width)
    wrap_line(rest, max_width, [current_line | lines])
  end

  # split string, and trying its best to not break a word
  defp split_string_sementically(string, length) when is_binary(string) do
    {left, right} = split_string_by_length(string, length)

    {left, right} =
      if break_word?(left, right) do
        {new_left, rest} = split_string_by_last_whitespace(left)
        new_right = rest <> right
        {new_left, new_right}
      else
        {left, right}
      end

    {String.trim_trailing(left), String.trim_leading(right)}
  end

  defp split_string_by_length(string, length) when is_binary(string) do
    {left, right} =
      string
      |> String.graphemes()
      |> Enum.split(length)

    {to_string(left), to_string(right)}
  end

  defp break_word?(_left, "" = _right), do: false

  defp break_word?(left, right) do
    last_char_of_left = String.last(left)
    first_char_of_right = String.first(right)
    !whitespace?(last_char_of_left) and !whitespace?(first_char_of_right)
  end

  defp split_string_by_last_whitespace(string) when is_binary(string) do
    case Regex.run(~r/(.*)\s+(\S*)$/, string, capture: :all_but_first) do
      [left, right] -> {left, right}
      nil -> {string, ""}
    end
  end

  @whitespace ~r|\s|
  defp whitespace?(<<_::utf8>> = char) do
    char =~ @whitespace
  end
end
