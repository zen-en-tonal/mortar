defmodule Mortar.Error do
  defexception [:message, :context, :type]

  @type t :: %__MODULE__{
          type: error_type(),
          message: String.t(),
          context: keyword()
        }

  @type error_type :: :invalid | :internal

  @doc """
  Creates an invalid operation error with the given reason.
  """
  def invalid(reason, ctx \\ []) when is_binary(reason) do
    %__MODULE__{
      type: :invalid,
      message: "Invalid operation: #{reason}",
      context: ctx
    }
  end

  @doc """
  Creates an internal error with the given message and optional context.
  """
  def internal(message, context \\ []) when is_binary(message) and is_list(context) do
    %__MODULE__{
      type: :internal,
      message: "Internal error: #{message}",
      context: context
    }
  end
end
