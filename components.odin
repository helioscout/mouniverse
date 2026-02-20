package mouniverse

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
	actions : bit_set[Action; u64]
}

Player   :: distinct u8
Bullet   :: distinct u8
Asteroid :: distinct u8
Enemy    :: distinct u8
Spark    :: distinct u8
