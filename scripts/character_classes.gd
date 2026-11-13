class_name CharacterClasses
extends RefCounted

const ALL = [
	preload("res://data/classes/warrior.tres"),
	preload("res://data/classes/rogue.tres"),
	preload("res://data/classes/mage.tres"),
]


static func find_class(id: String) -> CharacterClass:
	for definition: CharacterClass in ALL:
		if definition.id == id:
			return definition
	return null
