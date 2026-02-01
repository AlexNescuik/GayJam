extends CharacterBody2D

# #########################################################
# 1. ESTADOS Y CONFIGURACIÓN
# #########################################################
enum Estado { IDLE, MOVIENDO, SALTANDO, CAYENDO, ATACANDO, TACLEANDO, BARRIDO, PARED, CAIDA_BOMBA, DIVE, HERIDO, MUERTO }

@export_group("Movimiento Horizontal")
const VEL_NORMAL        = 100.0
const VEL_CORRER        = 170.0
const VEL_SUPER_CORRER  = 260.0
const VEL_BARRIDO       = 200.0   
const VEL_TACLEADO      = 380.0

# INERCIA & GAME FEEL
const ACELERACION       = 1200.0 
const FRICCION          = 2000.0 
const ACELERACION_GIRO  = 4000.0 
const ACELERACION_AIRE  = 500.0   
const FRICCION_AIRE     = 100.0   

@export_group("Salto y Gravedad")
const FUERZA_SALTO       = -300.0
const FUERZA_SALTO_SUPER = -380.0
const BONUS_SALTO_INERCIA = -100.0
const GRAVEDAD           = 980.0
const MULT_CORTE_SALTO   = 0.5
const TIEMPO_COYOTE      = 0.12
const TIEMPO_BUFFER_SALTO = 0.1

@export_group("Especiales")
const VEL_CAIDA_BOMBA       = 600.0
const VEL_DESLIZAMIENTO     = 50.0
const REBOTE_PARED_X        = 180.0
const TIEMPO_BLOQUEO_WALLJUMP = 0.25 
const DIVE_JUMP_X           = 120.0
const DIVE_JUMP_Y           = -180.0
const DIVE_LONG_X           = 250.0
const DIVE_LONG_Y           = -150.0
const TIEMPO_SPRINT_MAX      = 1.2
const PAUSA_ANTICIPACION     = 0.5
const VENTANA_SALTO_POTENTE  = 0.2 
const TIEMPO_MAX_BARRIDO = 0.3   

@export_group("Combate y Vida")
const FUERZA_RETROCESO_DAÑO = Vector2(200, -200) 
@export var limite_caida_y : int = 200 

# #########################################################
# 2. VARIABLES DE CONTROL
# #########################################################
var estado_actual      : Estado = Estado.IDLE
var timer_sprint       : float = 0.0
var timer_super_salto  : float = 0.0
var timer_bomba        : float = 0.0
var timer_wall_jump    : float = 0.0 

var coyote_timer       : float = 0.0
var jump_buffer_timer  : float = 0.0

var ultima_dir_sprint  : float = 0.0
var es_salto_potenciado: bool = false
var es_long_dive       : bool = false
var puedo_hacer_dive   : bool = true

var input_dir   : float = 0.0
var input_corre : bool  = false

var vida_maxima : int = 3
var vida_actual : int = 3
var es_invulnerable : bool = false

var tiempo_barrido_actual = 0.0   
var bloqueo_barrido = false
var recuperando_bomba : bool = false    

var posicion_inicio : Vector2 
var mask_original : int

@onready var animaciones = $AnimatedSprite2D
@onready var hitbox_ataque = $HitboxAtaque/CollisionShape2D

# #########################################################
# 3. BUCLE PRINCIPAL
# #########################################################

func _ready():
	posicion_inicio = global_position
	mask_original = collision_mask

func _physics_process(delta: float) -> void:
	if global_position.y > limite_caida_y and estado_actual != Estado.MUERTO:
		morir()
		
	if estado_actual == Estado.MUERTO:
		velocity.y += GRAVEDAD * delta
		move_and_slide()
		return
		
	if is_on_floor() and Input.is_action_just_pressed("ui_down"):
		position.y += 2
		if estado_actual == Estado.HERIDO:
			velocity.y += GRAVEDAD * delta
			move_and_slide()
			return

	leer_inputs()
	actualizar_timers(delta)
	procesar_gravedad(delta)
	
	if is_on_floor():
		puedo_hacer_dive = true
		coyote_timer = TIEMPO_COYOTE
		timer_wall_jump = 0 
		
		var teclas_barrido_presionadas = Input.is_action_pressed("ui_down") and input_corre
		if estado_actual != Estado.BARRIDO and not teclas_barrido_presionadas:
			bloqueo_barrido = false
	
	match estado_actual:
		Estado.IDLE:          logica_idle(delta)
		Estado.MOVIENDO:      logica_movimiento(delta)
		Estado.SALTANDO, \
		Estado.CAYENDO:       logica_aire(delta)
		Estado.ATACANDO, \
		Estado.TACLEANDO:     pass 
		Estado.BARRIDO:       logica_barrido(delta)
		Estado.PARED:         logica_pared() 
		Estado.CAIDA_BOMBA:   logica_caida_bomba(delta)
		Estado.DIVE:          logica_dive()

	move_and_slide()
	verificar_inputs_especiales()

