package graphics

import "core:log"
import vk "vendor:vulkan"

create_primitive_pipeline :: proc(g: ^Graphics) -> Pipeline_Handle {
	vert_bind, vert_attr := default_shader_attribute()

	set_infos := []Pipeline_Set_Info{create_bindless_pipeline_set_info(context.temp_allocator)}

	push_constants := []Push_Constant_Range { 	// const
		{offset = 0, size = size_of(Push_Constant), stageFlags = vk.ShaderStageFlags_ALL_GRAPHICS},
	}

	create_info := Create_Pipeline_Info {
		set_infos = set_infos[:],
		push_constants = push_constants,
		vertex_input_description = {
			input_rate = .VERTEX,
			binding_description = vert_bind,
			attribute_descriptions = vert_attr[:],
		},
		stage_infos = []Pipeline_Stage_Info {
			{stage = {.VERTEX}, shader_path = "assets/buildin/shaders/shape.vert"},
			{stage = {.FRAGMENT}, shader_path = "assets/buildin/shaders/shape.frag"},
		},
		input_assembly = {topology = .TRIANGLE_LIST},
		rasterizer = {polygon_mode = .FILL, line_width = 1, cull_mode = {}, front_face = .COUNTER_CLOCKWISE},
		multisampling = {sample_count = ._4, min_sample_shading = 1},
		depth = {
			enable = true,
			write_enable = true,
			compare_op = .LESS,
			bounds_test_enable = false,
			min_bounds = 0,
			max_bounds = 0,
		},
		stencil = {enable = true, front = {}, back = {}},
	}

	handle, ok := create_graphics_pipeline(g, &create_info)
	if !ok {
		log.info("couldn't create default pipeline")
	}

	return handle
}

create_square_mesh :: proc(g: ^Graphics, size: f32, allocator := context.allocator) -> Mesh {
	vertices := make([]Vertex, 6, context.allocator)
	vertices[0] = {{size, size, 0.0}, {size, size}, {0.0, 0.0, size}, {1.0, 1.0, 1.0, 1.0}}
	vertices[1] = {{size, -size, 0.0}, {size, 0.0}, {0.0, size, 0.0}, {1.0, 1.0, 1.0, 1.0}}
	vertices[2] = {{-size, -size, 0.0}, {0.0, 0.0}, {size, 0.0, 0.0}, {1.0, 1.0, 1.0, 1.0}}

	vertices[3] = {{size, size, 0.0}, {size, size}, {0.0, 0.0, size}, {1.0, 1.0, 1.0, 1.0}}
	vertices[4] = {{-size, -size, 0}, {0.0, 0.0}, {0.0, size, 0.0}, {1.0, 1.0, 1.0, 1.0}}
	vertices[5] = {{-size, size, 0.0}, {0.0, size}, {size, size, size}, {1.0, 1.0, 1.0, 1.0}}

	return create_mesh(g.vulkan_state, vertices, {})
}

create_square_model :: proc(g: ^Graphics) -> Model {
	mesh := create_square_mesh(g, 0.3)
	meshes := make([]Mesh, 1)
	meshes[0] = mesh

	materials := make([dynamic]Material, 1, context.allocator)
	mesh_material := make([dynamic]int, 1, context.allocator)
	mesh_material[0] = 0

	model := create_model(meshes, materials, mesh_material)

	return model
}

draw_square :: proc(g: ^Graphics, frame_data: Frame_Data, camera: ^Camera, position: vec3, scale: vec3, color: vec4) {
	model := g.buildin.square

	material := _temp_pool_acquire(g.temp_material_pool)
	model.materials[0] = material
	material_set_pipeline(&model.materials[0], g.buildin.primitive_pipeline_h)
	material_set_color(&model.materials[0], color)
	_material_apply(&model.materials[0], g)

	transform := _temp_pool_acquire(g.temp_transform_pool)
	trf_set_position(&transform, position)
	trf_set_scale(&transform, scale)
	_trf_apply(&transform, g)

	draw_model(g, frame_data, model, camera, &transform)
}
