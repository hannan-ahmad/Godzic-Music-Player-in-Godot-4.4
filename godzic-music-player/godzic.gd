extends Node2D

@export var section_animation_duration := 0.5

@onready var music_file_dialogue: FileDialog = %MusicFileDialogue
@onready var audio_player: AudioStreamPlayer = %AudioPlayer
@onready var seek_bar: HSlider = %SeekBar
@onready var play_button: Clicky = %PlayButton
@onready var history_section: Control = %HistorySection
@onready var play_handler: Control = %PlayHandler
@onready var volume_slider: VSlider = %VolumeSlider
@onready var song_label: Label = %SongLabel
@onready var history_container: VBoxContainer = %HistoryContainer
@onready var player_handler_animation_player: AnimationPlayer = %PlayerHandlerAnimationPlayer
@onready var history_animation_player: AnimationPlayer = %HistoryAnimationPlayer
@onready var playlist_button: Clicky = $CanvasLayer/UI/Playlist/PlaylistButton
@onready var playlist_animation_player: AnimationPlayer = $PlaylistAnimationPlayer
@onready var playlist_edit: LineEdit = %PlaylistEdit
@onready var playlist_name: Label = %PlaylistName
@onready var playlist_container: VBoxContainer = %PlaylistContainer
@onready var playlist_file_dialog: FileDialog = %PlaylistFileDialog
@onready var loop_song_check: CheckBox = %LoopSongCheck
@onready var loop_playlist_check: CheckBox = %LoopPlaylistCheck
@onready var randomize_playlist_check: CheckBox = %RandomizePlaylistCheck
@onready var about_text: RichTextLabel = %AboutText

var is_seekbar_dragging := false
var audio_bus: int = AudioServer.get_bus_index("Master")
var history_data: Dictionary[String, Label]
var is_history_visible := false
var is_playlist_visible := false
var playlist_data: Array[String] = []
var is_audio_finished := false
var playlist_song_index: int = 0


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_music_browser"):
		music_file_dialogue.show()


func _process(_delta: float) -> void:
	if audio_player.playing and not is_seekbar_dragging:
		seek_bar.value = audio_player.get_playback_position()

	if audio_player.playing:
		play_button.text = "PAUSE"
	else:
		play_button.text = "PLAY"


func _on_browse_button_pressed() -> void:
	music_file_dialogue.visible = not music_file_dialogue.visible


func _on_music_file_dialogue_file_selected(path: String) -> void:
	if is_file_valid(path):
		audio_player.stream = load_stream(path)
		song_label.text = path.split("/")[-1]

		update_seek_bar()
		audio_player.play()
		add_to_history(path)


func load_stream(path: String) -> AudioStream:
	var audio_stream: AudioStream
	var file_type := path.split(".")[-1].to_lower()

	if file_type == "mp3":
		audio_stream = AudioStreamMP3.load_from_file(path)
	elif file_type == "ogg":
		audio_stream = AudioStreamOggVorbis.load_from_file(path)
	elif file_type == "wav":
		audio_stream = AudioStreamWAV.load_from_file(path)

	return audio_stream


func is_file_valid(path: String) -> bool:
	var file_type := path.split(".")[-1].to_lower()

	return (
		file_type == "mp3" or
		file_type == "wav" or
		file_type == "ogg"
	)


func update_seek_bar() -> void:
	seek_bar.max_value = audio_player.stream.get_length()
	seek_bar.value = 0.0


func _on_seek_bar_drag_started() -> void:
	is_seekbar_dragging = true


func _on_seek_bar_drag_ended(value_changed: bool) -> void:
	if value_changed:
		audio_player.play(seek_bar.value)

	is_seekbar_dragging = false


func _on_play_button_pressed() -> void:
	if not is_audio_finished:
		audio_player.stream_paused = not audio_player.stream_paused
	else:
		audio_player.play()
		is_audio_finished = false


func _on_history_button_pressed() -> void:
	if is_history_visible:
		history_animation_player.play("close")
		player_handler_animation_player.play("open", -1, -1, true)
	else:
		history_animation_player.play("open")
		player_handler_animation_player.play("open")

	is_history_visible = not is_history_visible


func _on_volume_button_pressed() -> void:
	volume_slider.visible = not volume_slider.visible


func _on_volume_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(audio_bus, value)


