package mouniverse

import b2 "vendor:box2d"
import k2 "../../code/karl2d"
import ecs "../moecs/odin/src"
import sqlite "../../code/odin-sqlite3"
import str "core:strings"
import "core:time"
import "core:fmt"

load_resources :: proc(entities: ^[dynamic]^ecs.Entity, world: ^ecs.World) {
	sprites: map[string]k2.Texture

	db, status := sqlite.open("space.db")

	if status != nil {
		fmt.panicf("Unable to open database 'space.db' (%v): %s", status, sqlite.status_explain(status))
	}

	query, _ := sqlite.sql_bind(db, "select key, label, file_name from sprite")

	for row in sqlite.sql_row(db, query, struct { key: string, label: string, file_name: string }) {
		sprites[str.clone(row.key)] = k2.load_texture_from_file(fmt.tprintf("./assets/%s", row.file_name))
	}

	ecs.set(world, Sprites, &Sprites {
		spritesheet  = k2.load_texture_from_file("./assets/spritesheet-px.png"),
		trace_thin   = k2.load_texture_from_file("./assets/trace-thin.png"),
		trace_medium = k2.load_texture_from_file("./assets/trace-medium.png"),
		trace_thick  = k2.load_texture_from_file("./assets/trace-thick.png"),
		sprites = sprites
	})

	query, _ = sqlite.sql_bind(db, "select id, label, width, height from world")

	maps: map[u64]^Map
	
	for row in sqlite.sql_row(db, query, struct { id: u64, label: string, width: int, height: int }) {
		_map: ^Map = new(Map)
		_map^ = { id = row.id, label = row.label, width = f32(row.width), height = f32(row.height) }
		maps[row.id] = _map
	}

	ecs.set(world, GameState, &GameState {
		screen  = .Playing,	// TODO: Change to Menu when UI added.
		maps    = maps,
		map_id  = 10,		// TODO: remove when UI added.
		zoom    = 1.0,
		scaled  = time.now()
	})

	sqlite.close(db)
}

prepare :: proc(entities: ^[dynamic]^ecs.Entity, world: ^ecs.World) {
	debug_drawer := b2.DefaultDebugDraw()
	debug_drawer.drawShapes = true
	debug_drawer.DrawSegmentFcn = draw_segment
	debug_drawer.DrawPolygonFcn = draw_polygon
	debug_drawer.DrawSolidPolygonFcn = draw_solid_polygon
	debug_drawer.DrawPointFcn = draw_point

	ecs.set(world, Space, &Space {
		world_id = b2.nullWorldId,
		debug_drawer = debug_drawer
	})
}

load_world :: proc(entities: ^[dynamic]^ecs.Entity, world: ^ecs.World) {
	state := ecs.get(world, GameState)
	sprites, space := ecs.get_mut(world, Sprites, Space)

	/* Recreate physics world. */
	if b2.IS_NON_NULL(space.world_id) do b2.DestroyWorld(space.world_id)

	world_def := b2.DefaultWorldDef()
	world_def.gravity = { 0.0, 0.0 }
	
	space.world_id = b2.CreateWorld(world_def)

	/* Load entities from database. */
	db, status := sqlite.open("space.db")

	if status != nil {
		fmt.panicf("Unable to open database 'space.db' (%v): %s", status, sqlite.status_explain(status))
	}

	query, _ := sqlite.sql_bind(db, fmt.tprintf(
		`select p.x as x, p.y as y, r.angle as angle, sprite_key, t.* 
		from entity e 
		inner join position p on p.id = e.position_id 
		inner join rotation r on r.id = e.rotation_id 
		left join tag t on t.id = e.tag_id 
		where e.world_id = %d`, state.map_id))

	for row in sqlite.sql_row(db, query, struct { x: int, y: int, angle: f32, key: string, tag_id: u64,
												  player: bool, asteroid: bool, enemy: bool }) {
		entity := ecs.spawn(world, row.asteroid ? .STATIC : .DYNAMIC)

		if row.player   do ecs.tag(entity, Player)
		if row.asteroid do ecs.tag(entity, Asteroid)
		if row.enemy    do ecs.tag(entity, Enemy)

		texture, ok := sprites.sprites[row.key]

		if !ok do continue

		width: f32 = f32(texture.width)
		height: f32 = f32(texture.height)
		cx: f32 = width / 2
		cy: f32 = height / 2

		/* Adding components specific to all entities. */
		ecs.add(entity,
			Position, &Position { x = f32(row.x), y = f32(row.y) },
			Size,	  &Size { width = width, height = height },
			Center,	  &Center { cx = cx, cy = cy },
			Rotation, &Rotation { angle = row.angle },
			Sprite,	  &Sprite { texture = texture })

		/* Ship with trace and weapon are specific only for player and enemy. */
		if row.player || row.enemy {
			ecs.add(entity,
				Weapon, &Weapon { kind = .OneBullet },
				Ship,   &Ship { speed = 50 })
		}

		/* Actions is specific only for player. */
		if row.player {
			ecs.add(entity, Actions, &Actions { })
		}

		/* Creating entity physics body. */
		body_def := b2.DefaultBodyDef()
		body_def.userData = entity
		body_def.type = b2.BodyType.dynamicBody
		body_def.position = {
			pixels_to_meters(f32(row.x) + cx),
			pixels_to_meters(f32(row.y) + cy)
		}
		body_def.rotation = b2.MakeRot(row.angle)

		body_id := b2.CreateBody(space.world_id, body_def)

		/* Adding physics handle component to link entity with it's physics. */
		ecs.add(entity, Handle, &Handle { body_id = body_id })
		
		/* Creating body collider. */
		dynamic_box := b2.MakeBox(pixels_to_meters(width) / 2, pixels_to_meters(height) / 2)
		shape_def := b2.DefaultShapeDef()
		shape_def.density = 1.0
		shape_def.material.friction = 0.1
		shape_def.enableContactEvents = true

		_ = b2.CreatePolygonShape(body_id, shape_def, dynamic_box)

		/* Setting mass for asteroid depending on it's size. */
		if row.asteroid {
			mass_data: b2.MassData
			mass_data.mass = width * height / 9.8
			mass_data.center = { 0.0, 0.0 }
			mass_data.rotationalInertia = 50.0

			b2.Body_SetMassData(body_id, mass_data)
		}
	}

	sqlite.close(db)
}

