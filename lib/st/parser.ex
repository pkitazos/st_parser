defmodule ST.Parser do
  import NimbleParsec

  # Identifiers
  identifier =
    ascii_char([?A..?Z, ?a..?z, ?_])
    |> repeat(ascii_char([?A..?Z, ?a..?z, ?0..?9, ?_]))
    |> reduce({List, :to_string, []})
    |> map({Macro, :underscore, []})
    |> map({String, :to_atom, []})

  # Basic types
  string_type = string("string") |> replace(:binary)
  number_type = string("number") |> replace(:number)
  unit_type = string("unit") |> replace(:unit)
  boolean_type = string("boolean") |> replace(:boolean)

  # Basic payload type - matches one of the basic types
  basic_payload_type =
    choice([
      string_type,
      number_type,
      unit_type,
      boolean_type
    ])

  # List type (e.g., string[], number[])
  list_type =
    basic_payload_type
    |> ignore(string("[]"))
    |> map({__MODULE__, :wrap_list_type, []})

  # Combined payload type (either basic or list)
  payload_type =
    choice([
      list_type,
      basic_payload_type
    ])

  # End terminal
  end_type =
    string("end")
    |> replace(%ST.SEnd{})

  # Helper function for map
  def wrap_list_type(type) do
    {:list, [type]}
  end

  # Export parsers
  defparsec(:parse_identifier, identifier)
  defparsec(:parse_basic_type, basic_payload_type)
  defparsec(:parse_payload_type, payload_type)
  defparsec(:parse_end, end_type)
end
