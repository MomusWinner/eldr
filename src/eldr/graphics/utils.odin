package graphics

import "../common"
import "base:runtime"
import "core:fmt"
import "core:log"
import vk "vendor:vulkan"

@(private)
must :: proc(result: vk.Result, msg: string = "", loc := #caller_location) {
	if result != .SUCCESS {
		log.panicf("vulkan failure: %s (%v)", msg, result, location = loc)
	}
}

merge :: common.merge
assert_not_nil :: common.assert_not_nil
