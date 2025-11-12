package graphics

import "core:math/linalg/glsl"

init_material :: proc(g: ^Graphics, material: ^Material, pipeline_h: Pipeline_Handle, loc := #caller_location) {
	assert_not_nil(g, loc)
	assert_not_nil(material, loc)

	buffer := create_uniform_buffer(g.vulkan_state, size_of(Material_UBO))
	material.buffer_h = bindless_store_buffer(g, buffer)
	material.pipeline_h = pipeline_h
	material.color = {1, 1, 1, 1}
	material.dirty = true
}

material_set_color :: proc(material: ^Material, color: color, loc := #caller_location) {
	assert_not_nil(material, loc)

	material.color = color
	material.dirty = true
}

material_set_texture :: proc(material: ^Material, texture_h: Texture_Handle, loc := #caller_location) {
	assert_not_nil(material, loc)

	material.texture_h = texture_h
	material.dirty = true
}

@(private)
_material_apply :: proc(material: ^Material, g: ^Graphics, loc := #caller_location) {
	assert_not_nil(g, loc)
	assert_not_nil(material, loc)

	if !material.dirty {
		return
	}

	texture_index: u32 = 0
	if texture, has := material.texture_h.?; has {
		texture_index = texture.index
	}

	ubo := Material_UBO {
		color   = material.color,
		texture = texture_index,
	}
	buffer := bindless_get_buffer(g, material.buffer_h)
	_fill_buffer(buffer, g.vulkan_state, size_of(Material_UBO), &ubo)
	material.dirty = false
}

destroy_material :: proc(g: ^Graphics, material: ^Material, loc := #caller_location) {
	assert_not_nil(g, loc)
	assert_not_nil(material, loc)

	bindless_destroy_buffer(g, material.buffer_h)
}

init_transform :: proc(g: ^Graphics, transform: ^Transform, loc := #caller_location) {
	assert_not_nil(g, loc)
	assert_not_nil(transform, loc)

	buffer := create_uniform_buffer(g.vulkan_state, size_of(Transform_UBO))
	transform.scale = 1
	transform.rotation = 0
	transform.position = 0
	transform.dirty = true
	transform.buffer_h = bindless_store_buffer(g, buffer)
}

transform_set_position :: proc(transform: ^Transform, position: vec3, loc := #caller_location) {
	assert_not_nil(transform, loc)

	transform.position = position
	transform.dirty = true
}

transform_set_scale :: proc(transform: ^Transform, scale: vec3, loc := #caller_location) {
	assert_not_nil(transform, loc)

	transform.scale = scale
	transform.dirty = true
}

@(private)
_transform_apply :: proc(transform: ^Transform, g: ^Graphics, loc := #caller_location) {
	assert_not_nil(transform, loc)
	assert_not_nil(g, loc)

	if !transform.dirty {
		return
	}

	transform.model = glsl.mat4Translate(transform.position) * glsl.mat4Scale(transform.scale)
	transform.dirty = false

	buffer := bindless_get_buffer(g, transform.buffer_h)
	transform_ubo := Transform_UBO {
		model   = transform.model,
		tangens = 0,
	}

	_fill_buffer(buffer, g.vulkan_state, size_of(Transform_UBO), &transform_ubo)
}

destroy_transform :: proc(g: ^Graphics, transform: ^Transform, loc := #caller_location) {
	assert_not_nil(transform, loc)
	bindless_destroy_buffer(g, transform.buffer_h)
}
