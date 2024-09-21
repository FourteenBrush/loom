package loom

import "core:fmt"
import "core:strconv"
import "core:encoding/ini"
import "core:path/filepath"

import "base:intrinsics"

BUILDSYS_BASE_DIR :: ".build"
LOCKFILE_NAME :: "dependencies_lock"
LOCKFILE_PATH :: BUILDSYS_BASE_DIR + filepath.SEPARATOR_STRING + LOCKFILE_NAME

// A LockFile represents a snapshot of the list of dependencies.
// For a Git submodule, either a commit, branch or tag is recorded.
// For a code source dir a combination of mtimes and other facts that
// make a build unique (e.g. defineables) are recorded and combined into a hash.
@(private)
LockFile :: struct {
    data:   ini.Map,
}

@(private)
DependencySnapshot :: union {
    CodeSourceSnapshot,
    GitSubmoduleBranch,
    GitSubmoduleTag,
    GitSubmoduleCommit,
}

@(private)
CodeSourceSnapshot :: struct {}

@(private)
GitSubmoduleBranch :: distinct string
@(private)
GitSubmoduleTag :: distinct string
@(private)
GitSubmoduleCommit :: distinct string

@(private)
get_or_create_lock_file :: proc(allocator := context.allocator) -> (file: LockFile, ok: bool) {
    ini_data, _ := ini.load_map_from_path(LOCKFILE_PATH, allocator) or_return

    return LockFile{ini_data}, true
}

@(private)
lockfile_destroy :: proc(file: LockFile) {
    ini.delete_map(file.data)
}

@(private)
discriminant_of :: intrinsics.type_variant_index_of

@(private)
get_dependency_snapshot :: proc(
    lockfile: LockFile,
    dep_name: string,
) -> (
    snapshot: DependencySnapshot,
    ok: bool,
) {
    dep_data := lockfile.data[dep_name] or_return
    type := dep_data["type"] or_return

    discriminant := strconv.parse_uint(type, base = 10) or_return
    switch discriminant {
    case discriminant_of(DependencySnapshot, CodeSourceSnapshot):
        fmt.println("CodeSourceSnapshot")
    case discriminant_of(DependencySnapshot, GitSubmoduleBranch):
        fmt.println("GitSubmoduleBranch")
    case discriminant_of(DependencySnapshot, GitSubmoduleTag):
        fmt.println("GitSubmoduleTag")
    case discriminant_of(DependencySnapshot, GitSubmoduleCommit):
        fmt.println("GitSubmoduleCommit")
    }

    return
}
