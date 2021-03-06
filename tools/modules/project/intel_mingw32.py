#Copyright (c) 2010-2012, Gabriel Jacobo
#All rights reserved.
#Permission to use this file is granted under the conditions of the Ignifuga Game Engine License
#whose terms are available in the LICENSE file or at http://www.ignifuga.org/license

# Schafer Module: Build Project for Win 32 using mingw
# Author: Gabriel Jacobo <gabriel@mdqinc.com>

import os, shlex, shutil
from os.path import *
from subprocess import Popen, PIPE
from ..log import log, error
from schafer import prepare_source, make_python_freeze
from ..util import get_sdl_flags, get_freetype_flags, get_png_flags

def make(options, env, target, sources, cython_src, cfiles):
    # Get some required flags
    extralibs = "-lodbc32 -lwinspool -lwinmm -lshell32 -lcomctl32 -lctl3d32 -lodbc32 -ladvapi32 -lopengl32 -lglu32 -lole32 -loleaut32 -luuid -lgdi32 -limm32 -lversion"

    if options.bare:
        cmd = '%s -Wl,--no-export-dynamic -static-libgcc -static -DMS_WIN32 -DMS_WINDOWS -DHAVE_USABLE_WCHAR_T %s -I%s -I%s -L%s -lpython2.7 -mwindows -lmingw32 -lz -lws2_32 -lwsock32 %s -o %s' %\
              (env['CC'],
               sources,
               join(target.dist, 'include'),
               join(target.dist, 'include', 'python2.7'),
               join(target.dist, 'lib'),
               extralibs, options.project)
    else:
        sdlflags = get_sdl_flags(target)
        freetypeflags = get_freetype_flags(target)
        pngflags = get_png_flags(target)
        cmd = '%s -Wl,--no-export-dynamic -static-libgcc -static -DMS_WIN32 -DMS_WINDOWS -DHAVE_USABLE_WCHAR_T %s -I%s -I%s -L%s -lpython2.7 -mwindows -lmingw32 -lSDL2_ttf -lSDL2_image -lSDL2_mixer -lvorbisfile -lvorbis -logg -lSDL2main -lSDL2 -lpng -lturbojpeg -ljpeg -lfreetype -lz -lws2_32 -lwsock32 -lstdc++ %s %s %s -o %s' % \
        (env['CC'],
        sources,
        join(target.dist, 'include'),
        join(target.dist, 'include', 'python2.7'),
        join(target.dist, 'lib'),
        sdlflags, freetypeflags, extralibs, options.project)

    Popen(shlex.split(cmd), cwd = cython_src, env=env).communicate()

    if not isfile(join(cython_src, options.project)):
        error('Error during compilation of project')
        exit()
    cmd = '%s %s' % (env['STRIP'], join(cython_src, options.project))
    Popen(shlex.split(cmd), cwd = cython_src, env=env).communicate()
    shutil.move(join(cython_src, options.project), join(target.project, '..', options.project+'.exe'))

    return True
