package graphics

import hm "../handle_map"
import "core:log"
import vk "vendor:vulkan"

@(private = "file")
UNIFORM_BINDING :: 0
@(private = "file")
STORAGE_BINDING :: 1
@(private = "file")
TEXTURE_BINDING :: 2

@(require_results)
bindless_store_texture :: proc(g: ^Graphics, texture: Texture, loc := #caller_location) -> Texture_Handle {
	assert_not_nil(g, loc)

	return _bindless_store_texture(g.bindless, g.vulkan_state.device, texture)
}

bindless_destroy_texture :: proc(g: ^Graphics, texture_h: Texture_Handle, loc := #caller_location) -> bool {
	assert_not_nil(g, loc)

	texture, has_texture := _bindless_remove_texture(g.bindless, texture_h)
	if has_texture {
		destroy_texture(g.vulkan_state, &texture)
		return true
	}

	return false
}

@(require_results)
bindless_store_buffer :: proc(g: ^Graphics, buffer: Buffer, loc := #caller_location) -> Buffer_Handle {
	assert_not_nil(g, loc)

	return _bindless_store_buffer(g.bindless, g.vulkan_state.device, buffer)
}

bindless_destroy_buffer :: proc(g: ^Graphics, buffer_h: Buffer_Handle, loc := #caller_location) {
	assert_not_nil(g, loc)

	buffer, has_buffer := _bindless_remove_buffer(g.bindless, buffer_h)
	if has_buffer {
		destroy_buffer(&buffer, g.vulkan_state)
	}
}

@(require_results)
bindless_get_buffer :: proc(g: ^Graphics, buffer_h: Buffer_Handle, loc := #caller_location) -> ^Buffer {
	assert_not_nil(g, loc)

	result, ok := hm.get(&g.bindless.buffers, buffer_h)
	if !ok {
		log.error("couln't get buffer by handle ", buffer_h)
		return nil
	}

	return result
}

@(require_results)
create_bindless_pipeline_set_info :: proc(allocator := context.allocator) -> Pipeline_Set_Info {
	binding_infos := make([]Pipeline_Set_Binding_Info, 3, allocator)
	binding_infos[0].binding = UNIFORM_BINDING
	binding_infos[0].descriptor_type = .UNIFORM_BUFFER
	binding_infos[0].descriptor_count = BINDLESS_DESCRIPTOR_COUNT
	binding_infos[0].stage_flags = vk.ShaderStageFlags_ALL_GRAPHICS

	binding_infos[1].binding = STORAGE_BINDING
	binding_infos[1].descriptor_type = .STORAGE_BUFFER
	binding_infos[1].descriptor_count = BINDLESS_DESCRIPTOR_COUNT
	binding_infos[1].stage_flags = vk.ShaderStageFlags_ALL_GRAPHICS

	binding_infos[2].binding = TEXTURE_BINDING
	binding_infos[2].descriptor_type = .COMBINED_IMAGE_SAMPLER
	binding_infos[2].descriptor_count = BINDLESS_DESCRIPTOR_COUNT
	binding_infos[2].stage_flags = vk.ShaderStageFlags_ALL_GRAPHICS

	flags := make([]vk.DescriptorBindingFlags, 3)
	flags[0] = {.UPDATE_AFTER_BIND, .PARTIALLY_BOUND}
	flags[1] = {.UPDATE_AFTER_BIND, .PARTIALLY_BOUND}
	flags[2] = {.UPDATE_AFTER_BIND, .PARTIALLY_BOUND}

	return Pipeline_Set_Info{set = 0, binding_infos = binding_infos, flags = flags}
}

@(require_results)
bindless_get_texture :: proc(g: ^Graphics, texture_h: Texture_Handle, loc := #caller_location) -> (^Texture, bool) {
	assert_not_nil(g, loc)

	return hm.get(&g.bindless.textures, texture_h)
}

bindless_bind :: proc(
	g: ^Graphics,
	cmd: vk.CommandBuffer,
	pipeline_layout: vk.PipelineLayout,
	loc := #caller_location,
) {
	assert_not_nil(g, loc)

	vk.CmdBindDescriptorSets(cmd, .GRAPHICS, pipeline_layout, 0, 1, &g.bindless.set, 0, nil)
}

@(private)
_init_bindless :: proc(g: ^Graphics, loc := #caller_location) {
	assert(g.bindless == nil, "Bindless already initialized", loc)

	g.bindless = new(Bindless)
	_bindless_init(g.bindless, g.vulkan_state)
}

@(private)
_destory_bindless :: proc(g: ^Graphics, loc := #caller_location) {
	assert(g.bindless != nil, "Bindless already uninitialized", loc)

	_bindless_destroy(g.bindless, g.vulkan_state)
	free(g.bindless)
}

