package mouniverse

import "core:time"
import "core:math"
import k2 "../../code/karl2d"

pixels_to_meters :: #force_inline proc(pixels: f32) -> f32 {
	return pixels * SCALING_FACTOR
}

meters_to_pixels :: #force_inline proc(meters: f32) -> f32 {
	return meters / SCALING_FACTOR
}

zoom_allowed :: #force_inline proc(zoom_time: time.Time) -> bool {
	return time.duration_milliseconds(time.diff(zoom_time, time.now())) >= ZOOM_INTERVAL
}

shot_allowed :: #force_inline proc(shot_time: time.Time) -> bool {
	return time.duration_milliseconds(time.diff(shot_time, time.now())) >= SHOT_INTERVAL
}

rotate_point :: #force_inline proc(x, y, cx, cy, angle: f32) -> [2]f32 {
	return {
		math.cos(angle) * (x - cx) - math.sin(angle) * (y - cy) + cx,
		math.sin(angle) * (x - cx) + math.cos(angle) * (y - cy) + cy
	}
}

rotate_vec :: #force_inline proc(vec: ^[2]f32, cx, cy, angle: f32) {
	x, y := vec.x, vec.y

	vec.x = math.cos(angle) * (x - cx) - math.sin(angle) * (y - cy) + cx
	vec.y = math.sin(angle) * (x - cx) + math.cos(angle) * (y - cy) + cy
}

to_radians :: #force_inline proc(degrees: int) -> f32 {
	return f32(degrees) * math.PI / 180.0
}

angle_to_vector :: #force_inline proc(angle, scale: f32) -> [2]f32 {
	return [2]f32 {
		math.cos(angle) * scale,
		math.sin(angle) * scale
	}
}

is_outside_of_rect :: proc(pos: Position, size: Size, rect: k2.Rect) -> bool {
	return pos.x + size.width < rect.x  ||
		   pos.x > rect.x + rect.w      ||
		   pos.y + size.height < rect.y ||
		   pos.y > rect.y + rect.h
}
