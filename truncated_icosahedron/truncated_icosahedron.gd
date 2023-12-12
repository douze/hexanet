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

@export var is_sphere: bool = false:
	get:
		return is_sphere
	set(value):
		is_sphere = value
		_generate_mesh()

@export var show_main_mesh: bool = true:
	get:
		return show_main_mesh
	set(value):
		show_main_mesh = value
		_change_visibility()

var _vertices := PackedVector3Array()
var _indices := PackedInt32Array()
var _normals := PackedVector3Array()
var _vertex_to_faces := Dictionary()


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
	
	# _vertices = PackedVector3Array()
	# _vertices.append(Vector3(0, 1, golden_ratio))
	# _vertices.append(Vector3(-golden_ratio, 0, 1))
	# _vertices.append(Vector3(-1, golden_ratio, 0))
	# _indices = PackedInt32Array()
	# _indices.append_array([
	# 	0,1,2])


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


# Index faces per vertex
func _link_face_to_vertex(triangle: Array) -> void:
	for vertex in triangle:	
		if (not _vertex_to_faces.has(vertex)):
			_vertex_to_faces[vertex] = [triangle]
		else:
			_vertex_to_faces[vertex].append(triangle)


# Add a triangle to the indice list
func _add_triangle(indices: PackedInt32Array, a: int, b: int, c: int, is_final_form: bool) -> void:
	var triangle := [a, b, c]
	for indice in triangle:
		indices.append(indice)
	if is_final_form:
		_link_face_to_vertex(triangle)


# Subdivide the main geometry using loop subdivisions
func _subdivide() -> void:
	var segment_midpoint_cache := Dictionary()
	for i in range(subdivisions):
		var sub_indices := PackedInt32Array()
		var is_final_form := i == subdivisions - 1
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
			_add_triangle(sub_indices, idx_a, idx_ab, idx_ca, is_final_form)
			_add_triangle(sub_indices, idx_ab, idx_b, idx_bc, is_final_form)
			_add_triangle(sub_indices, idx_ca, idx_bc, idx_c, is_final_form)
			_add_triangle(sub_indices, idx_ab, idx_bc, idx_ca, is_final_form)
		# Replace main indices by sub indices for loop subdivisions
		_indices = sub_indices


# Create dual
func _create_dual() -> void:
	if _vertex_to_faces.size() > 0:
		var vertices := PackedVector3Array()
		var indices := PackedInt32Array()

		var first = _vertex_to_faces[0]
		var centroids = []
		var idx = _vertices.size()
		for faces in first:
			centroids.append((_vertices[faces[0]]+_vertices[faces[1]]+_vertices[faces[2]])/3)
		for centroid in centroids:
			vertices.append(centroid)
		vertices.append(centroids[0])

		var surface_array := Array()
		surface_array.resize(Mesh.ARRAY_MAX)
		surface_array[Mesh.ARRAY_VERTEX] = vertices
		# surface_array[Mesh.ARRAY_INDEX] = indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP, surface_array)
		
	

# Apply radius to the geometry
func _apply_radius() -> void:
	for i in range(_vertices.size()):
		_vertices[i] = radius * (_vertices[i].normalized() if is_sphere else  _vertices[i])
		_normals.append(_vertices[i].normalized())


# Generate the icosahedron mesh
func _generate_mesh() -> void:
	_vertices.clear()
	_indices.clear()
	_normals.clear()
	_vertex_to_faces.clear()
	mesh.clear_surfaces()
	
	_create_basic_icosahedron()
	_subdivide()
	_apply_radius()
	
	var surface_array := Array()
	surface_array.resize(Mesh.ARRAY_MAX)
	surface_array[Mesh.ARRAY_VERTEX] = _vertices
	surface_array[Mesh.ARRAY_INDEX] = _indices
	surface_array[Mesh.ARRAY_NORMAL] = _normals
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)

	_create_dual()
	
	_vertices.clear()
	_indices.clear()
	_normals.clear()
	_vertex_to_faces.clear()


func _change_visibility() -> void:
	get_surface_override_material(0).set_transparency(0 if show_main_mesh else 1)
