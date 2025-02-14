extends Inventory
class_name Bag

func is_full() -> bool:
	return total_size() >= get_max_capacity()

func get_max_capacity() -> int:
	var max_capacity = 25
	return max_capacity
	
func add_fragile_item(item: ItemStack) -> bool:
	for i in list:
		if i.type.id == item.type.id:
			var space_left = get_max_capacity() - total_size()
			if space_left <= 0:
				return false
			var amount_to_add = min(space_left, item.amount)
			i.amount += amount_to_add
			item.amount -= amount_to_add
			if item.amount == 0:
				return true

	if not is_full():
		var space_left = get_max_capacity() - total_size()
		var amount_to_add = min(space_left, item.amount)
		var new_stack = ItemStack.new(item.type, amount_to_add)
		list.append(new_stack)
		item.amount -= amount_to_add
		return true
	return false
