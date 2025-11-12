package graphics

import "core:log"

_init_deffered_destructor :: proc(g: ^Graphics) {
	g.deffered_destructor = new(Deferred_Destructor)
}

@(private)
_deffered_destructor_add :: proc(g: ^Graphics, resource: Resource) {
	__deffered_destructor_add(g.deffered_destructor, resource)
}

@(private)
_deffered_destructor_clean :: proc(g: ^Graphics) {
	__deffered_destructor_clean(g.deffered_destructor, g)
}

@(private)
_destroy_deffered_destructor :: proc(g: ^Graphics) {
	_deffered_destructor_destroy(g.deffered_destructor, g)
	free(g.deffered_destructor)
}

@(private = "file")
__deffered_destructor_add :: proc(d: ^Deferred_Destructor, resource: Resource) {
	d.resources[d.next_index] = resource
	d.next_index += 1
	assert(d.next_index < DEFERRED_DESTRUCTOR_SIZE, "Defered destructor is full. Increase DEFERRED_DESTRUCTOR_SIZE.")
}

@(private = "file")
__deffered_destructor_clean :: proc(d: ^Deferred_Destructor, g: ^Graphics) {
	for i in 0 ..< d.next_index {
		switch &resource in d.resources[i] {
		case Buffer:
			destroy_buffer(&resource, g.vulkan_state)
		case Buffer_Handle:
			bindless_destroy_buffer(g, resource)
		case Texture:
			destroy_texture(g.vulkan_state, &resource)
		case Texture_Handle:
			bindless_destroy_texture(g, resource)
		}
	}
	d.next_index = 0
}

@(private = "file")
_deffered_destructor_destroy :: proc(d: ^Deferred_Destructor, g: ^Graphics) {
	__deffered_destructor_clean(d, g)
}
