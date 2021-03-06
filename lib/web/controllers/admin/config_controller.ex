defmodule Web.Admin.ConfigController do
  use Web.AdminController

  alias Web.Config

  def index(conn, _params) do
    conn |> render("index.html")
  end

  def edit(conn, %{"id" => name}) do
    config = Config.get(name)
    changeset = Config.edit(config)

    conn
    |> assign(:config, config)
    |> assign(:changeset, changeset)
    |> render("edit.html")
  end

  def update(conn, %{"id" => name, "config" => %{"value" => value}}) do
    case Config.update(name, value) do
      {:ok, _config} ->
        conn
        |> put_flash(:info, "Config updated!")
        |> redirect(to: config_path(conn, :index))

      {:error, changeset} ->
        config = Config.get(name)

        conn
        |> put_flash(:error, "There was an issue updating the config. Please try again.")
        |> assign(:config, config)
        |> assign(:changeset, changeset)
        |> render("edit.html")
    end
  end
end
