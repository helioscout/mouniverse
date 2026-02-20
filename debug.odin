package mouniverse

import "core:c"
import "base:runtime"
import b2 "vendor:box2d"
import k2 "../../code/karl2d"

draw_segment :: proc "c" (p1, p2: b2.Vec2, color: b2.HexColor, ctx: rawptr) {
	context = runtime.default_context()
	
	k2.draw_line(p1, p2, 1, k2.GREEN)
}

draw_polygon :: proc "c" (vertices: [^]b2.Vec2, vertexCount: c.int, color: b2.HexColor, ctx: rawptr) {
	context = runtime.default_context()
	
	for i in 0 ..< vertexCount - 1 {
		v1 := vertices[i]
		v2 := vertices[i + 1]

		k2.draw_line({ v1.x, -v1.y }, { v2.x, -v2.y }, 1, k2.GREEN)
	}

	v1 := vertices[vertexCount - 1]
	v2 := vertices[0]

	k2.draw_line({ v1.x, -v1.y }, { v2.x, -v2.y }, 1, k2.GREEN)
}

draw_solid_polygon :: proc "c" (transform: b2.Transform, vertices: [^]b2.Vec2, vertexCount: c.int, radius: f32,
	color: b2.HexColor, ctx: rawptr) {
	context = runtime.default_context()
	
	for i := 0; i < int(vertexCount); i += 1 {
		next_idx := i + 1 == int(vertexCount) ? 0 : i + 1

		p0: b2.Vec2 = b2.TransformPoint(transform, vertices[i])
		p1: b2.Vec2 = b2.TransformPoint(transform, vertices[next_idx])

		x0: f32 = meters_to_pixels(p0.x)
		y0: f32 = meters_to_pixels(p0.y)
		x1: f32 = meters_to_pixels(p1.x)
		y1: f32 = meters_to_pixels(p1.y)

		k2.draw_line({ x0, y0 }, { x1, y1 }, 1, k2.GREEN)
	}
}

draw_point :: proc "c" (p: b2.Vec2, size: f32, color: b2.HexColor, ctx: rawptr) {
	context = runtime.default_context()

	k2.draw_circle(p, size, k2.GREEN)
}
