extends Node
## Every content definition, loaded from res://data at start-up and looked up by id.
## Adding an item, resident, monster, building or profession means adding a .tres file
## to its folder; nothing else keeps a hard-coded list.

const FOLDERS := {
	"items": "res://data/items",
	"npcs": "res://data/npcs",
	"monsters": "res://data/monsters",
	"buildings": "res://data/buildings",
	"professions": "res://data/professions",
}

var _defs := {}     # kind -> { id -> Resource }


func _ready() -> void:
	for kind in FOLDERS:
		_defs[kind] = _load_folder(FOLDERS[kind])


func _load_folder(path: String) -> Dictionary:
	var out := {}
	for file in ResourceLoader.list_directory(path):
		if file.ends_with(".tres") or file.ends_with(".res"):
			var res := load(path.path_join(file))
			var id: String = res.get("id") if res.get("id") else file.get_basename()
			out[id] = res
	return out


func get_def(kind: String, id: String) -> Resource:
	return _defs.get(kind, {}).get(id)


func all(kind: String) -> Array:
	return _defs.get(kind, {}).values()
