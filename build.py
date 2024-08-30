#!/usr/bin/env python

import os
from os import path
import sys
import argparse
import subprocess
import configparser

GITHUB_URL = 'https://github.com/FourteenBrush/grumm.git'

# summary
# bootstrap build system
# call odin compiler on the build file
# build file pulls in build system dependency
# build file asks it to compile itself
# build system may decide that files are up to date and no build has to be
# performed, à la mtime or file hash comparison
def main():
    global verbose

    args = parse_args()
    verbose = args.verbose
    print(args)

    if args.update_self:
        update_self()
        return

    exitcode = bootstrap_build_sys(args.install_path)
    ensure(exitcode == 0, f'Failed bootstrapping build system with exit code {exitcode}')

    ensure(path.exists(args.build_file), f'Cannot find build file {args.build_file} in current directory')
    ensure(path.splitext(args.build_file)[1] == '.odin', 'Build file must have an .odin extension')

    # ensure out dir exists, odin compiler doesn't want to generate it itself
    os.makedirs(args.output_path, exist_ok=True)

    # FIXME: can't we do an execve, do we really need to return?
    compiler_argv = [
        'odin', 'run', args.build_file,
        '-file', '-o:none', '-use-separate-modules',
        f'-out:{args.output_path}/buildfile',
    ]

    compiler_argv.extend(
        f'-define:GRUMM_{prop.upper()}={value}'
        for prop, value in vars(args).items()
        if value and prop in ['install_path', 'output_path']
    )

    exitcode = subprocess.call(compiler_argv)
    ensure(exitcode == 0, f'Build exited with exit code {exitcode}')


# WARNING: defaults must be kept in sync with buildsystem
class BuildArgs(argparse.Namespace):
    build_file = 'build.odin'
    install_path = 'dependencies'
    output_path = 'out'
    update_self: bool
    verbose: bool


def parse_args() -> BuildArgs:
    """Exits if parsing failed"""
    parser = argparse.ArgumentParser(allow_abbrev=False)

    # TODO: rethink this design of defining some options twice
    parser.add_argument('--build-file',   dest='build_file',   metavar='file', help="The location of the build file, standard build.odin")
    parser.add_argument('--update-self',  dest='update_self',  action='store_true', help='Updates the build system')
    parser.add_argument('--install-path', dest='install_path', metavar='path', help='The path where dependencies will be installed')
    parser.add_argument('--output-path',  dest='output_path',  metavar='path', help='The path where any build artifacts will be located')
    parser.add_argument('--verbose', action='store_true', help='Be verbose')

    # FIXME: is there to way to let the parser assign to snakecase variable names by default
    # avoid writing a dest=name without _ in every argument

    # TODO: parser.parse_known_args() and pass remaining args the build script (sys.argv[1:])
    return parser.parse_args(namespace=BuildArgs())


def update_self():
    pass # TODO


def bootstrap_build_sys(install_path: str) -> int:
    build_sys_dir = path.join(os.getcwd(), install_path, 'grumm')
    if path.exists(build_sys_dir): return 0

    # TODO: do we really need a distinct case apart from just git cloning?
    # also what do we do with the .git folder if not a submodule?
    if has_build_submodule():
        cmd = 'git submodule update --init --remote --merge'
        log('Pulling build system through git submodule')
    else:
        cmd = f'git clone {GITHUB_URL} --filter=blob:none --recurse-submodules --branch=main {build_sys_dir}'
        log('Cloning build system')

    return subprocess.call(cmd)


# git config -f .gitmodules --get 'submodule.dependencies/grumm.url' 
def has_build_submodule() -> bool:
    config = configparser.ConfigParser()
    config.read('.gitmodules')

    return any(config[section].get('url') == GITHUB_URL for section in config.sections())

def log(msg: str):
    print(msg) if verbose else None

def ensure(cond: bool, err: str):
    sys.exit(err) if not cond else None


if __name__ == '__main__':
    main()