# #########################################################
# 4. SISTEMA DE VIDA, DAÑO Y RESPAWN
# #########################################################
func recibir_daño(cantidad: int, origen_daño_x: float):
	if es_invulnerable or estado_actual == Estado.MUERTO: return
	vida_actual -= cantidad
	print("Auch! Vida restante: ", vida_actual)
	
	if vida_actual <= 0:
		morir()
	else:
		estado_actual = Estado.HERIDO
		
		if animaciones.sprite_frames.has_animation("Herido"):
			animaciones.play("Herido")
		else:
			animaciones.play("IDLE")
			animaciones.modulate = Color.RED
		
		var dir_empuje = -1 if origen_daño_x > global_position.x else 1
		velocity.x = dir_empuje * FUERZA_RETROCESO_DAÑO.x
		velocity.y = FUERZA_RETROCESO_DAÑO.y

		es_invulnerable = true
		await get_tree().create_timer(0.5).timeout
		es_invulnerable = false
		
		if vida_actual > 0:
			estado_actual = Estado.IDLE
			animaciones.modulate = Color.WHITE
			
func morir():
	if estado_actual == Estado.MUERTO: return
	estado_actual = Estado.MUERTO
	print("¡JUGADOR MUERTO!")
	
	velocity = Vector2.ZERO
	if animaciones.sprite_frames.has_animation("Muerte"):
		animaciones.play("Muerte")
	else:
		animaciones.stop()
	collision_mask = 0 
	await get_tree().create_timer(1.0).timeout
	respawn()

func respawn():
	velocity = Vector2.ZERO
	global_position = posicion_inicio
	collision_mask = mask_original
	
	# 3. Restaurar Vida y Estado
	vida_actual = vida_maxima
	estado_actual = Estado.IDLE
	animaciones.play("IDLE")
	animaciones.modulate = Color.WHITE
	es_invulnerable = false
	
	print("¡JUGADOR REVIVIDO!")

# #########################################################
# 5. SISTEMA DE INPUTS Y TIMERS
# #########################################################
func leer_inputs() -> void:
	if estado_actual == Estado.MUERTO: 
		input_dir = 0
		input_corre = false
		return

	var raw_dir = Input.get_axis("ui_left", "ui_right")
	input_dir = raw_dir if abs(raw_dir) > 0.15 else 0.0
	input_corre = Input.is_action_pressed("Correr")
	
	if Input.is_action_just_pressed("Saltar"):
		jump_buffer_timer = TIEMPO_BUFFER_SALTO

func actualizar_timers(delta: float) -> void:
	if timer_super_salto > 0: timer_super_salto -= delta
	if coyote_timer > 0:      coyote_timer -= delta
	if jump_buffer_timer > 0: jump_buffer_timer -= delta
	if timer_wall_jump > 0:   timer_wall_jump -= delta

# #########################################################
# 6. GESTIÓN DE TRANSICIONES
# #########################################################
func cambiar_estado(nuevo: Estado, forzar: bool = false) -> void:
	if estado_actual == nuevo: return
	
	var es_accion = estado_actual in [Estado.ATACANDO, Estado.TACLEANDO, Estado.BARRIDO, Estado.DIVE, Estado.CAIDA_BOMBA, Estado.HERIDO, Estado.MUERTO]
	if es_accion and not forzar: return
	
	animaciones.speed_scale = 1.0

	hitbox_ataque.disabled = true 
	
	if estado_actual == Estado.BARRIDO: animaciones.play() 
	
	estado_actual = nuevo
	
	match estado_actual:
		Estado.BARRIDO:
			tiempo_barrido_actual = 0.0
			animaciones.play("Barrido")
			
		Estado.CAIDA_BOMBA:
			timer_bomba = PAUSA_ANTICIPACION
			recuperando_bomba = false 
			velocity = Vector2.ZERO
			animaciones.play("Bomba") 
			
		Estado.DIVE:
			velocity.y = DIVE_LONG_Y if es_long_dive else DIVE_JUMP_Y
			animaciones.play("Caida")
		Estado.SALTANDO:
			ejecutar_salto()
		Estado.ATACANDO:  iniciar_accion("Ataque")
		Estado.TACLEANDO: iniciar_accion("Tacleado")

