extends Node2D

signal hbox_deleted(path: String)

@onready var music_file_dialog: FileDialog = %MusicFileDialog
@onready var audio_player: AudioStreamPlayer = %AudioPlayer
@onready var seek_bar: HSlider = %SeekBar
@onready var seek_timer: Timer = %SeekTimer
@onready var history_container: VBoxContainer = %HistoryContainer
@onready var history_animations: AnimationPlayer = %HistoryAnimations
@onready var play_ui_handler_animations: AnimationPlayer = %PlayUIHandlerAnimations
@onready var volume_slider: VSlider = %VolumeSlider
@onready var playlist_container: VBoxContainer = %PlaylistContainer
@onready var playlist_name: Label = %PlaylistName
@onready var playlist_edit: LineEdit = %PlaylistEdit
@onready var playlist_animations: AnimationPlayer = %PlaylistAnimations
@onready var playlist_file_dialog: FileDialog = %PlaylistFileDialog
@onready var loop_current_song_check: CheckButton = %LoopCurrentSongCheck
@onready var loop_playlist_check: CheckButton = %LoopPlaylistCheck
@onready var randomize_songs_check: CheckButton = %RandomizeSongsCheck
@onready var play_button: Button = %PlayButton
@onready var credits: RichTextLabel = %Credits

var mouse_on_seek_bar := false
var was_mouse_on_seek_bar := false
var last_mouse_position := Vector2.ZERO
var master_bus: int = AudioServer.get_bus_index("Master")
var playlist_data: Array[String]
var song_index: int = 0
var is_stream_finished := false


func _ready() -> void:
	music_file_dialog.hide()

	history_animations.assigned_animation = "close"
	playlist_animations.assigned_animation = "close"
	volume_slider.value = AudioServer.get_bus_volume_db(master_bus)

	hbox_deleted.connect(
		func (path: String) -> void:
			playlist_data.erase(path)
	)

	var home_dir := (
		"USERPROFILE" if OS.get_name() == "Windows"
		else "HOME"
	)

	music_file_dialog.root_subfolder = OS.get_environment(home_dir)
	playlist_file_dialog.root_subfolder = OS.get_environment(home_dir)


func _process(_delta: float) -> void:
	handle_seeking()

	if audio_player.playing:
		seek_bar.value = audio_player.get_playback_position()

	last_mouse_position = get_global_mouse_position()

	play_button.text = (
			"PAUSE" if audio_player.playing
			else "PLAY"
		)


func handle_seeking() -> void:
	var drag_condition: bool = (
		Input.is_action_pressed("left_click") and
		(mouse_on_seek_bar or was_mouse_on_seek_bar) and
		seek_timer.is_stopped()
	)

	if Input.is_action_just_pressed("left_click") and mouse_on_seek_bar:
		seek_timer.start()

		if audio_player.playing:
			audio_player.play(seek_bar.value)
	elif drag_condition:
		was_mouse_on_seek_bar = true

		if get_global_mouse_position() != last_mouse_position and audio_player.playing:
			audio_player.play(seek_bar.value)
	elif Input.is_action_just_released("left_click") and seek_timer.is_stopped():
		was_mouse_on_seek_bar = false


func _on_browse_button_pressed() -> void:
	music_file_dialog.visible = not music_file_dialog.visible


func _on_music_file_dialog_file_selected(path: String) -> void:
	audio_player.stream = load_stream(path)

	update_seek_bar()
	audio_player.play()
	add_to_vbox(path, history_container)


func load_stream(path: String) -> AudioStream:
	var audio_stream: AudioStream
	var file_type := path.split(".")[-1].to_lower()

	match file_type:
		"mp3":
			audio_stream = AudioStreamMP3.load_from_file(path)
		"ogg":
			audio_stream = AudioStreamOggVorbis.load_from_file(path)
		"wav":
			audio_stream = AudioStreamWAV.load_from_file(path)

	return audio_stream


func update_seek_bar() -> void:
	seek_bar.max_value = audio_player.stream.get_length()
	seek_bar.value = 0.0


func _on_seek_bar_mouse_entered() -> void:
	mouse_on_seek_bar = true


