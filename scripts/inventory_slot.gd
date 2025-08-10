extends Control

var item: Consumable = null

func set_item(consumable: Consumable) -> void:
	item = consumable
	if item == null:
		$TextureRect.texture = null
		$Label.text = ""
		$ProgressBar.visible = false
		$Button.disabled = false  # Make sure button is enabled when slot is empty
		return
	
	$TextureRect.texture = item.texture
	$ProgressBar.visible = item.cooldown

func _process(delta: float) -> void:
	if item == null:
		return

	var player = Man.get_player()
	var stack = player.bag.get_item_stack(item)
	
	var cooldown_active = item.cooldown and $Timer.time_left > 0.0
	$Button.disabled = (not player.alive) or cooldown_active

	if stack != null:
		$Label.text = str(stack.amount) + "x"
		if item.cooldown:
			$ProgressBar.value = ($Timer.time_left / $Timer.wait_time) * 100.0
	else:
		set_item(null)


func _on_pressed() -> void:
	if item == null:
		return
	if not item.infinite:
		Man.get_player().bag.take_item(item, 1)

	item.on_consume.call()

	if item.cooldown:
		$Timer.wait_time = item.cooldown_seconds
		$Timer.start()
		$Button.disabled = true
		$ProgressBar.value = 0

func _on_timer_timeout() -> void:
	$Button.disabled = false
	$Timer.stop()
