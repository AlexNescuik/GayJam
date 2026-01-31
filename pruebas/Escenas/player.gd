extends CharacterBody2D

# --- CONFIGURACIÓN DE MOVIMIENTO ---
const VELOCIDAD_NORMAL = 100.0
const VELOCIDAD_CORRER = 170.0
const VELOCIDAD_BARRIDO = 200.0
const FUERZA_SALTO = -300.0
const GRAVEDAD = 980.0

# --- CONFIGURACIÓN DE PARED ---
const VELOCIDAD_DESLIZAMIENTO = 50.0  
const FUERZA_REBOTE_X = 300.0         
const TIEMPO_BLOQUEO_WALLJUMP = 0.3  # Aumentado a 0.3s
var tiempo_bloqueo_pared = 0.0       
var bloqueo_por_pared = false        

# --- CONFIGURACIÓN DEL BARRIDO ---
const TIEMPO_MAX_BARRIDO = 0.9   
var tiempo_barrido_actual = 0.0  
var bloqueo_barrido = false      

# --- CONFIGURACIÓN DEL SALTO ---
const CORTE_SALTO = 0.5 

@onready var animaciones = $AnimatedSprite2D

func _physics_process(delta):
	# 1. GRAVEDAD
	if not is_on_floor():
		velocity.y += GRAVEDAD * delta

	# INPUTS
	var direccion = Input.get_axis("ui_left", "ui_right")
	
	# --- LÓGICA DE PARED ---
	var esta_en_pared = is_on_wall() and not is_on_floor()
	
	# Solo permitimos interactuar con la pared si NO estamos bloqueados
	if esta_en_pared and not bloqueo_por_pared:
		# A) WALL SLIDE
		if velocity.y > 0:
			velocity.y = min(velocity.y, VELOCIDAD_DESLIZAMIENTO)
			
			# Opcional: Que mire a la pared mientras resbala
			var normal_pared = get_wall_normal()
			if normal_pared.x != 0:
				animaciones.flip_h = (normal_pared.x > 0)

		# B) WALL JUMP (IMPULSO)
		if Input.is_action_just_pressed("ui_accept"):
			var normal = get_wall_normal()
			
			# Aplicamos fuerzas
			velocity.y = FUERZA_SALTO
			velocity.x = normal.x * FUERZA_REBOTE_X
			
			# ACTIVAMOS EL BLOQUEO
			bloqueo_por_pared = true
			tiempo_bloqueo_pared = 0.0
			
			# --- CORRECCIÓN VISUAL INMEDIATA ---
			# Forzamos al sprite a mirar hacia donde sale disparado AHORA MISMO.
			# Si la velocidad X es negativa (va a izquierda), flip_h es true.
			animaciones.flip_h = (velocity.x < 0)
	
	
	# --- GESTIÓN DE PRIORIDADES DE MOVIMIENTO ---
	var esta_barriendose = false
	var intentando_barrer = is_on_floor() and Input.is_action_pressed("Correr") and Input.is_action_pressed("ui_down") and direccion != 0

	# CASO 1: BLOQUEO POR PARED (El "Peso Visual")
	if bloqueo_por_pared:
		tiempo_bloqueo_pared += delta
		
		# Aquí NO leemos 'direccion'. El personaje viaja por inercia.
		# La animación también estará bloqueada (ver función abajo).
		
		if tiempo_bloqueo_pared >= TIEMPO_BLOQUEO_WALLJUMP:
			bloqueo_por_pared = false
			
		if is_on_floor(): # Si toca suelo, recupera control antes
			bloqueo_por_pared = false

	# CASO 2: BARRIDO
	elif intentando_barrer and not bloqueo_barrido:
		bloqueo_barrido = false 
		esta_barriendose = true
		velocity.x = direccion * VELOCIDAD_BARRIDO
		tiempo_barrido_actual += delta
		
		if tiempo_barrido_actual >= TIEMPO_MAX_BARRIDO:
			bloqueo_barrido = true
			esta_barriendose = false
	
	# CASO 3: MOVIMIENTO NORMAL
	else:
		if not intentando_barrer:
			bloqueo_barrido = false
			tiempo_barrido_actual = 0.0

		if Input.is_action_just_pressed("ui_accept") and is_on_floor():
			velocity.y = FUERZA_SALTO
		if Input.is_action_just_released("ui_accept") and velocity.y < 0:
			velocity.y *= CORTE_SALTO

		var velocidad_actual = VELOCIDAD_NORMAL
		if Input.is_action_pressed("Correr"):
			velocidad_actual = VELOCIDAD_CORRER

		if direccion:
			velocity.x = direccion * velocidad_actual
		else:
			velocity.x = move_toward(velocity.x, 0, velocidad_actual)

	move_and_slide()

	# PASAMOS "bloqueo_por_pared" A LA FUNCIÓN DE ANIMACIÓN
	actualizar_animacion(direccion, esta_barriendose, esta_en_pared)


func actualizar_animacion(direccion, esta_barriendose, esta_en_pared):
	# --- PRIORIDAD ABSOLUTA: BLOQUEO DE PARED ---
	# Si estamos en esos 0.3s de impulso, NO CAMBIAMOS NADA.
	# Mantenemos el frame y la dirección que forzamos en el salto.
	if bloqueo_por_pared:
		# Aquí podrías forzar la animación "Salto" si la tuvieras.
		# Como no la tienes, usamos "Caminado" o "IDLE" estático.
		if animaciones.animation != "Caminado":
			animaciones.play("Caminado")
		return # ¡IMPORTANTE! Salimos aquí para que el input no cambie el flip_h

	# --- PARED (SLIDE) ---
	if esta_en_pared and not is_on_floor() and velocity.y > 0:
		if animaciones.animation != "IDLE":
			animaciones.play("IDLE") 
		return

	# --- BARRIDO ---
	if esta_barriendose:
		if animaciones.animation != "Barrido":
			animaciones.play("Barrido")
		if animaciones.frame >= 2:
			animaciones.pause()
			animaciones.frame = 2 
		animaciones.flip_h = (direccion < 0)
		return 

	if animaciones.is_playing() == false:
		animaciones.play() 

	# --- MOVIMIENTO NORMAL ---
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
