package graphics

import vk "vendor:vulkan"

@(private)
SingleCommand :: struct {
	command_buffer: vk.CommandBuffer,
	_device:        vk.Device,
	_command_pool:  vk.CommandPool,
	_queue:         vk.Queue,
}

@(private)
_begin_single_command :: proc {
	_begin_single_command_from_device,
	_begin_single_command_from_graphics,
}

@(private)
_begin_single_command_from_graphics :: proc(g: ^Graphics) -> SingleCommand {
	return _begin_single_command_from_device(g.device, g.command_pool, g.graphics_queue)
}

@(private)
_begin_single_command_from_device :: proc(
	device: vk.Device,
	command_pool: vk.CommandPool,
	queue: vk.Queue,
) -> SingleCommand {
	alloc_info := vk.CommandBufferAllocateInfo {
		sType              = .COMMAND_BUFFER_ALLOCATE_INFO,
		level              = .PRIMARY,
		commandPool        = command_pool,
		commandBufferCount = 1,
	}

	command_buffer: vk.CommandBuffer
	must(vk.AllocateCommandBuffers(device, &alloc_info, &command_buffer))

	begin_info := vk.CommandBufferBeginInfo {
		sType = .COMMAND_BUFFER_BEGIN_INFO,
		flags = {.ONE_TIME_SUBMIT},
	}
	must(vk.BeginCommandBuffer(command_buffer, &begin_info))

	return SingleCommand {
		command_buffer = command_buffer,
		_device = device,
		_command_pool = command_pool,
		_queue = queue,
	}
}

@(private)
_end_single_command :: proc(single_command: SingleCommand) {
	command_buffer := single_command.command_buffer

	must(vk.EndCommandBuffer(command_buffer))

	submit_info := vk.SubmitInfo {
		sType              = .SUBMIT_INFO,
		commandBufferCount = 1,
		pCommandBuffers    = &command_buffer,
	}

	must(vk.QueueSubmit(single_command._queue, 1, &submit_info, 0))
	must(vk.QueueWaitIdle(single_command._queue))

	vk.FreeCommandBuffers(single_command._device, single_command._command_pool, 1, &command_buffer)
}

@(private)
_find_supported_format :: proc(
	physical_device: vk.PhysicalDevice,
	candidates: []vk.Format,
	tiling: vk.ImageTiling,
	features: vk.FormatFeatureFlags,
) -> vk.Format {
	for format in candidates {
		props: vk.FormatProperties
		vk.GetPhysicalDeviceFormatProperties(physical_device, format, &props)

		if (tiling == .OPTIMAL && (props.optimalTilingFeatures & features) == features) {
			return format
		} else if (tiling == .LINEAR && (props.optimalTilingFeatures & features) == features) {
			return format
		}
	}

	panic("failed to find supported format!")
}

@(private)
QueueFamilyIndices :: struct {
	graphics: Maybe(u32),
	present:  Maybe(u32),
}

@(private)
_find_queue_families :: proc(device: vk.PhysicalDevice, surface: vk.SurfaceKHR) -> (ids: QueueFamilyIndices) {
	count: u32
	vk.GetPhysicalDeviceQueueFamilyProperties(device, &count, nil)

	families := make([]vk.QueueFamilyProperties, count, context.temp_allocator)
	vk.GetPhysicalDeviceQueueFamilyProperties(device, &count, raw_data(families))

	for family, i in families {
		if .GRAPHICS in family.queueFlags && .COMPUTE in family.queueFlags {
			ids.graphics = cast(u32)i
		}

		supported: b32
		vk.GetPhysicalDeviceSurfaceSupportKHR(device, u32(i), surface, &supported)
		if supported {
			ids.present = cast(u32)i
		}

		_, has_graphics := ids.graphics.?
		_, has_present := ids.present.?

		if has_graphics && has_present {
			break
		}
	}

	return
}

@(private)
Swapchain_Support :: struct {
	capabilities: vk.SurfaceCapabilitiesKHR,
	formats:      []vk.SurfaceFormatKHR,
	presentModes: []vk.PresentModeKHR,
}

@(private)
_query_swapchain_support :: proc(
	device: vk.PhysicalDevice,
	surface: vk.SurfaceKHR,
	allocator := context.temp_allocator,
) -> (
	support: Swapchain_Support,
	result: vk.Result,
) {
	// NOTE: looks like a wrong binding with the third arg being a multipointer.
	vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(device, surface, &support.capabilities) or_return

	{
		count: u32
		vk.GetPhysicalDeviceSurfaceFormatsKHR(device, surface, &count, nil) or_return

		support.formats = make([]vk.SurfaceFormatKHR, count, allocator)
		vk.GetPhysicalDeviceSurfaceFormatsKHR(device, surface, &count, raw_data(support.formats)) or_return
	}

	{
		count: u32
		vk.GetPhysicalDeviceSurfacePresentModesKHR(device, surface, &count, nil) or_return

		support.presentModes = make([]vk.PresentModeKHR, count, allocator)
		vk.GetPhysicalDeviceSurfacePresentModesKHR(device, surface, &count, raw_data(support.presentModes)) or_return
	}

	return
}