func _on_seek_bar_mouse_exited() -> void:
	mouse_on_seek_bar = false


func _on_history_button_pressed() -> void:
	if history_animations.assigned_animation == "close":
		history_animations.play("open")
		play_ui_handler_animations.play("contract")
	else:
		history_animations.play("close")
		play_ui_handler_animations.play("expand")


func add_to_vbox(path: String, vbox: VBoxContainer, should_emit_signal := false) -> void:
	var hbox := HBoxContainer.new()
	var audio_button := Button.new()
	var close_button := Button.new()
	var file_name := path.split("/")[-1]

	close_button.text = "X"
	audio_button.text = file_name

	close_button.add_theme_color_override("font_color", Color.RED)

	vbox.add_child(hbox)
	hbox.add_child(close_button)
	hbox.add_child(audio_button)

	close_button.pressed.connect(
		func () -> void:
			hbox.queue_free()

			if should_emit_signal:
				hbox_deleted.emit(path)
	)

	audio_button.pressed.connect(
		func () -> void:
			audio_player.stream = load_stream(path)

			song_index = playlist_data.find(path)

			update_seek_bar()
			audio_player.play()
			add_to_vbox(path, history_container)
	)


func _on_volume_button_pressed() -> void:
	volume_slider.visible = not volume_slider.visible


func _on_volume_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(master_bus, value)


func _on_playlist_button_pressed() -> void:
	if playlist_animations.assigned_animation == "close":
		playlist_animations.play("open")
		play_ui_handler_animations.play("contract")
	else:
		playlist_animations.play("close")
		play_ui_handler_animations.play("expand")


func _on_rename_playlist_button_pressed() -> void:
	playlist_name.hide()
	playlist_edit.show()


func _on_playlist_edit_text_submitted(new_text: String) -> void:
	playlist_name.text = new_text
	playlist_name.visible = true
	playlist_edit.visible = false


func _on_add_to_playlist_button_pressed() -> void:
	playlist_file_dialog.visible = not playlist_file_dialog.visible


func _on_playlist_file_dialog_files_selected(paths: PackedStringArray) -> void:
	for path: String in paths:
		if not playlist_data.has(path):
			add_to_vbox(path, playlist_container, true)

			playlist_data.append(path)


func _on_loop_current_song_check_pressed() -> void:
	if loop_current_song_check.button_pressed:
		loop_playlist_check.disabled = true
		randomize_songs_check.disabled = true
	else:
		loop_playlist_check.disabled = false
		randomize_songs_check.disabled = false


func _on_loop_playlist_check_pressed() -> void:
	if loop_playlist_check.button_pressed:
		randomize_songs_check.disabled = false
		loop_current_song_check.disabled = true
	else:
		randomize_songs_check.disabled = true
		loop_current_song_check.disabled = false


func _on_audio_player_finished() -> void:
	if loop_current_song_check.button_pressed:
		audio_player.play()
	elif loop_playlist_check.button_pressed and not randomize_songs_check.button_pressed:
		song_index += 1

		if song_index >= playlist_data.size():
			song_index = 0

		audio_player.stream = load_stream(playlist_data[song_index])

		update_seek_bar()
		audio_player.play()
		add_to_vbox(playlist_data[song_index], history_container)
	elif randomize_songs_check.button_pressed and loop_playlist_check.button_pressed:
		var stream: String = playlist_data.pick_random()

		song_index = playlist_data.find(stream)

		audio_player.stream = load_stream(stream)

		update_seek_bar()
		audio_player.play()
		add_to_vbox(stream, history_container)
	else:
		is_stream_finished = true


func _on_play_button_pressed() -> void:
	if audio_player.stream != null:
		if not is_stream_finished:
			if not audio_player.playing:
				audio_player.play(seek_bar.value)
			else:
				audio_player.stream_paused = true
		else:
			audio_player.play()

			update_seek_bar()

			is_stream_finished = false


func _on_credits_button_pressed() -> void:
	credits.visible = not credits.visible


func _on_credits_meta_clicked(meta: Variant) -> void:
	OS.shell_open(str(meta))
