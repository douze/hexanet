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


func _ready():
	_generate_mesh()


func _generate_mesh():
	var surface_array: Array = []
	surface_array.resize(Mesh.ARRAY_MAX)

	# Generate basic isocahedron shape
	# https://en.wikipedia.org/wiki/Regular_icosahedron
	# http://blog.andreaskahler.com/2009/06/creating-icosphere-mesh-in-code.html
	
	var golden_ratio = (1+sqrt(5))/2; 
	
	var vertices = PackedVector3Array()
	vertices.append(Vector3(-1, golden_ratio, 0))
	vertices.append(Vector3(1, golden_ratio, 0,))
	vertices.append(Vector3(-1, -golden_ratio, 0))
	vertices.append(Vector3(1, -golden_ratio, 0))
	vertices.append(Vector3(0, -1, golden_ratio))
	vertices.append(Vector3(0, 1, golden_ratio))
	vertices.append(Vector3(0, -1, -golden_ratio))
	vertices.append(Vector3(0, 1, -golden_ratio))
	vertices.append(Vector3(golden_ratio, 0, -1))
	vertices.append(Vector3(golden_ratio, 0, 1))
	vertices.append(Vector3(-golden_ratio, 0, -1))
	vertices.append(Vector3(-golden_ratio, 0, 1))
	
	var indices = PackedInt32Array()
	indices.append_array([
			5, 11, 0,	1, 5, 0,	7, 1, 0,	10, 7, 0,	11, 10, 0,
			9, 5, 1,	4, 11, 5,	2, 10, 11,	6, 7, 10,	8, 1, 7,
			4, 9, 3,	2, 4, 3,	6, 2, 3,	8, 6, 3,	9, 8, 3,
			5, 9, 4,	11, 4, 2,	10, 2, 6,	7, 6, 8,	1, 8, 9
		])
		
	# Subdivide
	for i in range(subdivisions):
		var vertices2 = PackedVector3Array()
		var indices2 = PackedInt32Array()
		
		var index = 0
		for j in range(0, indices.size(), 3):
			# Grab triangle
			var a = vertices[indices[j]]
			var b = vertices[indices[j+1]]
			var c = vertices[indices[j+2]]
			# Compute mid points for each segments
			var ab = (a+b)/2
			var bc = (b+c)/2
			var ca = (c+a)/2
			# Create 6 vertices for each triangle
			vertices2.append(a)
			vertices2.append(ab)
			vertices2.append(b)
			vertices2.append(bc)
			vertices2.append(c)
			vertices2.append(ca)
			# From original triangle, create 4 triangles
			indices2.append(index)
			indices2.append(index+1)
			indices2.append(index+5)
			indices2.append(index+1)
			indices2.append(index+2)
			indices2.append(index+3)
			indices2.append(index+3)
			indices2.append(index+4)
			indices2.append(index+5)
			indices2.append(index+1)
			indices2.append(index+3)
			indices2.append(index+5)
			index += 6
		vertices = vertices2
		indices = indices2
		
	# Apply radius
	for i in range(vertices.size()):
		vertices[i] = vertices[i].normalized() * radius
	
	# Create mesh
	surface_array[Mesh.ARRAY_VERTEX] = vertices
	surface_array[Mesh.ARRAY_INDEX] = indices
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
