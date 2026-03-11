package mouniverse

import b2 "vendor:box2d"
import k2 "../karl2d"
import ecs "../moecs/src"
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
	map_id : u64,
	position : k2.Vec2,
	fullscreen : bool,
	zoom : f32,
	scaled : time.Time
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
	texture : k2.Texture,
	/* Rectangle on the texture to draw. */
	rect    : Maybe(k2.Rect)
}

Weapon :: struct {
	kind : WeapoonKind,
	shot : time.Time
}

Trace :: struct {
	tint : u8
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

Collision :: struct {
	entity : ^ecs.Entity
}

Animation :: struct {
	frame : int,			/* Current game loop frame since animation start. */
	speed : int,			/* Game loop frames count per animation frame.    */
	count : int				/* Animation frames count.						  */
}
