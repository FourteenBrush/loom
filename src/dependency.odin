package grumm

import "core:os"
import "core:fmt"
import "core:log"
import "core:c/libc"
import "core:strings"
import "core:path/filepath"

// FIXME: define ways how to build a dependency? (in case of compiled code)
Dependency :: struct {
    name:    string,
    variant: DependencyVariant,
}

@(private)
DependencyVariant :: union {
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

// FIXME: maybe have a const and non const variant, with comptime validation on the former

// odinfmt: disable
// Inputs:
//  - name: the name of the underlying collection going to be defined in the source code
add_code_source :: proc(name: string, opts := CodeSourceOptions{}) {
    if name in g_build_info.dependencies {
        fmt.eprintln("Duplicate dependency", name)
        os.exit(DUPLICATED_DEPENDENCY)
    }
    g_build_info.dependencies[name] = Dependency {
        name = name,
        variant = CodeSource { opts = opts },
    }
}

// Inputs:
//  - name: the name of the underlying collection going to be defined in the source code
add_git_submodule :: proc(name: string, url: string, opts := GitSubmoduleOptions{}) {
    if name in g_build_info.dependencies {
        fmt.eprintln("Duplicate dependency", name)
        os.exit(DUPLICATED_DEPENDENCY)
    }
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

        if variant.url == "" {
            return fmt.tprintf("Dependency %s does not have its git url set")
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
        
        // ensure only one of {branch, tag, commit} is set
        opts := [?]string{variant.branch, variant.tag, variant.commit}
        opt_set := -1

        for opt, i in opts {
            if opt_set != -1 && opt != "" {
                switch opt_set {
                case 0: return fmt.tprintfln("Dependency %s has its git branch set, and must not have a tag or commit set", name)
                case 1: return fmt.tprintfln("Dependency %s has its git tag set, and must not have a branch or commit set", name)
                case 2: return fmt.tprintfln("Dependency %s has its git commit set, and must not have a branch or tag set", name)
                }
            }
            if opt != "" {
                opt_set = i
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
    for name, dep in g_build_info.dependencies {
        submodule := dep.variant.(GitSubmodule) or_continue
        if is_dependency_present(install_dir, name) {
            log.debugf("Dependency %s is present and does not need to be cloned", name)
            continue
        }

        sb := strings.builder_make(context.temp_allocator)
        strings.write_string(&sb, "git clone --quiet ")

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
        log.debug(commandline)

        if exitcode := libc.system(commandline); exitcode != 0 {
            return fmt.tprintf(
                "Dependency %s: failed cloning repo with url %s and commandline %s",
                name, submodule.url, commandline,
            )
        }

        if submodule.commit != "" {
            // reset dependency to specific commit
            exitcode := libc.system(fmt.ctprintf("git checkout --no-overlay --quiet %s -- %s", submodule.commit, submodule.install_path))
            if exitcode != 0 {
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
