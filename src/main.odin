package loom

import "core:os"
import "core:log"
import "core:mem"
import "core:c/libc"

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

    arena: mem.Dynamic_Pool
    mem.dynamic_arena_init(&arena)
    defer mem.dynamic_arena_destroy(&arena)
    allocator := mem.dynamic_arena_allocator(&arena)

    run(allocator)    
}

run :: proc(allocator := context.allocator) {
    if !os.exists("build.odin") {
        fatal("build.odin does not exist in the current directory")
    }

    // compile buildfile, build system package is placed in ODIN_ROOT:shared
    exitcode := libc.system(fmt.ctprint("odin run "))
}

fatal :: proc(args: ..any) -> ! {
    log.fatal(..args)
    os.exit(1)
}
