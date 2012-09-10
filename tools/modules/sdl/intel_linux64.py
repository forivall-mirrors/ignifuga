#Copyright (c) 2010-2012, Gabriel Jacobo
#All rights reserved.
#Permission to use this file is granted under the conditions of the Ignifuga Game Engine License
#whose terms are available in the LICENSE file or at http://www.ignifuga.org/license

# Schafer Module: Build SDL for Linux 64
# Author: Gabriel Jacobo <gabriel@mdqinc.com>

import os, shlex, shutil
from os.path import *
from subprocess import Popen, PIPE
from ..log import log, error
from schafer import SOURCES, SED_CMD
from ..util import prepare_source
import multiprocessing
from shutil import copyfile

def prepare(env, target):
    prepare_source('SDL', SOURCES['SDL'], target.builds.SDL)
    prepare_source('SDL_image', SOURCES['SDL_IMAGE'], target.builds.SDL_IMAGE)
    prepare_source('zlib', SOURCES['ZLIB'], target.builds.ZLIB)
    prepare_source('libpng', SOURCES['PNG'], target.builds.PNG)
    shutil.copy(join(target.builds.PNG, 'scripts', 'makefile.linux'), join(target.builds.PNG, 'Makefile'))
    prepare_source('libjpeg', SOURCES['JPG'], target.builds.JPG)
    prepare_source('freetype', SOURCES['FREETYPE'], target.builds.FREETYPE)
    shutil.copy(join(SOURCES['FREETYPE'], 'Makefile'), join(target.builds.FREETYPE, 'Makefile') )
    prepare_source('SDL_ttf', SOURCES['SDL_TTF'], target.builds.SDL_TTF)


def make(env, target):
    ncpu = multiprocessing.cpu_count()
    # Build zlib
    if isfile(join(target.dist, 'lib', 'libz.a')):
        os.remove(join(target.dist, 'lib', 'libz.a'))
    if not isfile(join(target.builds.ZLIB, 'Makefile')):
        cmd = './configure --static --prefix="%s"'% (target.dist,)
        Popen(shlex.split(cmd), cwd = target.builds.ZLIB, env=env).communicate()
    cmd = 'make -j%d' % ncpu
    Popen(shlex.split(cmd), cwd = target.builds.ZLIB, env=env).communicate()
    cmd = 'make install'
    Popen(shlex.split(cmd), cwd = target.builds.ZLIB, env=env).communicate()
    if isfile(join(target.dist, 'lib', 'libz.a')):
        log('zlib built successfully')
    else:
        error('Problem building zlib')
        exit()

    # Build libpng
    if isfile(join(target.dist, 'lib', 'libpng.a')):
        os.remove(join(target.dist, 'lib', 'libpng.a'))

    cmd = 'make -j%d V=0 prefix="%s"' % (ncpu, target.dist,)
    Popen(shlex.split(cmd), cwd = target.builds.PNG, env=env).communicate()
    cmd = 'make V=0 install prefix="%s"' % (target.dist,)
    Popen(shlex.split(cmd), cwd = target.builds.PNG, env=env).communicate()
    # Remove dynamic libraries to avoid confusions with the linker
    cmd = 'find %s -name "*.so*" -delete' % join(target.dist, 'lib')
    Popen(shlex.split(cmd), cwd = join(target.dist, 'lib'), env=env).communicate()

    if isfile(join(target.dist, 'lib', 'libpng.a')):
        log('libpng built successfully')
    else:
        error('Problem building libpng')
        exit()

    # Build libjpeg
    if isfile(join(target.dist, 'lib', 'libjpeg.a')):
        os.remove(join(target.dist, 'lib', 'libjpeg.a'))

    if not isfile(join(target.builds.JPG, 'Makefile')):
        cmd = './configure --enable-silent-rules LDFLAGS="-static-libgcc" LIBTOOL= --disable-shared --enable-static --prefix="%s"'% (target.dist,)
        Popen(shlex.split(cmd), cwd = target.builds.JPG, env=env).communicate()
        # Fixes for the Makefile
        cmd = SED_CMD + '"s|\./libtool||g" %s' % (join(target.builds.JPG, 'Makefile'))
        Popen(shlex.split(cmd), cwd = target.builds.JPG, env=env).communicate()
        cmd = SED_CMD + '"s|^O = lo|O = o|g" %s' % (join(target.builds.JPG, 'Makefile'))
        Popen(shlex.split(cmd), cwd = target.builds.JPG, env=env).communicate()
        cmd = SED_CMD + '"s|^A = la|A = a|g" %s' % (join(target.builds.JPG, 'Makefile'))
        Popen(shlex.split(cmd), cwd = target.builds.JPG, env=env).communicate()

    cmd = 'make -j%d V=0 ' % ncpu
    Popen(shlex.split(cmd), cwd = target.builds.JPG, env=env).communicate()
    cmd = 'make V=0 install-lib'
    Popen(shlex.split(cmd), cwd = target.builds.JPG, env=env).communicate()
    cmd = 'make V=0 install-headers'
    Popen(shlex.split(cmd), cwd = target.builds.JPG, env=env).communicate()

    if isfile(join(target.dist, 'lib', 'libjpeg.a')):
        log('libjpeg built successfully')
    else:
        error('Problem building libjpeg')
        exit()

    # Build SDL
    if isfile(join(target.dist, 'lib', 'libSDL2.a')):
        os.remove(join(target.dist, 'lib', 'libSDL2.a'))

    if not isfile(join(target.builds.SDL, 'Makefile')):
        cmd = './configure --enable-silent-rules LDFLAGS="-static-libgcc" --disable-shared --enable-static --prefix="%s"'% (target.dist,)
        Popen(shlex.split(cmd), cwd = target.builds.SDL, env=env).communicate()
    cmd = 'make -j%d V=0' % ncpu
    Popen(shlex.split(cmd), cwd = target.builds.SDL, env=env).communicate()
    cmd = 'make V=0 install'
    Popen(shlex.split(cmd), cwd = target.builds.SDL, env=env).communicate()

    if isfile(join(target.dist, 'lib', 'libSDL2.a')):
        log('SDL built successfully')
    else:
        error('Problem building SDL')
        exit()

    # Copy SDL_gl*funcs.h to the include dir so we can use them from libRocket
