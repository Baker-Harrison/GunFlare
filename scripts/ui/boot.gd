extends Node
## Entry scene: goes straight to the main menu unless a test match was
## requested on the command line (handled by Game).


func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--match"):
		Game.return_to_menu.call_deferred()
