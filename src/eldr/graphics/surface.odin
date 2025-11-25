package graphics

import hm "../handle_map/"
import "base:runtime"
import "core:log"
import "core:mem"
import "core:time"
import vk "vendor:vulkan"
import "vma"

// TODO: ! Make surface more flexible

@(require_results)
create_surface :: proc(
	g: ^Graphics,
	sample_count: Sample_Count_Flag,
	anisotropy: f32,
	allocator := context.allocator,
	loc := #caller_location,
) -> Surface_Handle {
	assert_not_nil(g, loc)
	return _surface_manager_create_surface(g.surface_manager, g, sample_count, anisotropy, allocator)
}

destroy_surface :: proc(g: ^Graphics, surface_h: Surface_Handle, loc := #caller_location) {
	assert_not_nil(g, loc)
	_surface_manager_destroy_surface(g.surface_manager, g, surface_h)
}

@(require_results)
get_surface :: proc(g: ^Graphics, surface_h: Surface_Handle, loc := #caller_location) -> (^Surface, bool) {
	assert_not_nil(g, loc)
	return _surface_manager_get_surface(g.surface_manager, surface_h)
}

surface_add_color_attachment :: proc(
	surface: ^Surface,
	g: ^Graphics,
	clear_value: color = {0.01, 0.01, 0.01, 1.0},
	loc := #caller_location,
) {
	assert_not_nil(g, loc)
	assert_not_nil(surface, loc)

	width, height := get_screen_width(g), get_screen_height(g)

	color_resource := _create_surface_color_resource(
		g.vulkan_state,
		width,
		height,
		g.swapchain.format.format,
		surface.sample_count,
	)
	color_resolve_resource := _create_surface_color_resolve_resource(
		g.vulkan_state,
		width,
		height,
		surface.anisotropy,
		g.swapchain.format.format,
	)

	color_attachment := Surface_Color_Attachment {
		info = {
			sType = .RENDERING_ATTACHMENT_INFO,
			pNext = nil,
			imageView = color_resource.view,
			imageLayout = .ATTACHMENT_OPTIMAL,
			resolveMode = {.AVERAGE_KHR},
			resolveImageView = color_resolve_resource.view,
			resolveImageLayout = .GENERAL,
			loadOp = .CLEAR,
			storeOp = .STORE,
			clearValue = vk.ClearValue{color = {float32 = clear_value}},
		},
	}
	surface.color_attachment = color_attachment

	color_attachment.resource = color_resource
	color_attachment.resolve_handle = bindless_store_texture(g, color_resolve_resource)
	surface.color_attachment = color_attachment
}

surface_add_depth_attachment :: proc(surface: ^Surface, g: ^Graphics, clear_value: f32 = 1, loc := #caller_location) {
	assert_not_nil(surface, loc)

	sc := _cmd_single_begin(g.vulkan_state)
	width, height := get_screen_width(g), get_screen_height(g)
	depth_resource := _create_surface_depth_resource(
		g.vulkan_state,
		width,
		height,
		sc.command_buffer,
		surface.sample_count,
	)
	_cmd_single_end(sc, g.vulkan_state)

	depth_attachment := Surface_Depth_Attachment {
		resource = depth_resource,
		info = {
			sType = .RENDERING_ATTACHMENT_INFO,
			pNext = nil,
			imageView = depth_resource.view,
			imageLayout = .DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
			loadOp = .CLEAR,
			storeOp = .DONT_CARE,
			clearValue = vk.ClearValue{depthStencil = {clear_value, 0}},
		},
	}
	surface.depth_attachment = depth_attachment
}

@(require_results)
begin_surface :: proc(surface: ^Surface, frame_data: Frame_Data, loc := #caller_location) -> Frame_Data {
	assert_not_nil(surface, loc)

	cmd := frame_data.cmd

	color_attachment, has_color_attachment := surface.color_attachment.?
	depth_attachment, has_depth_attachment := surface.depth_attachment.?
	assert(has_color_attachment || has_depth_attachment, "Couldn't begin_surface() without attachments")

	begin_info := vk.CommandBufferBeginInfo {
		sType = .COMMAND_BUFFER_BEGIN_INFO,
	}

	p_color_attachment: ^vk.RenderingAttachmentInfo = nil
	p_depth_attachment: ^vk.RenderingAttachmentInfo = nil

	if has_color_attachment {
		_transition_image_layout_from_cmd(
			cmd,
			color_attachment.resource.image,
			{.COLOR},
			color_attachment.resource.format,
			.UNDEFINED,
			.COLOR_ATTACHMENT_OPTIMAL,
			1,
		)

		p_color_attachment = &color_attachment.info
	}

	if has_depth_attachment {
		p_depth_attachment = &depth_attachment.info
	}

	rendering_info := vk.RenderingInfo {
		sType = .RENDERING_INFO,
		renderArea = {extent = surface.extent},
		layerCount = 1,
		colorAttachmentCount = 1,
		pColorAttachments = p_color_attachment,
		pDepthAttachment = p_depth_attachment,
	}

	vk.CmdBeginRendering(cmd, &rendering_info)

	frame_data := frame_data
	frame_data.surface_info = {
		type         = .Surface,
		sample_count = surface.sample_count,
	}

	return frame_data
}

