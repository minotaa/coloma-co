extends Control

var item: ItemType

func set_item(item: ItemType) -> void:
	self.item = item
	tooltip_text = item.description
	$Button.tooltip_text = item.description
	$TextureRect.texture = item.texture
	$HBoxContainer/Gold.text = str(item.price)
	$Label.text = item.name

func _on_button_pressed() -> void:
	var player = Man.get_player()
	var bag = player.bag
	var upgrade_bag = player.upgrade_bag

	if player.gold >= item.price:
		if not item is Upgrade:
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
			# Check if the player already has this upgrade
			var has_stack := false
			for stack in upgrade_bag.list:
				if stack.type.id == item.id:
					has_stack = true
					break
			if has_stack:
				var item_stack = upgrade_bag.get_item_stack(item)
				
				if item_stack.data["level"] >= item.max_level:
					Toast.add(item.name + " is already at max level!")
					return
				
				item_stack.data["level"] = item_stack.data["level"] + 1
				for stack in Man.get_player().upgrade_bag.list:
					if stack.type == item:
						stack.data["level"] = item_stack.data["level"]
						break
				Toast.add("You purchased: " + str(item_stack))
				Toast.add("-" + str(item.price) + " Gold")
				player.gold -= item.price
			else:
				if item.max_level <= 0:
					Toast.add(item.name + " cannot be purchased.")
					return
				var item_stack = ItemStack.new(item, 1)
				item_stack.data["level"] = 1
				upgrade_bag.add_item(item_stack)
				Toast.add("You purchased: " + str(item_stack))
				Toast.add("-" + str(item.price) + " Gold")
				player.gold -= item.price
	else:
		Toast.add("You can't afford this!")
