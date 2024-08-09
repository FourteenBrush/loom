#!/usr/bin/env python3

import os
from os import path
import sys
import subprocess
import configparser

# dependencies design
# local path / github url
# 

GIT_URL = 'https://github.com/FourteenBrush/grumm.git'

# summary
# bootstrap build system
# call odin compiler on the build file
# build file pulls in build system dependency
# build file asks it to compile itself
# build system may decide that files are up to date and no build has to be
# performed, à la mtime or file hash comparison
def main():
    exitcode = bootstrap_build_sys()
    ensure(exitcode == 0, f'Failed bootstrapping build system with exit code {exitcode}')

    ensure(path.exists('build.odin'), 'Cannot find build file build.odin in current directory')

    # call into buildfile
    # FIXME: can't we do an execve, do we really need to return?
    exitcode = subprocess.call(
        ['odin', 'run', 'build.odin', '-file', '-out=out/buildfile', '-use-separate-modules', '-o=none'] + sys.argv[1:],
    )
    ensure(exitcode == 0, f'Build exited with exit code {exitcode}')


def bootstrap_build_sys() -> int:
    # FIXME: make path overridable
    build_sys_dir = path.join(os.getcwd(), 'dependencies', 'grumm')
    if path.exists(build_sys_dir): return 0

    # TODO: do we really need a distinct case apart from just git cloning?
    if has_build_submodule():
        print('Pulling build system through Git submodule')
        cmd = 'git submodule update --init --remote --merge'
    else:
        print('Cloning build system')
        cmd = f'git clone {GIT_URL} --filter=blob:none --recurse-submodules --branch=main {build_sys_dir}'

    return subprocess.call(cmd)

# git config -f .gitmodules --get 'submodule.dependencies/grumm.url' 
def has_build_submodule() -> bool:
    expected_url = 'https://github.com/FourteenBrush/grumm.git'
    config = configparser.ConfigParser()
    config.read('.gitmodules')

    return any(config[section].get('url') == expected_url for section in config.sections())

def ensure(cond: bool, err: str):
    sys.exit(err) if not cond else None


if __name__ == '__main__':
    main()
