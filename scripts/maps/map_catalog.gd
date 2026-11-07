class_name MapCatalog
## All maps.

const MAPS := [
	{"id": "dustline", "name": "Dustline", "desc": "Desert market town. Mid-size, mixed ranges.", "script": "res://scripts/maps/map_dustline.gd"},
]


static func create(id: String) -> MapBase:
	for m in MAPS:
		if m["id"] == id:
			return (load(m["script"]) as GDScript).new()
	return (load(MAPS[0]["script"]) as GDScript).new()


static func display_name(id: String) -> String:
	for m in MAPS:
		if m["id"] == id:
			return m["name"]
	return id.capitalize()
