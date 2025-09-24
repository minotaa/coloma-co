extends Control

var item: ItemType

func set_item(item: ItemType) -> void:
	self.item = item
	tooltip_text = item.description
	$TextureRect.texture = item.texture
	$HBoxContainer/Gold.text = str(item.price)
	$Label.text = item.name

func _on_button_pressed() -> void:
	var player = Man.get_player()
	var bag = player.bag

	if player.gold >= item.price:
		# Check if the player already has this item
		var has_stack := false
		for stack in bag.list:
			if stack.type == item:
				has_stack = true
				break

		# Allow purchase if there is space OR if they already have a stack of this item
		if has_stack or bag.list.size() < 3:
			player.gold -= item.price
			bag.add_item(ItemStack.new(item, 1))
			Toast.add("You purchased: " + str(ItemStack.new(item, 1)))
			Toast.add("-" + str(item.price) + " Gold")
		else:
			Toast.add("You don't have the inventory space!")
	else:
		Toast.add("You can't afford this!")
