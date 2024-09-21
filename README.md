# LOOM

A work in progress Odin build system

Loom will consist of two parts, that when combined are able to build a project:
1. A system command that invokes the build system
2. The build system itself, which is a loader and wrapper around a user-written build file

## GOALS

- Deterministic builds based off the same build file
- Build cache (maybe even incremental builds)
- Fetching of either local dependencies or git based ones

## Design

- Dependency that defines build system API, defined in shared:loom
- Loader code that wraps around build invocation

## Steps of execution

- Call loom build
- Bootstrap takes place to compile build file (if necessary), together with loader code (dependency)
- Build system main() gets called, initializes itself and calls build()
- build() finishes configuration phase and build system performs actual work

## Phases overview (analogue to steps of execution)

- Bootstrap phase (API dependency needed), build file compilation and initialization
- Configuration phase, build() gets called
- Execution phase, actual compilation
