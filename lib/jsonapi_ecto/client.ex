defmodule JSONAPI.Ecto.Client do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, name: __MODULE__)
  end

  def get!(_path) do
    raise "Not implemented yet"
  end
end
