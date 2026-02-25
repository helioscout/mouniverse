package mouniverse

import "core:time"

pixels_to_meters :: #force_inline proc(pixels: f32) -> f32 {
	return pixels * SCALING_FACTOR
}

meters_to_pixels :: #force_inline proc(meters: f32) -> f32 {
	return meters / SCALING_FACTOR
}

zoom_allowed :: #force_inline proc(zoom_time: time.Time) -> bool {
	return time.duration_milliseconds(time.diff(zoom_time, time.now())) >= ZOOM_INTERVAL
}
