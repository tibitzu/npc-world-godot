extends Node
## Networking: the host runs the simulation and everyone else receives its state.
## Empty until milestone 9; single-player and multiplayer run the same game code,
## and only this node knows about other players.

var is_host := true
