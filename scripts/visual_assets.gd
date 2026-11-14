class_name VisualAssets
extends RefCounted
## Optional presentation resources. Gameplay data never loads these files.

const ROOT := "res://assets/KayKit_Adventurers_2.0_FREE/"
const MODELS := {
	"warrior": ROOT + "Characters/gltf/Knight.glb",
	"rogue": ROOT + "Characters/gltf/Rogue_Hooded.glb",
	"mage": ROOT + "Characters/gltf/Mage.glb",
	"skeleton": "res://assets/KayKit_Skeletons_1.1_FREE/characters/gltf/Skeleton_Minion.glb",
	"mannequin": "res://assets/Universal Animation Library[Standard]/Unreal-Godot/UAL1_Standard.glb",
}
const GENERAL := ROOT + "Animations/gltf/Rig_Medium/Rig_Medium_General.glb"
const MOVEMENT := ROOT + "Animations/gltf/Rig_Medium/Rig_Medium_MovementBasic.glb"


static func scene(path: String) -> PackedScene:
	if OS.get_environment("LUNA_NO_ASSETS") == "1" or not ResourceLoader.exists(path, "PackedScene"):
		return null
	return load(path) as PackedScene
