extends CanvasLayer

@export var corazon_lleno : Texture2D
@export var corazon_vacio : Texture2D

@onready var lista_corazones = $HBoxContainer.get_children()
@onready var pantalla_game_over = $PantallaGameOver 

var es_game_over : bool = false

func _process(delta):
	if es_game_over and Input.is_key_pressed(KEY_Z):
		get_tree().reload_current_scene()

func actualizar_vidas(vidas_jugador: int):
	for indice in range(lista_corazones.size()):
		if indice < vidas_jugador:
			lista_corazones[indice].texture = corazon_lleno
		else:
			lista_corazones[indice].texture = corazon_vacio

func activar_game_over():
	print("HUD: ¡Recibido Game Over!")
	es_game_over = true
	pantalla_game_over.visible = true
