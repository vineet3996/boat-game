#@tool
extends Node3D

@onready var boat :Node3D = get_node("Boat")
@onready var camera :Camera3D = get_node("Camera3D")
#const mesh_sections = []
const TOTAL_SECTIONS = 10
var current_section = 0

const min_bank_width := 160 #minimum width allowed at the sides of the river

@export var section_length :int = 30:
	set(new_section_length):
		section_length = new_section_length
		#init_sections()
		
@export var section_width :int = 400:
	set(new_section_width):
		section_width = new_section_width
		#init_sections()

@export_range(4, 500, 4) var resolution := 300:
	set(new_resolution):
		resolution = new_resolution
		#init_sections()
		
@export_range(1, 10, 1) var curve_delta :int = 1:
	set(new_curve_delta):
		curve_delta = new_curve_delta
		#init_sections()

@export_range(20, 200, 5) var river_width := 30:
	set(new_river_width):
		river_width = new_river_width
		#init_sections()

@export var ground_texture :StandardMaterial3D = StandardMaterial3D.new():
	set(new_ground_texture):
		ground_texture = new_ground_texture
		#init_sections()

var tangents = []
var river_heads = []

var is_left = true;
var is_turning = true;
var current_curve_angle := deg_to_rad(randf_range(45, 60))
var river_dir := Vector2(1.0, 0)
var river_head_z :float = 0
var position_x :float = section_length/2

var child_node: Node3D = Node3D.new()
var mesh_array :Array = []
var mesh_repo :Array = []
const mesh_repo_size :int = 2
const max_distance_no_turn :int = 80
var distance_no_turn :int = 0

var thread: Thread

func _ready() -> void:
	seed(2)
	init_sections()

func init_sections():
	child_node = get_node("Terrain")
	if child_node.get_child_count() == 0:
		reset_generation_vars()
		for i:int in range(TOTAL_SECTIONS):
			var mesh = create_mesh()
			mesh_array.push_back(mesh)
			if mesh_array.size()==1:
				mesh.position = Vector3(section_length, 0, 0)
			else:
				mesh.position = Vector3(mesh_array[mesh_array.size()-2].position.x+section_length, 0, 0)
			child_node.add_child(mesh)
			mesh.owner=get_tree().edited_scene_root
			current_section+=1
		
		save_init_vars()
	else:
		load_init_vars()
		mesh_array = []
		for child in child_node.get_children():
			if mesh_array.size()==0:
				mesh_array.push_back(child)
			else:
				var new_mesh_array = []
				var new_child_inserted = false
				for mesh in mesh_array:
					if !new_child_inserted && mesh.position.x > child.position.x:
						new_child_inserted=true
						new_mesh_array.push_back(child)
					new_mesh_array.push_back(mesh)
				if !new_child_inserted:
					new_mesh_array.push_back(child)
				mesh_array = new_mesh_array
		
		#var scene = PackedScene.new()
		#scene.pack(child_node)
		#ResourceSaver.save(scene, "res://terrain.tscn")
		
	thread = Thread.new()
	thread.start(maintain_mesh_repo)

var save_path := "res://terrain_init_vars.cfg"

func save_init_vars() -> void:
	var init_vars :Dictionary = {}
	init_vars['current_section'] = current_section
	init_vars['is_left'] = is_left
	init_vars['is_turning'] = is_turning
	init_vars['river_dir_x'] = river_dir.x
	init_vars['river_dir_y'] = river_dir.y
	init_vars['river_head_z'] = river_head_z
	init_vars['position_x'] = position_x
	init_vars['current_curve_angle'] = current_curve_angle
	
	var config_file := ConfigFile.new()
	for item in init_vars.keys():
		config_file.set_value("Terrain", item, init_vars[item])
	var error := config_file.save(save_path)
	if error:
		print("An error happened while saving data: ", error)

func load_init_vars() -> void:
	var config_file := ConfigFile.new()
	var error := config_file.load(save_path)

	if error:
		print("An error happened while loading data: ", error)
		return
	current_section = config_file.get_value("Terrain", "current_section", 0)
	is_left = config_file.get_value("Terrain", "is_left", 0)
	is_turning = config_file.get_value("Terrain", "is_turning", 0)
	river_dir.x = config_file.get_value("Terrain", "river_dir_x", 0)
	river_dir.y = config_file.get_value("Terrain", "river_dir_y", 0)
	river_head_z = config_file.get_value("Terrain", "river_head_z", 0)
	position_x = config_file.get_value("Terrain", "position_x", 0)
	current_curve_angle = config_file.get_value("Terrain", "current_curve_angle", 0)

func reset_generation_vars()->void:
	current_section=0
	is_left = true;
	is_turning = true;
	river_dir = Vector2(1.0, 0)
	river_head_z = 0
	position_x = section_length/2
	tangents = []
	river_heads = []
	mesh_array = []
	mesh_repo = []
	set_new_curve_angle()

func maintain_mesh_repo() -> void:
	while mesh_repo.size() < mesh_repo_size:
		mesh_repo.push_back(create_mesh())

func add_section_remove_last() -> void:
	var mesh = mesh_repo[0]
	mesh_repo.remove_at(0)
	thread.wait_to_finish()
	thread.start(maintain_mesh_repo)
	mesh_array.push_back(mesh)
	mesh.position = Vector3(mesh_array[mesh_array.size()-2].position.x+section_length, 0, 0)
	child_node.add_child(mesh)
	child_node.remove_child(mesh_array[0])
	mesh_array[0].free()
	mesh_array.remove_at(0)
	current_section+=1

