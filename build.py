#!/bin/python3

import os
from os import path
import sys
import subprocess
import configparser

GIT_URL = 'https://github.com/FourteenBrush/grumm.git'

# summary
# bootstrap build system
# call odin compiler on the build file
# build file pulls in build system dependency
# build file asks it to compile itself
# build system may decide that files are up to date and no build has to be
# performed, à la mtime or file hash comparison
def main():
    build_sys_dir = path.join(os.getcwd(), 'dependencies', 'grumm')
    if not path.exists(build_sys_dir):
        exitcode = bootstrap_build_sys(build_sys_dir)
        ensure(exitcode == 0, f'Failed bootstrapping build system with exit code {exitcode}')

    ensure(path.exists('build.odin'), 'Cannot find build file build.odin in current directory')

    # call into buildfile
    # FIXME: can't we do an execve, do we really need to return?
    exitcode = subprocess.call(['odin', 'run', 'build.odin', '-file', '-out=out'] + sys.argv[1:])
    ensure(exitcode == 0, f'Build exited with exit code {exitcode}')

def bootstrap_build_sys(build_sys_dir: str) -> int:
    if has_build_submodule():
        print('Pulling build system through Git submodule')
        return os.system('git submodule update --init --remote --merge')
    else:
        print('Cloning build system')
        cmd = f'git clone {GIT_URL} --filter=blob:none --recurse-submodules --branch=main {build_sys_dir}'
        return os.system(cmd)

def ensure(cond: bool, err: str):
    sys.exit(err) if not cond else None

# git config -f .gitmodules --get 'submodule.dependencies/grumm.url' 
def has_build_submodule() -> bool:
    expected_url = 'https://github.com/FourteenBrush/grumm.git'
    config = configparser.ConfigParser()
    config.read('.gitmodules')

    return any(config[section].get('url') == expected_url for section in config.sections())

if __name__ == '__main__':
    main()
