defmodule Charlie.Lastfm do
  defstruct [:artist, :album, :image, :title, :url]

  def get_latest(username) do
    api_key = Application.get_env(:charlie, :lastfm_api_key)
    body = Req.get!(
      "http://ws.audioscrobbler.com/2.0/",
      params: [method: "user.getRecentTracks", user: username, format: "json", api_key: api_key, limit: 1],
      headers: [user_agent: "Charlie/0.1"]
    ).body

    case body do
      %{"error" => 17} -> {:private_error, "#{username} has their recent plays set to private. Please fix and try again."}
      %{"error" => 6} -> {:username_error, "#{username} does not exist."}
      %{"recenttracks" => %{"track" => tracks}} -> parse_track(Enum.at(tracks, 0))
    end
  end
  
  def parse_track(nil), do: {:playing_error, "You are not currently playing anything."}
  def parse_track(track) do
    {:ok, %__MODULE__{
      artist: track["artist"]["#text"] || "",
      album: track["album"]["#text"] || "",
      image: track["image"] |> List.last() |> Map.get("#text", ""),
      title: track["name"],
      url: track["url"]
    }}
  end
end