control :: proc(entities: ^[dynamic]^ecs.Entity, world: ^ecs.World) {
	state := ecs.get(world, GameState)

	if state.screen == .Playing {
		for entity in entities {
			actions := ecs.get_mut(entity, Actions)
			actions.actions = {}

			if k2.key_went_down(.N1)      do actions.actions += { .UseOneBullet }
			else if k2.key_went_down(.N2) do actions.actions += { .UseTwoBullets }

			if k2.key_is_held(.A)     do actions.actions += { .MoveLeft }
			if k2.key_is_held(.D)     do actions.actions += { .MoveRight }
			if k2.key_is_held(.Up)    do actions.actions += { .MoveForward }
			if k2.key_is_held(.Down)  do actions.actions += { .MoveBackward }
			if k2.key_is_held(.Left)  do actions.actions += { .TurnLeft }
			if k2.key_is_held(.Right) do actions.actions += { .TurnRight }

			if k2.key_went_down(.Minus)      do actions.actions += { .MinimizeSpeed }
			else if k2.key_went_down(.Equal) do actions.actions += { .MaximizeSpeed }

			if k2.key_is_held(.Q)      do actions.actions += { .DecreaseSpeed }
			else if k2.key_is_held(.E) do actions.actions += { .IncreaseSpeed }
			
			if k2.key_is_held(.Space) do actions.actions += { .Brake }
			if k2.key_is_held(.W)     do actions.actions += { .Shoot }

			if k2.key_is_held(.Left_Control) {
				if k2.key_is_held(.I) do actions.actions += { .ZoomIn }
				if k2.key_is_held(.O) do actions.actions += { .ZoomOut }
			}
		}
	}
}

global_control :: proc(entities: ^[dynamic]^ecs.Entity, world: ^ecs.World) {
	state := ecs.get_mut(world, GameState)
	
	state.actions = {}

	if k2.key_is_held(.Left_Control) {
		if k2.key_went_down(.F) {
			if state.fullscreen do state.actions += { .FullscreenOff }
			else do state.actions += { .FullscreenOn }
		}
	}
}

