#Copyright (c) 2010-2012, Gabriel Jacobo
#All rights reserved.
#Permission to use this file is granted under the conditions of the Ignifuga Game Engine License
#whose terms are available in the LICENSE file or at http://www.ignifuga.org/license

# Schafer Module: Build Project for Android
# Author: Gabriel Jacobo <gabriel@mdqinc.com>

import os, shlex, shutil
from os.path import *
from subprocess import Popen, PIPE
from schafer import log, error, prepare_source, make_python_freeze

def make(options, env, DIST_DIR, BUILDS, sources, cython_src, cfiles):
    from schafer import SED_CMD, ANDROID_SDK, ANDROID_NDK

    # Copy/update the skeleton
    android_project = join(platform_build, 'android_project')
    jni_src = join(android_project, 'jni', 'src')
    local_cfiles = []
    for cfile in cfiles:
        local_cfiles.append(basename(cfile))

    cmd = 'rsync -aqPm --exclude .svn --exclude .hg %s/ %s' % (DIST_DIR, android_project)
    Popen(shlex.split(cmd), cwd = DIST_DIR).communicate()

    if options.wallpaper:
        # Wallpapers use a slightly different manifest
        if isfile(join(android_project, 'AndroidManifest.wallpaper.xml')):
            shutil.move(join(android_project, 'AndroidManifest.wallpaper.xml'), join(android_project, 'AndroidManifest.xml'))

    # Modify the glue code to suit the project
    cmd = SED_CMD + "'s|\[\[PROJECT_NAME\]\]|%s|g' %s" % (options.project.replace('.', '_'), join(jni_src, 'jni_glue.cpp'))
    Popen(shlex.split(cmd), cwd = jni_src).communicate()
    cmd = SED_CMD + "'s|\[\[PROJECT_NAME\]\]|%s|g' %s" % (options.project, join(android_project, 'AndroidManifest.xml'))
    Popen(shlex.split(cmd), cwd = jni_src).communicate()
    cmd = SED_CMD + "'s|\[\[PROJECT_NAME\]\]|%s|g' %s" % (options.project, join(android_project, 'src', 'SDLActivity.java'))
    Popen(shlex.split(cmd), cwd = jni_src).communicate()
    cmd = SED_CMD + "'s|\[\[PROJECT_NAME\]\]|%s|g' %s" % (options.project, join(android_project, 'src', 'SDLActivity.wallpaper.java'))
    Popen(shlex.split(cmd), cwd = jni_src).communicate()
    cmd = SED_CMD + "'s|\[\[PROJECT_NAME\]\]|%s|g' %s" % (options.project, join(android_project, 'build.xml'))
    Popen(shlex.split(cmd), cwd = jni_src).communicate()
    cmd = SED_CMD + "'s|\[\[SDK_LOCATION\]\]|%s|g' %s" % (ANDROID_SDK, join(android_project, 'local.properties'))
    Popen(shlex.split(cmd), cwd = jni_src).communicate()
    cmd = SED_CMD + "'s|\[\[LOCAL_SRC_FILES\]\]|%s|g' %s" % (' '.join(local_cfiles), join(jni_src, 'Android.mk'))
    Popen(shlex.split(cmd), cwd = jni_src).communicate()

    # Make the correct structure inside src
    sdlActivityDir = join(android_project, 'src', options.project.replace('.', os.sep))
    if not isdir(sdlActivityDir):
        os.makedirs(sdlActivityDir)
    if options.wallpaper:
        # Wallpapers use a slightly different activity
        shutil.move(join(android_project, 'src', 'SDLActivity.wallpaper.java'), join(sdlActivityDir, 'SDLActivity.java'))
        os.unlink(join(android_project, 'src', 'SDLActivity.java'))
    else:
        shutil.move(join(android_project, 'src', 'SDLActivity.java'), join(sdlActivityDir, 'SDLActivity.java'))
        os.unlink(join(android_project, 'src', 'SDLActivity.wallpaper.java'))

    # Copy cythonized sources
    cmd = 'rsync -aqPm --exclude .svn --exclude .hg %s/ %s' % (cython_src, jni_src)
    Popen(shlex.split(cmd), cwd = cython_src).communicate()

    # Copy assets
    for asset in options.assets:
        cmd = 'rsync -aqPm --exclude .svn --exclude .hg %s %s' % (asset, join(android_project, 'assets'))
        Popen(shlex.split(cmd)).communicate()

    # Build it
    cmd = 'ndk-build'
    Popen(shlex.split(cmd), cwd = join(platform_build, 'android_project'), env=env).communicate()
    cmd = 'ant debug'
    Popen(shlex.split(cmd), cwd = join(platform_build, 'android_project'), env=env).communicate()

    apk = join(android_project, 'bin', options.project+'-debug.apk')
    if not isfile(apk):
        error ('Error during compilation of the project')
        exit()

    shutil.move(apk, join(BUILDS['PROJECT'], '..', options.project+'.apk'))

    return True
