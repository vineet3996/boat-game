@tool
extends Node3D

@onready var boat :Node3D = get_node("Boat")
@onready var camera :Camera3D = get_node("Camera3D")
#const mesh_sections = []
const TOTAL_SECTIONS = 12
var current_section = 0

const min_bank_width := 120 #minimum width allowed at the sides of the river

@export var section_length :int = 20:
	set(new_section_length):
		section_length = new_section_length
		init_sections()
		
@export var section_width :int = 400:
	set(new_section_width):
		section_width = new_section_width
		init_sections()

@export_range(4, 256, 4) var resolution := 256:
	set(new_resolution):
		resolution = new_resolution
		init_sections()
		
@export_range(1, 10, 1) var curve_delta :int = 1:
	set(new_curve_delta):
		curve_delta = new_curve_delta
		init_sections()

@export_range(20, 200, 5) var river_width := 50:
	set(new_river_width):
		river_width = new_river_width
		init_sections()

@export var ground_texture :StandardMaterial3D = StandardMaterial3D.new():
	set(new_ground_texture):
		ground_texture = new_ground_texture
		init_sections()

const total_width := 400.0

var tangents = []
var river_heads = []

var is_left = true;
var is_turning = true;
var current_curve_angle := deg_to_rad(randf_range(45, 60))
var river_dir := Vector2(1.0, 0)
var river_head_z :float = 0
var position_x :float = section_length/2

var child_node: Node3D = Node3D.new()

func _ready() -> void:
	init_sections()

func init_sections():
	reset_generation_vars()
	var children = child_node.get_children()
	for child in children:
		child.free()
	child_node.free()
	child_node = Node3D.new()
	for i:int in range(TOTAL_SECTIONS):
		child_node.add_child(create_mesh())
		current_section+=1
	add_child(child_node)

func reset_generation_vars()->void:
	current_section=0
	is_left = true;
	is_turning = true;
	current_curve_angle = deg_to_rad(randf_range(45, 60))
	river_dir = Vector2(1.0, 0)
	river_head_z = 0
	position_x = section_length/2
	tangents = []
	river_heads = []
	
func add_section() -> void:
	child_node.add_child(create_mesh())
	child_node.remove_child(child_node.get_child(current_section-TOTAL_SECTIONS))
	current_section+=1

func _input(event: InputEvent) -> void:
	if Input.is_key_pressed(KEY_UP):
		move_boat(1)
		move_camera(1)
	if Input.is_key_pressed(KEY_LEFT):
		boat.position.z -= 1
	if Input.is_key_pressed(KEY_RIGHT):
		boat.position.z += 1

func move_boat(distance: float) -> void:
	boat.position.x += distance
	if boat.position.x >= section_length*(current_section-(TOTAL_SECTIONS/2)):
		add_section()

func move_camera(distance: float) -> void:
	camera.position.x += distance

#update the dir of the river after moving a certain distance
func get_updated_dir(river_dir :Vector2, is_left :bool) -> Vector2:
	return river_dir.rotated(deg_to_rad((-1*curve_delta) if is_left else curve_delta)).normalized()

func get_updated_head(river_head_z :float, river_dir :Vector2) -> float:
	return river_head_z + tan(river_dir.angle())

func get_height(x: float, z: float) -> float:
	if roundi(x) == roundi(section_length/2):
		return -10
	var min_distance = 10000
	var curr_point = Vector2(x, z)
	var head_index = ceil(x+(section_length/2)) + (section_length if current_section>0 else 0)
	if(abs(river_heads[head_index]-z)<(river_width/2)):
		return -10
	elif(abs(river_heads[head_index]-z)>(river_width*3)/4):
		return 10
	else:
		for i in range(-30, 30):
			var new_head_index = ceil(x+i+(section_length/2)) + (section_length if current_section>0 else 0)
			if(new_head_index >= 0 && new_head_index < river_heads.size()):
				var head_point = Vector2(x+i, river_heads[new_head_index])
				if(min_distance>curr_point.distance_to(head_point)):
					min_distance = curr_point.distance_to(head_point)
		
		if(min_distance<=(river_width/2)):
			return -10
		else:
			return 10
	#var adj_x = ceil(x+(total_length/2))
	#var horizontal_width = (river_width/2)/sin(tangents[adj_x].angle_to(Vector2(0,1)))
	#if(z <= river_heads[adj_x]+horizontal_width && z>=river_heads[adj_x]-horizontal_width):
		#return -10
	#else:
		#return 10

func get_normal(x: float, y: float) -> Vector3:
	var epsilon := section_length / resolution
	var normal := Vector3(
		(get_height(x + epsilon, y) - get_height(x - epsilon, y)) / (2.0 * epsilon),
		1.0,
		(get_height(x, y + epsilon) - get_height(x, y - epsilon)) / (2.0 * epsilon)
	)
	return normal.normalized()

func get_current_bank_width(river_head_z :float, is_left :bool) -> float:
	if(is_left):
		return (total_width/2) + river_head_z - (river_width/2)
	else:
		return (total_width/2) - river_head_z - (river_width/2)

func create_mesh() -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.subdivide_depth = resolution
	plane.subdivide_width = resolution
	plane.size = Vector2(section_length, section_width)
	
	var plane_arrays := plane.get_mesh_arrays()
	var vertex_array: PackedVector3Array = plane_arrays[ArrayMesh.ARRAY_VERTEX]
	var normal_array: PackedVector3Array = plane_arrays[ArrayMesh.ARRAY_NORMAL]
	var tangent_array: PackedFloat32Array = plane_arrays[ArrayMesh.ARRAY_TANGENT]
	
	if current_section>=2:
		for i:int in range(0,section_length+1):
			river_heads.remove_at(i)
			tangents.remove_at(i)
		
	var target_bank_width = min_bank_width
	for i:int in range(0,section_length+1):
		tangents.push_back(river_dir)
		river_heads.push_back(river_head_z)
		if current_section == 0:
			continue
		if is_turning:
			river_dir = get_updated_dir(river_dir, is_left)
			
			if( ((is_left && river_dir.angle() < 0) || (!is_left && river_dir.angle() > 0)) && abs(river_dir.angle()) >= abs(current_curve_angle) ):
				is_turning=false;
		
		if( !is_turning && get_current_bank_width(river_head_z, is_left) <= target_bank_width):
			#start turning in the other direction
			is_left = !is_left
			is_turning = true
			current_curve_angle = deg_to_rad(randf_range(45, 60))
		
		river_head_z = get_updated_head(river_head_z, river_dir)

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
	mesh_instance.position = Vector3(position_x+(current_section*section_length)-current_section, 0, 0)
	return mesh_instance
