extends Control

signal patience_expired(customer_data: Dictionary)

@onready var sprite: Label = %CustomerSprite
@onready var name_label: Label = %CustomerName
@onready var patience_bar: ProgressBar = %PatienceBar
@onready var bubble: Label = %Bubble

var customer_data: Dictionary = {}
var _patience_max: float = 45.0
var _patience_current: float = 45.0
var _is_waiting: bool = false
var _is_served: bool = false

const TYPE_ICONS := {
	"normal": "🧑",
	"sick": "🤒",
	"special": "🧐",
}

const TYPE_COLORS := {
	"normal": Color.WHITE,
	"sick": Color(0.8, 1.0, 0.8),
	"special": Color(1.0, 0.9, 0.7),
}

func setup(data: Dictionary) -> void:
	customer_data = data
	_patience_max = data.get("patience", 45.0)
	_patience_current = _patience_max
	_is_waiting = true
	_is_served = false

	var type = data.get("type", "normal")
	sprite.text = TYPE_ICONS.get(type, "🧑")
	modulate = TYPE_COLORS.get(type, Color.WHITE)

	match type:
		"normal":
			name_label.text = "普通客人"
			bubble.text = "想吃点东西"
		"sick":
			name_label.text = "不适客人"
			bubble.text = data.get("symptom_name", "不舒服")
		"special":
			name_label.text = "特殊客人"
			bubble.text = "想要特别的"

	patience_bar.max_value = _patience_max
	patience_bar.value = _patience_current

func _process(delta: float) -> void:
	if not _is_waiting or _is_served:
		return
	_patience_current -= delta
	patience_bar.value = _patience_current
	if _patience_current / _patience_max < 0.3:
		patience_bar.modulate = Color.RED
	elif _patience_current / _patience_max < 0.6:
		patience_bar.modulate = Color.ORANGE
	if _patience_current <= 0:
		_is_waiting = false
		patience_expired.emit(customer_data)

func mark_served() -> void:
	_is_served = true
	_is_waiting = false

func pause_patience() -> void:
	_is_waiting = false

func resume_patience() -> void:
	if not _is_served:
		_is_waiting = true

func get_patience_ratio() -> float:
	return _patience_current / _patience_max
