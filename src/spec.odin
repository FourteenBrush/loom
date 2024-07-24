package grumm

Build :: struct {
    src_path: string,
    out_path: string,
    type: OdinCommand,
    flags: Flags,
    vet_flags: VetFlags,
    timings: Timings,
    opt: OptimizationMode,
	deps: [dynamic]Dependency,
}

Dependency :: struct {
	// url and local_dir are mutually exclusive.
	url: string,
	local_dir: string,
}
