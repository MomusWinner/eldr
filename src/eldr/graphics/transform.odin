package graphics

import "core:math/linalg/glsl"

init_trf :: proc(g: ^Graphics, transform: ^Transform, loc := #caller_location) {
	assert_not_nil(g, loc)
	assert_not_nil(transform, loc)

	buffer := create_uniform_buffer(g.vulkan_state, size_of(Transform_UBO))
	transform.scale = 1
	// transform.rotation = glsl.quatAxisAngle({0, 0, 1}, 0)
	transform.position = 0
	transform.dirty = true
	transform.buffer_h = bindless_store_buffer(g, buffer)

}

trf_set_position :: proc(transform: ^Transform, position: vec3, loc := #caller_location) {
	assert_not_nil(transform, loc)

	transform.position = position
	transform.dirty = true
}

trf_set_scale :: proc(transform: ^Transform, scale: vec3, loc := #caller_location) {
	assert_not_nil(transform, loc)

	transform.scale = scale
	transform.dirty = true
}

trf_get_forward :: proc(trf: ^Transform) -> vec3 {
	return glsl.quatMulVec3(trf.rotation, {0, 0, 1})
}

trf_get_up :: proc(trf: ^Transform) -> vec3 {
	return glsl.quatMulVec3(trf.rotation, {0, 1, 0})
}

trf_get_right :: proc(trf: ^Transform) -> vec3 {
	return glsl.quatMulVec3(trf.rotation, {1, 0, 0})
}

@(private)
_trf_apply :: proc(transform: ^Transform, g: ^Graphics, loc := #caller_location) {
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

destroy_trf :: proc(g: ^Graphics, transform: ^Transform, loc := #caller_location) {
	assert_not_nil(transform, loc)
	bindless_destroy_buffer(g, transform.buffer_h)
}
