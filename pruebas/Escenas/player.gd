extends CharacterBody2D

# --- CONFIGURACIÓN DE MOVIMIENTO ---
const VELOCIDAD_NORMAL = 100.0
const VELOCIDAD_CORRER = 170.0
const VELOCIDAD_BARRIDO = 200.0
const VELOCIDAD_TACLEADO = 40.0  # ¡Nuevo! Impulso fuerte
const FUERZA_SALTO = -300.0
const GRAVEDAD = 980.0

# --- CONFIGURACIÓN DE PARED ---
const VELOCIDAD_DESLIZAMIENTO = 50.0  
const FUERZA_REBOTE_X = 300.0         
const TIEMPO_BLOQUEO_WALLJUMP = 0.3
var tiempo_bloqueo_pared = 0.0       
var bloqueo_por_pared = false        

# --- CONFIGURACIÓN DEL BARRIDO ---
const TIEMPO_MAX_BARRIDO = 0.9   
var tiempo_barrido_actual = 0.0  
var bloqueo_barrido = false      

# --- CONFIGURACIÓN DE COMBATE ---
var esta_atacando = false
var esta_tacleando = false # ¡Nuevo Estado!

# --- CONFIGURACIÓN DEL SALTO ---
const CORTE_SALTO = 0.5 

@onready var animaciones = $AnimatedSprite2D

func _physics_process(delta):
	# 1. GRAVEDAD
	if not is_on_floor():
		velocity.y += GRAVEDAD * delta

	# INPUTS
	var direccion = Input.get_axis("ui_left", "ui_right")
	
	# --- LÓGICA DE COMBATE (ATAQUE Y TACLEADO) ---
	if Input.is_action_just_pressed("Ataque"):
		# Verificamos que no estemos ocupados haciendo otra cosa
		if not esta_atacando and not esta_tacleando and not bloqueo_barrido and not bloqueo_por_pared:
			
			# DECISIÓN: ¿Es Tacleado o Ataque Normal?
			if Input.is_action_pressed("Correr"):
				realizar_tacleado() # Shift + C
			else:
				realizar_ataque()   # Solo C
	
	
	# --- LÓGICA DE PARED ---
	var esta_en_pared = is_on_wall() and not is_on_floor()
	
	# No permitimos wall jump si estamos en medio de un tacleado (opcional, por estabilidad)
	if esta_en_pared and not bloqueo_por_pared and not esta_atacando and not esta_tacleando:
		# A) WALL SLIDE
		if velocity.y > 0:
			velocity.y = min(velocity.y, VELOCIDAD_DESLIZAMIENTO)
			var normal_pared = get_wall_normal()
			if normal_pared.x != 0:
				animaciones.flip_h = (normal_pared.x > 0)

		# B) WALL JUMP
		if Input.is_action_just_pressed("ui_accept"):
			var normal = get_wall_normal()
			velocity.y = FUERZA_SALTO
			velocity.x = normal.x * FUERZA_REBOTE_X
			bloqueo_por_pared = true
			tiempo_bloqueo_pared = 0.0
			animaciones.flip_h = (velocity.x < 0)
	
	
	# --- GESTIÓN DE PRIORIDADES DE MOVIMIENTO ---
	var esta_barriendose = false
	var intentando_barrer = is_on_floor() and Input.is_action_pressed("Correr") and Input.is_action_pressed("ui_down") and direccion != 0

	# CASO 1: BLOQUEO POR PARED
	if bloqueo_por_pared:
		tiempo_bloqueo_pared += delta
		if tiempo_bloqueo_pared >= TIEMPO_BLOQUEO_WALLJUMP:
			bloqueo_por_pared = false
		if is_on_floor(): 
			bloqueo_por_pared = false

	# CASO 2: TACLEADO (Prioridad Alta)
	elif esta_tacleando:
		# Durante el tacleado, el jugador se mueve automáticamente hacia donde mira
		# No leemos "direccion" para que no pueda frenar
		var dir_tacleado = -1 if animaciones.flip_h else 1
		velocity.x = dir_tacleado * VELOCIDAD_TACLEADO
		
		# Nota: Si choca con pared, se detendrá por física, pero el estado sigue hasta acabar animacion

	# CASO 3: BARRIDO
	elif intentando_barrer and not bloqueo_barrido and not esta_atacando:
		bloqueo_barrido = false 
		esta_barriendose = true
		velocity.x = direccion * VELOCIDAD_BARRIDO
		tiempo_barrido_actual += delta
		if tiempo_barrido_actual >= TIEMPO_MAX_BARRIDO:
			bloqueo_barrido = true
			esta_barriendose = false
	
	# CASO 4: MOVIMIENTO NORMAL
	else:
		if not intentando_barrer:
			bloqueo_barrido = false
			tiempo_barrido_actual = 0.0

		if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not esta_atacando:
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

	# GESTOR DE ANIMACIONES
	actualizar_animacion(direccion, esta_barriendose, esta_en_pared)


# --- FUNCIONES DE ACCIÓN ---

func realizar_ataque():
	esta_atacando = true
	animaciones.play("Ataque")
	await animaciones.animation_finished
	esta_atacando = false
	if animaciones.animation == "Ataque": animaciones.play("IDLE") 

func realizar_tacleado():
	esta_tacleando = true
	animaciones.play("Tacleado")
	
	# Aseguramos la dirección visual al inicio del tacleado
	# Si nos movemos, miramos a esa dirección; si no, mantenemos la actual.
	var direccion_input = Input.get_axis("ui_left", "ui_right")
	if direccion_input != 0:
		animaciones.flip_h = (direccion_input < 0)
	
	await animaciones.animation_finished
	
	esta_tacleando = false
	if animaciones.animation == "Tacleado": animaciones.play("IDLE")


func actualizar_animacion(direccion, esta_barriendose, esta_en_pared):
	# PRIORIDAD 1: BLOQUEO DE PARED
	if bloqueo_por_pared:
		if animaciones.animation != "Caminado": animaciones.play("Caminado")
		return 

	# PRIORIDAD 2: TACLEADO (¡Máxima prioridad visual!)
	if esta_tacleando:
		if animaciones.animation != "Tacleado": animaciones.play("Tacleado")
		return

	# PRIORIDAD 3: ATAQUE NORMAL
	if esta_atacando:
		if animaciones.animation != "Ataque": animaciones.play("Ataque")
		if direccion != 0: animaciones.flip_h = (direccion < 0)
		return

	# PRIORIDAD 4: PARED (SLIDE)
	if esta_en_pared and not is_on_floor() and velocity.y > 0:
		if animaciones.animation != "IDLE": animaciones.play("IDLE") 
		return

	# PRIORIDAD 5: BARRIDO
	if esta_barriendose:
		if animaciones.animation != "Barrido": animaciones.play("Barrido")
		if animaciones.frame >= 2:
			animaciones.pause()
			animaciones.frame = 2 
		animaciones.flip_h = (direccion < 0)
		return 

	if animaciones.is_playing() == false:
		animaciones.play() 

	# PRIORIDAD 6: MOVIMIENTO NORMAL
	if direccion != 0:
		if animaciones.animation != "Caminado": animaciones.play("Caminado")
		animaciones.flip_h = (direccion < 0)
		if Input.is_action_pressed("Correr"):
			animaciones.speed_scale = 1.5
		else:
			animaciones.speed_scale = 1.0
	else:
		if animaciones.animation != "IDLE": animaciones.play("IDLE")
		animaciones.speed_scale = 1.0
