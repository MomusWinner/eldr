package main

import "base:runtime"
import "core:log"
import "core:math"
import "core:math/linalg/glsl"
import "core:math/rand"
import "eldr"
import gfx "eldr/graphics"
import "vendor:glfw"
import vk "vendor:vulkan"

UniformBufferObject :: struct {
	model:      glsl.mat4,
	view:       glsl.mat4,
	projection: glsl.mat4,
}

RoomSceneData :: struct {
	room_texture:   eldr.Texture,
	room_ubo:       gfx.Uniform_Buffer,
	room_model:     eldr.Model,
	pipeline_h:     gfx.Handle,
	descriptor_set: vk.DescriptorSet,
}

create_room_scene :: proc(e: ^eldr.Eldr) -> Scene {
	return Scene {
		e = e,
		init = room_scene_init,
		update = room_scene_update,
		draw = room_scene_draw,
		destroy = room_scene_destroy,
	}
}

room_scene_init :: proc(s: ^Scene) {
	e := s.e
	room_data := new(RoomSceneData)
	room_data.room_texture = eldr.load_texture(e, "./assets/room.png")
	room_data.room_model = eldr.load_model(e, "./assets/room.obj")
	room_data.room_ubo = gfx.create_uniform_buffer(e.g, cast(vk.DeviceSize)size_of(UniformBufferObject))
	pipeline_h := create_default_pipeline(e)
	s.data = room_data

	pipeline, _ := gfx.get_graphics_pipeline(s.e.g, room_data.pipeline_h)

	room_data.descriptor_set = gfx.create_descriptor_set(
		e.g,
		pipeline,
		pipeline.create_info.set_infos[0],
		{room_data.room_ubo, room_data.room_texture},
	)

	init_unfiform_buffer(&room_data.room_ubo, s.e.g.swapchain.extent)
}

room_scene_update :: proc(s: ^Scene, dt: f64) {
	e := s.e
	data := cast(^RoomSceneData)s.data
	update_unfiform_buffer(&data.room_ubo, s.e.g.swapchain.extent)
}

room_scene_draw :: proc(s: ^Scene) {
	e := s.e
	data := cast(^RoomSceneData)s.data

	pipeline, ok := gfx.get_graphics_pipeline(e.g, data.pipeline_h)

	gfx.begin_render(e.g)
	// Begin gfx. ------------------------------

	viewport := vk.Viewport {
		width    = f32(e.g.swapchain.extent.width),
		height   = f32(e.g.swapchain.extent.height),
		maxDepth = 1.0,
	}
	vk.CmdSetViewport(e.g.cmd, 0, 1, &viewport)

	scissor := vk.Rect2D {
		extent = e.g.swapchain.extent,
	}
	vk.CmdSetScissor(e.g.cmd, 0, 1, &scissor)

	gfx.bind_pipeline(e.g, pipeline)

	offset := vk.DeviceSize{}
	vk.CmdBindVertexBuffers(e.g.cmd, 0, 1, &data.room_model.vbo.buffer, &offset)
	vk.CmdBindIndexBuffer(e.g.cmd, data.room_model.ebo.buffer, 0, .UINT16)

	gfx.bind_descriptor_set(e.g, pipeline, &data.descriptor_set)
	vk.CmdDrawIndexed(e.g.cmd, cast(u32)len(data.room_model.indices), 1, 0, 0, 0)

	// End gfx. ------------------------------
	gfx.end_render(e.g, []vk.Semaphore{}, {})

}

room_scene_destroy :: proc(s: ^Scene) {
	g := s.e.g
	data := cast(^RoomSceneData)s.data

	eldr.unload_texture(s.e, &data.room_texture)
	gfx.destroy_uniform_buffer(g, &data.room_ubo)
	eldr.destroy_model(s.e, &data.room_model)
	free(data)
}

init_unfiform_buffer :: proc(buffer: ^gfx.Uniform_Buffer, extend: vk.Extent2D) {
	ubo := UniformBufferObject{}
	ubo.model = glsl.mat4Rotate(glsl.vec3{0, 0, 0}, glsl.radians_f32(0))
	ubo.model = glsl.mat4Translate(glsl.vec3{0, 0, 0})
	ubo.view = glsl.mat4LookAt(glsl.vec3{2, 2, 2}, glsl.vec3{0, 0, 0}, glsl.vec3{0, 0, 1})
	ubo.projection = glsl.mat4Perspective(
		glsl.radians_f32(45),
		(cast(f32)extend.width / cast(f32)extend.height),
		0.1,
		10,
	)
	// NOTE: GLM was originally designed for OpenGL, where the Y coordinate of the clip coordinates is inverted
	ubo.projection[1][1] *= -1

	runtime.mem_copy(buffer.mapped, &ubo, size_of(ubo))
}

update_unfiform_buffer :: proc(buffer: ^gfx.Uniform_Buffer, extend: vk.Extent2D) {
	ubo := UniformBufferObject{}
	ubo.model = glsl.mat4Rotate(glsl.vec3{1, 1, 1}, cast(f32)glfw.GetTime() * glsl.radians_f32(90))
	ubo.view = glsl.mat4LookAt(glsl.vec3{0, 0, 2}, glsl.vec3{0, 0, 0}, glsl.vec3{0, 1, 0})
	ubo.projection = glsl.mat4Perspective(
		glsl.radians_f32(45),
		(cast(f32)extend.width / cast(f32)extend.height),
		0.1,
		10,
	)
	// NOTE: GLM was originally designed for OpenGL, where the Y coordinate of the clip coordinates is inverted
	ubo.projection[1][1] *= -1

	runtime.mem_copy(buffer.mapped, &ubo, size_of(ubo)) // TODO: create special function
}
