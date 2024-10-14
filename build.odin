package build

import "core:fmt"
import "core:mem"
import "dependencies/loom"

main :: proc() {
    build := loom.define_build(context.allocator)
    defer loom.build(build)
    // ensure no implicit allocations occur which use the contexts allocator
    context.allocator = mem.panic_allocator()
	
	build_config, build_step := loom.add_build_step(&build)
    build_config.print_odin_invocation = true
    build_config.flags += {.ShowSystemCalls}

    loom.step_depends_on(&build.root_step, build_step)

	/*
	loom.add_git_submodule("reader", "https://github.com/FourteenBrush/Classreader.git", {
        //branch = "stable",
        commit = "d8ea24a3f401a62151a42dd0889e406636a8e9f4",
    })
    */

	//loom.add_code_source("back", "dependencies/back")

	// define a dependency, and where to obtain it from
	//back := loom.dependency("duck")
	// duck defines its source in src/, however we want to hook a different
	// directory as the collection root
	//loom.add_code_source("back", "dependencies/back")
	//loom.add_dependency(&build, {"back", "https://github.com/laytan/back.git"})
	//loom.odin_invocation(&{})
	//}
	//loom.add_dependency(&build, {"back", "https://github.com/laytan/back.git"})
	//loom.odin_invocation(&{})
}
