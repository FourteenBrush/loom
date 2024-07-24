package grumm

// Structures as defined in the `odin build` or `odin check` command.

OdinCommand :: enum {
    Build,
    Check,
}

Flags :: bit_set[Flag]

Flag :: enum {
	SelfContainedPackage,
	ShowTimings,
	ShowMoreTimings,
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

Timings :: struct {
    mode: TimingsMode,
    format: TimingsFormat,
    output_file: string,
}

TimingsMode :: enum {
    Disabled,
    Verbose,
    ExtraVerbose,
}

TimingsFormat :: enum {
    Json,
    Csv,
}

OptimizationMode :: enum {
	None,
	Minimal,
	Size,
	Speed,
}

BuildMode :: enum {
    Exe,
    Dll,
    Shared,
    Lib,
    Static,
    Obj,
    Assembly,
    LlvmIr,
}

Sanitization :: bit_set[SanitizeMode]

SanitizeMode :: enum {
	Address,
	Memory,
	Thread,
}
