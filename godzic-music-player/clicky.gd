## This is just a base button that plays a sound when clicked.

extends Button
class_name Clicky

@onready var sfx_player: AudioStreamPlayer = get_tree().current_scene.get_node_or_null("%SfxPlayer")


func _ready() -> void:
	pressed.connect(sfx_player.play)
