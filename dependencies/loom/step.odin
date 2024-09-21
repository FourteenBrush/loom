package loom

Step :: struct {
    // TODO: replace with Id? just like zig does
    name: string,
    dependencies: [dynamic]Step,
    // allocated with Build allocator
    data: rawptr,
}

make_step :: proc(name: string, data: rawptr) -> Step {
    return {name=name, data=data}
}

step_depends_on :: proc(step: ^Step, dependency: Step) {
    assert(step != nil)
    append(&step.dependencies, dependency)
}

@(require_results)
add_check_step :: proc(build: ^Build, opts := CheckStepOpts{}) -> Step {
    data := new_clone(opts, build.allocator)
    return make_step("check", data)
}

CheckStepOpts :: struct {
}

@(require_results)
add_build_step :: proc(build: ^Build, $opts: $BuildStepOpts) -> Step where opts != {} {
    data := new(BuildStep, build.allocator)
    data.opts = opts
    return make_step("build", data)
}

@(private)
BuildStep :: struct {
    using opts: BuildStepOpts,
}

@(require_results)
add_run_step :: proc(build: ^Build, opts: RunStepOpts) -> Step {
    data := new(RunStep, build.allocator)
    data.opts = opts
    return make_step("run", data)
}

RunStepOpts :: struct {
}

@(private)
RunStep :: struct {
    using opts: RunStepOpts,
}

@(require_results)
add_system_command_invocation :: proc(build: ^Build, argv: RunArgs) -> Step {
    data := new(SystemCommandStep, build.allocator)
    data.argv = argv
    return make_step("system-command", data)
}

RunArgs :: union {[]string, []cstring}

SystemCommandStep :: struct {
    argv: RunArgs,
}