func add_to_history(path: String) -> void:
	if not history_data.has(path):
		var hbox := HBoxContainer.new()
		var button_close := Clicky.new()
		var count_label := Label.new()
		var song_button := Clicky.new()

		history_container.add_child(hbox)
		hbox.add_child(button_close)
		hbox.add_child(count_label)
		hbox.add_child(song_button)

		button_close.text = "X"
		count_label.text = "1"
		song_button.text = path.split("/")[-1]

		button_close.add_theme_color_override("font_color", Color.RED)

		button_close.pressed.connect(
			func () -> void:
				hbox.queue_free()
				history_data.erase(path)
		)

		song_button.pressed.connect(
			func () -> void:
				count_label.text = str(int(count_label.text) + 1)
				audio_player.stream = load_stream(path)
				song_label.text = path.split("/")[-1]
				song_button.focus_mode = Control.FOCUS_NONE

				update_seek_bar()
				audio_player.play()
		)

		history_data[path] = count_label
	else:
		history_data[path].text = str(int(history_data[path].text) + 1)


func _on_playlist_button_pressed() -> void:
	if is_playlist_visible:
		playlist_animation_player.play("close")
		player_handler_animation_player.play("open", -1, -1, true)
	else:
		playlist_animation_player.play("open")
		player_handler_animation_player.play("open")

	is_playlist_visible = not is_playlist_visible


func _on_rename_playlist_button_pressed() -> void:
	playlist_name.hide()
	playlist_edit.show()


func _on_playlist_edit_text_submitted(new_text: String) -> void:
	playlist_name.text = str(new_text)
	playlist_name.show()
	playlist_edit.hide()


func add_to_playlist(path: String) -> void:
	if not playlist_data.has(path):
		var hbox := HBoxContainer.new()
		var close_button := Clicky.new()
		var song_button := Clicky.new()

		close_button.text = "X"
		song_button.text = path.split("/")[-1]

		playlist_container.add_child(hbox)
		hbox.add_child(close_button)
		hbox.add_child(song_button)

		close_button.add_theme_color_override("font_color", Color.RED)

		song_button.pressed.connect(
			func () -> void:
				audio_player.stream = load_stream(path)
				song_button.focus_mode = Control.FOCUS_NONE
				playlist_song_index = playlist_data.find(path)
				song_label.text = path.split("/")[-1]

				update_seek_bar()
				audio_player.play()

				add_to_history(path)
		)

		close_button.pressed.connect(
			func () -> void:
				hbox.queue_free()
				playlist_data.erase(path)
		)

		playlist_data.append(path)


func _on_add_to_playlist_button_pressed() -> void:
	playlist_file_dialog.visible = not playlist_file_dialog.visible


func _on_playlist_file_dialog_files_selected(paths: PackedStringArray) -> void:
	for i: String in paths:
		add_to_playlist(i)


func _on_loop_song_check_pressed() -> void:
	loop_playlist_check.disabled = loop_song_check.button_pressed
	randomize_playlist_check.disabled = loop_song_check.button_pressed
	randomize_playlist_check.button_pressed = loop_playlist_check.button_pressed


func _on_loop_playlist_check_pressed() -> void:
	loop_song_check.disabled = loop_playlist_check.button_pressed
	randomize_playlist_check.disabled = loop_playlist_check.disabled

	if not loop_playlist_check.button_pressed:
		randomize_playlist_check.button_pressed = false


func _on_audio_player_finished() -> void:
	if loop_song_check.button_pressed:
		audio_player.play(0.0)
		update_seek_bar()
	elif loop_playlist_check.button_pressed and not randomize_playlist_check.button_pressed:
		playlist_song_index += 1

		if playlist_song_index >= playlist_data.size():
			playlist_song_index = 0

		audio_player.stream = load_stream(playlist_data[playlist_song_index])
		song_label.text = playlist_data[playlist_song_index].split("/")[-1]
		update_seek_bar()
		audio_player.play()
	elif randomize_playlist_check.button_pressed:
		var random_stream: String = playlist_data.pick_random()

		audio_player.stream = load_stream(random_stream)
		update_seek_bar()
		audio_player.play()
		song_label.text = random_stream.split("/")[-1]
	else:
		is_audio_finished = true


func _on_about_text_meta_clicked(meta: Variant) -> void:
	OS.shell_open(meta)


func _on_about_button_pressed() -> void:
	about_text.visible = not about_text.visible
