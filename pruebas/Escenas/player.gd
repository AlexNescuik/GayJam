extends CharacterBody2D

# --- CONFIGURACIÓN DE MOVIMIENTO ---
const VELOCIDAD_NORMAL = 110.0
const VELOCIDAD_CORRER = 180.0
const FUERZA_SALTO = -280.0
const GRAVEDAD = 980.0

# --- CONFIGURACIÓN DEL SALTO ---
const CORTE_SALTO = 0.5       # Salto variable
const MAX_SALTOS = 2          # Doble salto
var saltos_disponibles = 0

@onready var animaciones = $AnimatedSprite2D

func _physics_process(delta):
	# 1. Gravedad
	if not is_on_floor():
		velocity.y += GRAVEDAD * delta
	
	# 2. SISTEMA DE SALTO (Recarga al tocar suelo)
	if is_on_floor():
		saltos_disponibles = MAX_SALTOS

	# Salto inicial y Doble Salto
	if Input.is_action_just_pressed("ui_accept"):
		if saltos_disponibles > 0:
			velocity.y = FUERZA_SALTO
			saltos_disponibles -= 1
			
	# Corte de salto (Variable Jump)
	if Input.is_action_just_released("ui_accept") and velocity.y < 0:
		velocity.y *= CORTE_SALTO

	# 3. MOVIMIENTO HORIZONTAL Y CORRER
	# Determinamos la velocidad actual dependiendo de si presionamos "correr"
	var velocidad_actual = VELOCIDAD_NORMAL
	
	if Input.is_action_pressed("Correr"):
		velocidad_actual = VELOCIDAD_CORRER

	var direccion = Input.get_axis("ui_left", "ui_right")
	
	if direccion:
		velocity.x = direccion * velocidad_actual
	else:
		velocity.x = move_toward(velocity.x, 0, velocidad_actual)

	# 4. ANIMACIONES
	actualizar_animacion(direccion)
	
	move_and_slide()

func actualizar_animacion(direccion):
	# Nota: Como aún no tienes animación de correr, 
	# usaremos "Caminado" pero se verá más rápido al moverse el personaje.
	if direccion != 0:
		animaciones.play("Caminado")
		animaciones.flip_h = (direccion < 0)
		
		# Opcional: Acelerar la animación si está corriendo
		if Input.is_action_pressed("Correr"):
			animaciones.speed_scale = 1.5 # Se mueve las patas más rápido
		else:
			animaciones.speed_scale = 1.0 # Velocidad normal
	else:
		animaciones.play("IDLE")
		animaciones.speed_scale = 1.0
