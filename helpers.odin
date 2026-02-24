package mouniverse

pixels_to_meters :: #force_inline proc(pixels: f32) -> f32 {
	return pixels * SCALING_FACTOR
}

meters_to_pixels :: #force_inline proc(meters: f32) -> f32 {
	return meters / SCALING_FACTOR
}
