defmodule Charlie.StatusRotator do
  use GenServer
  require Logger

  @songs [
    "Searching for food",
    "Roaming the backyard",
    "Sleeping"
  ]

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(state) do
    Process.send_after(self(), :rotate, :timer.seconds(5))
    Logger.info("Successfully started status rotator")
    {:ok, state}
  end

  def handle_info(:rotate, state) do
    Nostrum.Api.Self.update_status(:online, {:custom, Enum.random(@songs)})
    Process.send_after(self(), :rotate, :timer.hours(1))
    {:noreply, state}
  end
end
