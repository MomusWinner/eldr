package eldr

import "vendor:glfw"

window_should_close :: proc() -> b32 {
	return glfw.WindowShouldClose(ctx.window)
}
