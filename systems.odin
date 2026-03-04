package mouniverse

import b2 "vendor:box2d"
import k2 "../../code/karl2d"
import ecs "../moecs/src"
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
		sprites      = sprites,
		bullet_a     = { x = 13, y = 0, w = 2, h = 9 },
		spark        = { 0 = { x = 34, y = 0, w = 10, h = 8 },
					     1 = { x = 45, y = 0, w = 7,  h = 8 },
					     2 = { x = 54, y = 0, w = 9,  h = 8 } }
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
				Weapon, &Weapon { kind = .OneBullet, shot = time.now() },
				Ship,   &Ship { speed = 50 })
		}

		/* Actions is specific only for player. */
		if row.player {
			ecs.add(entity, Actions, &Actions { })
		}

		/* Creating entity physics body. */
		body_def := b2.DefaultBodyDef()
		body_def.userData = entity
		body_def.type = .dynamicBody
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

		events := b2.World_GetContactEvents(space.world_id)

		for i in 0..<events.beginCount {
			event := events.beginEvents[i]
			body_id_a := b2.Shape_GetBody(event.shapeIdA)
			body_id_b := b2.Shape_GetBody(event.shapeIdB)
			entity_a := cast(^ecs.Entity)b2.Body_GetUserData(body_id_a)
			entity_b := cast(^ecs.Entity)b2.Body_GetUserData(body_id_b)

			if !ecs.deleted(entity_a) && !ecs.deleted(entity_b) {
				ecs.add(entity_a, Collision, &Collision { entity = entity_b })
				ecs.add(entity_b, Collision, &Collision { entity = entity_a })
			}
		}
	}
}

transformation :: proc(entities: ^[dynamic]^ecs.Entity, world: ^ecs.World) {
	state := ecs.get_mut(world, GameState)

	if state.screen == .Playing {
		for entity in entities {
			handle, pos, rot, center := ecs.get_mut(entity, Handle, Position, Rotation, Center)

			position := b2.Body_GetPosition(handle.body_id)
			rotation := b2.Body_GetRotation(handle.body_id)

			pos.x = meters_to_pixels(position.x) - center.cx
			pos.y = meters_to_pixels(position.y) - center.cy
			rot.angle = b2.Rot_GetAngle(rotation)
			
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
			rect, is_rect := sprite.rect.?

			if rot.angle == 0.0 {
				if is_rect do k2.draw_texture_rect(sprite.texture, rect, { pos.x, pos.y })
				else do k2.draw_texture(sprite.texture, { pos.x, pos.y })
			} else {
				k2.draw_texture_ex(
					sprite.texture,
					rect if is_rect else k2.get_texture_rect(sprite.texture),
					{ x = pos.x + center.cx, y = pos.y + center.cy,
					  w = is_rect ? rect.w : f32(sprite.texture.width),
					  h = is_rect ? rect.h : f32(sprite.texture.height) },
					{ center.cx, center.cy },
					rot.angle)
			}
		}
	}
}

draw_ships :: proc(entities: ^[dynamic]^ecs.Entity, world: ^ecs.World) {
	state, sprites := ecs.get(world, GameState, Sprites)

	if state.screen == .Playing {
		for entity in entities {
			pos, rot, center, size, ship := ecs.get_mut(entity, Position, Rotation, Center, Size, Ship)

			if ship.tracing {
				dh: f32 = 50.0 - f32(ship.speed)
				width    := f32(sprites.trace_thin.width)
				height   := f32(sprites.trace_thin.height) - dh
				position := rotate_point(
					pos.x + center.cx - width / 2.0,
					pos.y + size.height,
					pos.x + center.cx,
					pos.y + center.cy,
					rot.angle)

				if ship.trace.tint < 255 do ship.trace.tint += 5

				k2.draw_texture_ex(
					sprites.trace_thin,
					{ x = 0.0, y = dh, w = width, h = height },
					{ x = position.x, y = position.y, w = width, h = height },
					{ 0.0, 0.0 },
					rot.angle,
					{ 255 - ship.trace.tint, 255, 255, 255 }
				)
			} else {
				ship.trace.tint = 0
			}
		}
	}
}

