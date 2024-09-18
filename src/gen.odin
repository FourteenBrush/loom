package grumm

import "core:os"
import "core:fmt"
import "core:log"
import "core:c/libc"
import "core:strings"
import "core:path/filepath"

// odinfmt: disable
VERIFICATION_FAILED     :: 1
ODIN_INVOCATION_FAILED  :: 2
INSTALLATION_FAILED     :: 3
DUPLICATED_DEPENDENCY   :: 4
DEFAULT_INSTALL_DIR     :: "dependencies"
// odinfmt: enable

odin_invocation :: proc(build: ^Build, allocator := context.allocator) {
	context.logger = log.create_console_logger(.Debug when ODIN_DEBUG else .Warning)
	defer log.destroy_console_logger(context.logger)

    if err := verify_build(build^); err != "" {
        fmt.eprintln(err)
        os.exit(VERIFICATION_FAILED)
    }

	// FIXME: apply to build immediately before verification
	if build.install_dir == "" {
		build.install_dir = DEFAULT_INSTALL_DIR
	}

    if err := install_missing_dependencies(build.install_dir); err != "" {
        fmt.eprintln(err)
        os.exit(INSTALLATION_FAILED)
    }

	cmdline := build_invocation(build^, allocator)
	if build.print_odin_invocation {
		fmt.println(cmdline)
	}

	// TODO: execve instead of system
	if exitcode := libc.system(cmdline); exitcode != 0 {
		// odin will have printed to stderr
		os.exit(ODIN_INVOCATION_FAILED)
	}
}

// extra options computed from the users build configuration
@(private)
BuildInfo :: struct {
	self_contained_package: bool,
	dependencies:           map[string]Dependency,
	collections:            [dynamic]Collection,
}

@(private)
g_build_info: BuildInfo

// odinfmt: disable
@(private)
verify_build :: proc(
    build: Build,
    allocator := context.allocator,
) -> ErrorMsg {
    self_contained, ok := verify_src_path(build.src_path, allocator)
    if !ok {
        format := "Source file %s does not exist" if self_contained else "Source files %s do not exist"
        return fmt.tprintln(format, build.src_path)
    }
    g_build_info.self_contained_package = self_contained

    if build.out_filepath == "" {
        return "Build.out_filepath must not be empty"
    }

    if build.timings_export.format != .None {
        if build.timings_export.output_file == "" {
            return "Build.timings_export.output_file must be set when format is set"
        }
        if build.timings_export.mode == .Disabled {
            return "Build.timings_export.mode must not be disabled when format is set"
        }
    } else if build.timings_export.output_file != "" {
        return "Build.timings_export.output_file must not be set when format is none"
    }

    if build.dependencies_export.format != .None {
        if build.dependencies_export.output_file == "" {
            return "Build.dependencies_export.output_file must be set when format is set"
        }
    } else if build.dependencies_export.output_file != "" {
        return "Build.dependencies_export.output_file must be set when output file is set"
    }

    if build.subtarget != .None && (build.target == .DarwinAmd64 || build.target == .DarwinArm64) {
        return "Build.subtarget can only be used with darwin based targets at the moment"
        // ignore a possible minimum_os_version being set, just like the compiler does, will still emit a linker warning
    }

    // FIXME: we may want to apply verification to arch specific flags

    return verify_dependencies(build.install_dir, allocator)
}
// odinfmt: enable

@(private)
verify_src_path :: proc(
	src: string,
	allocator := context.allocator,
) -> (
	self_contained, ok: bool,
) {
	stat, errno := os.stat(src, allocator)
	if errno != nil {
		// fallback to make caller able to provide a more accurate error message
		self_contained = filepath.ext(src) == ".odin"
		return
	}

	defer os.file_info_delete(stat, allocator)
	return !stat.is_dir, true
}

