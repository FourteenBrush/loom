package loom

import "core:os"
import "core:fmt"
import "core:mem"
import "core:c/libc"
import "core:strings"
import "core:path/filepath"

DEFAULT_INSTALL_DIR :: "dependencies"

// default compilation types
@(private)
ExecutionType :: enum {
    Check,
    Build,
    Run,
}

@(private)
resolve_compile_step :: proc(config: ^BuildConfig, type: ExecutionType, allocator: mem.Allocator) {
	//context.logger = log.create_console_logger(.Debug when ODIN_DEBUG else .Warning)
	//defer log.destroy_console_logger(context.logger)

	if err := verify_build(config); err != "" {
		fatal(err)
	}

	// FIXME: apply to build immediately before verification
	if config.install_dir == "" {
		config.install_dir = DEFAULT_INSTALL_DIR
	}

	if err := install_missing_dependencies(config^); err != "" {
		fatal(err)
	}

	commandline := build_invocation(config^, allocator)
	if config.print_odin_invocation {
        info(commandline)
	}

	if exitcode := libc.system(commandline); exitcode != 0 {
		// odin will have printed to stderr
        os.exit(1)
	}
}

// odinfmt: disable
@(private)
verify_build :: proc(
    config: ^BuildConfig,
    allocator := context.allocator,
) -> (err: string) {
    self_contained, ok := verify_src_path(config.src_path, allocator)
    if !ok {
        format := "Source file %s does not exist" if self_contained else "Source files %s do not exist"
        return fmt.tprintln(format, config.src_path)
    }
    config._self_contained_package = self_contained

    if config.out_filepath == "" {
        return "BuildConfig.out_filepath must not be empty"
    }

    if config.timings_export.format != .None {
        if config.timings_export.output_file == "" {
            return "BuildConfig.timings_export.output_file must be set when format is set"
        }
        if config.timings_export.mode == .Disabled {
            return "BuildConfig.timings_export.mode must not be disabled when format is set"
        }
    } else if config.timings_export.output_file != "" {
        return "BuildConfig.timings_export.output_file must not be set when format is none"
    }

    if config.dependencies_export.format != .None {
        if config.dependencies_export.output_file == "" {
            return "BuildConfig.dependencies_export.output_file must be set when format is set"
        }
    } else if config.dependencies_export.output_file != "" {
        return "BuildConfig.dependencies_export.output_file must be set when output file is set"
    }

    if config.subtarget != .None && (config.target == .DarwinAmd64 || config.target == .DarwinArm64) {
        return "BuildConfig.subtarget can only be used with darwin based targets at the moment"
        // ignore a possible minimum_os_version being set, just like the compiler does, will still emit a linker warning
    }

    // FIXME: we may want to apply verification to arch specific flags

    return verify_dependencies(config^, allocator)
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

	os.file_info_delete(stat, allocator)
	return !stat.is_dir, true
}

