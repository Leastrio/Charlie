defmodule Charlie.Birthday do
  use GenServer
  import Ecto.Query, only: [from: 2]
  require Logger

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(state) do
    Logger.info("Birthday GenServer started!")
    schedule()
    {:ok, state}
  end

  def handle_info(:queue_messages, state) do
    Task.await(Task.async(fn -> send_alerts() end), :infinity)
    schedule()
    {:noreply, state}
  end

  def schedule() do
    {curr, _} = Time.to_seconds_after_midnight(Time.utc_now())
    delay = (24 * 60 * 60) - curr
    Process.send_after(self(), :queue_messages, :timer.seconds(delay))
  end

  def send_alerts() do
    birthday_channels = Charlie.Repo.all(from(g in Charlie.Schema.Guild, where: not is_nil(g.birthday_channel_id)))

    Enum.each(birthday_channels, fn g ->
      today = Date.utc_today()
      birthdays =
        Charlie.Repo.all(from(b in Charlie.Schema.Birthday, where: b.guild_id == ^g.guild_id and b.day == ^today.day and b.month == ^today.month))
        |> Enum.filter(fn u ->
          case Nostrum.Cache.MemberCache.get(g.guild_id, u.user_id) do
            {:ok, _} -> true
            _ -> false
          end
        end)

      if birthdays != [] do
        Nostrum.Api.Message.create(g.birthday_channel_id, content: gen_message(birthdays))
        Process.sleep(5000)
      end
    end)
  end

  def gen_message(users) do
    curr_year = Date.utc_today().year

    case users do
      [user] ->
        "Happy birthday, #{mention(user, curr_year)}! 🎉"

      [user1, user2] ->
        "Happy birthday to #{mention(user1, curr_year)} and #{mention(user2, curr_year)}! 🎉"

      [head | tail] ->
        "Happy birthday to #{Enum.map(tail, fn u -> mention(u, curr_year) end) |> Enum.join(", ")}, and #{mention(head, curr_year)}! 🎉"
    end
  end

  def mention(user, curr_year) do
    case user.year do
      nil -> "<@#{user.user_id}>"
      year -> "<@#{user.user_id}> (#{curr_year - year})"
    end
  end
end