actions :: proc(entities: ^[dynamic]^ecs.Entity, world: ^ecs.World) {
	state := ecs.get_mut(world, GameState)

	if state.screen == .Playing {
		for entity in entities {
			handle, actions, weapon, ship := ecs.get_mut(entity, Handle, Actions, Weapon, Ship)

			action := actions.actions
			body_id := handle.body_id
			
			mass: f32 = b2.Body_GetMass(body_id)
			impulse: f32 = 3.90625 * mass
			angular_impulse: f32 = 0.7510417 * mass

			rotation     := b2.Body_GetRotation(body_id)
			vec_left     := b2.RotateVector(rotation, { -impulse, 0.0 });
			vec_right    := b2.RotateVector(rotation, { impulse, 0.0 });
			vec_forward  := b2.RotateVector(rotation, { 0.0, -impulse });
			vec_backward := b2.RotateVector(rotation, { 0.0, impulse });

			if .UseOneBullet  in action do weapon.kind = .OneBullet
			if .UseTwoBullets in action do weapon.kind = .TwoBullets
			if .MoveLeft      in action do b2.Body_ApplyLinearImpulseToCenter(body_id, vec_left, true)
			if .MoveRight     in action do b2.Body_ApplyLinearImpulseToCenter(body_id, vec_right, true)
			if .MoveForward   in action do b2.Body_ApplyLinearImpulseToCenter(body_id, vec_forward, true)
			if .MoveBackward  in action do b2.Body_ApplyLinearImpulseToCenter(body_id, vec_backward, true)
			if .TurnLeft      in action do b2.Body_ApplyAngularImpulse(body_id, -angular_impulse, true)
			if .TurnRight     in action do b2.Body_ApplyAngularImpulse(body_id, angular_impulse, true)
			if .MinimizeSpeed in action do ship.speed = 0
			if .MaximizeSpeed in action do ship.speed = 500

			if .DecreaseSpeed in action && ship.speed > 0  do ship.speed -= 1
			if .IncreaseSpeed in action && ship.speed < 50 do ship.speed += 1

			if .ZoomIn in action && state.zoom < 2.0 && zoom_allowed(state.scaled) {
				state.zoom += 0.1
				state.scaled = time.now()
			}

			if .ZoomOut in action && state.zoom > 1.0 && zoom_allowed(state.scaled) {
				state.zoom -= 0.1
				state.scaled = time.now()
			}

			if .Brake in action {
				linear_damping  := b2.Body_GetLinearDamping(body_id)
				angular_damping := b2.Body_GetAngularDamping(body_id)
		
				if linear_damping < 100  do b2.Body_SetLinearDamping(body_id, linear_damping * 1.2 + 0.5)
				if angular_damping < 100 do b2.Body_SetAngularDamping(body_id, angular_damping * 1.2 + 0.5)
			} else {
				vec_velocity     := b2.Body_GetLinearVelocity(body_id)
				linear_velocity  := max(abs(vec_velocity.x), abs(vec_velocity.y))
				angular_velocity := abs(b2.Body_GetAngularVelocity(body_id))
				linear_factor:  f32 = linear_velocity >= 200.0 ? linear_velocity : 0.0
				angular_factor: f32 = angular_velocity >= 10.0 ? angular_velocity : 0.0

				b2.Body_SetLinearDamping(body_id, (50 + linear_factor - f32(ship.speed)) / 10.0)
				b2.Body_SetAngularDamping(body_id, (50 + angular_factor - f32(ship.speed)) / 10.0)
			}

			ship.tracing = .MoveForward in action || .MoveBackward in action ||
						   .MoveLeft in action || .MoveRight in action
		}
	}
}

global_actions :: proc(entities: ^[dynamic]^ecs.Entity, world: ^ecs.World) {
	state := ecs.get_mut(world, GameState)

	if .FullscreenOn in state.actions {
		k2.set_window_mode(.Borderless_Fullscreen)
		state.fullscreen = true
	}

	if .FullscreenOff in state.actions {
		k2.set_window_mode(.Windowed_Resizable)
		state.fullscreen = false
	}
}

physics :: proc(entities: ^[dynamic]^ecs.Entity, world: ^ecs.World) {
	state, space := ecs.get(world, GameState, Space)

	if state.screen == .Playing {
		b2.World_Step(space.world_id, TIME_STEP, SUB_STEP_COUNT)
	}
}

transformation :: proc(entities: ^[dynamic]^ecs.Entity, world: ^ecs.World) {
	state := ecs.get_mut(world, GameState)

	if state.screen == .Playing {
		for entity in entities {
			handle, pos, rot, center := ecs.get_mut(entity, Handle, Position, Rotation, Center)

			if ecs.tagged(entity, Player) {
				state.position = { pos.x + center.cx, pos.y + center.cy }
			}
		}
	}
}

camera :: proc(entities: ^[dynamic]^ecs.Entity, world: ^ecs.World) {
	state := ecs.get(world, GameState)
	
	k2.set_camera(k2.Camera {
		target = state.position,
		offset = { f32(k2.get_screen_width()) / 2.0, f32(k2.get_screen_height()) / 2.0 },
		zoom = state.zoom })
}

draw :: proc(entities: ^[dynamic]^ecs.Entity, world: ^ecs.World) {
	state := ecs.get(world, GameState)

	if state.screen == .Playing {
		for entity in entities {
			pos, rot, sprite, center, size := ecs.get(entity, Position, Rotation, Sprite, Center, Size)

			if rot.angle == 0.0 {
				k2.draw_texture(sprite.texture, { pos.x, pos.y })
			} else {
				k2.draw_texture_ex(
					sprite.texture,
					k2.get_texture_rect(sprite.texture),
					{ x = pos.x + center.cx, y = pos.y + center.cy,
					  w = f32(sprite.texture.width), h = f32(sprite.texture.height) },
					{ center.cx, center.cy },
					rot.angle)
			}
		}
	}
}

debug :: proc(entities: ^[dynamic]^ecs.Entity, world: ^ecs.World) {
	state, space := ecs.get(world, GameState, Space)

	if state.screen == .Playing {
		b2.World_Draw(space.world_id, &space.debug_drawer)
	}
}

destroy :: proc(entities: ^[dynamic]^ecs.Entity, world: ^ecs.World) {
	sprites, state := ecs.get_mut(world, Sprites, GameState)

	for key, texture in sprites.sprites {
		k2.destroy_texture(texture)
		delete(key)
	}
	
	k2.destroy_texture(sprites.trace_thin)
	k2.destroy_texture(sprites.trace_medium)
	k2.destroy_texture(sprites.trace_thick)
	k2.destroy_texture(sprites.spritesheet)

	for _, _map in state.maps do free(_map)

	delete(sprites.sprites)
	delete(state.maps)
}
