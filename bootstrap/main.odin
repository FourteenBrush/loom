package bootstrap

import "core:os"
import "core:log"
import "core:mem"
import "core:flags"

foreign import posix "system:posix"

foreign posix {
    execlp :: proc(file: cstring, arg: cstring, #c_vararg args: ..cstring) -> i32 --- // zero-terminated args
}

main :: proc() {
    context.logger = log.create_console_logger(.Debug when ODIN_DEBUG else .Warning, {})
    for &header in log.Level_Headers {
        header = header[:len(header) - len("--- ")]
    }

    log.debug("build system main")

    arena: mem.Dynamic_Arena
    mem.dynamic_arena_init(&arena)
    defer mem.dynamic_arena_destroy(&arena)
    allocator := mem.dynamic_arena_allocator(&arena)

    run(allocator)    
}

BuildArgs :: struct {
    install_prefix: string `args="name=prefix"`,
}

run :: proc(allocator := context.allocator) {
    args: BuildArgs
    flags.parse_or_exit(&args, os.args)

    if !os.exists("build.odin") {
        fatal("build.odin does not exist in the current directory")
    }

    // compile buildfile, build system package is placed in ODIN_ROOT/shared
    // pass location of buildfile 
    //exitcode := libc.system(fmt.ctprint("odin run "))
}

fatal :: proc(args: ..any) -> ! {
    log.fatal(..args)
    os.exit(1)
}
