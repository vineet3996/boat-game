@tool
extends MeshInstance3D

const total_width := 400.0
const total_length := 512.0
const min_bank_width := 80 #minimum width allowed at the sides of the river
const max_bank_variance_for_curve := 20

var river_heads_l = []
var river_heads_r = []

var speed := 10

@export_range(40, 200, 5) var river_width := 50:
	set(new_river_width):
		river_width = new_river_width
		init_mesh()

#the angle by which the curve is incremented. This will determine the sharpness of curves
@export_range(1, 10, 1) var curve_delta :int = 1:
	set(new_curve_delta):
		curve_delta = new_curve_delta
		init_mesh()

@export_range(4, 256, 4) var resolution := 32:
	set(new_resolution):
		resolution = new_resolution
		init_mesh()

#update the dir of the river after moving a certain distance
func get_updated_dir(river_dir :Vector2, is_left :bool, is_l :bool) -> Vector2:
	if(is_l):
		if(is_left):
			return river_dir.rotated(deg_to_rad(-1*curve_delta*1.5)).normalized()
		else:
			return river_dir.rotated(deg_to_rad(curve_delta)).normalized()
	else:
		if(is_left):
			return river_dir.rotated(deg_to_rad(-1*curve_delta)).normalized()
		else:
			return river_dir.rotated(deg_to_rad(1.5*curve_delta)).normalized()

func get_updated_head(river_head_z :float, river_dir :Vector2) -> float:
	return river_head_z + tan(river_dir.angle())

func get_height(x: float, z: float) -> float:
	if(z>=river_heads_l[ceil(x+(total_length/2))] && z<=river_heads_r[ceil(x+(total_length/2))]):
		return -10
	else:
		return 10

func get_normal(x: float, y: float) -> Vector3:
	var epsilon := total_length / resolution
	var normal := Vector3(
		(get_height(x + epsilon, y) - get_height(x - epsilon, y)) / (2.0 * epsilon),
		1.0,
		(get_height(x, y + epsilon) - get_height(x, y - epsilon)) / (2.0 * epsilon)
	)
	return normal.normalized()

func get_current_bank_width(river_head_z_l :float, river_head_z_r :float, is_left :bool) -> float:
	if(is_left):
		return (total_width/2) + river_head_z_l
	else:
		return (total_width/2) - river_head_z_r

func init_mesh() -> void:
	var plane := PlaneMesh.new()
	plane.subdivide_depth = resolution
	plane.subdivide_width = resolution
	plane.size = Vector2(total_length, total_width)
	position = Vector3(total_length/2, 0, 0)
	
	var plane_arrays := plane.get_mesh_arrays()
	var vertex_array: PackedVector3Array = plane_arrays[ArrayMesh.ARRAY_VERTEX]
	var normal_array: PackedVector3Array = plane_arrays[ArrayMesh.ARRAY_NORMAL]
	var tangent_array: PackedFloat32Array = plane_arrays[ArrayMesh.ARRAY_TANGENT]
	
	var is_left = true;
	var is_turning_l = true;
	var is_turning_r = true;
	var current_curve_angle := deg_to_rad(randf_range(45, 60))
	var river_dir_l := Vector2(1.0, 0)
	var river_dir_r := Vector2(1.0, 0)
	var river_head_z_l :float = (-1*(river_width/2))
	var river_head_z_r :float = (river_width/2)
	var tangents = []
	river_heads_l = []
	river_heads_r = []
	var target_bank_width = min_bank_width
	for i:int in range(0,total_length+3):
		tangents.push_back(river_dir_l)
		river_heads_l.push_back(river_head_z_l)
		river_heads_r.push_back(river_head_z_r)
		if is_turning_l:
			river_dir_l = get_updated_dir(river_dir_l, is_left, true)
			
			if( ((is_left && river_dir_l.angle() < 0) || (!is_left && river_dir_l.angle() > 0)) && abs(river_dir_l.angle()) >= abs(current_curve_angle) ):
				is_turning_l=false;
				
		if is_turning_r:
			river_dir_r = get_updated_dir(river_dir_r, is_left, false)
			
			if( ((is_left && river_dir_r.angle() < 0) || (!is_left && river_dir_r.angle() > 0)) && abs(river_dir_r.angle()) >= abs(current_curve_angle) ):
				is_turning_r=false;
		
		if( !is_turning_l && !is_turning_r && get_current_bank_width(river_head_z_l, river_head_z_r, is_left) <= target_bank_width):
			#start turning in the other direction
			is_left = !is_left
			is_turning_l = true
			is_turning_r = true
			current_curve_angle = deg_to_rad(randf_range(45, 60))
			
		river_head_z_l = get_updated_head(river_head_z_l, river_dir_l)
		river_head_z_r = get_updated_head(river_head_z_r, river_dir_r)
	

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
	mesh = array_mesh

#func update_mesh() -> void:
	#var plane := PlaneMesh.new()
	#plane.subdivide_depth = resolution
	#plane.subdivide_width = resolution
	#plane.size = Vector2(size, size)
	#
	#var plane_arrays := plane.get_mesh_arrays()
	#var vertex_array: PackedVector3Array = plane_arrays[ArrayMesh.ARRAY_VERTEX]
	#var normal_array: PackedVector3Array = plane_arrays[ArrayMesh.ARRAY_NORMAL]
	#var tangent_array: PackedFloat32Array = plane_arrays[ArrayMesh.ARRAY_TANGENT]
	#
	#for i:int in vertex_array.size():
		#var vertex := vertex_array[i]
		#var normal := Vector3.UP
		#var tangent := Vector3.RIGHT
		#if noise:
			#vertex.y = get_height(vertex.x, vertex.z)
			#normal = get_normal(vertex.x, vertex.z)  
			#tangent = normal.cross(Vector3.UP)
		#vertex_array[i] = vertex
		#normal_array[i] = normal
		#tangent_array[4 * i] = tangent.x
		#tangent_array[4 * i + 1] = tangent.y
		#tangent_array[4 * i + 2] = tangent.z
	#
	#var array_mesh := ArrayMesh.new()
	#array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, plane_arrays)
	#mesh = array_mesh
