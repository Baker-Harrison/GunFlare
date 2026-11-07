class_name StreakData
extends UnlockableData
## kind == "killstreak": earned after `count` kills without dying.
## kind == "deathstreak": active after `count` deaths without a kill.

@export var count: int = 3
## True for the top reward that ends the match outright.
@export var ends_match: bool = false
