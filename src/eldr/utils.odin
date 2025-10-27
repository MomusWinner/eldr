package eldr

import "common"
import "core:fmt"

assert_frame_data :: proc(frame_data: Frame_Data) {
	assert(frame_data.cmd != nil)
}

merge :: common.merge
assert_not_nil :: common.assert_not_nil
