class_name CharacterClass
extends Resource
## Class presentation and starting basic melee attack.

@export var id: String
@export var name_key: String
@export var description_key: String
@export var role_key: String
@export_enum("sword", "dagger", "staff") var basic_weapon: String = "sword"
@export var basic_damage: int = 12
@export var basic_interval: float = 1.0
@export var basic_range: float = 1.8
