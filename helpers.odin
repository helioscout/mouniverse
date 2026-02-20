package mouniverse

pixels_to_meters :: proc(pixels: f32) -> f32 {
	return pixels * SCALING_FACTOR
}

meters_to_pixels :: proc(meters: f32) -> f32 {
	return meters / SCALING_FACTOR
}
