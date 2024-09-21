package loom

import "core:os"
import "core:log"

main :: proc() {
    context.logger = log.create_console_logger(.Debug when ODIN_DEBUG else .Warning, {})
    log.Level_Headers = [?]string {
         0..<10 = "debug",
        10..<20 = "info",
        20..<30 = "warning",
        30..<40 = "error",
        40..<50 = "fatal",
    }

    log.debug("build system main")
    x :: proc(y: int z: int) {}
    run()
}

run :: proc(allocator := context.allocator) {
    build_file, fserr := os.read_entire_file_or_err("build.odin", allocator)
    if fserr != nil {
        // TODO: proper error reporting
        fatal("unable to open build file:" , os.error_string(fserr))
    }
    defer delete(build_file)
}

build :: proc(build: ^Build) {
    step := &build.root_step
    for dependency in step.dependencies {
        switch dependency {

        }
    }
}

fatal :: proc(args: ..any) -> ! {
    log.fatal(..args)
    os.exit(1)
}
