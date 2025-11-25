package graphics

import "../common/"
import hm "../handle_map"
import "base:runtime"
import "core:c"
import "core:log"
import "core:mem"
import "core:path/filepath"
import "core:strings"
import "shaderc"
import vk "vendor:vulkan"

pipeline_hot_reload :: proc(g: ^Graphics) {
	_pipeline_manager_hot_reload(g.pipeline_manager, g)
}

get_graphics_pipeline :: proc(g: ^Graphics, handle: Pipeline_Handle) -> (^Graphics_Pipeline, bool) {
	return _pipeline_manager_get_graphics_pipeline(g.pipeline_manager, handle)
}

get_compute_pipeline :: proc(g: ^Graphics, handle: Pipeline_Handle) -> (^Compute_Pipeline, bool) {
	return _pipeline_manager_get_compute_pipeline(g.pipeline_manager, handle)
}

_init_pipeline_manager :: proc(g: ^Graphics, enable_compilation: bool) {
	assert(g.pipeline_manager == nil)
	g.pipeline_manager = new(Pipeline_Manager)
	_pipeline_manager_init(g.pipeline_manager, enable_compilation)
}

_destroy_pipeline_manager :: proc(g: ^Graphics) {
	_pipeline_manager_destroy(g.pipeline_manager, g.vulkan_state)
	free(g.pipeline_manager)
}

@(private = "file")
_pipeline_manager_init :: proc(pm: ^Pipeline_Manager, enable_compilation: bool) {
	pm.enable_compilation = enable_compilation
	if pm.enable_compilation {
		when DEBUG {
			_pipeline_manager_setup_compiler(pm)
		} else {
			log.panic("Couldn't setup Pipeline_Manager compiler in RELEASE mode")
		}
	}
}

@(private = "file")
_pipeline_manager_destroy :: proc(pm: ^Pipeline_Manager, vks: Vulkan_State) {
	for &pipeline in pm.pipelines.values {
		destroy_graphics_pipeline(vks, &pipeline)
	}
	for &pipeline in pm.compute_pipelines.values {
		destroy_compute_pipeline(vks, &pipeline)
	}
	hm.destroy(&pm.pipelines)
	hm.destroy(&pm.compute_pipelines)
	when DEBUG {
		shaderc.compile_options_release(pm.compiler_options)
		shaderc.compiler_release(pm.compiler)
	}
}

@(private)
_pipeline_manager_registe_graphics_pipeline :: proc(
	pm: ^Pipeline_Manager,
	pipeline: Graphics_Pipeline,
) -> Pipeline_Handle {
	return hm.insert(&pm.pipelines, pipeline)
}

@(private)
_pipeline_manager_registe_compute_pipeline :: proc(
	pm: ^Pipeline_Manager,
	pipeline: Compute_Pipeline,
) -> Pipeline_Handle {
	return hm.insert(&pm.compute_pipelines, pipeline)
}

@(private = "file")
_pipeline_manager_get_graphics_pipeline :: proc(
	pm: ^Pipeline_Manager,
	handle: Pipeline_Handle,
) -> (
	^Graphics_Pipeline,
	bool,
) {
	return hm.get(&pm.pipelines, handle)
}

@(private = "file")
_pipeline_manager_get_compute_pipeline :: proc(
	pm: ^Pipeline_Manager,
	handle: Pipeline_Handle,
) -> (
	^Compute_Pipeline,
	bool,
) {
	return hm.get(&pm.compute_pipelines, handle)
}

@(private = "file")
_pipeline_manager_hot_reload :: proc(pm: ^Pipeline_Manager, g: ^Graphics) {
	assert(pm.enable_compilation)

	vk.WaitForFences(g.vulkan_state.device, 1, &g.fence, true, max(u64))

	log.debug("--- RELOADING SHADERS ---")
	for &pipeline in pm.pipelines.values {
		pipeline_info: ^Create_Pipeline_Info

		_reload_graphics_pipeline(g, &pipeline)
	}
}

@(private = "file")
_pipeline_manager_setup_compiler :: proc(pm: ^Pipeline_Manager) {
	pm.compiler = shaderc.compiler_initialize()
	pm.compiler_options = shaderc.compile_options_initialize()
	shaderc.compile_options_set_include_callbacks(
		pm.compiler_options,
		_shader_resolve_include,
		_shader_result_releaser,
		nil,
	)
}

@(private = "file")
_shader_resolve_include :: proc "system" (
	userData: rawptr,
	requestedSource: cstring,
	type: c.int,
	requestingSource: cstring,
	ncludeDepth: c.size_t,
) -> ^shaderc.includeResult {
	context = g_ctx

	BUILDIN :: "buildin:"
	source: string = strings.clone_from_cstring(requestedSource, allocator = context.temp_allocator)
	path_to_include: strings.Builder
	strings.builder_init_none(&path_to_include, context.temp_allocator)

	if strings.starts_with(source, BUILDIN) {
		strings.write_string(&path_to_include, "./assets/buildin/shaders/")
		strings.write_string(&path_to_include, source[len(BUILDIN):])
	} else {
		strings.write_string(&path_to_include, "./assets/shaders/")
		strings.write_string(&path_to_include, source)
	}

	file := strings.to_string(path_to_include)
	content, ok := common.read_file(file, context.temp_allocator)
	if !ok {
		log.error("Couldn't read include file", file)
	}

	result := new(shaderc.includeResult)
	result.sourceName = strings.clone_to_cstring(file)
	result.sourceNameLength = len(result.sourceName)
	result.content = strings.clone_to_cstring(cast(string)content)
	result.contentLength = len(result.content)

	return result
}

@(private = "file")
_shader_result_releaser :: proc "system" (userData: rawptr, includeResult: ^shaderc.includeResult) {
	context = g_ctx
	delete(includeResult.sourceName)
	delete(includeResult.content)
	free(includeResult)
}

default_shader_attribute :: proc() -> (Vertex_Input_Binding_Description, [4]Vertex_Input_Attribute_Description) {
	bind_description := Vertex_Input_Binding_Description {
		binding   = 0,
		stride    = size_of(Vertex),
		inputRate = .VERTEX,
	}

	attribute_descriptions := [4]Vertex_Input_Attribute_Description {
		Vertex_Input_Attribute_Description {
			binding = 0,
			location = 0,
			format = .R32G32B32_SFLOAT,
			offset = cast(u32)offset_of(Vertex, position),
		},
		Vertex_Input_Attribute_Description {
			binding = 0,
			location = 1,
			format = .R32G32_SFLOAT,
			offset = cast(u32)offset_of(Vertex, tex_coord),
		},
		Vertex_Input_Attribute_Description {
			binding = 0,
			location = 2,
			format = .R32G32B32_SFLOAT,
			offset = cast(u32)offset_of(Vertex, normal),
		},
		Vertex_Input_Attribute_Description {
			binding = 0,
			location = 3,
			format = .R32G32B32A32_SFLOAT,
			offset = cast(u32)offset_of(Vertex, color),
		},
	}

	return bind_description, attribute_descriptions
}