func iniciar_accion(anim: String) -> void:
	animaciones.play(anim)
	hitbox_ataque.disabled = false 
	if not animaciones.animation_finished.is_connected(_on_anim_finished):
		animaciones.animation_finished.connect(_on_anim_finished, CONNECT_ONE_SHOT)

func _on_anim_finished():
	hitbox_ataque.disabled = true 
	if estado_actual in [Estado.ATACANDO, Estado.TACLEANDO]:
		cambiar_estado(Estado.IDLE, true)

# #########################################################
# 7. LÓGICA DETALLADA DE ESTADOS
# #########################################################
func ejecutar_salto() -> void:
	if timer_wall_jump > 0:
		velocity.y = FUERZA_SALTO 
		return

	var velocidad_actual_x = abs(velocity.x)
	var salto_final = FUERZA_SALTO
	
	if timer_super_salto > 0:
		salto_final = FUERZA_SALTO_SUPER
		es_salto_potenciado = true
		timer_super_salto = 0
	else:
		var factor_impulso = clamp(velocidad_actual_x / VEL_SUPER_CORRER, 0.0, 1.0)
		salto_final += (BONUS_SALTO_INERCIA * factor_impulso)
		es_salto_potenciado = false

	velocity.y = salto_final
	coyote_timer = 0
	jump_buffer_timer = 0

func verificar_inputs_especiales() -> void:
	if timer_wall_jump > 0: return

	if estado_actual == Estado.CAIDA_BOMBA:
		if recuperando_bomba: return
		
		if puedo_hacer_dive:
			if jump_buffer_timer > 0:
				es_long_dive = false; puedo_hacer_dive = false; cambiar_estado(Estado.DIVE, true)
				return
			elif Input.is_action_just_pressed("Correr"):
				es_long_dive = true; puedo_hacer_dive = false; cambiar_estado(Estado.DIVE, true)
				return

	var es_libre = estado_actual in [Estado.IDLE, Estado.MOVIENDO, Estado.SALTANDO, Estado.CAYENDO]
	if not es_libre: return

	if jump_buffer_timer > 0 and coyote_timer > 0:
		cambiar_estado(Estado.SALTANDO)
		return

	if is_on_floor() and input_corre and Input.is_action_pressed("ui_down") and not bloqueo_barrido:
		if input_dir != 0 or velocity.x != 0:
			cambiar_estado(Estado.BARRIDO)
		return

	if Input.is_action_just_pressed("Ataque"):
		if not is_on_floor(): cambiar_estado(Estado.CAIDA_BOMBA)
		else: cambiar_estado(Estado.TACLEANDO if input_corre else Estado.ATACANDO)

func logica_movimiento(delta: float) -> void:
	var v_objetivo = VEL_NORMAL
	if input_corre:
		if input_dir == ultima_dir_sprint: timer_sprint += delta
		else: timer_sprint = 0.0; ultima_dir_sprint = input_dir
		v_objetivo = VEL_SUPER_CORRER if timer_sprint >= TIEMPO_SPRINT_MAX else VEL_CORRER
		animaciones.speed_scale = 2.0 if v_objetivo == VEL_SUPER_CORRER else 1.5
	else: 
		timer_sprint = 0.0; v_objetivo = VEL_NORMAL
	
	var acel_actual = ACELERACION
	if velocity.x != 0 and (velocity.x * input_dir < 0):
		acel_actual = ACELERACION_GIRO

	velocity.x = move_toward(velocity.x, input_dir * v_objetivo, acel_actual * delta)
	
	animaciones.play("Caminado")
	if input_dir != 0: animaciones.flip_h = (input_dir < 0)
	
	if input_dir == 0: cambiar_estado(Estado.IDLE)
	elif not is_on_floor() and coyote_timer <= 0: cambiar_estado(Estado.CAYENDO)

