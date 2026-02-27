package mouniverse

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

	k2.init(DISPLAY_WIDTH, DISPLAY_HEIGHT, "mouniverse", { window_mode = .Windowed_Resizable })

	ecs.init()

	world: ^ecs.World = ecs.new_world()

	register(world)
	mount(world)

	ecs.run(world)

	ecs.execute(world, "load-resources")

	for k2.update() {
		k2.clear(k2.BLACK)
		ecs.progress(world)
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
	ecs.mount(world, { callback = prepare,        phase = .START })
	ecs.mount(world, { callback = load_world,     phase = .START })
	ecs.mount(world, { callback = control,        components = { Actions }, tags = { Player } })
	ecs.mount(world, { callback = global_control })
	ecs.mount(world, { callback = actions,        components = { Handle, Actions, Weapon, Ship }, tags = { Player } })
	ecs.mount(world, { callback = global_actions })
	ecs.mount(world, { callback = physics })
	ecs.mount(world, { callback = transformation, components = { Handle, Position, Rotation, Center } })
	ecs.mount(world, { callback = camera })
	ecs.mount(world, { callback = draw,           components = { Position, Rotation, Sprite, Center, Size } })
	ecs.mount(world, { callback = draw_ships,     components = { Position, Rotation, Center, Size, Ship } })
	ecs.mount(world, { callback = shooting,       components = { Position, Center, Rotation, Size, Weapon, Actions } })
	ecs.mount(world, { callback = debug })
	ecs.mount(world, { callback = load_resources, name = "load-resources", phase = .MANUAL })
	ecs.mount(world, { callback = destroy,        name = "destroy", phase = .MANUAL })
}
