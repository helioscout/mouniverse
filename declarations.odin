package mouniverse

import b2 "vendor:box2d"
import k2 "../../code/karl2d"
import "core:time"

DISPLAY_WIDTH 	 : int : 800
DISPLAY_HEIGHT	 : int : 600
DISPLAY_CENTER_X : int : DISPLAY_WIDTH / 2
DISPLAY_CENTER_Y : int : DISPLAY_HEIGHT / 2
SCALING_FACTOR   : f32 : 0.1
TIME_STEP        : f32 : 1.0 / 60.0
SUB_STEP_COUNT   : i32 : 4
/* Interval between shots in milliseconds. */
SHOT_INTERVAL    : f64 : 100
/* Interval between camera zoom in milliseconds. */
ZOOM_INTERVAL    : f64 : 100

Sprites :: struct {
	sprites      : map[string]k2.Texture,
	trace_thin   : k2.Texture,
	trace_medium : k2.Texture,
	trace_thick  : k2.Texture,
	spritesheet  : k2.Texture
}

Space :: struct {
	world_id : b2.WorldId,
	debug_drawer : b2.DebugDraw
}

Map :: struct {
	id : u64,
	width : f32,
	height : f32,
	label : string
}
