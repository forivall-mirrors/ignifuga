#Copyright (c) 2010-2012, Gabriel Jacobo
#All rights reserved.
#Permission to use this file is granted under the conditions of the Ignifuga Game Engine License
#whose terms are available in the LICENSE file or at http://www.ignifuga.org/license

# Schafer Module: Build Python for OS X (for available architectures see prepare_osx_env)
# Author: Gabriel Jacobo <gabriel@mdqinc.com>

import os, shlex, shutil
from os.path import *
from subprocess import Popen, PIPE
from ..log import log, error
from schafer import prepare_source, make_python_freeze, SED_CMD, PATCHES_DIR
from ..util import get_sdl_flags, get_freetype_flags, get_png_flags
import multiprocessing

def prepare(env, target, options, ignifuga_src, python_build):
    if options.bare:
        if options.baresrc is None:
            ignifuga_module = ''
        else:
            ignifuga_module = "\n%s %s -I%s %s\n" % (options.modulename, ' '.join(ignifuga_src),target.builds.IGNIFUGA, options.baredependencies if options.baredependencies is not None else '')
    else:
        # Get some required flags
        sdlflags = get_sdl_flags(target)
        freetypeflags = get_freetype_flags(target)

        # Patch some problems with cross compilation
        cmd = 'patch -p1 -i %s -d %s' % (join(PATCHES_DIR, 'python.osx.diff'), python_build)
        Popen(shlex.split(cmd)).communicate()

        ignifuga_module = "\nignifuga %s -I%s -I%s -lturbojpeg -lSDL2_ttf -lSDL2_image -lSDL2_mixer -lvorbisfile -lvorbis -logg -lSDL2 -lpng12 -ljpeg %s %s -lstdc++\n" % (' '.join(ignifuga_src),target.builds.IGNIFUGA, join(target.builds.IGNIFUGA, 'spine'), sdlflags, freetypeflags)
    return ignifuga_module

def make(env, target, options, freeze_modules, frozen_file):
    if not isfile(join(target.builds.PYTHON, 'pyconfig.h')) or not isfile(join(target.builds.PYTHON, 'Makefile')):
        if options.bare:
            sdlldflags = sdlcflags = ''
        else:
            cmd = join(target.dist, 'bin', 'sdl2-config' ) + ' --static-libs'
            sdlldflags = Popen(shlex.split(cmd), stdout=PIPE).communicate()[0].split('\n')[0] #.replace('-lpthread', '').replace('-ldl', '') # Removing pthread and dl to make them dynamically bound (req'd for Linux)
            cmd = join(target.dist, 'bin', 'sdl2-config' ) + ' --cflags'
            sdlcflags = Popen(shlex.split(cmd), stdout=PIPE).communicate()[0].split('\n')[0]
        # As static as possible
        cmd = './configure --enable-silent-rules --with-universal-archs=intel --enable-universalsdk LDLAST="-lz" LDFLAGS="-static-libgcc %s" CPPFLAGS="-DBOOST_PYTHON_STATIC_LIB -DBOOST_PYTHON_SOURCE %s" CFLAGS="-DBOOST_PYTHON_STATIC_LIB -DBOOST_PYTHON_SOURCE" LINKFORSHARED=" " DYNLOADFILE="dynload_stub.o" --disable-shared --prefix="%s"'% (sdlldflags,sdlcflags,target.dist,)
        if options.valgrind:
            cmd += ' --with-valgrind'
        Popen(shlex.split(cmd), cwd = target.builds.PYTHON).communicate()
    make_python_freeze('osx', freeze_modules, frozen_file)
    if isfile(join(target.dist, 'lib', 'libpython2.7.a')):
        os.remove(join(target.dist, 'lib', 'libpython2.7.a'))

    # Remove setup.py as its of no use here and it tries to compile a lot of extensions that don't work in static mode
    if isfile(join(target.builds.PYTHON,'setup.py')):
        os.unlink(join(target.builds.PYTHON,'setup.py'))

    cmd = 'make V=0 install -k -j%d' % multiprocessing.cpu_count()
    # Rebuild Python including the frozen modules!
    Popen(shlex.split(cmd), cwd = target.builds.PYTHON, env=env).communicate()

    if not isdir (join(target.dist, 'include', 'Modules')):
        os.makedirs(join(target.dist, 'include', 'Modules'))
    shutil.copy(join(target.builds.PYTHON, 'Modules/greenlet.h'), join(target.dist, 'include', 'Modules', 'greenlet.h'))

    # Check success
    if isfile(join(target.dist, 'lib', 'libpython2.7.a')):
        log('Python built successfully')
    else:
        error('Error building python')
    return True