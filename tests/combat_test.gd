extends SceneTree
## Exercise proximity combat, optional targeting, hit feedback, death and respawning.

var failures: int = 0
var deaths: int = 0
var player_deaths: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var store: Node = root.get_node("CharacterStore")
	for class_id in ["warrior", "rogue", "mage"]:
		# Configure memory only; never write to the player's real save.
		store.characters.assign([{"id": "combat_test", "name": "Combat test", "class_id": class_id}])
		store.selected_character_id = "combat_test"
		var scene: Node3D = load("res://scenes/main.tscn").instantiate()
		root.add_child(scene)
		var player: CharacterBody3D = scene.get_node("Player")
		player.respawned.connect(_on_player_respawned)
		var enemy: BasicSkeleton = scene.get_node("BasicSkeleton")
		enemy.defeated.connect(_on_defeated)
		var visual: CharacterVisual = player.get_node("Model/Library")
		await _frames(10)
		_check(enemy.health_bar.value == enemy.MAX_HEALTH and enemy.nameplate.visible, "The living enemy displays its overhead health bar")
		_check(visual.model.find_child("BasicWeapon", true, false) != null, class_id + " enters with a weapon equipped")
		_check(player.target == null and not player.auto_attacking, "Combat starts without an active target")
		_key(KEY_TAB)
		_check(player.target == enemy and enemy.selection.visible, "Tab selects the skeleton and displays its ring")
		var camera: Camera3D = scene.get_node("Camera3D")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = camera.unproject_position(enemy.global_position + Vector3.UP * 0.85)
		click.pressed = true
		root.push_input(click, true)
		click.pressed = false
		root.push_input(click, true)
		_check(player.target == enemy, "Clicking can select a preferred target")
		await _frames(60)
		_check(not player.auto_attacking and enemy.attacker == null, "Both actors wait outside detection and melee range")
		_check(enemy.health == enemy.MAX_HEALTH and player.health == player.MAX_HEALTH, "Neither actor attacks from out of range")

		# The enemy notices and approaches before the player is in melee range.
		player.position = enemy.home + Vector3(0, 0, enemy.AGGRO_RADIUS - 0.1)
		await _frames(3)
		_check(enemy.attacker == player and enemy.position.distance_to(enemy.home) > 0.02, "Approaching the skeleton triggers pursuit without hitting it")
		_check(not player.auto_attacking and enemy.health == enemy.MAX_HEALTH, "The player's attack waits for melee range")
		player.position = enemy.home + Vector3(12, 0, 0)
		await _frames(2)
		player.stop_combat()

		# Entering range starts a swing without selecting a target or pressing a key.
		player.position = enemy.home + Vector3(0, 0, 1.5)
		await _frames(5)
		_check(player.target == enemy and player.auto_attacking, "Proximity automatically selects and attacks a nearby enemy")
		_check(visual.animations.current_animation == "Attack", "The weapon swing animates")
		_check(enemy.health == enemy.MAX_HEALTH, "Damage waits until impact")
		player.position = enemy.home + Vector3(12, 0, 0)
		await _frames(30)
		_check(enemy.health == enemy.MAX_HEALTH and not player.auto_attacking, "Leaving range during windup prevents the hit and stops attacking")
		player.stop_combat()

		player.position = enemy.home + Vector3(0, 0, 1.5)
		await _frames(20)
		_check(enemy.health == enemy.MAX_HEALTH - player.definition.basic_damage, "The class's configured damage is applied once per impact")
		_check(enemy.health_bar.value == enemy.health, "The enemy health bar decreases with damage")
		_check(_has_basic_hit(enemy.visual, player.definition.basic_damage), "The enemy displays the basic hit name and damage")
		_check(enemy.attacker == player, "The skeleton fights the nearby player")
		var saw_player_feedback := false
		var hits: int = 1
		var previous_health: int = enemy.health
		for frame in range(300):
			await _frames(1)
			saw_player_feedback = saw_player_feedback or _has_basic_hit(visual, enemy.DAMAGE)
			if enemy.health < previous_health:
				hits += 1
				previous_health = enemy.health
			if enemy.dead:
				break
		_check(saw_player_feedback, "The player displays the enemy's basic hit name and damage")
		_check(hits >= 3 and hits <= 4, "The skeleton takes three or four basic hits for " + class_id)
		_check(player.health > 0 and player.health < player.MAX_HEALTH and player_deaths == 0, "The skeleton damages the player without killing them")
		_check(enemy.dead and enemy.health == 0, "Repeated basic attacks kill the skeleton for " + class_id)
		_check(enemy.health_bar.value == 0 and not enemy.nameplate.visible, "The enemy health bar empties and hides on death")
		_check(not enemy.get_collision_layer_value(2), "A corpse cannot be targeted by clicking")
		enemy.take_damage(999, player)
		_check(deaths == 1, "Each skeleton death emits a single defeat event")
		_check(player.target == null and not player.auto_attacking, "Killing the target stops automatic attacks")
		player.position = player.spawn_position
		await _frames(400)
		_check(not enemy.dead and enemy.health == enemy.MAX_HEALTH, "The skeleton respawns at full health")
		_check(enemy.health_bar.value == enemy.MAX_HEALTH and enemy.nameplate.visible, "The health bar returns full when the enemy respawns")
		_check(enemy.position.distance_to(enemy.home) < 0.03, "Respawning restores the enemy's home position")

		# Even consecutive fights at one health must remain safe for practice.
		player.health = 1
		player.position = enemy.position + Vector3(0, 0, 1.1)
		await _frames(45)
		_check(player.health == 1 and player_deaths == 0 and enemy.attacker == player and not enemy.hit_pending, "The starter skeleton cannot deal a killing blow")
		_check(_has_basic_hit(visual, 0), "A nonlethal hit at one health still displays its name and actual zero damage")

		player.position = enemy.position + Vector3(0, 0, 1.5)
		enemy.take_damage(1, player)
		player.position = enemy.home + Vector3(12, 0, 0)
		await _frames(2)
		_check(enemy.attacker == null and enemy.health == enemy.MAX_HEALTH, "Leaving the combat area resets the skeleton")
		player.position = enemy.position + Vector3(0, 0, 1.5)
		player.select_target(enemy)
		enemy.take_damage(1, player)
		player.take_damage(player.MAX_HEALTH)
		_check(player.health == player.MAX_HEALTH and player.position == player.spawn_position, "Player death restores health at the starting point")
		_check(player.target == null and enemy.attacker == null and enemy.health == enemy.MAX_HEALTH, "Player death resets both sides of combat")
		scene.queue_free()
		await _frames(3)
		deaths = 0
		player_deaths = 0
	if failures == 0:
		print("PASS: all class weapons, proximity combat, targeting, hit names/damage, range, windup, nonlethal attacks and respawning.")
	quit(0 if failures == 0 else 1)


func _has_basic_hit(visual: CharacterVisual, damage: int) -> bool:
	for child: Node in visual.get_children():
		if child is Label3D and child.text == "%s\n%d" % [TranslationServer.translate("COMBAT_BASIC_HIT"), damage]:
			return true
	return false


func _key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	root.push_input(event)
	event.pressed = false
	root.push_input(event)


func _on_defeated(_enemy: BasicSkeleton, _source: Node3D, _attack_id: StringName) -> void:
	deaths += 1


func _on_player_respawned() -> void:
	player_deaths += 1


func _frames(count: int) -> void:
	for frame in range(count):
		await physics_frame
		await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