shooting :: proc(entities: ^[dynamic]^ecs.Entity, world: ^ecs.World) {
	state, space, sprites := ecs.get(world, GameState, Space, Sprites)
	texture := sprites.spritesheet

	new_body :: proc(world_id: b2.WorldId, bullet: ^ecs.Entity, pos: [2]f32, rect: k2.Rect,
		rot: ^Rotation) -> b2.BodyId {
		width: f32 = rect.w
		height: f32 = rect.h

		body_def := b2.DefaultBodyDef()
		body_def.userData = bullet
		body_def.type = .dynamicBody
		body_def.position = {
			pixels_to_meters(pos.x + width / 2.0),
			pixels_to_meters(pos.y + height / 2.0)
		}
		body_def.rotation = b2.MakeRot(rot.angle)
		body_def.isBullet = true

		body_id := b2.CreateBody(world_id, body_def)

		dynamic_box := b2.MakeBox(pixels_to_meters(width) / 2.0, pixels_to_meters(height) / 2.0)
		shape_def := b2.DefaultShapeDef()
		shape_def.density = 1.0
		shape_def.material.friction = 0.01
		shape_def.filter.groupIndex = -1
		shape_def.enableContactEvents = true

		_ = b2.CreatePolygonShape(body_id, shape_def, dynamic_box)

		b2.Body_ApplyLinearImpulseToCenter(
			body_id,
			b2.RotateVector(b2.MakeRot(to_radians(-90)), angle_to_vector(rot.angle, 20.0)),
			true)

		return body_id
	}

	new_bullet :: proc(world: ^ecs.World, world_id: b2.WorldId, pos: [2]f32, texture: k2.Texture,
		rect: k2.Rect, rot: ^Rotation) {
		bullet := ecs.spawn(world)

		ecs.tag(bullet, Bullet)
		ecs.add(bullet,
			Position, &Position { x = pos.x, y = pos.y },
			Size,     &Size     { width = rect.w, height = rect.h },
			Center,   &Center   { cx = rect.w / 2.0, cy = rect.h / 2.0 },
			Rotation, &Rotation { angle = rot.angle },
			Sprite,   &Sprite   { texture = texture, rect = rect },
			Handle,   &Handle   { body_id = new_body(world_id, bullet, pos, rect, rot) })
	}

	if state.screen == .Playing {
		for entity in entities {
			pos, center, rot, size, weapon, actions :=
				ecs.get_mut(entity, Position, Center, Rotation, Size, Weapon, Actions)

			if .Shoot in actions.actions && shot_allowed(weapon.shot) {
				width: f32 = sprites.bullet_a.w
				height: f32 = sprites.bullet_a.h

				switch weapon.kind {
					case .OneBullet:
						position: [2]f32 = {
							pos.x + center.cx - width / 2.0,
							pos.y - height - 1
						}

						rotate_vec(&position, pos.x + center.cx, pos.y + center.cy, rot.angle)
						new_bullet(world, space.world_id, position, texture, sprites.bullet_a, rot)

					case .TwoBullets:
						dx: f32 = size.width / 3.0
						pos1: [2]f32 = {
							pos.x + dx - width / 2.0,
							pos.y - height - 1
						}
						pos2: [2]f32 = {
							pos.x + 2 * dx - width / 2.0,
							pos.y - height - 1
						}

						rotate_vec(&pos1, pos.x + center.cx, pos.y + center.cy, rot.angle)
						rotate_vec(&pos2, pos.x + center.cx, pos.y + center.cy, rot.angle)

						new_bullet(world, space.world_id, pos1, texture, sprites.bullet_a, rot)
						new_bullet(world, space.world_id, pos2, texture, sprites.bullet_a, rot)
				}

				weapon.shot = time.now()
			}
		}
	}
}

collisions :: proc(entities: ^[dynamic]^ecs.Entity, world: ^ecs.World) {
	state := ecs.get(world, GameState)

	if state.screen == .Playing {
		for entity in entities {
			collision, handle, pos, center := ecs.get(entity, Collision, Handle, Position, Center)
			
			if ecs.tagged(entity, Bullet) {
				spark := ecs.spawn(world)

				ecs.tag(spark, Spark)
				ecs.add(spark,
					Position,  &Position  { x = pos.x + center.cx, y = pos.y + center.cy },
					Animation, &Animation { frame = 0, speed = 2, count = 3 })
				
				b2.DestroyBody(handle.body_id)
				ecs.despawn(world, entity)
				ecs.remove(collision.entity, Collision)
			}
		}
	}
}

effects :: proc(entities: ^[dynamic]^ecs.Entity, world: ^ecs.World) {
	state, sprites := ecs.get(world, GameState, Sprites)

	if state.screen == .Playing {
		for entity in entities {
			pos, animation := ecs.get_mut(entity, Position, Animation)

			if ecs.tagged(entity, Spark) {
				animation.frame += 1

				if animation.frame == animation.count * animation.speed {
					ecs.despawn(world, entity)
				} else {
					idx := animation.frame / animation.speed
					rect := sprites.spark[idx]
					
					k2.draw_texture_rect(
						sprites.spritesheet,
						rect,
						{ pos.x - rect.w / 2.0, pos.y - rect.h / 2.0 })
				}
			}
		}
	}
}

cleaning :: proc(entities: ^[dynamic]^ecs.Entity, world: ^ecs.World) {
	state := ecs.get(world, GameState)

	if state.screen == .Playing {
		width, height := f32(k2.get_screen_width()), f32(k2.get_screen_height())
		rect: k2.Rect = { x = state.position.x - width / 2.0,
						  y = state.position.y - height / 2.0,
						  w = width,
						  h = height }
			
		for entity in entities {
			pos, size, handle := ecs.get(entity, Position, Size, Handle)
			
			/* Destroy bullets that are outside of the screen. */
			if is_outside_of_rect(pos, size, rect) {
				b2.DestroyBody(handle.body_id)
				ecs.despawn(world, entity)
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
