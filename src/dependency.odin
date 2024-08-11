package grumm

import "core:os"
import "core:fmt"
import "core:c/libc"
import "core:strings"
import "core:path/filepath"

// TODO: dependencies installation dir
// TODO: allow optional dependencies?
// TODO: define ways how to build a dependency? (in case of compiled code)
Dependency :: struct {
    name:    string,
    variant: DependencyVariant,
}

DependencyVariant :: union {
    CodeSource,
    GitSubmodule,
}

@(private)
CodeSource :: struct {
    using opts: CodeSourceOptions,
}

duck := Dependency {
    name = "duck",
    variant = CodeSource {
        install_path = "dependencies/duckdb",
    },
}

CodeSourceOptions :: struct {
    // the path where a code source dir is located, this must only be specified when this is
    // different from the default path ($Build.install_dir/$dependency_name). For example when a
    // dependency lives in another folder than its name. Path starts from the project root.
    install_path: string,
}

@(private)
GitSubmodule :: struct {
    url:        string,
    using opts: GitSubmoduleOptions,
}

GitSubmoduleOptions :: struct {
    branch:                string,
    tag:                   string,
    commit:                string,
    // don't recursively fetch submodules
    ignore_submodules:     bool,
    // the path where a Git submodule is supposed to be placed, this must only be specified when this is
    // different from the default path ($Build.install_dir/$dependency_name). Path starts from the project root.
    install_path: string,
}

// a processed dependency
@(private)
Collection :: struct {
    name: string,
    path: string,
}

// odinfmt: disable
// Params:
//  - name: the name of the underlying collection going to be defined in the source code
add_code_source :: proc(name: string, opts := CodeSourceOptions{}) {
    fmt.assertf(name not_in g_build_info.dependencies, "duplicate dependency %s", name)
    g_build_info.dependencies[name] = Dependency {
        name = name,
        variant = CodeSource { opts = opts },
    }
}

// Params:
//  - name: the name of the underlying collection going to be defined in the source code
add_git_submodule :: proc(name: string, url: string, opts := GitSubmoduleOptions{}) {
    fmt.assertf(name not_in g_build_info.dependencies, "duplicate dependency %s", name)
    g_build_info.dependencies[name] = Dependency {
        name = name,
        variant = GitSubmodule { url = url, opts = opts },
    }
}
// odinfmt: enable

@(private)
verify_dependencies :: proc(install_path: string, allocator := context.allocator) -> ErrorMsg {
    for name, dependency in g_build_info.dependencies {
        err := verify_dependency(name, dependency, install_path, allocator)
        if err != "" do return err
    }

    return ""
}

// odinfmt: disable
@(private)
verify_dependency :: proc(
    name: string,
    dep: Dependency,
    install_path: string,
    allocator := context.allocator,
) -> ErrorMsg {
    if name == "" do return "Empty dependency name"

    if !is_valid_dependency_name(name) {
        return fmt.tprintf(
            "Invalid dependency name '%s', must not include any of " + illegal_name_chars_str,
            name,
        )
    }

    switch variant in dep.variant {
    case CodeSource:
        sources_loc := variant.install_path if variant.install_path != "" \
            else filepath.join({install_path, dep.name}, allocator)

        if !os.is_dir(sources_loc) {
            return fmt.tprintf(
                "Dependency %s could not be found, the directory containing its sources (%s) is missing",
                name, filepath.clean(sources_loc, allocator),
            )
        }
    case GitSubmodule:
        // our best effort to check for valid urls FIXME
        if !strings.contains(variant.url, ".git") {
            return fmt.tprintf("Dependency %s does not have a valid git url", name)
        }

        if variant.commit != "" {
            hash_len := len(variant.commit)
            if hash_len < min_commit_hash_len || hash_len > max_commit_hash_len {
                return fmt.tprintf(
                    "Dependency %s does not have a valid commit hash, length must be between %d and %d",
                    name, min_commit_hash_len, max_commit_hash_len,
                )
            }

            for _, i in variant.commit {
                c := variant.commit[i]
                if c >= 'a' && c <= 'z' || c >= '0' && c <= '9' do continue

                return fmt.tprintf(
                    "Dependency %s does not have its commit match pattern [a-f0-9]{{%d,%d}",
                    name, min_commit_hash_len, max_commit_hash_len,
                )
            }
        }
    }

    return ""
}
// odinfmt: enable

@(private)
illegal_name_chars_str :: `./\`

@(private)
min_commit_hash_len :: 7
@(private)
max_commit_hash_len :: 40

// cannot assign multi value expression to globals
@(private)
illegal_name_chars := get_illegal_name_chars()

@(private)
get_illegal_name_chars := proc() -> strings.Ascii_Set {
    set, ok := strings.ascii_set_make(illegal_name_chars_str)
    assert(ok, "sanity check")
    return set
}

@(private)
is_valid_dependency_name :: proc(name: string) -> bool {
    for _, i in name {
        if strings.ascii_set_contains(illegal_name_chars, name[i]) {
            return false
        }
    }
    return true
}

@(private)
is_dependency_present :: proc(install_path, name: string) -> bool {
    return os.exists(filepath.join({install_path, name}, context.temp_allocator))
}

@(private)
install_missing_dependencies :: proc(install_path: string) -> (err: string) {
    // only consider Git submodules, as code source dirs are verified to exist
    for name, dep in g_build_info.dependencies {
        variant := dep.variant.(GitSubmodule) or_continue
        if !is_dependency_present(install_path, name) {

        }
    }
    return
}

// odinfmt: disable
@(private)
resolve_dependency :: proc(dep: Dependency) -> (err: string) {
    switch variant in dep.variant {
    case CodeSource:
        append(&g_build_info.collections, Collection {
            name = dep.name,
            path = variant.path,
        })
    case GitSubmodule:
        // TODO: access lockfile for previous versions
        branch_opt: string
        switch {
        case variant.branch != "": branch_opt = variant.branch
        case variant.tag != "": branch_opt = variant.tag
        case variant.commit != "": branch_opt = variant.commit
        case: return // dependency is locked to this point
        }

        // clone if necessary (target isn't hardcoded and target is the same for atleast two runs)
        commandline := fmt.ctprintf("git clone --depth 1 -b %s %s", branch_opt, variant.url)
        if exitcode := libc.system(commandline); exitcode != 0 {
            return fmt.tprintf("Git clone failed with exitcode %d for dependency %s", exitcode, dep.name)
        }
    }
    return ""
}
// odinfmt: enable