#    copyfile(join(target.builds.SDL, 'src', 'render', 'opengl', 'SDL_glfuncs.h'), join(target.dist, 'include', 'SDL2', 'SDL_glfuncs.h'))
#    copyfile(join(target.builds.SDL, 'src', 'render', 'opengles', 'SDL_glesfuncs.h'), join(target.dist, 'include', 'SDL2', 'SDL_glesfuncs.h'))
#    copyfile(join(target.builds.SDL, 'src', 'render', 'opengles2', 'SDL_gles2funcs.h'), join(target.dist, 'include', 'SDL2', 'SDL_gles2funcs.h'))

    # Build SDL_Image
    if isfile(join(target.dist, 'lib', 'libSDL2_image.a')):
        os.remove(join(target.dist, 'lib', 'libSDL2_image.a'))

    if not isfile(join(target.builds.SDL_IMAGE, 'Makefile')):
        cmd = join(target.dist, 'bin', 'libpng-config' ) + ' --static --cflags'
        pngcf = Popen(shlex.split(cmd), stdout=PIPE).communicate()[0].split('\n')[0]
        cmd = join(target.dist, 'bin', 'libpng-config' ) + ' --static --ldflags'
        pngld = Popen(shlex.split(cmd), stdout=PIPE).communicate()[0].split('\n')[0]
        cmd = './configure --enable-silent-rules CFLAGS="%s" LDFLAGS="-static-libgcc" LIBPNG_CFLAGS="%s" LIBPNG_LIBS="%s -ljpeg" --disable-png-shared --disable-jpg-shared --disable-shared --enable-static --with-sdl-prefix="%s" --prefix="%s"'% (env['CFLAGS'], pngcf, pngld, target.dist, target.dist)
        Popen(shlex.split(cmd), cwd = target.builds.SDL_IMAGE, env=env).communicate()
    cmd = 'make -j%d V=0' % ncpu
    Popen(shlex.split(cmd), cwd = target.builds.SDL_IMAGE, env=env).communicate()
    cmd = 'make V=0 install'
    Popen(shlex.split(cmd), cwd = target.builds.SDL_IMAGE, env=env).communicate()
    if isfile(join(target.dist, 'lib', 'libSDL2_image.a')):
        log('SDL Image built successfully')
    else:
        error('Problem building SDL Image')
        exit()

    # Build freetype
    if isfile(join(target.dist, 'lib', 'libfreetype.a')):
        os.remove(join(target.dist, 'lib', 'libfreetype.a'))

    if not isfile(join(target.builds.FREETYPE, 'config.mk')):
        cmd = './configure --enable-silent-rules LDFLAGS="-static-libgcc" --without-bzip2 --disable-shared --enable-static --with-sysroot=%s --prefix="%s"'% (target.dist,target.dist)
        Popen(shlex.split(cmd), cwd = target.builds.FREETYPE, env=env).communicate()
    cmd = 'make -j%d V=0' % ncpu
    Popen(shlex.split(cmd), cwd = target.builds.FREETYPE, env=env).communicate()
    cmd = 'make V=0 install'
    Popen(shlex.split(cmd), cwd = target.builds.FREETYPE, env=env).communicate()
    if isfile(join(target.dist, 'lib', 'libfreetype.a')):
        log('Freetype built successfully')
    else:
        error('Problem building Freetype')
        exit()

    # Build SDL_ttf
    if isfile(join(target.dist, 'lib', 'libSDL2_ttf.a')):
        os.remove(join(target.dist, 'lib', 'libSDL2_ttf.a'))

    if not isfile(join(target.builds.SDL_TTF, 'configure')):
        cmd = './autogen.sh'
        Popen(shlex.split(cmd), cwd = target.builds.SDL_TTF, env=env).communicate()

    if not isfile(join(target.builds.SDL_TTF, 'Makefile')):
        cmd = './configure --enable-silent-rules LDFLAGS="-static-libgcc" --disable-shared --enable-static --with-sdl-prefix="%s" --with-freetype-prefix="%s" --prefix="%s"'% (target.dist, target.dist, target.dist)
        Popen(shlex.split(cmd), cwd = target.builds.SDL_TTF, env=env).communicate()
        # Disable showfont/glfont to avoid the dependencies they carry
        cmd = 'sed -e "s|.*showfont.*||g" -i "" %s' % (join(target.builds.SDL_TTF, 'Makefile'),)
        Popen(shlex.split(cmd), cwd = target.builds.SDL_TTF, env=env).communicate()
        cmd = 'sed -e "s|.*glfont.*||g" -i "" %s' % (join(target.builds.SDL_TTF, 'Makefile'),)
        Popen(shlex.split(cmd), cwd = target.builds.SDL_TTF, env=env).communicate()
    cmd = 'make -j%d V=0' % ncpu
    Popen(shlex.split(cmd), cwd = target.builds.SDL_TTF, env=env).communicate()
    cmd = 'make V=0 install'
    Popen(shlex.split(cmd), cwd = target.builds.SDL_TTF, env=env).communicate()
    if isfile(join(target.dist, 'lib', 'libSDL2_ttf.a')):
        log('SDL TTF built successfully')
    else:
        error('Problem building SDL TTF')
        exit()

    return True