// TODO: os and build mode specific out filename extensions
@(private)
build_invocation :: proc(config: BuildConfig, allocator := context.allocator) -> cstring {
	sb := strings.builder_make(0, 512, allocator)
	fmt.sbprint(&sb, "odin build ")

	fmt.sbprintf(&sb, "%s ", config.src_path)
	if config._self_contained_package {
		fmt.sbprint(&sb, "-file ")
	}

	// if not set assumes current directory
	if config.out_filepath != "" {
		fmt.sbprintf(&sb, "-out:%s ", config.out_filepath)
	}
	
    // odinfmt: disable
    switch config.optimization {
    case .None:       fmt.sbprint(&sb, "-o:none ")
    case .Minimal:    // default
    case .Size:       fmt.sbprint(&sb, "-o:size ")
    case .Speed:      fmt.sbprint(&sb, "-o:speed ")
    case .Aggressive: fmt.sbprint(&sb, "-o:aggressive ")
    }

    timings_export: {
        switch config.timings_export.format {
        case .None:
        case .Json: fmt.sbprint(&sb, "-export-timings:json ")
        case .Csv:  fmt.sbprint(&sb, "-export-dependencies:csv ")
        }

        switch config.timings_export.mode {
        case .Disabled:     break timings_export
        case .Verbose:      fmt.sbprint(&sb, "-show-timings ")
        case .ExtraVerbose: fmt.sbprint(&sb, "-show-more-timings ")
        }

        if config.timings_export.output_file != "" {
            fmt.sbprintf(&sb, "-export-timings-file:%s ", config.timings_export.output_file)
        }
    }

    switch config.dependencies_export.format {
    case .None:
    case .Make: fmt.sbprint(&sb, "-export-dependencies:make ")
    case .Json: fmt.sbprint(&sb, "-export-dependencies:json ")
    }
    // odinfmt: enable

	if config.definables_export_file != "" {
		fmt.sbprintf(&sb, "-export-defineables:%s ", config.definables_export_file)
	}
	
    // odinfmt: disable
    switch config.build_mode {
    case .Exe:       // default
    case .SharedLib: fmt.sbprint(&sb, "-build-mode:shared ")
    case .StaticLib: fmt.sbprint(&sb, "-build-mode:static ")
    case .Object:    fmt.sbprint(&sb, "-build-mode:obj ")
    case .Assembly:  fmt.sbprint(&sb, "-build-mode:asm ")
    case .LlvmIr:    fmt.sbprint(&sb, "-build-mode:llvm ")
    }
    // odinfmt: enable

	if config.target != .Host {
		fmt.sbprintf(&sb, "-target:%s ", target_to_str[config.target])
	}
	if config.subtarget != .None {
		fmt.sbprintf(&sb, "-subtarget:%s ", config.subtarget)
	}

	if config.minimum_os_version != "" {
		fmt.sbprintf(&sb, "-minimal-os-version:%s ", config.minimum_os_version)
	}

	if config.extra_linker_flags != "" {
		fmt.sbprintf(&sb, "-extra-linker-flags:%s ", config.extra_linker_flags)
	}

	if config.microarch != "" {
		fmt.sbprintf(&sb, "-microarch:%s ", config.microarch)
	}

	if config.target_features != "" {
		fmt.sbprintf(&sb, "-target-features:%s ", config.target_features)
	}
	
    // odinfmt: disable
    switch config.reloc_mode {
    case .Default:
    case .Static:       fmt.sbprint(&sb, "-reloc-mode:static ")
    case .Pic:          fmt.sbprint(&sb, "-reloc-mode:pic ")
    case .DynamicNoPic: fmt.sbprint(&sb, "-reloc-mode:dynamic-no-pic ")
    }

    for sanitization in config.sanitization {
        switch sanitization {
        case .Address: fmt.sbprint(&sb, "-sanitize:address ")
        case .Memory:  fmt.sbprint(&sb, "-sanitize:memory ")
        case .Thread:  fmt.sbprint(&sb, "-sanitize:thread ")
        }
    }
    // odinfmt: enable

	if config.thread_count > 0 {
		fmt.sbprintf(&sb, "-thread-count:%d ", config.thread_count)
	}

	if config.error_pos_style == .Unix {
		fmt.sbprint(&sb, "-error-style:unix ")
	}

	if config.max_error_count > 0 {
		fmt.sbprintf(&sb, "-max-error-count:%d ", config.max_error_count)
	}

	for flag in config.flags {
		fmt.sbprintf(&sb, "%s ", flag_to_str[flag])
	}

	for flag in config.vet_flags {
		fmt.sbprint(&sb, vet_flag_to_str[flag], ' ')
	}

    if config.vet_packages != "" {
        fmt.sbprint(&sb, "-vet-packages:%s ", config.vet_packages)
    }

	for define in config.defines {
		fmt.sbprintf(&sb, "-define:%s=%v ", define.name, define.value)
	}

	for attrib in config.custom_attributes {
		fmt.sbprintf(&sb, "-custom-attribute:%s ", attrib)
	}

	strings.pop_byte(&sb)
	return strings.to_cstring(&sb)
}

// TODO: logger cannot be initialized because build system does not act as the entrypoint
// but as a dependency that gets called into, so we cannot modify the context of the higher
// stackframe, convert this back to a logger when this gets fixed

@(private)
info :: proc(args: ..any) {
    fmt.println(..args)
}

@(private)
warn :: proc(args: ..any) {
    dest := make([]any, len(args) + 1, context.temp_allocator)
    copy(dest[1:], args[:])
    dest[0] = "warning:"
    fmt.println(args=dest)
}

@(private)
fatal :: proc(args: ..any) -> ! {
    fmt.eprintln(..args)
    os.exit(1)
}
