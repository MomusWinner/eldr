package graphics

import vk "vendor:vulkan"
import "vma"

Surface :: struct {
	color_image: Texture,
	depth_image: Texture,
	framebuffer: vk.Framebuffer,
	render_pass: vk.RenderPass,
}

surface_render_pass_color: vk.RenderPass
surface_render_pass_color_depth: vk.RenderPass
surface_render_pass_depth: vk.RenderPass

init_surface_render_passes :: proc(g: ^Graphics) {
	color_attachment := vk.AttachmentDescription {
		format         = g.swapchain.format.format,
		samples        = g.msaa_samples,
		loadOp         = .CLEAR,
		storeOp        = .STORE,
		stencilLoadOp  = .DONT_CARE,
		stencilStoreOp = .DONT_CARE,
		initialLayout  = .UNDEFINED,
		finalLayout    = .COLOR_ATTACHMENT_OPTIMAL,
	}

	color_attachment_ref := vk.AttachmentReference {
		attachment = 0,
		layout     = .COLOR_ATTACHMENT_OPTIMAL,
	}

	depth_attachment := vk.AttachmentDescription {
		format         = _find_depth_format(g.physical_device),
		samples        = g.msaa_samples,
		loadOp         = .CLEAR,
		storeOp        = .DONT_CARE,
		stencilLoadOp  = .DONT_CARE,
		stencilStoreOp = .DONT_CARE,
		initialLayout  = .UNDEFINED,
		finalLayout    = .DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
	}

	depth_attachment_ref := vk.AttachmentReference {
		attachment = 1,
		layout     = .DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
	}

	// color_attachment_resolve := vk.AttachmentDescription {
	// 	format         = g.swapchain.format.format,
	// 	samples        = {._1},
	// 	loadOp         = .DONT_CARE,
	// 	storeOp        = .STORE,
	// 	stencilLoadOp  = .DONT_CARE,
	// 	stencilStoreOp = .DONT_CARE,
	// 	initialLayout  = .UNDEFINED,
	// 	finalLayout    = .SHADER_READ_ONLY_OPTIMAL,
	// }
	//
	// color_attachment_resolve_ref := vk.AttachmentReference {
	// 	attachment = 2,
	// 	layout     = .COLOR_ATTACHMENT_OPTIMAL,
	// }

	attachments := []vk.AttachmentDescription{color_attachment, depth_attachment}

	subpass := vk.SubpassDescription {
		pipelineBindPoint       = .GRAPHICS,
		colorAttachmentCount    = 1,
		pColorAttachments       = &color_attachment_ref,
		pDepthStencilAttachment = &depth_attachment_ref,
		// pResolveAttachments     = &color_attachment_resolve_ref,
	}

	dependency := vk.SubpassDependency {
		srcSubpass    = vk.SUBPASS_EXTERNAL,
		dstSubpass    = 0,
		srcStageMask  = {.COLOR_ATTACHMENT_OUTPUT, .EARLY_FRAGMENT_TESTS},
		srcAccessMask = {},
		dstStageMask  = {.COLOR_ATTACHMENT_OUTPUT, .EARLY_FRAGMENT_TESTS},
		dstAccessMask = {.COLOR_ATTACHMENT_WRITE, .DEPTH_STENCIL_ATTACHMENT_WRITE},
	}

	render_pass_info := vk.RenderPassCreateInfo {
		sType           = .RENDER_PASS_CREATE_INFO,
		attachmentCount = cast(u32)len(attachments),
		pAttachments    = raw_data(attachments),
		subpassCount    = 1,
		pSubpasses      = &subpass,
		dependencyCount = 1,
		pDependencies   = &dependency,
	}

	must(vk.CreateRenderPass(g.device, &render_pass_info, nil, &surface_render_pass_color_depth))

	render_pass_info.dependencyCount = 0
	render_pass_info.pDependencies = nil

	subpass.pDepthStencilAttachment = nil


}

create_surface :: proc(g: ^Graphics, color_attachment, depth_attachment: bool) -> Surface {
	surface := Surface {
		render_pass = _create_offscreen_render_pass(g),
	}
	_create_offscreen_framebuffer(&surface, g, color_attachment, depth_attachment)
	return surface
}

