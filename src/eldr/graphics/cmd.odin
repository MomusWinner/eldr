package graphics

import vk "vendor:vulkan"

@(private)
SingleCommand :: struct {
	command_buffer: vk.CommandBuffer,
}

@(private)
@(require_results)
_cmd_single_begin :: proc() -> SingleCommand {
	alloc_info := vk.CommandBufferAllocateInfo {
		sType              = .COMMAND_BUFFER_ALLOCATE_INFO,
		level              = .PRIMARY,
		commandPool        = ctx.vulkan_state.command_pool,
		commandBufferCount = 1,
	}

	command_buffer: vk.CommandBuffer
	must(vk.AllocateCommandBuffers(ctx.vulkan_state.device, &alloc_info, &command_buffer))

	begin_info := vk.CommandBufferBeginInfo {
		sType = .COMMAND_BUFFER_BEGIN_INFO,
		flags = {.ONE_TIME_SUBMIT},
	}
	must(vk.BeginCommandBuffer(command_buffer, &begin_info))

	return SingleCommand{command_buffer = command_buffer}
}

@(private)
_cmd_single_end :: proc(single_command: SingleCommand) {
	command_buffer := single_command.command_buffer

	must(vk.EndCommandBuffer(command_buffer))

	submit_info := vk.SubmitInfo {
		sType              = .SUBMIT_INFO,
		commandBufferCount = 1,
		pCommandBuffers    = &command_buffer,
	}

	must(vk.QueueSubmit(ctx.vulkan_state.graphics_queue, 1, &submit_info, 0))
	must(vk.QueueWaitIdle(ctx.vulkan_state.graphics_queue))

	vk.FreeCommandBuffers(ctx.vulkan_state.device, ctx.vulkan_state.command_pool, 1, &command_buffer)
}

@(private)
_cmd_buffer_barrier :: proc(
	cmd: vk.CommandBuffer,
	buffer: Buffer,
	src_access_mask: vk.AccessFlags,
	dst_access_mask: vk.AccessFlags,
	src_stage_mask: vk.PipelineStageFlags,
	dst_stage_mask: vk.PipelineStageFlags,
) {
	buffer_barrier := vk.BufferMemoryBarrier {
		sType               = .BUFFER_MEMORY_BARRIER,
		srcAccessMask       = src_access_mask,
		dstAccessMask       = dst_access_mask,
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		buffer              = buffer.buffer,
		offset              = 0,
		size                = cast(vk.DeviceSize)vk.WHOLE_SIZE,
	}
	vk.CmdPipelineBarrier(cmd, src_stage_mask, dst_stage_mask, {}, 0, nil, 1, &buffer_barrier, 0, nil)
}
