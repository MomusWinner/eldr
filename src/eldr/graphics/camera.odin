package graphics

import "core:log"
import "core:math/linalg/glsl"
import vk "vendor:vulkan"

@(private)
DEFAULT_FOV :: 45
@(private)
DEFAULT_NEAR :: 0.01
@(private)
DEFAULT_FAR :: 100

camera_init :: proc(camera: ^Camera, g: ^Graphics, loc := #caller_location) {
	assert_not_nil(g, loc)
	assert_not_nil(camera, loc)

	camera.fov = DEFAULT_FOV
	camera.near = DEFAULT_NEAR
	camera.far = DEFAULT_FAR
	camera.zoom = vec3{1, 1, 1}

	buffer := create_uniform_buffer(g.vulkan_state, size_of(Camera_UBO))
	camera._buffer_h = bindless_store_buffer(g, buffer)
}

camera_get_forward :: proc(camera: ^Camera, loc := #caller_location) -> vec3 {
	assert_not_nil(camera, loc)

	return glsl.normalize_vec3(camera.target - camera.position)
}

camera_get_right :: proc(camera: ^Camera, loc := #caller_location) -> vec3 {
	assert_not_nil(camera, loc)

	return glsl.normalize(glsl.cross(camera_get_forward(camera), camera.up))
}

camera_get_left :: proc(camera: ^Camera, loc := #caller_location) -> vec3 {
	assert_not_nil(camera, loc)

	return -camera_get_right(camera)
}

camera_set_yaw :: proc(camera: ^Camera, angle: f32, loc := #caller_location) {
	assert_not_nil(camera, loc)

	target_position := camera.target - camera.position
	trans := glsl.mat4Rotate(camera.up, glsl.radians(angle))
	target := trans * vec4{target_position.x, target_position.y, target_position.z, 0}
	camera.target = target.xyz

	camera.dirty = true
}

camera_set_pitch :: proc(camera: ^Camera, angle: f32, loc := #caller_location) {
	assert_not_nil(camera, loc)

	target_position := camera.target - camera.position
	trans := glsl.mat4Rotate(camera_get_right(camera), glsl.radians(angle))
	target := trans * vec4{target_position.x, target_position.y, target_position.z, 0}
	camera.target = target.xyz

	camera.dirty = true
}

camera_set_roll :: proc(camera: ^Camera, angle: f32, loc := #caller_location) {
	assert_not_nil(camera, loc)

	target_position := camera.target - camera.position
	trans := glsl.mat4Rotate(camera_get_forward(camera), glsl.radians(angle))
	target := trans * vec4{target_position.x, target_position.y, target_position.z, 0}
	camera.target = target.xyz

	camera.dirty = true
}

camera_set_zoom :: proc(camera: ^Camera, zoom: vec3, loc := #caller_location) {
	assert_not_nil(camera, loc)

	camera.zoom = zoom

	camera.dirty = true
}

camera_get_view :: proc(camera: ^Camera, loc := #caller_location) -> mat4 {
	assert_not_nil(camera, loc)

	return(
		glsl.mat4LookAt(camera.position, camera.position + camera_get_forward(camera), camera.up) *
		glsl.mat4Scale(camera.zoom) \
	)
}

camera_get_projection :: proc(camera: ^Camera, aspect: f32, loc := #caller_location) -> mat4 {
	assert_not_nil(camera, loc)

	projection := glsl.mat4Perspective(glsl.radians_f32(camera.fov), aspect, camera.near, camera.far)
	// NOTE: GLM was originally designed for OpenGL, where the Y coordinate of the clip coordinates is inverted
	projection[1][1] *= -1

	return projection
}

@(private)
_camera_get_buffer :: proc(camera: ^Camera, g: ^Graphics, aspect: f32, loc := #caller_location) -> Buffer_Handle {
	assert_not_nil(g, loc)
	assert_not_nil(camera, loc)

	if !camera.dirty && aspect == camera.last_aspect {
		return camera._buffer_h
	}

	camera.last_aspect = aspect

	view := camera_get_view(camera)
	projection := camera_get_projection(camera, aspect)

	buffer := bindless_get_buffer(g, camera._buffer_h)
	camera_ubo := Camera_UBO {
		view       = view,
		projection = projection,
	}
	_fill_buffer(buffer, g.vulkan_state, size_of(Camera_UBO), &camera_ubo)

	return camera._buffer_h
}

