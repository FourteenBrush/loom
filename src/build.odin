package loom

import "core:mem"

define_build :: proc(backing_alloc := context.allocator) -> (b: Build) {
    b.allocator = backing_alloc
    b.root_step.name = "root"
    b.root_step.dependencies = make([dynamic]Step, backing_alloc)
    return
}

Build :: struct {
    allocator: mem.Allocator,
    root_step: Step,
}

BuildMode :: enum {
    Exe = 0,
    SharedLib,
    StaticLib,
    Object,
    Assembly,
    LlvmIr,
}

// https://github.com/odin-lang/Odin/blob/cb31df34c199638a03193520e03a59fc722429d2/src/build_settings.cpp#L721
// odinfmt: disable
CompilationTarget :: enum {
    Host,
    DarwinAmd64,
    DarwinArm64,

    EssenceAmd64,

    LinuxI386,
    LinuxAmd64,
    LinuxArm64,
    LinuxArm32,

    WindowsI386,
    WindowsAmd64,

    FreebsdI386,
    FreebsdAmd64,
    FreebsdArm64,

    NetbsdAmd64,
    NetbsdArm64,

    OpenbsdAmd64,
    
    HaikuAmd64,

    FreestandingWasm32,
    WasiWasm32,
    JsWasm32,
    OrcaWasm32,
    FreestandingWasm64p32,
    JsWasm64p32,
    WasiWasm64p32,

    FreestandingAmd64Sysv,
    FreestandingAmd64Win64,
    FreestandingArm64,
    FreestandingArm32,

    Riscv64,
}

CompilationSubTarget :: enum {
    None,
    IOS,
}
// odinfmt: enable

@(private, rodata)
target_to_str := [CompilationTarget]string {
    .Host                   = "",
    .DarwinAmd64            = "darwin_amd64",
    .DarwinArm64            = "darwin_arm64",
    .EssenceAmd64           = "essence_amd64",
    .LinuxI386              = "linux_i386",
    .LinuxAmd64             = "linux_amd64",
    .LinuxArm64             = "linux_arm64",
    .LinuxArm32             = "linux_arm32",
    .WindowsI386            = "windows_i386",
    .WindowsAmd64           = "windows_amd64",
    .FreebsdI386            = "freebsd_i386",
    .FreebsdAmd64           = "freebsd_amd64",
    .FreebsdArm64           = "freebsd_arm64",
    .NetbsdAmd64            = "netbsd_amd64",
    .NetbsdArm64            = "netbsd_arm64",
    .OpenbsdAmd64           = "openbsd_amd64",
    .HaikuAmd64             = "haiku_amd64",
    .FreestandingWasm32     = "freestanding_wasm32",
    .WasiWasm32             = "wasi_wasm32",
    .JsWasm32               = "js_wasm32",
    .OrcaWasm32             = "orca_wasm32",
    .FreestandingWasm64p32  = "freestanding_wasm64p32",
    .JsWasm64p32            = "js_wasm64p32",
    .WasiWasm64p32          = "wasi_wasm64_p32",
    .FreestandingAmd64Sysv  = "freestanding_amd64_sysv",
    .FreestandingAmd64Win64 = "freestanding_amd_64_win64",
    .FreestandingArm64      = "freestanding_arm64",
    .FreestandingArm32      = "freestanding_arm32",
    .Riscv64                = "freestanding_riscv64",
}

RelocMode :: enum {
    Default,
    Static,
    Pic,
    DynamicNoPic,
}

ErrorStyle :: enum {
    // file/path(45:3)
    Odin,
    // file/path:45:3:
    Unix,
}

// FIXME: microarch enum? seems to be specific per target

Flags :: bit_set[Flag]

