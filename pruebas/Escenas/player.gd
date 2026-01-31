extends CharacterBody2D

# #########################################################
# 1. ESTADOS Y CONFIGURACIÓN
# #########################################################
enum Estado { IDLE, MOVIENDO, SALTANDO, CAYENDO, ATACANDO, TACLEANDO, BARRIDO, PARED, CAIDA_BOMBA, DIVE }

# --- Movimiento Base ---
const VEL_NORMAL        = 100.0
const VEL_CORRER        = 170.0
const VEL_SUPER_CORRER  = 260.0
const VEL_BARRIDO       = 250.0
const VEL_TACLEADO      = 380.0
const VEL_CAIDA_BOMBA   = 600.0

# --- Salto y Gravedad ---
const FUERZA_SALTO           = -300.0
const FUERZA_SALTO_SUPER     = -380.0
const GRAVEDAD               = 980.0
const MULT_CORTE_SALTO       = 0.5
const VENTANA_SALTO_POTENTE  = 0.2

# --- Mecánicas de Pared ---
const VEL_DESLIZAMIENTO = 50.0
const REBOTE_PARED_X    = 300.0

# --- Dive (Impulsos) ---
const DIVE_JUMP_X = 120.0
const DIVE_JUMP_Y = -180.0
const DIVE_LONG_X = 250.0
const DIVE_LONG_Y = -150.0

# --- Timers y Duraciones ---
const TIEMPO_SPRINT_MAX      = 1.2
const DURACION_BARRIDO       = 0.5
const PAUSA_ANTICIPACION     = 0.5

# #########################################################
# 2. VARIABLES DE CONTROL
# #########################################################
var estado_actual      : Estado = Estado.IDLE
var timer_sprint       : float  = 0.0
var timer_barrido      : float  = 0.0
var timer_super_salto  : float  = 0.0
var timer_bomba        : float  = 0.0

var ultima_dir_sprint  : float  = 0.0
var es_salto_potenciado: bool   = false
var es_long_dive       : bool   = false
var puedo_hacer_dive   : bool   = true

@onready var animaciones = $AnimatedSprite2D

# #########################################################
# 3. BUCLE PRINCIPAL
# #########################################################
func _physics_process(delta: float) -> void:
	procesar_gravedad(delta)
	actualizar_timers(delta)
	
	# Input
	var raw_dir = Input.get_axis("ui_left", "ui_right")
	var dir     = raw_dir if abs(raw_dir) > 0.15 else 0.0
	var corre   = (dir != 0) and Input.is_action_pressed("Correr")
	
	if is_on_floor(): puedo_hacer_dive = true

	# Máquina de Estados
	match estado_actual:
		Estado.IDLE:         logica_idle(dir)
		Estado.MOVIENDO:     logica_movimiento(dir, corre, delta)
		Estado.SALTANDO, \
		Estado.CAYENDO:      logica_aire(dir)
		Estado.ATACANDO:     logica_ataque()
		Estado.TACLEANDO:    logica_tacleado()
		Estado.BARRIDO:      logica_barrido(delta)
		Estado.PARED:        logica_pared(dir)
		Estado.CAIDA_BOMBA:  logica_caida_bomba(delta)
		Estado.DIVE:         logica_dive()

	move_and_slide()
	verificar_inputs_especiales(dir, corre)

# #########################################################
# 4. FUNCIONES DE APOYO
# #########################################################
func procesar_gravedad(delta: float) -> void:
	if not is_on_floor() and estado_actual != Estado.PARED:
		# No hay gravedad durante la anticipación de la bomba
		if estado_actual == Estado.CAIDA_BOMBA and timer_bomba > 0:
			velocity = Vector2.ZERO
		else:
			var mult_g = 0.7 if estado_actual == Estado.DIVE else 1.0
			velocity.y += (GRAVEDAD * mult_g) * delta

func actualizar_timers(delta: float) -> void:
	if timer_super_salto > 0: timer_super_salto -= delta

# #########################################################
# 5. LÓGICA DE ESTADOS
# #########################################################
func logica_idle(dir: float) -> void:
	timer_sprint = 0.0
	velocity.x = move_toward(velocity.x, 0, VEL_NORMAL)
	animaciones.play("IDLE")
	
	if dir != 0:
		animaciones.flip_h = (dir < 0)
		cambiar_estado(Estado.MOVIENDO)
	if Input.is_action_just_pressed("saltar") and is_on_floor():
		cambiar_estado(Estado.SALTANDO)

func logica_movimiento(dir: float, corre: bool, delta: float) -> void:
	var vel_final = VEL_NORMAL
	
	if corre:
		if dir == ultima_dir_sprint: timer_sprint += delta
		else: timer_sprint = 0.0; ultima_dir_sprint = dir
		
		vel_final = VEL_SUPER_CORRER if timer_sprint >= TIEMPO_SPRINT_MAX else VEL_CORRER
		animaciones.speed_scale = 2.0 if vel_final == VEL_SUPER_CORRER else 1.5
	else:
		timer_sprint = 0.0; vel_final = VEL_NORMAL; animaciones.speed_scale = 1.0

	velocity.x = dir * vel_final
	animaciones.play("Caminado")
	if dir != 0: animaciones.flip_h = (dir < 0)
	
	if dir == 0: cambiar_estado(Estado.IDLE)
	elif Input.is_action_just_pressed("saltar"): cambiar_estado(Estado.SALTANDO)
	elif not is_on_floor(): cambiar_estado(Estado.CAYENDO)