// Resolution independed camera extension

// Resoulution_Independed_Ext :: struct {
// 	virtual_size:    ivec2,
// 	screen_size:     ivec2,
// 	scale_mat:       mat4,
// 	translation_mat: mat4,
// 	dirty:           bool,
// }
//
// camera_add_resoulution_independed_ext :: proc(camera: ^Camera, screenSize: ivec2, virtualSize: ivec2) {
// 	resoulution_indepened_ext := Resoulution_Independed_Ext {
// 		screen_size  = screenSize,
// 		virtual_size = virtualSize,
// 		dirty        = true,
// 	}
//
// 	camera.extension = Camera_Extension {
// 		data                       = resoulution_indepened_ext,
// 		get_view_matrix_multiplier = resoulution_independed_get_view_ext,
// 		test                       = 32,
// 	}
// }
//
// camera_get_resoulution_independed_ext :: proc(camera: ^Camera) -> Resoulution_Independed_Ext {
// 	extension, has_extension := camera.extension.?
// 	assert(has_extension)
// 	ri, ok := extension.data.(Resoulution_Independed_Ext)
// 	assert(ok)
//
// 	return ri
// }
//
// // resoulution_independed_set_screen_size :: proc(ri: ^Resoulution_Independed_Ext, screenSize: ivec2) {
// // 	ri.screen_size = screenSize
// // 	ri.dirty = true
// // } TODO: 
// //
// // resoulution_independed_set_virtual_size :: proc(ri: ^Resoulution_Independed_Ext, virtual_size: ivec2) {
// // 	ri.virtual_size = virtual_size
// // 	ri.dirty = true
// // }
//
//
// resoulution_independed_get_view_ext :: proc(data: Camera_Extension_Data) -> mat4 {
// 	ri, ok := data.(Resoulution_Independed_Ext)
// 	assert(ok)
//
// 	if ri.dirty {
// 		ri.scale_mat = glsl.mat4Scale(
// 			vec3 {
// 				cast(f32)ri.screen_size.x / cast(f32)ri.virtual_size.x,
// 				cast(f32)ri.screen_size.x / cast(f32)ri.virtual_size.x,
// 				1,
// 			},
// 		)
// 		// ri.scale_mat = 1
// 		// ri.scale_mat[0][0] = 0.12
// 		// ri.scale_mat[2][2] = 0.22
//
// 		ri.translation_mat = glsl.mat4Translate(
// 			vec3{cast(f32)ri.virtual_size.x * 0.5, cast(f32)ri.virtual_size.y * 0.5, 1},
// 		)
// 		ri.dirty = false
// 	}
//
// 	return ri.scale_mat // * ri.translation_mat
// }
//
// resoulution_independed_set_viewport :: proc(camera: ^Camera, g: ^Graphics, cmd: Command_Buffer) {
// 	ri := camera_get_resoulution_independed_ext(camera)
//
// 	target_aspect_ratio := cast(f32)ri.virtual_size.x / cast(f32)ri.virtual_size.y
//
// 	width := ri.screen_size.x
// 	height := cast(i32)(cast(f32)width / target_aspect_ratio + .5)
//
// 	if height > ri.screen_size.y {
// 		height = ri.screen_size.y
// 		width = (i32)(cast(f32)height * target_aspect_ratio + .5)
// 	}
//
// 	viewport := vk.Viewport {
// 		x        = cast(f32)(ri.screen_size.x / 2) - (cast(f32)width / 2),
// 		y        = cast(f32)(ri.screen_size.y / 2) - (cast(f32)height / 2),
// 		width    = cast(f32)width,
// 		height   = cast(f32)height,
// 		maxDepth = 1.0,
// 	}
// 	vk.CmdSetViewport(cmd, 0, 1, &viewport)
//
// 	scissor := vk.Rect2D {
// 		extent = g.swapchain.extent,
// 	}
// 	vk.CmdSetScissor(cmd, 0, 1, &scissor)
// }
