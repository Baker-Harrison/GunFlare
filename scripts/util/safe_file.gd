class_name SafeFile
extends RefCounted
## Writes a file without a risk of a half-written result.
## The new text goes to a temporary file first. Then the old file becomes the
## backup and the temporary file takes its place. A read uses the backup when
## the main file is missing or does not parse.


static func write_text(path: String, text: String) -> Error:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(text)
	f.flush()
	var err := f.get_error()
	f.close()
	if err != OK:
		DirAccess.remove_absolute(tmp)
		return err
	if FileAccess.get_file_as_string(tmp) != text:
		DirAccess.remove_absolute(tmp)
		return ERR_FILE_CORRUPT
	var bak := path + ".bak"
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(bak):
			DirAccess.remove_absolute(bak)
		var keep := DirAccess.rename_absolute(path, bak)
		if keep != OK:
			DirAccess.remove_absolute(tmp)
			return keep
	var moved := DirAccess.rename_absolute(tmp, path)
	if moved != OK:
		# Put the old file back so that a later read finds it.
		DirAccess.rename_absolute(bak, path)
		return moved
	return OK


## Returns the text of the file, or of its backup when the file is not usable.
## `valid` tells if a text is usable. An empty result means that no file is usable.
static func read_text(path: String, valid: Callable) -> String:
	for candidate in [path, path + ".bak", path + ".tmp"]:
		if not FileAccess.file_exists(candidate):
			continue
		var text := FileAccess.get_file_as_string(candidate)
		if text != "" and valid.call(text):
			if candidate != path:
				push_warning("Using %s because %s is not usable." % [candidate, path])
			return text
	return ""


static func is_json_object(text: String) -> bool:
	var json := JSON.new()
	return json.parse(text) == OK and typeof(json.data) == TYPE_DICTIONARY


static func remove(path: String) -> void:
	for candidate in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(candidate)
