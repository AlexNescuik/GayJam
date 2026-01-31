extends CharacterBody2D

# --- CONFIGURACIÓN DE MOVIMIENTO ---
const VELOCIDAD_NORMAL = 100.0
const VELOCIDAD_CORRER = 170.0
const VELOCIDAD_BARRIDO = 200.0
const FUERZA_SALTO = -300.0
const GRAVEDAD = 980.0

# --- CONFIGURACIÓN DEL BARRIDO ---
const TIEMPO_MAX_BARRIDO = 0.9   # Duración máxima en segundos
var tiempo_barrido_actual = 0.0  # Contador
var bloqueo_barrido = false      # Candado para obligar a soltar teclas

# --- CONFIGURACIÓN DEL SALTO ---
const CORTE_SALTO = 0.5 

@onready var animaciones = $AnimatedSprite2D

# --- FUNCIONES ---
func _physics_process(delta):
	# 1. Gravedad
	if not is_on_floor():
		velocity.y += GRAVEDAD * delta

	var direccion = Input.get_axis("ui_left", "ui_right")
	var esta_barriendose = false

	# Detectamos si el jugador QUIERE barrerse (teclas presionadas)
	var intentando_barrer = is_on_floor() and Input.is_action_pressed("Correr") and Input.is_action_pressed("ui_down") and direccion != 0

	# Desbloqueo de teclas
	if not intentando_barrer:
		bloqueo_barrido = false
		tiempo_barrido_actual = 0.0
	
	# Si intenta barrerse y NO está bloqueado
	if intentando_barrer and not bloqueo_barrido:
		esta_barriendose = true
		velocity.x = direccion * VELOCIDAD_BARRIDO
		
		# Aumentamos el contador de tiempo
		tiempo_barrido_actual += delta
		
		if tiempo_barrido_actual >= TIEMPO_MAX_BARRIDO:
			bloqueo_barrido = true     # ¡Activamos el bloqueo!
			esta_barriendose = false   # Cortamos el barrido inmediatamente
	
	else:
		# --- MOVIMIENTO NORMAL ---
		
		# --- SALTO ---
		if Input.is_action_just_pressed("ui_accept") and is_on_floor():
			velocity.y = FUERZA_SALTO
		if Input.is_action_just_released("ui_accept") and velocity.y < 0:
			velocity.y *= CORTE_SALTO

		# Caminar / Correr
		var velocidad_actual = VELOCIDAD_NORMAL
		if Input.is_action_pressed("Correr"):
			velocidad_actual = VELOCIDAD_CORRER

		if direccion:
			velocity.x = direccion * velocidad_actual
		else:
			velocity.x = move_toward(velocity.x, 0, velocidad_actual)

	# APLICAR MOVIMIENTO
	move_and_slide()

	# GESTOR DE ANIMACIONES
	actualizar_animacion(direccion, esta_barriendose)


func actualizar_animacion(direccion, esta_barriendose):
	# --- ANIMACIÓN DE BARRIDO ---
	if esta_barriendose:
		# Si no se estaba reproduciendo, darle play
		if animaciones.animation != "Barrido":
			animaciones.play("Barrido")
		
		# LÓGICA DE CONGELAR FRAME
		# Si llegamos al frame 2 (o mayor), pausamos la animación para que se congele ahí
		if animaciones.frame >= 2:
			animaciones.pause()
			animaciones.frame = 2 # Forzamos que se quede en el 2 por si acaso
			
		animaciones.flip_h = (direccion < 0)
		return # Salimos para que no se ejecute lo de abajo

	# Si NO nos estamos barriendo, asegurarnos de que la animación no se quede pausada
	if animaciones.is_playing() == false:
		animaciones.play() # Reanudar cualquier animación pausada

	# --- ANIMACIONES NORMALES ---
	if direccion != 0:
		if animaciones.animation != "Caminado":
			animaciones.play("Caminado")
		
		animaciones.flip_h = (direccion < 0)
		
		if Input.is_action_pressed("Correr"):
			animaciones.speed_scale = 1.5
		else:
			animaciones.speed_scale = 1.0
	else:
		if animaciones.animation != "IDLE":
			animaciones.play("IDLE")
		animaciones.speed_scale = 1.0
