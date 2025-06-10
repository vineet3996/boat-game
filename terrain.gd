@tool
extends MeshInstance3D

const size := 256.0
const min_bank_width := 10 #minimum width allowed at the sides of the river

var speed := 10

@export_range(40, 200, 5) var river_width := 50:
	set(new_river_width):
		river_width = new_river_width
		init_mesh()

@export_range(2, 100, 2) var curve_length :int = 2:
	set(new_curve_length):
		curve_length = new_curve_length
		init_mesh()

#the angle by which the curve is incremented. This will determine the sharpness of curves
@export_range(0.1, 6, 0.2) var curve_delta :float = 1.0:
	set(new_curve_delta):
		curve_delta = new_curve_delta
		init_mesh()

@export_range(4, 256, 4) var resolution := 32:
	set(new_resolution):
		resolution = new_resolution
		init_mesh()

@export_range(4.0, 128.0, 4.0) var height := 64.0:
	set(new_height):
		height = new_height
		material_override.set_shader_parameter("height", height * 2.0)
		init_mesh()

#update the dir of the river after moving a certain distance
func get_updated_dir(river_dir :Vector2, river_head_z :float) -> Vector2:
	var random_float = randf()
	var bias = (river_head_z + (size/2) - min_bank_width - (river_width/2))/(size-(2*min_bank_width)-river_width)
	if(random_float>bias):
		#update dir towards right by delta
		return river_dir.rotated(curve_delta).normalized()
	else:
		return river_dir.rotated(-1*curve_delta).normalized()

func get_updated_head(river_head_z :float, river_dir :Vector2) -> float:
	return river_head_z + river_dir.y

func get_height(x: float, z: float, river_head_z :float) -> float:
	if(z>=(river_head_z-(river_width/2)) && z<=(river_head_z+(river_width/2))):
		return -10
	else:
		return 10

func get_normal(x: float, y: float, river_heads) -> Vector3:
	var epsilon := size / resolution
	var normal := Vector3(
		(get_height(x + epsilon, y, river_heads[ceil(x+epsilon)]) - get_height(x - epsilon, y, river_heads[floor(x-epsilon)])) / (2.0 * epsilon),
		1.0,
		(get_height(x, y + epsilon, river_heads[x]) - get_height(x, y - epsilon, river_heads[x])) / (2.0 * epsilon)
	)
	return normal.normalized()
	
func init_mesh() -> void:
	var plane := PlaneMesh.new()
	plane.subdivide_depth = resolution
	plane.subdivide_width = resolution
	plane.size = Vector2(size, size)
	position = Vector3(size/2, 0, 0)
	
	var plane_arrays := plane.get_mesh_arrays()
	var vertex_array: PackedVector3Array = plane_arrays[ArrayMesh.ARRAY_VERTEX]
	var normal_array: PackedVector3Array = plane_arrays[ArrayMesh.ARRAY_NORMAL]
	var tangent_array: PackedFloat32Array = plane_arrays[ArrayMesh.ARRAY_TANGENT]
	
	var river_dir := Vector2(1.0, 0)
	var river_head_z :float = 0
	var tangents = []
	var river_heads = []
	for i:int in range(0,size+1):
		tangents.push_back(river_dir)
		river_heads.push_back(river_head_z)
		if(i%curve_length==0):
			river_dir = get_updated_dir(river_dir, river_head_z)
		river_head_z = get_updated_head(river_head_z, river_dir)
	
	for i:int in vertex_array.size():
		var vertex := vertex_array[i]
		vertex.y = get_height(vertex.x, vertex.z, river_heads[vertex.x])
		var normal = get_normal(vertex.x, vertex.z, river_heads)  
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
