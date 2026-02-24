package mouniverse

import b2 "vendor:box2d"
import k2 "../../code/karl2d"
import "core:time"

Action :: enum {
	UseOneBullet,
	UseTwoBullets,
	Weapon3,
	Weapon4,
	Weapon5,
	Weapon6,
	Weapon7,
	Weapon8,
	Weapon9,
	MoveForward,
	MoveBackward,
	MoveLeft,
	MoveRight,
	TurnLeft,
	TurnRight,
	IncreaseSpeed,
	DecreaseSpeed,
	MaximizeSpeed,
	MinimizeSpeed,
	Brake,
	Shoot,
	ZoomIn,
	ZoomOut,
	FullscreenOn,
	FullscreenOff,
	Resize,
	LoadWorld,
	ExitGame,
	Escape
}

GameScreen :: enum {
	Menu,
	Playing,
	Paused,
	Over
}

WeapoonKind :: enum {
	OneBullet,
	TwoBullets
}

Actions :: struct {
	actions : bit_set[Action; u64]
}

GameState :: struct {
	screen : GameScreen,
	actions : bit_set[Action; u64],
	maps : map[u64]^Map,
	map_id : u64
}

Player   :: distinct u8
Bullet   :: distinct u8
Asteroid :: distinct u8
Enemy    :: distinct u8
Spark    :: distinct u8

Position :: struct {
	x, y : f32
}

Size :: struct {
	width : f32,
	height : f32
}

Center :: struct {
	cx, cy : f32
}

Rotation :: struct {
	angle : f32
}

Sprite :: struct {
	texture : ^k2.Texture
}

Weapon :: struct {
	kind : WeapoonKind,
	shot : time.Time
}

Trace :: struct {
	tint : int
}

Ship :: struct {
	/* Maximum ship speed from 0 to 50 (anti-damping). */
	speed : int,
	/* Ship tracing sign (draw trace). */
	tracing : bool,
	trace : Trace
}

Handle :: struct {
	body_id : b2.BodyId
}
