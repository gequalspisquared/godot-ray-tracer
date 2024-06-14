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
	print("Starting")

	w = get_viewport().get_visible_rect().size.x
	h = get_viewport().get_visible_rect().size.y
	output_image = Image.create(w, h, false, Image.FORMAT_RGBAF)

	rd = RenderingServer.create_local_rendering_device()

	shader = load_shader("res://color.glsl")
	pipeline = rd.compute_pipeline_create(shader)

	fmt.width = w
	fmt.height = h
	fmt.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	fmt.usage_bits = \
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT	+ \
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT + \
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT

	texture = rd.texture_create(fmt, view, [output_image.get_data()])
	texture_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	texture_uniform.binding = 0
	texture_uniform.add_id(texture)
	texture_set = rd.uniform_set_create([texture_uniform], shader, 0)

	# Initialize output texture

	print("Finished")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	frame += 1
	time += delta
	push_constants = PackedFloat32Array([time, 1.0, 1.0, 1.0]).to_byte_array()
	# var push_set := rd.uniform_set_create([]

	# Create a compute pipeline
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_set_push_constant(compute_list, push_constants, push_constants.size())
	rd.compute_list_bind_uniform_set(compute_list, texture_set, 0)
	rd.compute_list_dispatch(compute_list, w/8, h/8, 1)
	rd.compute_list_end()

	# Submit to GPU and wait for sync
	rd.submit()
	rd.sync()

	var byte_data: PackedByteArray = rd.texture_get_data(texture, 0)
	var image := Image.create_from_data(w, h, false, Image.FORMAT_RGBAF, byte_data)

	var image_texture := ImageTexture.create_from_image(image)
	$Control/TextureRect.texture = image_texture

	if frame % 10 == 0:
		var fps: float = 1.0 / delta
		$Label.text = "FPS: %0.1f" % fps

func load_shader(path: String) -> RID:
	var shader_file := load(path)
	var shader_spirv: RDShaderSPIRV= shader_file.get_spirv()
	return rd.shader_create_from_spirv(shader_spirv)
