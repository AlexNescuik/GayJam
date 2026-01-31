extends CharacterBody2D

# #########################################################
# 1. ESTADOS Y CONFIGURACIÓN
# #########################################################
enum Estado { IDLE, MOVIENDO, SALTANDO, CAYENDO, ATACANDO, TACLEANDO, BARRIDO, PARED, CAIDA_BOMBA, DIVE }

@export_group("Movimiento Horizontal")
const VEL_NORMAL        = 100.0
const VEL_CORRER        = 170.0
const VEL_SUPER_CORRER  = 260.0
const VEL_BARRIDO       = 250.0
const VEL_TACLEADO      = 380.0

@export_group("Salto y Gravedad")
const FUERZA_SALTO       = -300.0
const FUERZA_SALTO_SUPER = -380.0
const GRAVEDAD           = 980.0
const MULT_CORTE_SALTO   = 0.5
const TIEMPO_COYOTE      = 0.12
const TIEMPO_BUFFER_SALTO = 0.1

@export_group("Especiales")
const VEL_CAIDA_BOMBA       = 600.0
const VEL_DESLIZAMIENTO     = 50.0
const REBOTE_PARED_X        = 300.0
const DIVE_JUMP_X           = 120.0
const DIVE_JUMP_Y           = -180.0
const DIVE_LONG_X           = 250.0
const DIVE_LONG_Y           = -150.0
const TIEMPO_SPRINT_MAX      = 1.2
const DURACION_BARRIDO       = 0.5
const PAUSA_ANTICIPACION     = 0.5
const VENTANA_SALTO_POTENTE  = 0.2 

# #########################################################
# 2. VARIABLES DE CONTROL
# #########################################################
var estado_actual      : Estado = Estado.IDLE
var timer_sprint       : float = 0.0
var timer_barrido      : float = 0.0
var timer_super_salto  : float = 0.0
var timer_bomba        : float = 0.0

# Game Feel Timers
var coyote_timer       : float = 0.0
var jump_buffer_timer  : float = 0.0

var ultima_dir_sprint  : float = 0.0
var es_salto_potenciado: bool = false
var es_long_dive       : bool = false
var puedo_hacer_dive   : bool = true

# Inputs centralizados
var input_dir   : float = 0.0
var input_corre : bool  = false

@onready var animaciones = $AnimatedSprite2D

# #########################################################
# 3. BUCLE PRINCIPAL
# #########################################################
func _physics_process(delta: float) -> void:
	leer_inputs()
	actualizar_timers(delta)
	procesar_gravedad(delta)
	
	if is_on_floor():
		puedo_hacer_dive = true
		coyote_timer = TIEMPO_COYOTE
	
	# Máquina de Estados (FSM)
	match estado_actual:
		Estado.IDLE:         logica_idle()
		Estado.MOVIENDO:     logica_movimiento(delta)
		Estado.SALTANDO, \
		Estado.CAYENDO:      logica_aire()
		Estado.ATACANDO, \
		Estado.TACLEANDO:    pass # Se resuelven por señal de animación
		Estado.BARRIDO:      logica_barrido(delta)
		Estado.PARED:        logica_pared()
		Estado.CAIDA_BOMBA:  logica_caida_bomba(delta)
		Estado.DIVE:         logica_dive()

	move_and_slide()
	verificar_inputs_especiales()

# #########################################################
# 4. SISTEMA DE INPUTS Y TIMERS
# #########################################################
func leer_inputs() -> void:
	var raw_dir = Input.get_axis("ui_left", "ui_right")
	input_dir = raw_dir if abs(raw_dir) > 0.15 else 0.0
	input_corre = Input.is_action_pressed("Correr")
	
	if Input.is_action_just_pressed("saltar"):
		jump_buffer_timer = TIEMPO_BUFFER_SALTO

func actualizar_timers(delta: float) -> void:
	if timer_super_salto > 0: timer_super_salto -= delta
	if coyote_timer > 0:      coyote_timer -= delta
	if jump_buffer_timer > 0: jump_buffer_timer -= delta

