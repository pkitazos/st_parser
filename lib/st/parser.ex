defmodule ST.Parser do
  import NimbleParsec

  # Identifiers: Start with letter or underscore, followed by letters, numbers, or underscores
  identifier =
    ascii_char([?A..?Z, ?a..?z, ?_])
    |> repeat(ascii_char([?A..?Z, ?a..?z, ?0..?9, ?_]))
    # Convert to string instead of joining
    |> reduce({List, :to_string, []})
    |> map({Macro, :underscore, []})
    |> map({String, :to_atom, []})

  # Define the end terminal
  end_type =
    string("end")
    |> replace(%ST.SEnd{})

  # Export parsers for testing individual components
  defparsec(:parse_identifier, identifier)
  defparsec(:parse_end, end_type)
end
