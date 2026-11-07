class_name MapCatalog
## All maps.

const MAPS := [
	{"id": "dustline", "name": "Dustline", "desc": "Desert market town. Mid-size, mixed ranges.", "script": "res://scripts/maps/map_dustline.gd"},
	{"id": "coldharbor", "name": "Coldharbor", "desc": "Frozen container port. Tight lanes, warehouses, a crane.", "script": "res://scripts/maps/map_coldharbor.gd"},
	{"id": "overpass", "name": "Overpass", "desc": "City block under an elevated highway. Vertical fights.", "script": "res://scripts/maps/map_overpass.gd"},
	{"id": "refinery", "name": "Refinery", "desc": "Industrial complex at night. Tanks, pipes, floodlights.", "script": "res://scripts/maps/map_refinery.gd"},
	{"id": "pinecrest", "name": "Pinecrest", "desc": "Forest radar outpost on a river. Large, long sightlines.", "script": "res://scripts/maps/map_pinecrest.gd"},
	{"id": "hangar9", "name": "Hangar 9", "desc": "Desert airfield at dusk. Hangars and a control tower.", "script": "res://scripts/maps/map_hangar9.gd"},
	{"id": "villa", "name": "Villa Marisol", "desc": "Hillside estate at sunset. Courtyard, pool, gardens.", "script": "res://scripts/maps/map_villa.gd"},
	{"id": "ashgrove", "name": "Ashgrove", "desc": "Shelled European town. Narrow streets, rubble, a clock tower.", "script": "res://scripts/maps/map_ashgrove.gd"},
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