end_surface :: proc(surface: ^Surface, frame_data: Frame_Data, loc := #caller_location) {
	assert_not_nil(surface, loc)

	vk.CmdEndRendering(frame_data.cmd)

	color_attachment, has_color_attachment := surface.color_attachment.?

	if has_color_attachment {
		_transition_image_layout_from_cmd(
			frame_data.cmd,
			color_attachment.resource.image,
			{.COLOR},
			color_attachment.resource.format,
			.COLOR_ATTACHMENT_OPTIMAL,
			.SHADER_READ_ONLY_OPTIMAL,
			1,
		)
	}
}

draw_surface :: proc(
	surface: ^Surface,
	g: ^Graphics,
	frame_data: Frame_Data,
	pipeline_h: Pipeline_Handle,
	loc := #caller_location,
) {
	assert_not_nil(surface, loc)
	assert_not_nil(g, loc)

	camera := Camera{} // FIX:
	color_attachment, has_color := surface.color_attachment.?
	assert(has_color, loc = loc)

	surface.model.materials[0].pipeline_h = pipeline_h
	surface.model.materials[0].texture_h = color_attachment.resolve_handle
	_material_apply(&surface.model.materials[0], g)
	draw_model(g, frame_data, surface.model, &camera, &surface.transform, loc)
}

_init_surface_manager :: proc(g: ^Graphics) {
	assert(g.surface_manager == nil)
	g.surface_manager = new(Surface_Manager)
	_surface_manager_init(g.surface_manager)
}

_destroy_surface_manager :: proc(g: ^Graphics) {
	_surface_manager_destroy(g.surface_manager, g)
	free(g.surface_manager)
}

@(private = "file")
_surface_manager_init :: proc(sm: ^Surface_Manager, loc := #caller_location) {
	assert_not_nil(sm, loc)
}

@(private = "file")
_surface_manager_destroy :: proc(sm: ^Surface_Manager, g: ^Graphics, loc := #caller_location) {
	assert_not_nil(sm, loc)
	assert_not_nil(g, loc)

	for &surface in sm.surfaces.values {
		_surface_destroy(&surface, g)
	}

	hm.destroy(&sm.surfaces)
}

@(private)
@(require_results)
_surface_manager_create_surface :: proc(
	sm: ^Surface_Manager,
	g: ^Graphics,
	sample_count: Sample_Count_Flag,
	anisotropy: f32,
	allocator := context.allocator,
	loc := #caller_location,
) -> Surface_Handle {
	assert_not_nil(sm, loc)
	assert_not_nil(g, loc)

	surface := Surface{}
	_surface_init(&surface, g, sample_count, anisotropy)

	return hm.insert(&sm.surfaces, surface)
}

@(private)
@(require_results)
_surface_manager_get_surface :: proc(
	sm: ^Surface_Manager,
	surface_h: Surface_Handle,
	loc := #caller_location,
) -> (
	^Surface,
	bool,
) {
	assert_not_nil(sm, loc)

	return hm.get(&sm.surfaces, surface_h)
}

@(private)
_surface_manager_destroy_surface :: proc(
	sm: ^Surface_Manager,
	g: ^Graphics,
	surface_h: Surface_Handle,
	loc := #caller_location,
) {
	assert_not_nil(sm, loc)
	assert_not_nil(g, loc)

	surface, ok := hm.remove(&sm.surfaces, surface_h)

	if ok {
		_surface_destroy(&surface, g)
	}
}

@(private)
_surface_manager_recreate_surfaces :: proc(sm: ^Surface_Manager, g: ^Graphics, loc := #caller_location) {
	assert_not_nil(sm, loc)
	assert_not_nil(g, loc)

	for &surface in sm.surfaces.values {
		surface_recreate(&surface, g)
	}
}

@(private)
_surface_init :: proc(
	surface: ^Surface,
	g: ^Graphics,
	sample_count: Sample_Count_Flag,
	anisotropy: f32,
	allocator := context.allocator,
	loc := #caller_location,
) {
	assert_not_nil(surface, loc)
	assert_not_nil(g, loc)

	surface.extent = {
		width  = get_device_width(g),
		height = get_device_height(g),
	}

	material: Material
	init_material(g, &material, {})

	mesh := create_square_mesh(g, 1)

	meshes := make([]Mesh, 1)
	meshes[0] = mesh

	materials := make([dynamic]Material, 1, allocator)
	materials[0] = material

	mesh_material := make([dynamic]int, 1, allocator)
	mesh_material[0] = 0

	init_trf(g, &surface.transform)

	surface.model = create_model(meshes, materials, mesh_material)
	surface.sample_count = sample_count
	surface.anisotropy = anisotropy
}

