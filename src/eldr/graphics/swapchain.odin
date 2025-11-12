package graphics

import "base:runtime"

import "core:log"
import "core:slice"
import "core:strings"

import "vendor:glfw"
import vk "vendor:vulkan"
import "vma"

@(private)
_init_swapchain :: proc(g: ^Graphics, sample_count: Sample_Count_Flag) {
	g.swapchain = _swapchain_new(g.window, g.vulkan_state, sample_count)
	sc := _cmd_single_begin(g.vulkan_state)
	_swapchain_setup(g.swapchain, g.vulkan_state, sc.command_buffer)
	_cmd_single_end(sc, g.vulkan_state)
}

@(private)
_destroy_swapchain :: proc(g: ^Graphics) {
	_swapchain_destroy(g.swapchain, g.vulkan_state)
}

@(private)
_recreate_swapchain :: proc(swapchain: ^Swap_Chain, vks: Vulkan_State, window: ^glfw.WindowHandle) {
	vk.DeviceWaitIdle(vks.device)

	_swapchain_destroy(swapchain, vks)

	swapchain := _swapchain_new(window, vks, swapchain.sample_count)

	sc := _cmd_single_begin(vks)
	_swapchain_setup(swapchain, vks, sc.command_buffer)
	_cmd_single_end(sc, vks)
}

@(private = "file")
@(require_results)
_swapchain_new :: proc(window: ^glfw.WindowHandle, vks: Vulkan_State, sample_count: Sample_Count_Flag) -> ^Swap_Chain {
	indices := _find_queue_families(vks.physical_device, vks.surface)

	support, result := _query_swapchain_support(vks.physical_device, vks.surface, context.temp_allocator)
	if result != .SUCCESS {
		log.panicf("query swapchain failed: %v", result)
	}

	surface_format := _choose_swapchain_surface_format(support.formats)
	present_mode := _choose_swapchain_present_mode(support.presentModes)
	extent := _choose_swapchain_extent(window, support.capabilities)

	image_count := support.capabilities.minImageCount + 1
	if support.capabilities.maxImageCount > 0 && image_count > support.capabilities.maxImageCount {
		image_count = support.capabilities.maxImageCount
	}

	create_info := vk.SwapchainCreateInfoKHR {
		sType            = .SWAPCHAIN_CREATE_INFO_KHR,
		surface          = vks.surface,
		minImageCount    = image_count,
		imageFormat      = surface_format.format,
		imageColorSpace  = surface_format.colorSpace,
		imageExtent      = extent,
		imageArrayLayers = 1,
		imageUsage       = {.COLOR_ATTACHMENT},
		preTransform     = support.capabilities.currentTransform,
		compositeAlpha   = {.OPAQUE},
		presentMode      = present_mode,
		clipped          = true,
	}

	if indices.graphics != indices.present {
		create_info.imageSharingMode = .CONCURRENT
		create_info.queueFamilyIndexCount = 2
		create_info.pQueueFamilyIndices = raw_data([]u32{indices.graphics.?, indices.present.?})
	}

	vk_swapchain: vk.SwapchainKHR
	must(vk.CreateSwapchainKHR(vks.device, &create_info, nil, &vk_swapchain))

	swapchain := new(Swap_Chain)
	swapchain.swapchain = vk_swapchain
	swapchain.format = surface_format
	swapchain.extent = extent
	swapchain.sample_count = sample_count
	_swapchain_setup_images(swapchain, vks)
	_swapchain_setup_semaphores(swapchain, vks)

	return swapchain
}

@(private = "file")
_swapchain_setup :: proc(swapchain: ^Swap_Chain, vks: Vulkan_State, command_buffer: vk.CommandBuffer) {
	_swapchain_setup_color_resource(swapchain, vks)
	_swapchain_setupt_depth_buffer(swapchain, vks, command_buffer)
}

@(private = "file")
_swapchain_destroy :: proc(swapchain: ^Swap_Chain, vks: Vulkan_State) {
	destroy_texture(vks, &swapchain.color_image)
	destroy_texture(vks, &swapchain.depth_image)

	for sem in swapchain.render_finished_semaphores {
		vk.DestroySemaphore(vks.device, sem, nil)
	}
	delete(swapchain.render_finished_semaphores)

	for view in swapchain.image_views {
		vk.DestroyImageView(vks.device, view, nil)
	}

	delete(swapchain.image_views)
	delete(swapchain.images)

	vk.DestroySwapchainKHR(vks.device, swapchain.swapchain, nil)

	free(swapchain)
}

