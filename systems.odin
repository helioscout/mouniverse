package mouniverse

import b2 "vendor:box2d"
import k2 "../../code/karl2d"
import ecs "../moecs/odin/src"
import sqlite "../../code/odin-sqlite3"
import "core:fmt"

load_resources :: proc(entities: ^[dynamic]^ecs.Entity, world: ^ecs.World) {
	sprites := ecs.get_mut(world, Sprites)

	sprites.spritesheet  = k2.load_texture_from_file("./assets/spritesheet-px.png")
	sprites.trace_thin   = k2.load_texture_from_file("./assets/trace-thin.png")
	sprites.trace_medium = k2.load_texture_from_file("./assets/trace-medium.png")
	sprites.trace_thick  = k2.load_texture_from_file("./assets/trace-thick.png")

	db, status := sqlite.open("space.db")

	if status != nil {
		fmt.panicf("Unable to open database 'space.db' (%v): %s", status, sqlite.status_explain(status))
	}

	query, _ := sqlite.sql_bind(db, "select key, label, file_name from sprite")

	for row in sqlite.sql_row(db, query, struct { key: string, label: string, file_name: string }) {
		sprites.sprites[row.key] = k2.load_texture_from_file(fmt.tprintf("./assets/%s", row.file_name))
	}

	ecs.set(world, GameState, &GameState {
		screen = .Menu
	})

	sqlite.close(db)
}

preapare :: proc(entities: ^[dynamic]^ecs.Entity, world: ^ecs.World) {
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

destroy :: proc(entities: ^[dynamic]^ecs.Entity, world: ^ecs.World) {
	s := ecs.get_mut(world, Sprites)

	for _, texture in s.sprites do k2.destroy_texture(texture)
	
	k2.destroy_texture(s.trace_thin)
	k2.destroy_texture(s.trace_medium)
	k2.destroy_texture(s.trace_thick)
	k2.destroy_texture(s.spritesheet)
}
