package loom

import "core:os"
import "core:fmt"
import "core:log"
import "core:c/libc"
import "core:strings"
import "core:path/filepath"

// FIXME: define ways how to build a dependency? (in case of compiled code)

@(private)
Dependency :: union {
    CodeSource,
    GitSubmodule,
}

@(private)
CodeSource :: struct {
    using opts: CodeSourceOptions,
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

// branch, tag and commit are mutually exclusive, as tags behave like commits
// and those are unique accross all branches. A branch being set implies its last commit is to be used.
GitSubmoduleOptions :: struct {
    branch:                string,
    tag:                   string,
    commit:                string,
    // don't recursively fetch submodules
    ignore_submodules:     bool,
    // the path where a Git submodule is supposed to be placed, this must only be specified when this is
    // different from the default path ($Build.install_dir/$dependency_name). Path starts from the project root.
    // TODO: add possibility to simply rename dependency
    install_path:          string,
}

// a processed dependency
@(private)
Collection :: struct {
    name: string,
    path: string,
}

// odinfmt: disable
// Inputs:
//  - name: the name of the underlying collection going to be defined in the source code
add_code_source :: proc(name: string, opts := CodeSourceOptions{}) {
    if name in g_build_info.dependencies {
        fatal("duplicated dependency", name)
    }
    g_build_info.dependencies[name] = CodeSource { opts = opts }
}

// Inputs:
//  - name: the name of the underlying collection going to be defined in the source code
add_git_submodule :: proc(name: string, url: string, opts := GitSubmoduleOptions{}) {
    if name in g_build_info.dependencies {
        fatal("duplicated dependency", name)
    }
    g_build_info.dependencies[name] = GitSubmodule { url = url, opts = opts }
}
// odinfmt: enable

@(private)
verify_dependencies :: proc(install_path: string, allocator := context.allocator) -> (err: string) {
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
    dependency: Dependency,
    install_path: string,
    allocator := context.allocator,
) -> (err: string) {
    if name == "" do return "Empty dependency name"

    if !is_valid_dependency_name(name) {
        return fmt.tprintf(
            "Invalid dependency name '%s', must not include any of " + illegal_name_chars_str,
            name,
        )
    }

    switch dependency in dependency {
    case CodeSource:
        sources_loc := dependency.install_path if dependency.install_path != "" else
            filepath.join({install_path, name}, allocator)

        if !os.is_dir(sources_loc) {
            return fmt.tprintf(
                "Dependency %s could not be found, the directory containing its sources (%s) is missing",
                name, filepath.clean(sources_loc, allocator),
            )
        }
    case GitSubmodule:
        // our best effort to check for valid urls FIXME
        if !strings.contains(dependency.url, ".git") {
            return fmt.tprintf("Dependency %s does not have a valid git url", name)
        }

        if dependency.url == "" {
            return fmt.tprintf("Dependency %s does not have its git url set")
        }

        // ensure only one of {branch, tag, commit} is set
        opts := [?]string{dependency.branch, dependency.tag, dependency.commit}
        opt_set := -1

        for opt, i in opts do if opt != "" {
            if opt_set != -1 {
                switch opt_set {
                case 0: return fmt.tprintfln("Dependency %s has its git branch set, and must not have a tag or commit set", name)
                case 1: return fmt.tprintfln("Dependency %s has its git tag set, and must not have a branch or commit set", name)
                case 2: return fmt.tprintfln("Dependency %s has its git commit set, and must not have a branch or tag set", name)
                }
            }
            opt_set = i
        }

        if dependency.commit != "" {
            hash_len := len(dependency.commit)
            if hash_len < MIN_COMMIT_HAS_LEN || hash_len > MAX_COMMIT_HASH_LEN {
                return fmt.tprintf(
                    "Dependency %s does not have a valid commit hash, length must be between %d and %d",
                    name, MIN_COMMIT_HAS_LEN, MAX_COMMIT_HASH_LEN,
                )
            }

            for _, i in dependency.commit {
                c := dependency.commit[i]
                if c >= 'a' && c <= 'z' || c >= '0' && c <= '9' do continue

                return fmt.tprintf(
                    "Dependency %s does not have its commit match pattern [a-f0-9]{{%d,%d}",
                    name, MIN_COMMIT_HAS_LEN, MAX_COMMIT_HASH_LEN,
                )
            }
        }
    }

    return ""
}
// odinfmt: enable
@(private)
illegal_name_chars_str :: `./\`

MIN_COMMIT_HAS_LEN :: 7
MAX_COMMIT_HASH_LEN :: 40

@(private)
illegal_name_chars := strings.ascii_set_make(illegal_name_chars_str) or_else panic("sanity check")

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
is_dependency_present :: proc(install_dir, name: string) -> bool {
    return os.exists(filepath.join({install_dir, name}, context.temp_allocator))
}

@(private)
install_missing_dependencies :: proc(install_dir: string) -> (err: string) {
    // only consider Git submodules, as code source dirs are verified to exist
    for name, dependency in g_build_info.dependencies {
        submodule := dependency.(GitSubmodule) or_continue
        if is_dependency_present(install_dir, name) {
            log.debugf("Dependency %s is present and does not need to be cloned", name)
            continue
        }

        sb := strings.builder_make(context.temp_allocator)
        strings.write_string(&sb, "git clone -q ")

        switch {
        case submodule.branch != "": fmt.sbprintf(&sb, "-b %s ", submodule.branch)
        case submodule.tag != "":    fmt.sbprintf(&sb, "-b %s ", submodule.tag)
        }

        if submodule.ignore_submodules {
            strings.write_string(&sb, "--ignore-submodules ")
        }

        if submodule.install_path == "" {
            submodule.install_path = filepath.join({install_dir, name}, context.temp_allocator)
        }

        fmt.sbprintf(&sb, "%s %s", submodule.url, submodule.install_path)

        commandline := strings.to_cstring(&sb)
        log.debugf("Cloning submodule %s with git invocation %d", name, commandline)

        if exitcode := libc.system(commandline); exitcode != 0 {
            return fmt.tprintf(
                "Dependency %s: failed cloning repo with url %s and commandline %s",
                name, submodule.url, commandline,
            )
        }

        if submodule.commit != "" {
            // reset dependency to specific commit
            commandline := fmt.ctprintf("git checkout --no-overlay --quiet %s -- %s", submodule.commit, submodule.install_path)
            if exitcode := libc.system(commandline); exitcode != 0 {
                return fmt.tprintf(
                    "Dependency %s: successfully cloned repo but checking out commit %s failed",
                    name, submodule.commit,
                )
            }
        }

        log.infof("Cloned git repo %s", submodule.url)
    }

    return
}
