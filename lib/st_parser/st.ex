defmodule ST do
  @moduledoc """
  Defines the target data structures for parsed Session Types.
  """

  defmodule SBranch do
    @moduledoc "Represents a single branch in a choice or a single action sequence."
    @enforce_keys [:label, :payload, :continue_as]
    defstruct [:label, :payload, :continue_as]
    # label: atom() - snake_case message label
    # payload: term() - Elixir representation of the Type
    # continue_as: ST.t() - The next session type structure
  end

  defmodule SIn do
    @moduledoc "Represents receiving messages (external choice)."
    @enforce_keys [:from, :branches]
    defstruct [:from, :branches]
    # from: atom() - snake_case role name sending the message(s)
    # branches: [SBranch.t()] - List of possible messages/branches
  end

  defmodule SOut do
    @moduledoc "Represents sending messages (internal choice)."
    @enforce_keys [:to, :branches]
    defstruct [:to, :branches]
    # to: atom() - snake_case role name receiving the message(s)
    # branches: [SBranch.t()] - List of possible messages/branches being sent
  end

  defmodule SEnd do
    @moduledoc "Represents the termination of a session path."
    defstruct []
  end

  # @type t :: SIn.t() | SOut.t() | SEnd.t()
end
