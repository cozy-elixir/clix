defmodule CLIX.Feedback.FormatterTest do
  use ExUnit.Case, async: true

  alias CLIX.Feedback.Formatter

  test "format/2" do
    content =
      Formatter.format(
        """
        Lorem ipsum is placeholder text commonly used in the graphic, print, and publishing \
        industries for previewing layouts and visual mockups.

        Lorem ipsum is typically a corrupted version of De finibus bonorum et malorum, \
        a 1st-century BC text by the Roman statesman and philosopher Cicero, with words \
        altered, added, and removed to make it nonsensical and improper Latin. The first \
        two words themselves are a truncation of dolorem ipsum ("pain itself").
        """,
        68
      )

    assert content == """
           Lorem ipsum is placeholder text commonly used in the graphic, print,
           and publishing industries for previewing layouts and visual mockups.

           Lorem ipsum is typically a corrupted version of De finibus bonorum
           et malorum, a 1st-century BC text by the Roman statesman and
           philosopher Cicero, with words altered, added, and removed to make
           it nonsensical and improper Latin. The first two words themselves
           are a truncation of dolorem ipsum ("pain itself").\
           """
  end

  test "format_columns/1" do
    content =
      Formatter.format_columns([
        {
          """
          Lorem ipsum is placeholder text commonly used in the graphic, print, and publishing \
          industries for previewing layouts and visual mockups.
          """,
          30
        },
        {"", 4},
        {
          """
          Lorem ipsum is typically a corrupted version of De finibus bonorum et malorum, \
          a 1st-century BC text by the Roman statesman and philosopher Cicero, with words \
          altered, added, and removed to make it nonsensical and improper Latin.\nThe first \
          two words themselves are a truncation of dolorem ipsum ("pain itself").
          """,
          30
        },
        {"", 4},
        {
          """
          Lorem ipsum is placeholder text commonly used in the graphic, print, and publishing \
          industries for previewing layouts and visual mockups.
          """,
          30
        }
      ])

    assert content ==
             """
             Lorem ipsum is placeholder        Lorem ipsum is typically a        Lorem ipsum is placeholder
             text commonly used in the         corrupted version of De           text commonly used in the
             graphic, print, and publishing    finibus bonorum et malorum, a     graphic, print, and publishing
             industries for previewing         1st-century BC text by the        industries for previewing
             layouts and visual mockups.       Roman statesman and               layouts and visual mockups.
                                               philosopher Cicero, with words
                                               altered, added, and removed to
                                               make it nonsensical and
                                               improper Latin.
                                               The first two words themselves
                                               are a truncation of dolorem
                                               ipsum ("pain itself").\
             """
  end
end
