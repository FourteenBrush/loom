package loom

import "core:mem"

Step :: struct {
    // TODO: replace with Id? just like zig does
    name: string,
    // allocated with Build allocator to extend lifetime
    // TODO: union instead of rawptr?
    data: any,
    dependencies: [dynamic]Step,
}

@(private)
make_step :: proc(name: string, data: ^$D, allocator: mem.Allocator) -> Step {
    return {
        name=name,
        data=mem.make_any(data, typeid_of(D)),
        dependencies=make([dynamic]Step, allocator),
    }
}

step_depends_on :: proc(step: ^Step, dependency: Step) {
    assert(step != nil)
    append(&step.dependencies, dependency)
}

@(require_results)
add_check_step :: proc(build: ^Build, opts := CheckStepOpts{}) -> Step {
    data := new_clone(opts, build.allocator)
    return make_step("check", data, build.allocator)
}

CheckStepOpts :: struct {
}

// Returns a build configuration with default values, to be configured by the user.
@(require_results)
add_build_step :: proc(build: ^Build) -> (^BuildConfig, Step) {
    data := new_clone(default_build_config, build.allocator)
    step := make_step("build", data, build.allocator)
    return data, step
}

// Structures as defined in the `odin build` command.
// TODO: revision https://github.com/odin-lang/Odin/blob/cb31df34c199638a03193520e03a59fc722429d2/src/main.cpp#L506
//odinfmt: disable
BuildConfig :: struct {
    src_path:               string,
    out_filepath:           string,
    // location for any build artifacts to be placed.
    install_dir:            string,
    optimization:           OptimizationMode,
    // exports
    timings_export:         TimingsExport,
    dependencies_export:    DependenciesExport,
    definables_export_file: string,

    build_mode:             BuildMode,
    target:                 CompilationTarget,
    // only used when target is Darwin
    subtarget:              CompilationSubTarget,
    minimum_os_version:     string,

    extra_linker_flags:     string,
    extra_assembler_flags:  string,
    microarch:              string,
    // comma-separated list of strings
    // https://github.com/odin-lang/Odin/blob/cb31df34c199638a03193520e03a59fc722429d2/src/build_settings_microarch.cpp#L20
    target_features:        string,
    reloc_mode:             RelocMode,
    sanitization:           Sanitization,

    thread_count:           uint,
    error_pos_style:        ErrorStyle,
    max_error_count:        uint,

    flags:                  Flags,
    vet_flags:              VetFlags,
    defines:                [dynamic]Define,
    custom_attributes:      [dynamic]string,

    print_odin_invocation:  bool,
}
//odinfmt: enable

// TODO: should we make this user visible?
default_build_config := BuildConfig {
    src_path    = "src",
    install_dir = "out",
}

@(require_results)
add_run_step :: proc(build: ^Build, opts: RunStepOpts) -> Step {
    data := new(RunStep, build.allocator)
    data.opts = opts
    return make_step("run", data, build.allocator)
}

RunStepOpts :: struct {
}

@(private)
RunStep :: struct {
    using opts: RunStepOpts,
}

@(require_results)
add_system_command_invocation :: proc(build: ^Build, argv: []string) -> Step {
    data := new(SystemCommandStep, build.allocator)
    data.argv = argv
    return make_step("system-command", data, build.allocator)
}

SystemCommandStep :: struct {
    argv: []string,
}
