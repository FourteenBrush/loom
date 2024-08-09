package build

import grumm "dependencies/grumm/src"

main :: proc() {
	build := grumm.Build {
		src_path              = "src",
		out_filepath          = "out/grumm",
		optimization          = .None,
		timings_export        = {mode = .Verbose},
		flags                 = {.UseSeparateModules},
		print_odin_invocation = true,
	}

	grumm.add_git_submodule("reader", "https://github.com/FourteenBrush/Classreader.git", {
        branch = "stable",
        commit = "41c8736d922312f9a505771363547e5b626e7742",
    })
	//grumm.add_code_source("back", "dependencies/back")

	// define a dependency, and where to obtain it from
	//back := grumm.dependency("duck")
	// duck defines its source in src/, however we want to hook a different
	// directory as the collection root
	//grumm.add_collection()
	//grumm.add_code_source("back", "dependencies/back")
	//grumm.add_dependency(&build, {"back", "https://github.com/laytan/back.git"})
	grumm.odin_invocation(build)
}
