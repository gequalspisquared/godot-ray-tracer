extends Node

var rd: RenderingDevice

var w: float
var h: float

var push_constants: PackedByteArray
var pipeline: RID
var output_image: Image
var shader: RID
var time := 0.0
var fmt := RDTextureFormat.new()
var view := RDTextureView.new()
var texture: RID
var texture_uniform := RDUniform.new()
var texture_set: RID

var frame := 0

# Called when the node enters the scene tree for the first time.
func _ready():
	w = get_viewport().get_visible_rect().size.x
	h = get_viewport().get_visible_rect().size.y
	@warning_ignore("narrowing_conversion")
	output_image = Image.create(w, h, false, Image.FORMAT_RGBAF)

	# rd = RenderingServer.create_local_rendering_device()
	rd = RenderingServer.get_rendering_device()

	shader = load_shader("res://simple_ray_tracer.glsl")
	pipeline = rd.compute_pipeline_create(shader)

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

	texture = rd.texture_create(fmt, view, [])
	texture_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	texture_uniform.binding = 0
	texture_uniform.add_id(texture)
	texture_set = rd.uniform_set_create([texture_uniform], shader, 0)
	print("Texture: ", texture)
	
	$Control/TextureRect.texture = Texture2DRD.new()
	$Control/TextureRect.texture.texture_rd_rid = texture


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	frame += 1
	time += delta
	push_constants = PackedFloat32Array([time, 1.0, 1.0, 1.0]).to_byte_array()

	# Tell compute shader what to do
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_set_push_constant(compute_list, push_constants, push_constants.size())
	rd.compute_list_bind_uniform_set(compute_list, texture_set, 0)
	@warning_ignore("narrowing_conversion")
	rd.compute_list_dispatch(compute_list, w/8, h/8, 1)
	rd.compute_list_end()

	# Submit to GPU and wait for sync
	# rd.submit()
	# rd.sync()

	# var byte_data: PackedByteArray = rd.texture_get_data(texture, 0)
	# @warning_ignore("narrowing_conversion")
	# var image := Image.create_from_data(w, h, false, Image.FORMAT_RGBAF, byte_data)

	# var image_texture := ImageTexture.create_from_image(image)
	# # texture.texture_rd_rid = 
	# $Control/TextureRect.texture = image_texture
	
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
