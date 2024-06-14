extends Node

var rd: RenderingDevice

var w: float
var h: float

var pipeline: RID
var shader: RID
var time := 0.0

# Uniforms and textures
var texture: RID
var texture_set: RID

var spheres_rid: RID
var spheres_set: RID

var frame := 0

class Sphere:
	var center: Vector3
	var radius: float

func sphere_to_packed_array(sphere: Sphere) -> PackedFloat32Array:
	var array: PackedFloat32Array = []
	array.append(sphere.center.x)
	array.append(sphere.center.y)
	array.append(sphere.center.z)
	array.append(sphere.radius)

	return array

func create_world_spheres() -> PackedFloat32Array:
	var data: PackedFloat32Array = []

	var sphere := Sphere.new()
	sphere.center = Vector3(0.0, 0.0, -1.0)
	sphere.radius = 0.5

	data.append_array(sphere_to_packed_array(sphere))

	var sphere2 := Sphere.new()
	sphere2.center = Vector3(0.0, -100.5, -1.0)
	sphere2.radius = 100.0

	data.append_array(sphere_to_packed_array(sphere2))

	return data


# Called when the node enters the scene tree for the first time.
func _ready():
	var world_sphere_data := create_world_spheres()

	w = get_viewport().get_visible_rect().size.x
	h = get_viewport().get_visible_rect().size.y
	@warning_ignore("narrowing_conversion")

	# rd = RenderingServer.create_local_rendering_device()
	rd = RenderingServer.get_rendering_device()

	shader = load_shader("res://simple_ray_tracer.glsl")
	pipeline = rd.compute_pipeline_create(shader)

	var fmt := RDTextureFormat.new()
	@warning_ignore("narrowing_conversion")
	fmt.width = w
	@warning_ignore("narrowing_conversion")
	fmt.height = h
	fmt.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	fmt.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	fmt.usage_bits = \
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT	+ \
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT + \
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + \
		RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT + \
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
	
	var view := RDTextureView.new()

	texture = rd.texture_create(fmt, view, [])
	var texture_uniform := RDUniform.new()
	texture_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	texture_uniform.binding = 0
	texture_uniform.add_id(texture)
	texture_set = rd.uniform_set_create([texture_uniform], shader, 0)
	print("Texture: ", texture)

	$Control/TextureRect.texture = Texture2DRD.new()
	$Control/TextureRect.texture.texture_rd_rid = texture


	@warning_ignore("integer_division")
	# Extra zeros are for padding since GPU likes spacing everything by 16 bytes
	var size_array: PackedInt32Array = [world_sphere_data.size() / 4, 0, 0, 0]
	# var size_array: PackedInt32Array = [2, 0, 0, 0]
	var spheres_bytes: PackedByteArray = size_array.to_byte_array()
	spheres_bytes.append_array(world_sphere_data.to_byte_array())
	print("size: ", spheres_bytes.size())
	spheres_rid = rd.storage_buffer_create(spheres_bytes.size(), spheres_bytes)
	var spheres_uniform := RDUniform.new()
	spheres_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	spheres_uniform.binding = 0
	spheres_uniform.add_id(spheres_rid)
	spheres_set = rd.uniform_set_create([spheres_uniform], shader, 1)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	frame += 1
	time += delta
	var push_constants := PackedFloat32Array([time, 1.0, 1.0, 1.0]).to_byte_array()

	# Tell compute shader what to do
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_set_push_constant(compute_list, push_constants, push_constants.size())
	rd.compute_list_bind_uniform_set(compute_list, texture_set, 0)
	rd.compute_list_bind_uniform_set(compute_list, spheres_set, 1)
	@warning_ignore("narrowing_conversion")
	rd.compute_list_dispatch(compute_list, w/8, h/8, 1)
	rd.compute_list_end()

	if frame % 100 == 0:
		$Label.text = "FPS: %0.1f" % Performance.get_monitor(Performance.TIME_FPS)


func load_shader(path: String) -> RID:
	var shader_file := load(path)
	var shader_spirv: RDShaderSPIRV= shader_file.get_spirv()
	return rd.shader_create_from_spirv(shader_spirv)


func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		cleanup_gpu()


func cleanup_gpu() -> void:
	if rd == null:
		return
	
	rd.free_rid(pipeline)
	pipeline = RID()

	rd.free_rid(texture_set)
	texture_set = RID()

	rd.free_rid(texture)
	texture = RID()

	rd.free_rid(shader)
	shader = RID()

	rd.free()
	rd = null
