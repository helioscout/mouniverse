package mouniverse

import b2 "vendor:box2d"
import k2 "../../code/karl2d"
import ecs "../moecs/odin/src"

main :: proc() {
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
	ecs.mount(world, { name = "load-resources", phase = .MANUAL, callback = load_resources })
	ecs.mount(world, { name = "destroy", phase = .MANUAL, callback = destroy })
}
