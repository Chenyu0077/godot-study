extends RigidBody2D


# Called when the node enters the scene tree for the first time.
func _ready():
	var mob_types = Array($AnimatedSprite2D.sprite_frames.get_animation_names())
	$AnimatedSprite2D.animation = mob_types.pick_random()
	$AnimatedSprite2D.play()
	
	
# 退出屏幕时销毁自身
func _on_visible_on_screen_notifier_2d_screen_exited():
	queue_free()