func logica_aire(delta: float) -> void:
	if timer_wall_jump > 0:
		animaciones.play("Saltar") 
		animaciones.flip_h = (velocity.x < 0)
	else:
		if input_dir != 0:
			velocity.x = move_toward(velocity.x, input_dir * VEL_NORMAL, ACELERACION_AIRE * delta)
			animaciones.flip_h = (input_dir < 0)
		else:
			velocity.x = move_toward(velocity.x, 0, FRICCION_AIRE * delta)
		
		if velocity.y < 0:
			animaciones.play("Saltar")
		else:
			animaciones.play("Caida")
	
	if not es_salto_potenciado and Input.is_action_just_released("Saltar") and velocity.y < -50:
		velocity.y *= MULT_CORTE_SALTO
	
	if is_on_floor():
		es_salto_potenciado = false
		cambiar_estado(Estado.IDLE if input_dir == 0 else Estado.MOVIENDO, true)
	elif is_on_wall_only() and velocity.y > 0:
		var n = get_wall_normal()
		if (n.x < 0 and input_dir > 0) or (n.x > 0 and input_dir < 0): 
			cambiar_estado(Estado.PARED, true)

func logica_idle(delta: float):
	timer_sprint = 0.0
	velocity.x = move_toward(velocity.x, 0, FRICCION * delta)
	animaciones.play("IDLE")
	if input_dir != 0: 
		animaciones.flip_h = (input_dir < 0)
		cambiar_estado(Estado.MOVIENDO)

func logica_barrido(delta: float) -> void:
	if input_dir != 0:
		velocity.x = input_dir * VEL_BARRIDO
		animaciones.flip_h = (input_dir < 0)
	else:
		var dir_actual = -1 if animaciones.flip_h else 1
		velocity.x = dir_actual * VEL_BARRIDO

	if animaciones.animation == "Barrido" and animaciones.frame >= 2:
		animaciones.pause()
		animaciones.frame = 2
	
	tiempo_barrido_actual += delta
	
	if not (Input.is_action_pressed("ui_down") and input_corre):
		cambiar_estado(Estado.MOVIENDO if input_dir != 0 else Estado.IDLE, true)
		return
	
	if tiempo_barrido_actual >= TIEMPO_MAX_BARRIDO:
		bloqueo_barrido = true
		cambiar_estado(Estado.MOVIENDO if input_dir != 0 else Estado.IDLE, true)
		return
		
	if is_on_wall():
		cambiar_estado(Estado.IDLE, true)

func logica_pared():
	var n = get_wall_normal()
	var presionando_hacia_pared = (n.x < 0 and input_dir > 0) or (n.x > 0 and input_dir < 0)
	
	if not presionando_hacia_pared or not is_on_wall() or is_on_floor():
		cambiar_estado(Estado.CAYENDO, true)
		return
	
	velocity.y = min(velocity.y, VEL_DESLIZAMIENTO)
	animaciones.play("Pared")
	if n.x != 0: animaciones.flip_h = (n.x > 0)
	
	if jump_buffer_timer > 0:
		velocity.x = n.x * REBOTE_PARED_X
		timer_wall_jump = TIEMPO_BLOQUEO_WALLJUMP
		animaciones.flip_h = (velocity.x < 0)
		cambiar_estado(Estado.SALTANDO, true)

func logica_caida_bomba(delta: float) -> void:
	if animaciones.animation == "Bomba" and animaciones.frame >= 3:
		animaciones.pause()
		animaciones.frame = 3

	if recuperando_bomba:
		velocity = Vector2.ZERO
		return

	if timer_bomba > 0:
		timer_bomba -= delta
		velocity = Vector2.ZERO
		return

	velocity.y = VEL_CAIDA_BOMBA
	
	if is_on_floor():
		recuperando_bomba = true
		await get_tree().create_timer(0.2).timeout
		recuperando_bomba = false
		timer_super_salto = VENTANA_SALTO_POTENTE
		cambiar_estado(Estado.IDLE, true)

func logica_dive() -> void:
	var dir_f = -1 if animaciones.flip_h else 1
	var btn_activo = input_corre if es_long_dive else Input.is_action_pressed("Saltar")
	
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