func logica_aire(dir: float) -> void:
	velocity.x = move_toward(velocity.x, dir * VEL_NORMAL, 10.0)
	if dir != 0: animaciones.flip_h = (dir < 0)
	
	# Salto Variable
	if not es_salto_potenciado and Input.is_action_just_released("saltar") and velocity.y < -50:
		velocity.y *= MULT_CORTE_SALTO
	
	if is_on_floor():
		es_salto_potenciado = false
		cambiar_estado(Estado.IDLE if dir == 0 else Estado.MOVIENDO)
	elif is_on_wall_only() and velocity.y > 0:
		var n = get_wall_normal()
		if (n.x < 0 and dir > 0) or (n.x > 0 and dir < 0): cambiar_estado(Estado.PARED)

func logica_caida_bomba(delta: float) -> void:
	if timer_bomba > 0:
		timer_bomba -= delta
		velocity = Vector2.ZERO
		animaciones.play("Caida")
	else:
		velocity.x = 0
		velocity.y = VEL_CAIDA_BOMBA
		
	if is_on_floor():
		timer_super_salto = VENTANA_SALTO_POTENTE
		cambiar_estado(Estado.IDLE)

func logica_dive() -> void:
	var dir_f = -1 if animaciones.flip_h else 1
	var btn = "saltar" if not es_long_dive else "Correr"
	
	if not Input.is_action_pressed(btn):
		cambiar_estado(Estado.CAYENDO)
		return

	velocity.x = dir_f * (DIVE_LONG_X if es_long_dive else DIVE_JUMP_X)
	if is_on_floor(): cambiar_estado(Estado.IDLE)
	elif is_on_wall(): cambiar_estado(Estado.PARED)

func logica_barrido(delta: float) -> void:
	velocity.x = -VEL_BARRIDO if animaciones.flip_h else VEL_BARRIDO
	animaciones.play("Barrido")
	if animaciones.frame >= 2: animaciones.pause()
	timer_barrido -= delta
	if timer_barrido <= 0: cambiar_estado(Estado.IDLE)

func logica_pared(dir: float) -> void:
	var n = get_wall_normal()
	var pegado = (n.x < 0 and dir > 0) or (n.x > 0 and dir < 0)
	
	if not pegado or not is_on_wall() or is_on_floor():
		cambiar_estado(Estado.CAYENDO)
		return
		
	velocity.y = min(velocity.y, VEL_DESLIZAMIENTO)
	animaciones.play("IDLE")
	animaciones.flip_h = (n.x > 0)
	
	if Input.is_action_just_pressed("saltar"):
		velocity.y = FUERZA_SALTO
		velocity.x = n.x * REBOTE_PARED_X
		cambiar_estado(Estado.SALTANDO)

func logica_tacleado(): velocity.x = -VEL_TACLEADO if animaciones.flip_h else VEL_TACLEADO
func logica_ataque():   velocity.x = move_toward(velocity.x, 0, 15.0)

# #########################################################
# 6. SISTEMA DE TRANSICIÓN
# #########################################################
func cambiar_estado(nuevo: Estado) -> void:
	if estado_actual == nuevo: return
	if estado_actual == Estado.BARRIDO: animaciones.play()
	
	estado_actual = nuevo
	
	match estado_actual:
		Estado.CAIDA_BOMBA:
			timer_bomba = PAUSA_ANTICIPACION
			velocity = Vector2.ZERO
			animaciones.play("Caida")
		Estado.DIVE:
			velocity.y = DIVE_LONG_Y if es_long_dive else DIVE_JUMP_Y
			animaciones.play("Caida")
		Estado.SALTANDO:
			if timer_super_salto > 0:
				velocity.y = FUERZA_SALTO_SUPER
				es_salto_potenciado = true
				timer_super_salto = 0
			else:
				velocity.y = FUERZA_SALTO
				es_salto_potenciado = false
		Estado.BARRIDO:  timer_barrido = DURACION_BARRIDO
		Estado.ATACANDO: ejecutar_anim_combate("Ataque")
		Estado.TACLEANDO: ejecutar_anim_combate("Tacleado")

func ejecutar_anim_combate(anim: String) -> void:
	animaciones.play(anim)
	await animaciones.animation_finished
	if estado_actual == Estado.ATACANDO or estado_actual == Estado.TACLEANDO:
		cambiar_estado(Estado.IDLE)

func verificar_inputs_especiales(dir: float, corre: bool) -> void:
	# Dive (Solo desde Bomba)
	if estado_actual == Estado.CAIDA_BOMBA and puedo_hacer_dive:
		if Input.is_action_just_pressed("saltar"):
			es_long_dive = false; puedo_hacer_dive = false; cambiar_estado(Estado.DIVE)
			return
		elif Input.is_action_just_pressed("Correr"):
			es_long_dive = true; puedo_hacer_dive = false; cambiar_estado(Estado.DIVE)
			return

	# Ataque / Bomba / Tacleado
	if Input.is_action_just_pressed("Ataque"):
		if not is_on_floor() and estado_actual != Estado.CAIDA_BOMBA:
			cambiar_estado(Estado.CAIDA_BOMBA)
		elif is_on_floor():
			cambiar_estado(Estado.TACLEANDO if corre else Estado.ATACANDO)
			
	# Barrido
	if Input.is_action_just_pressed("ui_down") and corre and is_on_floor():
		cambiar_estado(Estado.BARRIDO)
