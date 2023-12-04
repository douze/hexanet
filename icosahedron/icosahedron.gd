@tool
extends MeshInstance3D


@export_range(1, 20, 1) var radius: int = 1:
	get:
		return radius
	set(value):
		radius = value
		_generate_mesh()

@export_range(0, 10, 1) var subdivisions: int = 0:
	get:
		return subdivisions
	set(value):
		subdivisions = value
		_generate_mesh()

var _vertices := PackedVector3Array()
var _indices := PackedInt32Array()


func _ready() -> void:
	_generate_mesh()


# Generate basic isocahedron shape
# https://en.wikipedia.org/wiki/Regular_icosahedron
# http://blog.andreaskahler.com/2009/06/creating-icosphere-mesh-in-code.html
func _create_basic_icosahedron() -> void:
	var golden_ratio := (1+sqrt(5))/2; 
	
	_vertices.append(Vector3(-1, golden_ratio, 0))
	_vertices.append(Vector3(1, golden_ratio, 0,))
	_vertices.append(Vector3(-1, -golden_ratio, 0))
	_vertices.append(Vector3(1, -golden_ratio, 0))
	_vertices.append(Vector3(0, -1, golden_ratio))
	_vertices.append(Vector3(0, 1, golden_ratio))
	_vertices.append(Vector3(0, -1, -golden_ratio))
	_vertices.append(Vector3(0, 1, -golden_ratio))
	_vertices.append(Vector3(golden_ratio, 0, -1))
	_vertices.append(Vector3(golden_ratio, 0, 1))
	_vertices.append(Vector3(-golden_ratio, 0, -1))
	_vertices.append(Vector3(-golden_ratio, 0, 1))
	
	_indices.append_array([
		5, 11, 0,	1, 5, 0,	7, 1, 0,	10, 7, 0,	11, 10, 0,
		9, 5, 1,	4, 11, 5,	2, 10, 11,	6, 7, 10,	8, 1, 7,
		4, 9, 3,	2, 4, 3,	6, 2, 3,	8, 6, 3,	9, 8, 3,
		5, 9, 4,	11, 4, 2,	10, 2, 6,	7, 6, 8,	1, 8, 9
	])


# Get the index of the segment midpoint
# Value is cached because midpoint is shared between multiple triangles
func _get_midpoint_index(first_point: Vector3, second_point: Vector3, segment_midpoint_cache: Dictionary) -> int:
	var midpoint: Vector3 = (first_point + second_point) / 2
	var dic_key := [first_point, second_point]
	var index_midpoint = segment_midpoint_cache.get(dic_key)
	if (index_midpoint == null):
		_vertices.append(midpoint)
		index_midpoint = _vertices.size() - 1
		segment_midpoint_cache[dic_key] = index_midpoint
	return index_midpoint


# Subdivide the main geometry using loop subdivisions
func _subdivide() -> void:
	var segment_midpoint_cache := Dictionary()
	for i in range(subdivisions):
		var sub_indices := PackedInt32Array()
		for j in range(0, _indices.size(), 3):
			# Grab triangle ABC
			var idx_a = _indices[j]
			var idx_b = _indices[j+1]
			var idx_c = _indices[j+2]
			var a := _vertices[idx_a]
			var b := _vertices[idx_b]
			var c := _vertices[idx_c]
			# Get midpoint for each segment of the ABC triangle
			var idx_ab = _get_midpoint_index(a,b,segment_midpoint_cache)
			var idx_bc = _get_midpoint_index(b,c,segment_midpoint_cache)
			var idx_ca = _get_midpoint_index(c,a,segment_midpoint_cache)
			# From original triangle ABC, create 4 sub triangles
			sub_indices.append(idx_a)
			sub_indices.append(idx_ab)
			sub_indices.append(idx_ca)
			sub_indices.append(idx_ab)
			sub_indices.append(idx_b)
			sub_indices.append(idx_bc)
			sub_indices.append(idx_ca)
			sub_indices.append(idx_bc)
			sub_indices.append(idx_c)
			sub_indices.append(idx_ab)
			sub_indices.append(idx_bc)
			sub_indices.append(idx_ca)
		# Replace main indices by sub indices for loop subdivisions
		_indices = sub_indices


# Apply radius to the geometry
func _apply_radius() -> void:
	for i in range(_vertices.size()):
		_vertices[i] = _vertices[i].normalized() * radius


# Generate the icosahedron mesh
func _generate_mesh() -> void:
	_vertices.clear()
	_indices.clear()
	mesh.clear_surfaces()
	
	_create_basic_icosahedron()
	_subdivide()
	_apply_radius()
	
	var surface_array := Array()
	surface_array.resize(Mesh.ARRAY_MAX)
	surface_array[Mesh.ARRAY_VERTEX] = _vertices
	surface_array[Mesh.ARRAY_INDEX] = _indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
	
	_vertices.clear()
	_indices.clear()
