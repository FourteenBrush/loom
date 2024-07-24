package grumm

import "core:strings"

odin_invocation :: proc(build: Build, allocator := context.allocator) {
    cmd := "build" if build.type == .Build else "check"
    args := build_odin_args(build, allocator)
    

}

build_odin_args :: proc(build: Build, allocator := context.allocator) -> string {
    sb := strings.builder_make(allocator)

    return strings.to_string(sb)
}