@(private)
build_invocation :: proc(build: Build, allocator := context.allocator) -> cstring {
	sb := strings.builder_make(0, 512, allocator)
	fmt.sbprint(&sb, "odin build ")

	fmt.sbprintf(&sb, "%s ", build.src_path)
	if g_build_info.self_contained_package {
		fmt.sbprint(&sb, "-file ")
	}

	// if not set assumes current directory
	if build.out_filepath != "" {
		fmt.sbprintf(&sb, "-out:%s ", build.out_filepath)
	}
	
    // odinfmt: disable
    switch build.optimization {
    case .None:    fmt.sbprint(&sb, "-o:none ")
    case .Minimal: // default
    case .Size:    fmt.sbprint(&sb, "-o:size ")
    case .Speed:   fmt.sbprint(&sb, "-o:speed ")
    }

    timings_export: {
        switch build.timings_export.format {
        case .None:
        case .Json: fmt.sbprint(&sb, "-export-timings:json ")
        case .Csv:  fmt.sbprint(&sb, "-export-dependencies:csv ")
        }

        switch build.timings_export.mode {
        case .Disabled:     break timings_export
        case .Verbose:      fmt.sbprint(&sb, "-show-timings ")
        case .ExtraVerbose: fmt.sbprint(&sb, "-show-more-timings ")
        }

        if build.timings_export.output_file != "" {
            fmt.sbprintf(&sb, "-export-timings-file:%s ", build.timings_export.output_file)
        }
    }

    switch build.dependencies_export.format {
    case .None:
    case .Make: fmt.sbprint(&sb, "-export-dependencies:make ")
    case .Json: fmt.sbprint(&sb, "-export-dependencies:json ")
    }
    // odinfmt: enable

	if build.definables_export_file != "" {
		fmt.sbprintf(&sb, "-export-defineables:%s ", build.definables_export_file)
	}
	
    // odinfmt: disable
    switch build.build_mode {
    case .Exe:       // default
    case .SharedLib: fmt.sbprint(&sb, "-build-mode:shared ")
    case .StaticLib: fmt.sbprint(&sb, "-build-mode:static ")
    case .Obj:       fmt.sbprint(&sb, "-build-mode:obj ")
    case .Assembly:  fmt.sbprint(&sb, "-build-mode:asm ")
    case .LlvmIr:    fmt.sbprint(&sb, "-build-mode:llvm ")
    }
    // odinfmt: enable

	if build.target != .Unspecified {
		fmt.sbprintf(&sb, "-target:%s ", target_to_str[build.target])
	}
    if build.subtarget != .None {
        fmt.sbprintf(&sb, "-subtarget:%s ", build.subtarget)
    }

	if build.minimum_os_version != "" {
		fmt.sbprintf(&sb, "-minimal-os-version:%s ", build.minimum_os_version)
	}

	if build.extra_linker_flags != "" {
		fmt.sbprintf(&sb, "-extra-linker-flags:%s ", build.extra_linker_flags)
	}

	if build.microarch != "" {
		fmt.sbprintf(&sb, "-microarch:%s ", build.microarch)
	}

	if build.target_features != "" {
		fmt.sbprintf(&sb, "-target-features:%s ", build.target_features)
	}
	
    // odinfmt: disable
    switch build.reloc_mode {
    case .Default:
    case .Static:       fmt.sbprint(&sb, "-reloc-mode:static ")
    case .Pic:          fmt.sbprint(&sb, "-reloc-mode:pic ")
    case .DynamicNoPic: fmt.sbprint(&sb, "-reloc-mode:dynamic-no-pic ")
    }

    for sanitization in build.sanitization {
        switch sanitization {
        case .Address: fmt.sbprint(&sb, "-sanitize:address ")
        case .Memory:  fmt.sbprint(&sb, "-sanitize:memory")
        case .Thread:  fmt.sbprint(&sb, "-sanitize:thread ")
        }
    }
    // odinfmt: enable

	if build.thread_count > 0 {
		fmt.sbprintf(&sb, "-thread-count:%d ", build.thread_count)
	}

	if build.error_pos_style == .Unix {
		fmt.sbprint(&sb, "-error-style:unix ")
	}

	if build.max_error_count > 0 {
		fmt.sbprintf(&sb, "-max-error-count:%d ", build.max_error_count)
	}

	for flag in build.flags {
		fmt.sbprintf(&sb, "%s ", flag_to_str[flag])
	}

	for flag in build.vet_flags {
		fmt.sbprint(&sb, vet_flag_to_str[flag], ' ')
	}

	for define in build.defines {
		fmt.sbprintf(&sb, "-define:%s=%v ", define.name, define.value)
	}

	for attrib in build.custom_attributes {
		fmt.sbprintf(&sb, "-custom-attribute:%s ", attrib)
	}

	strings.pop_byte(&sb)
	return strings.to_cstring(&sb)
}