# #########################################################
# 5. GESTIÓN DE TRANSICIONES
# #########################################################
func cambiar_estado(nuevo: Estado, forzar: bool = false) -> void:
	if estado_actual == nuevo: return
	
	# Bloqueo de acciones especiales
	var es_accion = estado_actual in [Estado.ATACANDO, Estado.TACLEANDO, Estado.BARRIDO, Estado.DIVE, Estado.CAIDA_BOMBA]
	if es_accion and not forzar: return
	
	# Limpieza de estado anterior
	animaciones.speed_scale = 1.0
	if estado_actual == Estado.BARRIDO: animaciones.play() 
	
	estado_actual = nuevo
	
	match estado_actual:
		Estado.BARRIDO:
			timer_barrido = DURACION_BARRIDO
			animaciones.play("Barrido")
		Estado.CAIDA_BOMBA:
			timer_bomba = PAUSA_ANTICIPACION
			velocity = Vector2.ZERO
			animaciones.play("Caida")
		Estado.DIVE:
			velocity.y = DIVE_LONG_Y if es_long_dive else DIVE_JUMP_Y
			animaciones.play("Caida")
		Estado.SALTANDO:
			ejecutar_salto()
		Estado.ATACANDO:  iniciar_accion("Ataque")
		Estado.TACLEANDO: iniciar_accion("Tacleado")

func iniciar_accion(anim: String) -> void:
	animaciones.play(anim)
	if not animaciones.animation_finished.is_connected(_on_anim_finished):
		animaciones.animation_finished.connect(_on_anim_finished, CONNECT_ONE_SHOT)

func _on_anim_finished():
	if estado_actual in [Estado.ATACANDO, Estado.TACLEANDO]:
		cambiar_estado(Estado.IDLE, true)

# #########################################################
# 6. LÓGICA DETALLADA DE ESTADOS
# #########################################################
func ejecutar_salto() -> void:
	if timer_super_salto > 0:
		velocity.y = FUERZA_SALTO_SUPER
		es_salto_potenciado = true
		timer_super_salto = 0
	else:
		velocity.y = FUERZA_SALTO
		es_salto_potenciado = false
	coyote_timer = 0
	jump_buffer_timer = 0

func verificar_inputs_especiales() -> void:
	# 1. DIVE (Solo disponible durante o inmediatamente después de Caida Bomba)
	if estado_actual == Estado.CAIDA_BOMBA and puedo_hacer_dive:
		if jump_buffer_timer > 0:
			es_long_dive = false; puedo_hacer_dive = false; cambiar_estado(Estado.DIVE, true)
			return
		elif Input.is_action_just_pressed("Correr"):
			es_long_dive = true; puedo_hacer_dive = false; cambiar_estado(Estado.DIVE, true)
			return

	var es_libre = estado_actual in [Estado.IDLE, Estado.MOVIENDO, Estado.SALTANDO, Estado.CAYENDO]
	if not es_libre: return

	# 2. SALTO (Coyote Time + Buffer)
	if jump_buffer_timer > 0 and coyote_timer > 0:
		cambiar_estado(Estado.SALTANDO)
		return

	# 3. BARRIDA
	if Input.is_action_just_pressed("ui_down") and input_corre and is_on_floor():
		cambiar_estado(Estado.BARRIDO)
		return

	# 4. ATAQUE / BOMBA
	if Input.is_action_just_pressed("Ataque"):
		if not is_on_floor(): cambiar_estado(Estado.CAIDA_BOMBA)
		else: cambiar_estado(Estado.TACLEANDO if input_corre else Estado.ATACANDO)

