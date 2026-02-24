package mouniverse

import b2 "vendor:box2d"
import k2 "../../code/karl2d"
import ecs "../moecs/odin/src"
import "core:mem"
import "core:fmt"

main :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				for _, entry in track.allocation_map {
					fmt.eprintf("%v leaked %v bytes\n", entry.location, entry.size)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	k2.init(DISPLAY_WIDTH, DISPLAY_HEIGHT, "mouniverse")

	ecs.init()

	world: ^ecs.World = ecs.new_world()

	register(world)
	mount(world)

	ecs.run(world)

	ecs.execute(world, "load-resources")

	for k2.update() {
		ecs.progress(world)
		
		k2.clear(k2.BLACK)
		k2.present()
	}

	ecs.execute(world, "destroy")
	ecs.destroy()

	k2.shutdown()
}

register :: proc(world: ^ecs.World) {
	ecs.register(world, .COMPONENT, Actions)
	ecs.register(world, .COMPONENT, Position)
	ecs.register(world, .COMPONENT, Size)
	ecs.register(world, .COMPONENT, Center)
	ecs.register(world, .COMPONENT, Rotation)
	ecs.register(world, .COMPONENT, Sprite)
	ecs.register(world, .COMPONENT, Weapon)
	ecs.register(world, .COMPONENT, Ship)
	ecs.register(world, .COMPONENT, Handle)
	ecs.register(world, .RESOURCE, Sprites)
	ecs.register(world, .RESOURCE, GameState)
	ecs.register(world, .RESOURCE, Space)
	ecs.register(world, .TAG, Player)
	ecs.register(world, .TAG, Bullet)
	ecs.register(world, .TAG, Asteroid)
	ecs.register(world, .TAG, Enemy)
	ecs.register(world, .TAG, Spark)
}

mount :: proc(world: ^ecs.World) {
	ecs.mount(world, { phase = .START, callback = preapare })
	ecs.mount(world, { phase = .START, callback = load_world })
	ecs.mount(world, { components = { Actions }, tags = { Player }, callback = control })
	ecs.mount(world, { components = { Position, Rotation, Sprite, Center, Size }, callback = draw })
	ecs.mount(world, { name = "load-resources", phase = .MANUAL, callback = load_resources })
	ecs.mount(world, { name = "destroy", phase = .MANUAL, callback = destroy })
}
