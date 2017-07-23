defmodule Game.Command.Quit do
  @moduledoc """
  The "quit" command
  """

  use Game.Command

  alias Game.Account

  @doc """
  Save and quit the game
  """
  @spec run([], session :: Session.t, state :: map) :: :ok
  def run([], session, %{socket: socket, user: user, save: save}) do
    socket |> @socket.echo("Good bye.")
    socket |> @socket.disconnect

    @room.leave(save.room_id, {:user, session, user})
    user |> Account.save(save)

    :ok
  end
end