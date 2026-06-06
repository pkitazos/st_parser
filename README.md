# Session Type Parser

A simple, lightweight, flexible parser for Session Types in Elixir.

ST Parser converts textual session type descriptions into typed Elixir data structures, enabling formal verification and implementation of communication protocols between distributed system components.

## What are Session Types?

Session types provide a way to formally describe communication protocols between different roles in a distributed system. They let you specify:

- Who sends messages to whom
- What data is exchanged in those messages
- The order of interactions
- Choices and branches in the protocol flow

## Features

- Parse session type expressions into structured Elixir terms
- Build session types programmatically with constructor functions
- Handle complex session type constructs like input (external choice) and output (internal choice)
- Support nested payload types (lists, tuples)
- Clean and simple API for integration into larger projects

## Installation

Add `st_parser` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:st_parser, "~> 0.5.0"}
  ]
end
```

## Usage

### Parsing Session Type Expressions

```elixir
# Parse a session type string into a structured type
{:ok, session_type} = ST.Parser.parse("&Server:{ Ack(nil).end }")

# Or use the bang version which raises on error
session_type = ST.Parser.parse!("&Server:{ Ack(nil).end }")

# Parse just a payload type
{:ok, payload_type} = ST.Parser.parse_type("(string, boolean[])")
```

### Building Session Types Programmatically

```elixir
# Create an End type
end_type = ST.end_session()

# Create a simple branch
ack_branch = ST.branch(:ack, nil, end_type)

# Create an input type (receiving a message)
input_type = ST.input(:server, [ack_branch])
# Or more concisely:
input_type = ST.input_one(:server, :ack, nil, end_type)

# Create an output type (sending a message)
output_type = ST.output_one(:client, :request, :binary, end_type)
```

### Using Session Type Sigils

For cleaner syntax and compile-time validation, you can use the `~q` sigil to define session types directly in your code:

```elixir
import ST.Sigils

# Define session types with clean, readable syntax
auth_protocol = ~q/
  &Server:{
    Login((string, string)).+Client:{
      Success(nil).end,
      Failure(string).end
    }
  }
/

# Access properties directly from the compiled struct
IO.puts("Expecting message from: #{auth_protocol.from}")
IO.puts("First branch label: #{hd(auth_protocol.branches).label}")
```

Sigils provide the same functionality as ST.Parser.parse/1 but with compile-time parsing and validation, meaning syntax errors are caught when you compile rather than when your code runs.

### Session Type Syntax

Session type expressions use a concise syntax:

```
# Input (receiving messages)
&Role:{ Label1(PayloadType).Continuation, Label2(PayloadType).Continuation }

# Output (sending messages)
+Role:{ Label1(PayloadType).Continuation, Label2(PayloadType).Continuation }

# Termination
end
```

Payload types can be:

- Basic types: `atom`, `string`, `number`, `boolean`, `nil`
- List types: `type[]` (e.g., `string[]`)
- Tuple types: `(type1, type2, ...)` (e.g., `(string, number[])`)

### Example: A Simple Request-Response Protocol

```elixir
request_response = """
&Server:{
  Request(string).+Client:{
    Response((string, number[])).end,
    Error(string).end
  }
}
"""

{:ok, protocol} = ST.Parser.parse(request_response)
```

This describes a protocol where:
1. The user sends a `Request` with a string payload to the server
2. The client responds with either:
   - A `Response` containing a tuple of a string and a number array, then ends
   - An `Error` with a string message, then ends

## Documentation

Full documentation is available via ExDoc:

```
mix docs
```
