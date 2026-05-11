extends RefCounted
class_name CustomerPool

var _pool: Array[Control] = []
var _scene: PackedScene

func _init(scene: PackedScene, initial_size: int = 5) -> void:
	_scene = scene
	for i in range(initial_size):
		var node = _scene.instantiate()
		node.visible = false
		_pool.append(node)

func acquire() -> Control:
	if _pool.size() > 0:
		var node = _pool.pop_back()
		node.visible = true
		return node
	var node = _scene.instantiate()
	return node

func return_node(node: Control) -> void:
	if not is_instance_valid(node):
		return
	node.visible = false
	if node.get_parent():
		node.get_parent().remove_child(node)
	_pool.append(node)

func clear() -> void:
	for node in _pool:
		if is_instance_valid(node):
			node.queue_free()
	_pool.clear()

func get_pool_size() -> int:
	return _pool.size()
