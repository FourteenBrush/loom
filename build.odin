package build

import "dependencies/loom"

main :: proc() {
	build := loom.BuildStepOpts {
		src_path              = "src",
		out_filepath          = "out/loom",
        build_mode            = .SharedLib,
		timings_export        = {mode = .Verbose},
		flags                 = {.UseSeparateModules, .Debug, .NoEntryPoint},
		print_odin_invocation = true,
	}

	loom.add_git_submodule("reader", "https://github.com/FourteenBrush/Classreader.git", {
        //branch = "stable",
        commit = "d8ea24a3f401a62151a42dd0889e406636a8e9f4",
    })

	//loom.add_code_source("back", "dependencies/back")

	// define a dependency, and where to obtain it from
	//back := loom.dependency("duck")
	// duck defines its source in src/, however we want to hook a different
	// directory as the collection root
	//loom.add_collection()
	//loom.add_code_source("back", "dependencies/back")
	//loom.add_dependency(&build, {"back", "https://github.com/laytan/back.git"})
	loom.odin_invocation(&build)
}

build :: proc(build: ^loom.Build) {
    build_step := loom.add_build_step(build, {})
    loom.step_depends_on(&build_step, build.root_step)
}
