defmodule Charlie.Commands.Advice do
  use Charlie.Command

  @advice [
    "run",
    "get off discord and go do something productive with youre life",
    "touch grass",
    "dont be mad be glad",
    "your relationship too boring? start drama to make it fun again",
    "if u sad be happy :)",
    "need money just buy more",
    "if ur bored at 3am try learning opera singing",
    "worried about global warming? just open your fridge",
    "if your hungry just eat",
    "house too dirty? just move out!! new house will be clean",
    "if you are stressing about something, just forget about it",
    "you are now manually breathing.",
    "if ur cold at night wear socks on hands to keep warm (bonus: ur fingers look like wiggly sausages)",
    "if your phone is dead just charge it with positive engery from yourself",
    "forget about umbrella, just absorbe the rain around you",
    "Someone spreading rumors about u? just start some about yourself for competition!!",
    "cant swim? just drink the pool",
    "if people are talking behind your back, just fart"
  ]

  def aliases, do: []
  def description, do: "Have the bot send you advice (disclaimer do not follow this advice!!)"
  def options, do: []
  def permissions, do: :everyone
  def predicates, do: []

  def msg_command(_, _), do: {:reply, {:content, Enum.random(@advice)}}
  def slash_command(_, _), do: {:content, Enum.random(@advice)}
end
