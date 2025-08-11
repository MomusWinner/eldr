package common

import "core:os"

read_file :: proc(name: string, allocator := context.allocator) -> ([]byte, bool) {
	data, ok := os.read_entire_file(name, allocator)
	return data, ok
}

wirte_file :: proc(name: string, data: []byte) -> bool {
	return os.write_entire_file(name, data)
}