// SelfContainedPackage (-file) will be implicitly detected from the src_path.
Flag :: enum {
    ShowSystemCalls,
    KeepTempFiles,
    ShowDefineables,
    Debug,
    DisableAssert,
    NoBoundsCheck,
    NoTypeAssert,
    NoCrt,
    NoThreadLocal,
    Lld,
    UseSeparateModules,
    NoThreadedChecker,
    IgnoreUnknownAttributes,
    NoEntryPoint,
    NoRPath,
    StrictTargetFeatures,
    DisableRedZone,
    DynamicMapCalls,
    DisallowDo,
    DefaultToNilAllocator,
    StrictStyle,
    IgnoreWarnings,
    WarningsAsErrors,
    TerseErrors,
    JsonErrors,
    MinLinkLibs,
    ForeignErrorProcedures,
    ObfuscateSourceCodeLocations,
}

@(private, rodata)
flag_to_str := [Flag]string {
    .ShowSystemCalls              = "-show-system-calls",
    .KeepTempFiles                = "-keep-temp-files",
    .ShowDefineables              = "-show-defineables",
    .Debug                        = "-debug",
    .DisableAssert                = "-disable-assert",
    .NoBoundsCheck                = "-no-bounds-check",
    .NoTypeAssert                 = "-no-type-assert",
    .NoCrt                        = "-no-crt",
    .NoThreadLocal                = "-no-thread-local",
    .Lld                          = "-lld",
    .UseSeparateModules           = "-use-separate-modules",
    .NoThreadedChecker            = "-no-threaded-checker",
    .IgnoreUnknownAttributes      = "-ignore-unknown-attributes",
    .NoEntryPoint                 = "-no-entry-point",
    .NoRPath                      = "-no-rpath",
    .StrictTargetFeatures         = "-strict-target-features",
    .DisableRedZone               = "-disable-red-zone",
    .DynamicMapCalls              = "-dynamic-map-calls",
    .DisallowDo                   = "-disallow-do",
    .DefaultToNilAllocator        = "-default-to-nil-allocator",
    .StrictStyle                  = "-strict-style",
    .IgnoreWarnings               = "-ignore-warnings",
    .WarningsAsErrors             = "-warnings-as-errors",
    .TerseErrors                  = "-terse-errors",
    .JsonErrors                   = "-json-errors",
    .MinLinkLibs                  = "-min-link-libs",
    .ForeignErrorProcedures       = "-foreign-error-procedures",
    .ObfuscateSourceCodeLocations = "-obfuscate-source-code-locations",
}

VetFlags :: bit_set[VetFlag]

VetFlag :: enum {
    Vet,
    VetUnused,
    VetUnusedVariables,
    VetUnusedImports,
    VetShadowing,
    VetUsingStmt,
    VetUsingParam,
    VetStyle,
    VetSemicolon,
    VetCast,
    VetTabs,
}

@(private, rodata)
vet_flag_to_str := [VetFlag]string {
    .Vet                = "-vet",
    .VetUnused          = "-vet-unused",
    .VetUnusedVariables = "-vet-unused-variables",
    .VetUnusedImports   = "-vet-unused-imports",
    .VetShadowing       = "-vet-shadowing",
    .VetUsingStmt       = "-vet-using-stmt",
    .VetUsingParam      = "-vet-using-param",
    .VetStyle           = "-vet-style",
    .VetSemicolon       = "-vet-semicolon",
    .VetCast            = "-vet-cast",
    .VetTabs            = "-vet-tabs",
}

TimingsExport :: struct {
    mode:        TimingsExportMode,
    format:      TimingsExportFormat,
    output_file: string,
}

TimingsExportMode :: enum {
    // do not export timings
    Disabled,
    // -show-timings
    Verbose,
    // -show-more-timings
    ExtraVerbose,
}

TimingsExportFormat :: enum {
    // do not export timings
    None,
    Json,
    Csv,
}

DependenciesExport :: struct {
    format:      DependenciesExportFormat,
    output_file: string,
}

DependenciesExportFormat :: enum {
    // do not export dependencies
    None,
    Make,
    Json,
}

OptimizationMode :: enum {
    None       = 1,
    Minimal    = 0,
    Size       = 2,
    Speed      = 3,
    Aggressive = 4,
}

Sanitization :: bit_set[SanitizeMode]

SanitizeMode :: enum {
    Address,
    Memory,
    Thread,
}

Define :: struct {
    name:  string,
    value: union {
        bool,
        int,
        string,
    },
}