func logica_movimiento(delta: float) -> void:
	var v = VEL_NORMAL
	if input_corre:
		if input_dir == ultima_dir_sprint: timer_sprint += delta
		else: timer_sprint = 0.0; ultima_dir_sprint = input_dir
		v = VEL_SUPER_CORRER if timer_sprint >= TIEMPO_SPRINT_MAX else VEL_CORRER
		animaciones.speed_scale = 2.0 if v == VEL_SUPER_CORRER else 1.5
	else: 
		timer_sprint = 0.0; v = VEL_NORMAL
	
	velocity.x = input_dir * v
	animaciones.play("Caminado")
	if input_dir != 0: animaciones.flip_h = (input_dir < 0)
	
	if input_dir == 0: cambiar_estado(Estado.IDLE)
	elif not is_on_floor() and coyote_timer <= 0: cambiar_estado(Estado.CAYENDO)

func logica_aire() -> void:
	velocity.x = move_toward(velocity.x, input_dir * VEL_NORMAL, 10.0)
	if input_dir != 0: animaciones.flip_h = (input_dir < 0)
	
	# Salto variable (cortar el salto al soltar botón)
	if not es_salto_potenciado and Input.is_action_just_released("saltar") and velocity.y < -50:
		velocity.y *= MULT_CORTE_SALTO
	
	if is_on_floor():
		es_salto_potenciado = false
		cambiar_estado(Estado.IDLE if input_dir == 0 else Estado.MOVIENDO, true)
	elif is_on_wall_only() and velocity.y > 0:
		var n = get_wall_normal()
		if (n.x < 0 and input_dir > 0) or (n.x > 0 and input_dir < 0): 
			cambiar_estado(Estado.PARED, true)

func logica_idle():
	timer_sprint = 0.0
	velocity.x = move_toward(velocity.x, 0, VEL_NORMAL)
	animaciones.play("IDLE")
	if input_dir != 0: 
		animaciones.flip_h = (input_dir < 0)
		cambiar_estado(Estado.MOVIENDO)

func logica_barrido(delta: float) -> void:
	velocity.x = -VEL_BARRIDO if animaciones.flip_h else VEL_BARRIDO
	if animaciones.animation == "Barrido" and animaciones.frame >= 2:
		animaciones.pause()
	timer_barrido -= delta
	if timer_barrido <= 0 or is_on_wall():
		cambiar_estado(Estado.IDLE, true)

func logica_pared():
	var n = get_wall_normal()
	var presionando_hacia_pared = (n.x < 0 and input_dir > 0) or (n.x > 0 and input_dir < 0)
	if not presionando_hacia_pared or not is_on_wall() or is_on_floor():
		cambiar_estado(Estado.CAYENDO, true)
		return
	velocity.y = min(velocity.y, VEL_DESLIZAMIENTO)
	animaciones.play("IDLE")
	if jump_buffer_timer > 0:
		velocity.y = FUERZA_SALTO
		velocity.x = n.x * REBOTE_PARED_X
		cambiar_estado(Estado.SALTANDO, true)

func logica_caida_bomba(delta: float) -> void:
	if timer_bomba > 0:
		timer_bomba -= delta
		velocity = Vector2.ZERO
	else:
		velocity.y = VEL_CAIDA_BOMBA
	if is_on_floor():
		timer_super_salto = VENTANA_SALTO_POTENTE
		cambiar_estado(Estado.IDLE, true)

func logica_dive() -> void:
	var dir_f = -1 if animaciones.flip_h else 1
	var btn_activo = input_corre if es_long_dive else Input.is_action_pressed("saltar")
	
	if not btn_activo:
		cambiar_estado(Estado.CAYENDO, true)
		return
		
	velocity.x = dir_f * (DIVE_LONG_X if es_long_dive else DIVE_JUMP_X)
	if is_on_floor(): cambiar_estado(Estado.IDLE, true)
	elif is_on_wall():
		velocity.x = -dir_f * 50
		cambiar_estado(Estado.CAYENDO, true)

func procesar_gravedad(delta):
	if not is_on_floor() and estado_actual != Estado.PARED:
		if estado_actual == Estado.CAIDA_BOMBA and timer_bomba > 0: 
			velocity = Vector2.ZERO
		else: 
			var mult = 0.7 if estado_actual == Estado.DIVE else 1.0
			velocity.y += (GRAVEDAD * mult) * delta
