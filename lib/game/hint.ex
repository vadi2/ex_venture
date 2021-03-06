defmodule Game.Hint do
  @moduledoc """
  Module to help guard for hiding hints
  """

  use ExVenture.TextCompiler, "help/hint.help"
  use Networking.Socket

  alias Game.Format

  def hint(key, context) do
    context = Enum.into(context, %{})

    key
    |> get()
    |> Format.template(context)
  end

  def gate(state, key, context \\ %{}) do
    case state.save.config.hints do
      true ->
        state.socket |> @socket.echo("{hint}HINT{/hint}: #{hint(key, context)}")

      false ->
        :ok
    end
  end
end