@(private = "file")
_swapchain_setup_color_resource :: proc(swapchain: ^Swap_Chain, vks: Vulkan_State) {
	color_format := swapchain.format.format

	image, allocation, allocation_info := _create_image(
		vks,
		swapchain.extent.width,
		swapchain.extent.height,
		1,
		swapchain.sample_count,
		color_format,
		vk.ImageTiling.OPTIMAL,
		vk.ImageUsageFlags{.TRANSIENT_ATTACHMENT, .COLOR_ATTACHMENT},
		vma.MemoryUsage.AUTO_PREFER_DEVICE,
		vma.AllocationCreateFlags{},
	)

	view := _create_image_view(vks, image, color_format, {.COLOR}, 1)

	swapchain.color_image = Texture {
		name            = "swapchain_image",
		image           = image,
		view            = view,
		allocation      = allocation,
		allocation_info = allocation_info,
	}
}

@(private = "file")
_swapchain_setupt_depth_buffer :: proc(swapchain: ^Swap_Chain, vks: Vulkan_State, command_buffer: vk.CommandBuffer) {
	format := _find_depth_format(vks.physical_device)
	image, allocation, allocation_info := _create_image(
		vks,
		swapchain.extent.width,
		swapchain.extent.height,
		1,
		swapchain.sample_count,
		format,
		vk.ImageTiling.OPTIMAL,
		vk.ImageUsageFlags{.DEPTH_STENCIL_ATTACHMENT},
		vma.MemoryUsage.AUTO_PREFER_DEVICE,
		vma.AllocationCreateFlags{},
	)

	_transition_image_layout(command_buffer, image, {.DEPTH}, format, .UNDEFINED, .DEPTH_STENCIL_ATTACHMENT_OPTIMAL, 1)

	view := _create_image_view(vks, image, format, {.DEPTH}, 1)
	swapchain.depth_image = Texture {
		image           = image,
		view            = view,
		allocation      = allocation,
		allocation_info = allocation_info,
	}
}

@(private = "file")
_swapchain_setup_images :: proc(swapchain: ^Swap_Chain, vks: Vulkan_State) {
	swapchain.image_index = 0

	count: u32
	must(vk.GetSwapchainImagesKHR(vks.device, swapchain.swapchain, &count, nil))

	swapchain.images = make([]vk.Image, count)
	swapchain.image_views = make([]vk.ImageView, count)
	must(vk.GetSwapchainImagesKHR(vks.device, swapchain.swapchain, &count, raw_data(swapchain.images)))

	for image, i in swapchain.images {
		swapchain.image_views[i] = _create_image_view(vks, image, swapchain.format.format, {.COLOR}, 1)
	}
}

@(private = "file")
_swapchain_setup_semaphores :: proc(swapchain: ^Swap_Chain, vks: Vulkan_State) {
	swapchain.render_finished_semaphores = make([]vk.Semaphore, len(swapchain.images))
	sem_info := vk.SemaphoreCreateInfo {
		sType = .SEMAPHORE_CREATE_INFO,
	}
	for _, i in swapchain.images {
		must(vk.CreateSemaphore(vks.device, &sem_info, nil, &swapchain.render_finished_semaphores[i]))
	}
}

@(private = "file")
@(require_results)
_choose_swapchain_surface_format :: proc(formats: []vk.SurfaceFormatKHR) -> vk.SurfaceFormatKHR {
	for format in formats {
		if format.format == .B8G8R8A8_SRGB && format.colorSpace == .SRGB_NONLINEAR {
			return format
		}
	}

	// Fallback non optimal.
	return formats[0]
}

@(private = "file")
@(require_results)
_choose_swapchain_present_mode :: proc(modes: []vk.PresentModeKHR) -> vk.PresentModeKHR {
	// We would like mailbox for the best tradeoff between tearing and latency.
	for mode in modes {
		if mode == .MAILBOX {
			return .MAILBOX
		}
	}
	log.error("Fifo selected")

	// As a fallback, fifo (basically vsync) is always available.
	return .FIFO
}

@(private = "file")
@(require_results)
_choose_swapchain_extent :: proc(window: ^glfw.WindowHandle, capabilities: vk.SurfaceCapabilitiesKHR) -> vk.Extent2D {
	// special value (0xFFFFFFFF, 0xFFFFFFFF) indicating that the surface size will be determined
	// by the extent of a swapchain targeting the surface.
	if capabilities.currentExtent.width != max(u32) {
		return capabilities.currentExtent
	}

	width, height := glfw.GetFramebufferSize(window^)
	return vk.Extent2D {
		width = clamp(u32(width), capabilities.minImageExtent.width, capabilities.maxImageExtent.width),
		height = clamp(u32(height), capabilities.minImageExtent.height, capabilities.maxImageExtent.height),
	}
}
