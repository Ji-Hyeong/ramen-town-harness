extends Node
## Short local PCM cues accompany committed actions. Audio never owns input,
## recipe state or timing. One player per cue and finite polyphony bound voices.
## Mute is an explicit current-run preference; it is not part of save schema13.

const CUES: Dictionary = {
	"tap": preload("res://assets/audio/tap.wav"),
	"ingredient": preload("res://assets/audio/ingredient.wav"),
	"broth": preload("res://assets/audio/broth.wav"),
	"noodle": preload("res://assets/audio/noodle.wav"),
	"plate": preload("res://assets/audio/plate.wav"),
	"complete": preload("res://assets/audio/complete.wav"),
	"discover": preload("res://assets/audio/discover.wav"),
	"refuse": preload("res://assets/audio/refuse.wav"),
}
var muted: bool = false
var _players: Dictionary = {}
var _counts: Dictionary = {}


func _ready() -> void:
	for id in CUES:
		var player := AudioStreamPlayer.new()
		player.stream = CUES[id]
		player.volume_db = -12.0
		player.max_polyphony = 2
		add_child(player)
		_players[id] = player


## Even counters only track accepted cues, so canceled swipes/mute can be tested
## without mistaking a dummy audio backend for a human listening test.
func play(id: String) -> void:
	if not CUES.has(id):
		push_error("Unknown action audio cue: " + id)
		return
	if muted:
		return
	_counts[id] = int(_counts.get(id, 0)) + 1
	(_players[id] as AudioStreamPlayer).play()


func count(id: String) -> int:
	return int(_counts.get(id, 0))


## Stop every voice immediately; toggling mute cannot leave a completion sound
## playing in the background or mutate the player's normal game save.
func set_muted(value: bool) -> void:
	muted = value
	if muted:
		for player in _players.values():
			(player as AudioStreamPlayer).stop()