@(private = "file")
_bindless_init :: proc(bindless: ^Bindless, vks: Vulkan_State, loc := #caller_location) {
	assert_not_nil(bindless, loc)

	descriptor_types := [3]vk.DescriptorType{.UNIFORM_BUFFER, .STORAGE_BUFFER, .COMBINED_IMAGE_SAMPLER}
	descriptor_bindings: [3]vk.DescriptorSetLayoutBinding
	descriptor_binding_flags: [3]vk.DescriptorBindingFlags

	for i in 0 ..< 3 {
		descriptor_bindings[i].binding = cast(u32)i
		descriptor_bindings[i].descriptorType = descriptor_types[i]
		descriptor_bindings[i].descriptorCount = BINDLESS_DESCRIPTOR_COUNT
		descriptor_bindings[i].stageFlags = vk.ShaderStageFlags_ALL_GRAPHICS
		descriptor_binding_flags[i] = {.PARTIALLY_BOUND, .UPDATE_AFTER_BIND}
	}

	binding_flags := vk.DescriptorSetLayoutBindingFlagsCreateInfo {
		sType         = .DESCRIPTOR_SET_LAYOUT_BINDING_FLAGS_CREATE_INFO,
		pNext         = nil,
		pBindingFlags = raw_data(&descriptor_binding_flags),
		bindingCount  = 3,
	}

	create_info := vk.DescriptorSetLayoutCreateInfo {
		sType        = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		bindingCount = 3,
		pBindings    = raw_data(&descriptor_bindings),
		flags        = {.UPDATE_AFTER_BIND_POOL},
		pNext        = &binding_flags,
	}

	must(vk.CreateDescriptorSetLayout(vks.device, &create_info, nil, &bindless.set_layout))

	allocate_info := vk.DescriptorSetAllocateInfo {
		sType              = .DESCRIPTOR_SET_ALLOCATE_INFO,
		pNext              = nil,
		descriptorPool     = vks.descriptor_pool,
		pSetLayouts        = &bindless.set_layout,
		descriptorSetCount = 1,
	}

	must(vk.AllocateDescriptorSets(vks.device, &allocate_info, &bindless.set))
}

@(private = "file")
_bindless_destroy :: proc(bindless: ^Bindless, vks: Vulkan_State, loc := #caller_location) {
	assert_not_nil(bindless, loc)

	vk.DestroyDescriptorSetLayout(vks.device, bindless.set_layout, nil)

	for &texture in bindless.textures.values {
		destroy_texture(vks, &texture)
	}
	hm.destroy(&bindless.textures)

	for &buffer in bindless.buffers.values {
		destroy_buffer(&buffer, vks)
	}
	hm.destroy(&bindless.buffers)
}

@(private = "file")
_bindless_bind :: proc(
	bindless: ^Bindless,
	cmd: vk.CommandBuffer,
	pipeline_layout: vk.PipelineLayout,
	loc := #caller_location,
) {
	assert_not_nil(bindless, loc)

	vk.CmdBindDescriptorSets(cmd, .GRAPHICS, pipeline_layout, 0, 1, &bindless.set, 0, nil)
}

@(private = "file")
_bindless_store_texture :: proc(
	bindless: ^Bindless,
	device: vk.Device,
	texture: Texture,
	loc := #caller_location,
) -> Texture_Handle {
	assert_not_nil(bindless, loc)

	handle := hm.insert(&bindless.textures, texture)

	image_info := vk.DescriptorImageInfo {
		imageLayout = .SHADER_READ_ONLY_OPTIMAL,
		imageView   = texture.view,
		sampler     = texture.sampler,
	}

	write := vk.WriteDescriptorSet {
		sType           = .WRITE_DESCRIPTOR_SET,
		descriptorType  = .COMBINED_IMAGE_SAMPLER,
		dstBinding      = TEXTURE_BINDING,
		dstSet          = bindless.set,
		descriptorCount = 1,
		dstArrayElement = handle.index,
		pImageInfo      = &image_info,
	}
	vk.UpdateDescriptorSets(device, 1, &write, 0, nil)

	return handle
}

@(private = "file")
_bindless_remove_texture :: proc(
	bindless: ^Bindless,
	texture_h: Texture_Handle,
	loc := #caller_location,
) -> (
	Texture,
	bool,
) {
	assert_not_nil(bindless, loc)

	return hm.remove(&bindless.textures, texture_h)
}

@(private = "file")
_bindless_store_buffer :: proc(
	bindless: ^Bindless,
	device: vk.Device,
	buffer: Buffer,
	loc := #caller_location,
) -> Buffer_Handle {
	assert_not_nil(bindless, loc)

	handle := hm.insert(&bindless.buffers, buffer)

	writes: [2]vk.WriteDescriptorSet

	for &write in writes {
		buffer_info := vk.DescriptorBufferInfo {
			buffer = buffer.buffer,
			offset = 0,
			range  = cast(vk.DeviceSize)vk.WHOLE_SIZE,
		}

		write.sType = .WRITE_DESCRIPTOR_SET
		write.dstSet = bindless.set
		write.descriptorCount = 1
		write.dstArrayElement = handle.index
		write.pBufferInfo = &buffer_info
	}

	i: u32 = 0
	if vk.BufferUsageFlag.UNIFORM_BUFFER in buffer.usage {
		writes[i].dstBinding = UNIFORM_BINDING
		writes[i].descriptorType = .UNIFORM_BUFFER
		i += 1
	}

	if vk.BufferUsageFlag.STORAGE_BUFFER in buffer.usage {writes[i].dstBinding = STORAGE_BINDING
		writes[i].descriptorType = .STORAGE_BUFFER
	}

	vk.UpdateDescriptorSets(device, i, raw_data(&writes), 0, nil)

	return handle
}

@(private = "file")
_bindless_remove_buffer :: proc(
	bindless: ^Bindless,
	buffer_h: Buffer_Handle,
	loc := #caller_location,
) -> (
	Buffer,
	bool,
) {
	assert_not_nil(bindless, loc)

	return hm.remove(&bindless.buffers, buffer_h)
}
