package graphics

import "core:log"

_init_deffered_destructor :: proc() {
	ctx.deffered_destructor = new(Deferred_Destructor)
	ctx.deffered_destructor.next_index = 0
}

@(private)
_deffered_destructor_add :: proc(resource: Resource) {
	__deffered_destructor_add(ctx.deffered_destructor, resource)
}

@(private)
_clear_deffered_destructor :: proc() {
	_deffered_destructor_clear(ctx.deffered_destructor)
}

@(private)
_destroy_deffered_destructor :: proc() {
	_deffered_destructor_destroy(ctx.deffered_destructor)
	free(ctx.deffered_destructor)
}

@(private = "file")
__deffered_destructor_add :: proc(d: ^Deferred_Destructor, resource: Resource) {
	d.resources[d.next_index] = resource
	d.next_index += 1
	assert(d.next_index < DEFERRED_DESTRUCTOR_SIZE, "Defered destructor is full. Increase DEFERRED_DESTRUCTOR_SIZE.")
}

@(private = "file")
_deffered_destructor_clear :: proc(d: ^Deferred_Destructor) {
	for i in 0 ..< d.next_index {
		switch &resource in d.resources[i] {
		case Buffer:
			destroy_buffer(&resource)
		case Buffer_Handle:
			bindless_destroy_buffer(resource)
		case Texture:
			destroy_texture(&resource)
		case Texture_Handle:
			bindless_destroy_texture(resource)
		}
	}
	d.next_index = 0
}

@(private = "file")
_deffered_destructor_destroy :: proc(d: ^Deferred_Destructor) {
	_deffered_destructor_clear(d)
}
