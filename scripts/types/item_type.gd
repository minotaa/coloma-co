extends Object
class_name ItemType

var name: String
var id: int
var description: String
var rarity: String = "COMMON" # COMMON, UNCOMMON, RARE, EPIC, LEGENDARY
var texture: Texture
var purchasable: bool = false
var price: int = 0
var shop_type: String = "ANY"

func _init(id: int, name: String, texture: Texture) -> void:
	self.id = id
	self.name = name
	self.texture = texture

func _to_string() -> String:
	return name + " (" + str(id) + ")"