_create_offscreen_render_pass :: proc(g: ^Graphics) -> vk.RenderPass {
	color_attachment := vk.AttachmentDescription {
		format         = g.swapchain.format.format,
		samples        = g.msaa_samples,
		loadOp         = .CLEAR,
		storeOp        = .STORE,
		stencilLoadOp  = .DONT_CARE,
		stencilStoreOp = .DONT_CARE,
		initialLayout  = .UNDEFINED,
		finalLayout    = .COLOR_ATTACHMENT_OPTIMAL,
	}

	color_attachment_ref := vk.AttachmentReference {
		attachment = 0,
		layout     = .COLOR_ATTACHMENT_OPTIMAL,
	}

	depth_attachment := vk.AttachmentDescription {
		format         = _find_depth_format(g.physical_device),
		samples        = g.msaa_samples,
		loadOp         = .CLEAR,
		storeOp        = .DONT_CARE,
		stencilLoadOp  = .DONT_CARE,
		stencilStoreOp = .DONT_CARE,
		initialLayout  = .UNDEFINED,
		finalLayout    = .DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
	}

	depth_attachment_ref := vk.AttachmentReference {
		attachment = 1,
		layout     = .DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
	}

	// color_attachment_resolve := vk.AttachmentDescription {
	// 	format         = g.swapchain.format.format,
	// 	samples        = {._1},
	// 	loadOp         = .DONT_CARE,
	// 	storeOp        = .STORE,
	// 	stencilLoadOp  = .DONT_CARE,
	// 	stencilStoreOp = .DONT_CARE,
	// 	initialLayout  = .UNDEFINED,
	// 	finalLayout    = .SHADER_READ_ONLY_OPTIMAL,
	// }
	//
	// color_attachment_resolve_ref := vk.AttachmentReference {
	// 	attachment = 2,
	// 	layout     = .COLOR_ATTACHMENT_OPTIMAL,
	// }

	attachments := []vk.AttachmentDescription{color_attachment, depth_attachment}

	subpass := vk.SubpassDescription {
		pipelineBindPoint       = .GRAPHICS,
		colorAttachmentCount    = 1,
		pColorAttachments       = &color_attachment_ref,
		pDepthStencilAttachment = &depth_attachment_ref,
		// pResolveAttachments     = &color_attachment_resolve_ref,
	}

	dependency := vk.SubpassDependency {
		srcSubpass    = vk.SUBPASS_EXTERNAL,
		dstSubpass    = 0,
		srcStageMask  = {.COLOR_ATTACHMENT_OUTPUT, .EARLY_FRAGMENT_TESTS},
		srcAccessMask = {},
		dstStageMask  = {.COLOR_ATTACHMENT_OUTPUT, .EARLY_FRAGMENT_TESTS},
		dstAccessMask = {.COLOR_ATTACHMENT_WRITE, .DEPTH_STENCIL_ATTACHMENT_WRITE},
	}

	render_pass_info := vk.RenderPassCreateInfo {
		sType           = .RENDER_PASS_CREATE_INFO,
		attachmentCount = cast(u32)len(attachments),
		pAttachments    = raw_data(attachments),
		subpassCount    = 1,
		pSubpasses      = &subpass,
		dependencyCount = 1,
		pDependencies   = &dependency,
	}

	render_pass: vk.RenderPass

	must(vk.CreateRenderPass(g.device, &render_pass_info, nil, &render_pass))

	return render_pass
}

_create_offscreen_framebuffer :: proc(surface: ^Surface, g: ^Graphics, color_attachment, depth_attachment: bool) {
	assert(color_attachment || depth_attachment, "Couldn't create framebuffer without attachments")
	attachments: []vk.ImageView
	if color_attachment && depth_attachment {
		surface.color_image = _create_surface_color_resource(g, g.swapchain.format.format, g.msaa_samples)

		cmd := _cmd_single_begin(g)
		surface.depth_image = _create_surface_depth_resource(g, cmd.command_buffer)
		_cmd_single_end(cmd)

		attachments = []vk.ImageView{surface.color_image.view, surface.depth_image.view}
	} else if color_attachment {
		surface.color_image = _create_surface_color_resource(g, g.swapchain.format.format, g.msaa_samples)
		attachments = []vk.ImageView{surface.color_image.view}
	} else if depth_attachment {
		cmd := _cmd_single_begin(g)
		surface.depth_image = _create_surface_depth_resource(g, cmd.command_buffer)
		_cmd_single_end(cmd)

		attachments = []vk.ImageView{surface.depth_image.view}
	}

	frame_buffer := vk.FramebufferCreateInfo {
		sType           = .FRAMEBUFFER_CREATE_INFO,
		renderPass      = surface.render_pass,
		attachmentCount = cast(u32)len(attachments),
		pAttachments    = raw_data(attachments),
		width           = get_width(g),
		height          = get_height(g),
		layers          = 1,
	}

	must(vk.CreateFramebuffer(g.device, &frame_buffer, nil, &surface.framebuffer))
}

_create_surface_color_resource :: proc(g: ^Graphics, format: vk.Format, samples: vk.SampleCountFlags) -> Texture {
	// color_format := swapchain.format.format

	image, allocation, allocation_info := _create_image(
		g,
		get_width(g),
		get_height(g),
		1,
		samples,
		format,
		vk.ImageTiling.OPTIMAL,
		vk.ImageUsageFlags{.TRANSIENT_ATTACHMENT, .COLOR_ATTACHMENT},
		vma.MemoryUsage.AUTO_PREFER_DEVICE,
		vma.AllocationCreateFlags{},
	)

	view := _create_image_view(g.device, image, format, {.COLOR}, 1)

	return Texture {
		name = "surface color resource",
		image = image,
		view = view,
		allocation = allocation,
		allocation_info = allocation_info,
	}
}

_create_surface_depth_resource :: proc(g: ^Graphics, cmd: Command_Buffer) -> Texture {
	format := _find_depth_format(g.physical_device)
	image, allocation, allocation_info := _create_image(
		g,
		get_width(g),
		get_height(g),
		1,
		g.msaa_samples,
		format,
		vk.ImageTiling.OPTIMAL,
		vk.ImageUsageFlags{.DEPTH_STENCIL_ATTACHMENT},
		vma.MemoryUsage.AUTO_PREFER_DEVICE,
		vma.AllocationCreateFlags{},
	)

	_transition_image_layout(cmd, image, {.DEPTH}, format, .UNDEFINED, .DEPTH_STENCIL_ATTACHMENT_OPTIMAL, 1)

	view := _create_image_view(g.device, image, format, {.DEPTH}, 1)
	return Texture{image = image, view = view, allocation = allocation, allocation_info = allocation_info}
}