@(private)
_surface_destroy :: proc(surface: ^Surface, g: ^Graphics, loc := #caller_location) {
	assert_not_nil(surface, loc)
	assert_not_nil(g, loc)

	destroy_model(g, &surface.model)
	color_attachment, has_color_attachment := surface.color_attachment.?
	depth_attachment, has_depth_attachment := surface.depth_attachment.?

	if has_color_attachment {
		destroy_texture(g.vulkan_state, &color_attachment.resource)
	}

	if has_depth_attachment {
		destroy_texture(g.vulkan_state, &depth_attachment.resource)
	}
}

surface_recreate :: proc(surface: ^Surface, g: ^Graphics, loc := #caller_location) {
	must(vk.QueueWaitIdle(g.vulkan_state.graphics_queue))

	surface.extent.width = get_screen_width(g)
	surface.extent.height = get_screen_height(g)

	color_attachment, has_color_attachment := surface.color_attachment.?
	depth_attachment, has_depth_attachment := surface.depth_attachment.?

	if has_color_attachment {
		destroy_texture(g.vulkan_state, &color_attachment.resource)
		bindless_destroy_texture(g, color_attachment.resolve_handle)
		surface_add_color_attachment(surface, g)
	}

	if has_depth_attachment {
		destroy_texture(g.vulkan_state, &depth_attachment.resource)
		surface_add_depth_attachment(surface, g)
	}
}

@(private = "file")
@(require_results)
_create_surface_color_resource :: proc(
	vks: Vulkan_State,
	width, height: u32,
	format: vk.Format,
	sample_count: Sample_Count_Flag,
	loc := #caller_location,
) -> Texture {
	image, allocation, allocation_info := _create_image(
		vks,
		width,
		height,
		1,
		sample_count,
		format,
		vk.ImageTiling.OPTIMAL,
		vk.ImageUsageFlags{.COLOR_ATTACHMENT, .SAMPLED},
		vma.MemoryUsage.AUTO_PREFER_DEVICE,
		vma.AllocationCreateFlags{},
	)

	view := _create_image_view(vks, image, format, {.COLOR}, 1)

	return Texture {
		name = "surface color attachment",
		image = image,
		view = view,
		format = format,
		allocation = allocation,
		allocation_info = allocation_info,
	}
}

@(private = "file")
@(require_results)
_create_surface_color_resolve_resource :: proc(
	vks: Vulkan_State,
	width, height: u32,
	sampler_anisotropy: f32,
	format: vk.Format,
	loc := #caller_location,
) -> Texture {
	image, allocation, allocation_info := _create_image(
		vks,
		width,
		height,
		1,
		Sample_Count_Flag._1,
		format,
		vk.ImageTiling.OPTIMAL,
		vk.ImageUsageFlags{.COLOR_ATTACHMENT, .SAMPLED},
		vma.MemoryUsage.AUTO_PREFER_DEVICE,
		vma.AllocationCreateFlags{},
	)

	view := _create_image_view(vks, image, format, {.COLOR}, 1)

	sampler_info := vk.SamplerCreateInfo {
		sType                   = .SAMPLER_CREATE_INFO,
		magFilter               = .LINEAR,
		minFilter               = .LINEAR,
		addressModeU            = .REPEAT,
		addressModeV            = .REPEAT,
		addressModeW            = .REPEAT,
		anisotropyEnable        = true,
		maxAnisotropy           = sampler_anisotropy,
		borderColor             = .INT_OPAQUE_BLACK,
		unnormalizedCoordinates = false,
		compareEnable           = false,
		compareOp               = .ALWAYS,
		mipmapMode              = .LINEAR,
		mipLodBias              = 0.0,
		minLod                  = 0.0,
		maxLod                  = cast(f32)1,
	}

	sampler: vk.Sampler
	must(vk.CreateSampler(vks.device, &sampler_info, nil, &sampler))

	return Texture {
		name = "surface resolve color attachment",
		image = image,
		sampler = sampler,
		view = view,
		format = format,
		allocation = allocation,
		allocation_info = allocation_info,
	}
}

@(private = "file")
@(require_results)
_create_surface_depth_resource :: proc(
	vks: Vulkan_State,
	width: u32,
	height: u32,
	cmd: Command_Buffer,
	sample_count: Sample_Count_Flag,
	loc := #caller_location,
) -> Texture {
	format := _find_depth_format(vks.physical_device)
	image, allocation, allocation_info := _create_image(
		vks,
		width,
		height,
		1,
		sample_count,
		format,
		vk.ImageTiling.OPTIMAL,
		vk.ImageUsageFlags{.DEPTH_STENCIL_ATTACHMENT},
		vma.MemoryUsage.AUTO_PREFER_DEVICE,
		vma.AllocationCreateFlags{},
	)

	_transition_image_layout(cmd, image, {.DEPTH}, format, .UNDEFINED, .DEPTH_STENCIL_ATTACHMENT_OPTIMAL, 1)
	view := _create_image_view(vks, image, format, {.DEPTH}, 1)

	return Texture {
		name = "surface depth attachment",
		image = image,
		view = view,
		format = format,
		allocation = allocation,
		allocation_info = allocation_info,
	}
}
