extends Node
## Placeholder audio manager autoload.
## Provides an interface for playing sounds and music.
## Audio files can be added later without changing game code.

var sfx_enabled := true
var music_enabled := true
var sfx_volume := 1.0
var music_volume := 0.7

func play_sfx(sound_name: String) -> void:
	if not sfx_enabled:
		return
	# Placeholder: load and play sound from res://assets/sfx/{sound_name}.wav
	# var stream = load("res://assets/sfx/%s.wav" % sound_name)
	pass

func play_music(track_name: String) -> void:
	if not music_enabled:
		return
	# Placeholder: load and play music from res://assets/music/{track_name}.ogg
	pass

func stop_music() -> void:
	pass

func set_sfx_enabled(enabled: bool) -> void:
	sfx_enabled = enabled

func set_music_enabled(enabled: bool) -> void:
	music_enabled = enabled
	if not enabled:
		stop_music()

func tap() -> void:
	play_sfx("tap")

func collect() -> void:
	play_sfx("collect")

func milestone() -> void:
	play_sfx("milestone")

func prestige() -> void:
	play_sfx("prestige")

func buy() -> void:
	play_sfx("buy")

func hire() -> void:
	play_sfx("hire")
