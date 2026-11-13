class_name CharacterVisual
extends Node3D
## KayKit's characters and animation packs share the authored Rig_Medium skeleton.

const GENERAL = preload("res://assets/KayKit_Adventurers_2.0_FREE/Animations/gltf/Rig_Medium/Rig_Medium_General.glb")
const MOVEMENT = preload("res://assets/KayKit_Adventurers_2.0_FREE/Animations/gltf/Rig_Medium/Rig_Medium_MovementBasic.glb")
var class_id: String = ""
var model: Node3D
var animations: AnimationPlayer


func set_class(id: String) -> void:
	if id == class_id and is_instance_valid(model):
		return
	var definition := CharacterClasses.find_class(id)
	if definition == null:
		definition = CharacterClasses.find_class("warrior")
	class_id = definition.id
	if is_instance_valid(model):
		remove_child(model)
		model.queue_free()
	model = definition.model.instantiate()
	add_child(model)
	animations = AnimationPlayer.new()
	animations.name = "AnimationPlayer"
	model.add_child(animations)
	var library := AnimationLibrary.new()
	_add_clip(library, GENERAL, "Idle_A", "Idle")
	_add_clip(library, MOVEMENT, "Walking_A", "Walk")
	animations.add_animation_library("", library)
	animations.play("Idle")
	animations.advance(0)


func _add_clip(library: AnimationLibrary, source: PackedScene, source_name: String, name_in_game: String) -> void:
	var rig := source.instantiate()
	var source_player: AnimationPlayer = rig.get_node("AnimationPlayer")
	var animation: Animation = source_player.get_animation(source_name).duplicate()
	animation.loop_mode = Animation.LOOP_LINEAR
	library.add_animation(name_in_game, animation)
	rig.free()
