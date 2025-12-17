package main

import "../eldr"
import gfx "../eldr/graphics"
import "base:runtime"
import "core:log"
import "core:math"
import "core:math/rand"
import "core:time"

@(material)
Light_Material :: struct {
	direction: vec3,
	diffuse:   vec4,
	ambient:   vec4,
	view_pos:  vec3,
	color:     vec4,
	shininess: f32,
}

Lighting_Scene_Data :: struct {
	model:     gfx.Model,
	transform: gfx.Gfx_Transform,
	camera:    gfx.Camera,
	light_y:   f32,
}

create_light_scene :: proc() -> Scene {
	return Scene {
		init = light_scene_init,
		update = light_scene_update,
		draw = light_scene_draw,
		destroy = light_scene_destroy,
	}
}

light_scene_init :: proc(s: ^Scene) {
	data := new(Lighting_Scene_Data)

	// Init Camera
	data.camera = gfx.Camera {
		position = {0, 0, 2},
		target   = {0, 0, 0},
		up       = {0, 1, 0},
	}
	gfx.camera_init(&data.camera)

	// Load Model
	data.model = eldr.load_model("./assets/Suzanne.obj")
	pipeline_h := create_light_pipeline()

	// Setup Material
	material: gfx.Material
	init_mtrl_light(&material, pipeline_h)
	mtrl_light_set_diffuse(&material, {1, 1, 1, 1})
	mtrl_light_set_ambient(&material, {0.14, 0.14, 0.14, 14.0})
	mtrl_light_set_color(&material, {0.81, 0.447, 0.105, 1})
	append(&data.model.materials, material)
	append(&data.model.mesh_material, 0)

	// Setup Transform
	gfx.init_gfx_trf(&data.transform)
	eldr.trf_set_position(&data.transform, {0, 0, -1})
	eldr.trf_set_scale(&data.transform, {0.5, 0.5, 0.5})

	s.data = data
}

light_scene_update :: proc(s: ^Scene) {
	data := cast(^Lighting_Scene_Data)s.data

	data.light_y += eldr.get_delta_time() / 2
	mtrl_light_set_direction(&data.model.materials[0], {math.cos_f32(data.light_y), math.sin_f32(data.light_y), 0})
	mtrl_light_set_view_pos(&data.model.materials[0], data.camera.position)
}

light_scene_draw :: proc(s: ^Scene) {
	data := cast(^Lighting_Scene_Data)s.data

	frame := gfx.begin_render()

	// Begin gfx.
	// --------------------------------------------------------------------------------------------------------------------

	gfx.set_full_viewport_scissor(frame)

	base_frame := gfx.begin_draw(frame)
	{
		gfx.draw_model(base_frame, data.model, &data.camera, &data.transform)
	}
	gfx.end_draw(frame)

	// --------------------------------------------------------------------------------------------------------------------
	// End gfx.
	gfx.end_render(frame)
}

light_scene_destroy :: proc(s: ^Scene) {
	data := cast(^Lighting_Scene_Data)s.data

	gfx.destroy_model(&data.model)

	free(data)
}
