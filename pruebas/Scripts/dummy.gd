extends CharacterBody2D

const GRAVEDAD = 980.0

func _ready():
	if not is_in_group("enemigo"):
		add_to_group("enemigo")

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += GRAVEDAD * delta
	move_and_slide()

func morir():
	print("Enemigo destruido")
	queue_free()

# ---------------------------------------------------------
# Tu señal conectada debería verse así:
# ---------------------------------------------------------
func _on_hitbox_daño_body_entered(body):
	if body.has_method("recibir_daño") and body.has_method("morir"):
		
		var esta_rodando = body.es_invulnerable
		var esta_dasheando = (body.estado_actual == body.Estado.DASH)
		
		if not esta_rodando and not esta_dasheando:
			print("Enemigo lastimó")
			body.morir()
