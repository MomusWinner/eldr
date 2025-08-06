package graphics

import hm "../handle_map"
import "base:runtime"
import "core:mem"
import vk "vendor:vulkan"

pipeline_hot_reload :: proc(g: ^Graphics) {
	_pipeline_manager_hot_reload(g.pipeline_manager, g)
}

get_graphics_pipeline :: proc(g: ^Graphics, handle: hm.Handle) -> (^Graphics_Pipeline, bool) {
	return _get_graphics_pipeline(g.pipeline_manager, handle)
}

get_compute_pipeline :: proc(g: ^Graphics, handle: hm.Handle) -> (^Compute_Pipeline, bool) {
	return _get_compute_pipeline(g.pipeline_manager, handle)
}

@(private)
_pipeline_manager_new :: proc() -> ^Pipeline_Manager {
	pm := new(Pipeline_Manager)
	return pm
}

@(private)
_pipeline_manager_destroy :: proc(pm: ^Pipeline_Manager, device: vk.Device) {
	for &pipeline in pm.pipelines.values {
		destroy_graphics_pipeline(device, &pipeline)
	}
	for &pipeline in pm.compute_pipelines.values {
		destroy_compute_pipeline(device, &pipeline)
	}
	hm.destroy(&pm.pipelines)
	hm.destroy(&pm.compute_pipelines)

	free(pm)
}

@(private)
_registe_graphics_pipeline :: proc(pm: ^Pipeline_Manager, pipeline: Graphics_Pipeline) -> hm.Handle {
	return hm.insert(&pm.pipelines, pipeline)
}

@(private)
_registe_compute_pipeline :: proc(pm: ^Pipeline_Manager, pipeline: Compute_Pipeline) -> hm.Handle {
	return hm.insert(&pm.compute_pipelines, pipeline)
}

@(private)
_get_graphics_pipeline :: proc(pm: ^Pipeline_Manager, handle: hm.Handle) -> (^Graphics_Pipeline, bool) {
	return hm.get(&pm.pipelines, handle)
}

@(private)
_get_compute_pipeline :: proc(pm: ^Pipeline_Manager, handle: hm.Handle) -> (^Compute_Pipeline, bool) {
	return hm.get(&pm.compute_pipelines, handle)
}

@(private)
_pipeline_manager_hot_reload :: proc(pm: ^Pipeline_Manager, g: ^Graphics) {
	for &pipeline in pm.pipelines.values {
		pipeline_info: ^Create_Pipeline_Info

		_reload_graphics_pipeline(g, &pipeline)
	}
}