func _input(event: InputEvent) -> void:
	if Input.is_key_pressed(KEY_UP):
		move_terrain(1)
	if Input.is_key_pressed(KEY_LEFT):
		boat.position.z -= 1
	if Input.is_key_pressed(KEY_RIGHT):
		boat.position.z += 1

func move_terrain(distance: float) -> void:
	for mesh in mesh_array:
		mesh.position.x-=distance
	if mesh_array[0].position.x < 0:
		add_section_remove_last()

func set_new_curve_angle() -> void:
	current_curve_angle = deg_to_rad(randf_range(20, 60))

#update the dir of the river after moving a certain distance
func get_updated_dir() -> Vector2:
	return river_dir.rotated(deg_to_rad((-1*curve_delta) if is_left else curve_delta)).normalized()

func get_updated_head() -> float:
	return river_head_z + tan(river_dir.angle())

func get_height(x: float, z: float) -> float:
	var new_x = int(ceil(x+section_length/2))
	if new_x >= river_heads.size():
		new_x = river_heads.size()-1
	elif new_x < 0:
		new_x = 0
	var new_width = abs(river_width/(2*cos(tangents[new_x].angle())))
	
	if (z < (river_heads[new_x] - new_width) && z+1 >= (river_heads[new_x] - new_width)) || (z > (river_heads[new_x] + new_width) && z-1 <= (river_heads[new_x] + new_width)):
		return 2
	if (z < (river_heads[new_x] - new_width) && z+2 >= (river_heads[new_x] - new_width)) || (z > (river_heads[new_x] + new_width) && z-2 <= (river_heads[new_x] + new_width)):
		return 3
	if (z < (river_heads[new_x] - new_width) && z+3 >= (river_heads[new_x] - new_width)) || (z > (river_heads[new_x] + new_width) && z-3 <= (river_heads[new_x] + new_width)):
		return 4
	#if (z < (river_heads[new_x] - new_width) && z+4 >= (river_heads[new_x] - new_width)) || (z > (river_heads[new_x] + new_width) && z-4 <= (river_heads[new_x] + new_width)):
		#return 4.5
	if z >= (river_heads[new_x] - new_width) && z <= (river_heads[new_x] + new_width):
		return -10
	else:
		return 5

func get_normal(x: float, y: float) -> Vector3:
	var epsilon := 1#section_length / resolution
	var normal := Vector3(
		(get_height(x + epsilon, y) - get_height(x - epsilon, y)) / (2.0 * epsilon),
		1.0,
		(get_height(x, y + epsilon) - get_height(x, y - epsilon)) / (2.0 * epsilon)
	)
	return normal.normalized()

func get_current_bank_width() -> float:
	if(is_left):
		return (section_width/2) + river_head_z - (river_width/2)
	else:
		return (section_width/2) - river_head_z - (river_width/2)

func create_mesh() -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.subdivide_depth = resolution
	plane.subdivide_width = resolution
	plane.size = Vector2(section_length, section_width)
	
	var plane_arrays := plane.get_mesh_arrays()
	var vertex_array: PackedVector3Array = plane_arrays[ArrayMesh.ARRAY_VERTEX]
	var normal_array: PackedVector3Array = plane_arrays[ArrayMesh.ARRAY_NORMAL]
	var tangent_array: PackedFloat32Array = plane_arrays[ArrayMesh.ARRAY_TANGENT]
	
	river_heads = []
	tangents = []
	print("Creating mesh: ", mesh_array.size())
	var target_bank_width = min_bank_width
	for i:int in range(0,section_length+1):
		tangents.push_back(river_dir)
		river_heads.push_back(river_head_z)
		if current_section == 0:
			continue
		if is_turning:
			river_dir = get_updated_dir()
			if( ((is_left && river_dir.angle() < 0) || (!is_left && river_dir.angle() > 0)) && abs(river_dir.angle()) >= abs(current_curve_angle) ):
				is_turning=false;
		else:
			distance_no_turn+=1
			if distance_no_turn >= max_distance_no_turn:
				distance_no_turn=0
				is_left = !is_left
				is_turning = true
				set_new_curve_angle()
		
		if( !is_turning && get_current_bank_width() <= target_bank_width):
			#start turning in the other direction
			is_left = !is_left
			is_turning = true
			set_new_curve_angle()
		
		river_head_z = get_updated_head()
	
	river_head_z = river_heads[river_heads.size()-2]
	river_dir = tangents[tangents.size()-2]
	
	for i:int in vertex_array.size():
		var vertex := vertex_array[i]
		vertex.y = get_height(vertex.x, vertex.z)
		var normal = get_normal(vertex.x, vertex.z)
		var tangent = normal.cross(Vector3.UP)
		vertex_array[i] = vertex
		normal_array[i] = normal
		tangent_array[4 * i] = tangent.x
		tangent_array[4 * i + 1] = tangent.y
		tangent_array[4 * i + 2] = tangent.z
	
	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, plane_arrays)
	array_mesh.surface_set_material(0, ground_texture)
	var mesh_instance :MeshInstance3D = MeshInstance3D.new();
	mesh_instance.mesh = array_mesh
	#mesh_instance.position = Vector3(position_x+(current_section*section_length)-current_section, 0, 0)
	return mesh_instance

#func _exit_tree():
	#thread.wait_to_finish()
