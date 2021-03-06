#Copyright (c) 2010-2012, Gabriel Jacobo
#All rights reserved.
#Permission to use this file is granted under the conditions of the Ignifuga Game Engine License
#whose terms are available in the LICENSE file or at http://www.ignifuga.org/license

# Ignifuga Game Engine
# Main Renderer
# Backends available: SDL
# Author: Gabriel Jacobo <gabriel@mdqinc.com>

# xcython: profile=True
# cython: boundscheck=False
# cython: wraparound=False
# encoding UTF-8

from ignifuga.Gilbert import BACKENDS, Gilbert, Event
from ignifuga.Log import Log, debug, error

from ignifuga.Singleton import Singleton
from ignifuga.Rect cimport *
from cython.operator cimport dereference as deref, preincrement as inc #dereference and increment operators
from cython.parallel cimport parallel, prange, threadid
cimport cython
import sys
from ignifuga.Scene cimport _Scene, _WalkAreaVertex, WalkAreaVertexIterator, WalkAreaVertexDeque
from cpython cimport Py_CLEAR, Py_XINCREF, Py_XDECREF, PyObject

ctypedef unsigned long ULong
ctypedef deque[Sprite_p].iterator deque_Sprite_iterator
ctypedef map[int,deque[Sprite_p]].iterator zmap_iterator

SDL_WINDOWPOS_CENTERED_MASK = 0x2FFF0000
SDL_WINDOWPOS_UNDEFINED_MASK = 0x1FFF0000


cdef class RenderableComponent:
    cdef bint render(self):
        pass
    cdef bint rawEvent(self, SDL_Event *event):
        pass

cdef class Renderer:
    def __init__(self, width=None, height=None, fullscreen = True, autoflip=True, **kwargs):
        cdef SDL_DisplayMode dm
        cdef int display = 0, x, y
        cdef char *metamode

        self.released = False

        self.nativeResolution = (None, None)
        self._scale_x = 1.0
        self._scale_y = 1.0
        self._scroll_x = 0
        self._scroll_y = 0
        self.autoflip = autoflip
        self.renderWalkAreas = False
        self.renderWalkAreasR = 0
        self.renderWalkAreasRMin = 128
        self.renderWalkAreasRMax = 255
        self.renderWalkAreasRStep = 10
        self.renderWalkAreasRDir = True
        self.renderWalkAreasG = 0
        self.renderWalkAreasGMin = 0
        self.renderWalkAreasGMax = 10
        self.renderWalkAreasGStep = 10
        self.renderWalkAreasGDir = True
        self.renderWalkAreasB = 0
        self.renderWalkAreasBMin = 0
        self.renderWalkAreasBMax = 10
        self.renderWalkAreasBStep = 10
        self.renderWalkAreasBDir = True


    # Create target window and renderer
        self._fullscreen = fullscreen

        if 'display' in kwargs:
            display = int(kwargs['display'])

        ndisplays = SDL_GetNumVideoDisplays()
        debug ("System has %d displays" % ndisplays)
        if ndisplays == 0:
            error("Can not detect a valid display, exiting")
            exit(1)
        if display > ndisplays-1:
            display = 0
        x = SDL_WINDOWPOS_UNDEFINED_MASK | display
        y = SDL_WINDOWPOS_UNDEFINED_MASK | display

        #        debug ("NUM VIDEO DISPLAYS: %d" % ndisplays)
        #        for d in range(0, ndisplays):
        #            nmodes = SDL_GetNumDisplayModes(d)
        #            for nm in range(0, nmodes):
        #                SDL_GetDisplayMode(d, nm, &dm)
        #                debug("Display: %d,  Mode %d resolution %dx%d" % (d, nm, dm.w, dm.h))

        SDL_GetDesktopDisplayMode(display, &dm)
        self.platform = Gilbert().platform

        debug("Platform: " + str(self.platform))
        debug("Display: %d,  desktop mode is %dx%d" % (display, dm.w, dm.h))

        if width is None:
            width = dm.w
        else:
            width=int(width)
        if height is None:
            height = dm.h
        else:
            height=int(height)

        debug("WIDTH: %d HEIGHT: %d X: %d Y: %d" % (width, height, x, y))
        SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 0)
        SDL_GL_SetAttribute(SDL_GL_RETAINED_BACKING,1)

#if __OSX__ or __LINUX__ or __MINGW__
        if fullscreen:
            self.window = SDL_CreateWindow("Ignifuga",
                x, y,
                width, height, SDL_WINDOW_FULLSCREEN | SDL_WINDOW_RESIZABLE | SDL_WINDOW_OPENGL)
        else:
            self.window = SDL_CreateWindow("Ignifuga",
                SDL_WINDOWPOS_CENTERED_MASK, SDL_WINDOWPOS_CENTERED_MASK, #
                width, height, SDL_WINDOW_RESIZABLE)
#else
        # Android and iOS don't care what we tell them to do, they create a full screen window anyway
        self.window = SDL_CreateWindow("Ignifuga",
            SDL_WINDOWPOS_CENTERED_MASK, SDL_WINDOWPOS_CENTERED_MASK,
            width, height, SDL_WINDOW_FULLSCREEN | SDL_WINDOW_BORDERLESS | SDL_WINDOW_RESIZABLE | SDL_WINDOW_OPENGL)
#endif

        if self.window == NULL:
            error("COULD NOT CREATE SDL WINDOW")
            error(SDL_GetError())
            exit(1)
            return

        # Find the GL renderer (useful for windows)
        cdef int num_renderers =  SDL_GetNumRenderDrivers(), renderer_index = -1, ri
        cdef SDL_RendererInfo renderer_info
        #debug("FOUND %d RENDERERS" % num_renderers)
        for ri in range(num_renderers):
            SDL_GetRenderDriverInfo(ri, &renderer_info)
            #debug("RENDERER %s" % renderer_info.name)
            if renderer_info.name==bytes('opengl'):
                renderer_index = ri
                break

        self.renderer = SDL_CreateRenderer(self.window, renderer_index, SDL_RENDERER_PRESENTVSYNC)
        if self.renderer == NULL:
            error("COULD NOT CREATE RENDERER")
            error(SDL_GetError())
            exit(1)
            return

        SDL_SetHint("SDL_RENDER_SCALE_QUALITY", "1")
        SDL_GetWindowSize(self.window, &self._width, &self._height)
        SDL_GetRendererInfo(self.renderer, &self.render_info)

        # """if bytes(self.render_info.name) in ['opengles', 'opengles2', 'direct3d']:
        # This renderers have 2 or more separate render surfaces, we have to render the whole screen all the time
        #self._doublebuffered = True
        #else:
        # OPENGL, etc
        # Not double buffered, we can render only the required parts of the screen
        #self._doublebuffered = False

        # Test: Render it all as if doublebuffered
        self._doublebuffered = True
        debug('SDL backend is %s' % bytes(self.render_info.name))

        # Start with a black window
        SDL_SetRenderDrawColor(self.renderer, 0, 0, 0, 255)
        SDL_RenderClear(self.renderer)
        SDL_RenderPresent(self.renderer)


        # _Sprite list allocation and setup
        self.zmap = new map[int,deque[Sprite_p]]()
        self.active_sprites = new deque[_Sprite]()
        self.free_sprites = new deque[Sprite_p]()
        self.dirty = True
        self._userCanZoom = False
        self._userCanScroll = False

        # JPEG Turbo
        self.tjh = tjInitCompress()

        debug('Renderer initialized')

    @cython.cdivision(True)
    cdef void _processSprite(self, Sprite_p sprite, SDL_Rect *screen, bint doScale) nogil:
        cdef _Sprite out
        cdef SDL_Rect nr, ir, src_r, dst_r
        cdef int z, extra
        cdef bint intersection
        cdef double ex,ey,ew,eh,fx,fy
        cdef SDL_Point center

        sprite.show = False
        nr = sprite.dst

        # ir is the intersection, in scene coordinates
        if sprite.angle != 0:
            # Expand the entity rect with some generous dimensions (to avoid having to calculate exactly how bigger it is)
            extra = nr.w if nr.w > nr.h else nr.h
            nr.x -= extra
            nr.y -= extra
            nr.h += extra
            nr.w += extra

        intersection = SDL_IntersectRect(screen, &nr, &ir)
        if intersection:
            nr = sprite.dst

            if sprite.angle == 0 and sprite.flip == 0:
                intersection = SDL_IntersectRect(screen, &nr, &ir)
            else:
                ir = nr
                intersection = 1

            if intersection:
                # ir is now the intersection of the frame area (moved to the proper location in the scene) with the screen rectangle, in scene coordinates
                src_r = ir
                dst_r = ir

                # src_r is in scene coordinates, created by intersecting the destination rectangle with the screen rectangle in scene coordinates
                # We need to move it to the proper position on the source canvas
                # We adjust it to entity coordinates by substracting the entity position
                # Then, we substract the dx,dy coordinates (as they were used to construct nr and we don't need those)
                # Finally we add sx,sy to put the rectangle in the correct position in the canvas
                # This operations as completed in one step, and we end up with a source rectangle properly intersected with r, in source canvas coordinates
                #src_r.x += (sx-dx)
                #src_r.y += (sy-dy)
                src_r.x += (sprite.src.x-sprite.dst.x)
                src_r.y += (sprite.src.y-sprite.dst.y)

                # Apply reverse scaling to the source rectangle
                #print 'pre', src_r, dst_r
                if sprite.src.w != sprite.dst.w or sprite.src.h != sprite.dst.h:
                    fx = <double>sprite.src.w/<double>sprite.dst.w
                    fy = <double>sprite.src.h/<double>sprite.dst.h
                    src_r.x = <int>(src_r.x * fx)
                    src_r.w = <int>(src_r.w * fx)
                    src_r.y = <int>(src_r.y * fy)
                    src_r.h = <int>(src_r.h * fy)

                # dst_r is in scene coordinates, we will adjust it to screen coordinates
                # Now we apply the scale factor
                if not sprite.floating:
                    if doScale:
                        #Scale the dst_r values
                        dst_r.x = <int>(dst_r.x * self._scale_x)
                        dst_r.w = <int>(dst_r.w * self._scale_x)
                        dst_r.y = <int>(dst_r.y * self._scale_y)
                        dst_r.h = <int>(dst_r.h * self._scale_y)

                        # Apply scrolling
                        dst_r.x -= self._scroll_x
                        dst_r.y -= self._scroll_y

                if src_r.w > 0 and src_r.h >0 and dst_r.w>0 and dst_r.h > 0:
                    sprite._src = src_r
                    sprite._dst = dst_r
                    sprite.show = True


    @cython.cdivision(True)
    cdef void _processSprites(self, bint all) nogil:
        cdef int i, numsprites
        cdef SDL_Rect screen, screen_
        cdef bint doScale = 0
        cdef Sprite_p sprite

        screen_.x = screen_.y = 0

        screen.x = self._scroll_x
        screen.y = self._scroll_y
        screen_.w = screen.w = self._width
        screen_.h = screen.h = self._height

        # Apply the overall scale setting if needed.
        if self._scale_x != 1.0 or self._scale_y != 1.0:
            doScale = 1
            # Convert screen coordinates to unscaled absolute coordinates
            screen.x = <int> (screen.x / self._scale_x)
            screen.w = <int> (screen.w / self._scale_x)
            screen.y = <int> (screen.y / self._scale_y)
            screen.h = <int> (screen.h / self._scale_y)
        else:
            doScale = 0



        numsprites = self.active_sprites.size()

        #with nogil, parallel():
        for i in prange(numsprites, nogil=True):
            sprite = &self.active_sprites.at(i)
            if not sprite.free and (all or sprite.dirty):
                if sprite.floating:
                    self._processSprite(sprite, &screen_, doScale)
                else:
                    self._processSprite(sprite, &screen, doScale)
                sprite.dirty = False

#        cdef deque[Sprite].iterator iter, iter_last
#        iter = self.active_sprites.begin()
#        iter_last  = self.active_sprites.end()
#        while iter != iter_last:
#            self._processSprite(&deref(iter), &screen, doScale)
#            inc(iter)

    cpdef update(self, Uint32 now):
        """ Renders the whole screen in every frame, ignores dirty rectangle markings completely (easier for handling rotations, etc) """
        self.frameTimestamp = now

        # In the following, screen coordinates refers to a set of coordinates that start in 0,0 and go to (screen width-1, screen height-1)
        # Scene coordinates are the logical entity coordinates, which relate to the screen via scale and scroll modifiers.
        # What we do here is basically put everything in scene coordinates first, see what we have to render, then move those rectangles back to screen coordinates to render them.

        # Let's start building a rectangle that holds the part of the scene we want to show
        # screen is the rectangle that holds the piece of scene that we will show. We still have to apply scaling to it.

        cdef zmap_iterator ziter, ziter_last
        cdef deque[Sprite_p] *ds
        cdef deque[Sprite_p].iterator iter, iter_last
        cdef Sprite_p sprite
        cdef RenderableComponent renderable

        self._processSprites(self.dirty)
        self.dirty = False

        ziter = self.zmap.begin()
        ziter_last = self.zmap.end()
        while ziter != ziter_last:
            ds = &deref(ziter).second
            iter = ds.begin()
            iter_last = ds.end()
            while iter != iter_last:
                sprite = deref(iter)
                if sprite.texture:
                    if sprite.show:
                        SDL_SetTextureColorMod(sprite.texture, sprite.r, sprite.g, sprite.b)
                        SDL_SetTextureAlphaMod(sprite.texture, sprite.a)
                        SDL_RenderCopyEx(self.renderer, sprite.texture, &sprite._src, &sprite._dst, sprite.angle, &sprite.center, sprite.flip)
                else:
                    renderable = <RenderableComponent>sprite.component
                    renderable.render()

                inc(iter)
            inc (ziter)

        if self.renderWalkAreas:
            self._renderWalkAreas()

        # If remote screen is enabled, don't flip automatically, the gameloop will flip for us after it's taken the screenshot
        if self.autoflip:
            self.flip()

    cdef bint _indexSprite(self, _Sprite* sprite):
        cdef zmap_iterator ziter
        ziter = self.zmap.find(sprite.z)
        if ziter == self.zmap.end():
            self.zmap.insert(pair[int,deque[Sprite_p]](sprite.z,deque[Sprite_p]()))
            ziter = self.zmap.find(sprite.z)
        deref(ziter).second.push_back(sprite)
        self.dirty = True
        return True

    cdef bint _unindexSprite(self, _Sprite *sprite):
        cdef deque[Sprite_p] *ds
        cdef deque_Sprite_iterator iter
        cdef zmap_iterator ziter = self.zmap.find(sprite.z)
        if ziter != self.zmap.end():
            ds = &deref(ziter).second
            iter = ds.begin()
            while iter != ds.end():
                if deref(iter) == sprite:
                    ds.erase(iter)
                    self.dirty = True
                    return True
                inc(iter)
        return False

    cdef _Sprite* _addSprite(self,  obj, bint interactive, bint rawEvents, bint floating, Canvas canvas, int z, int sx, int sy, int sw, int sh, int dx, int dy, int dw, int dh, double angle, int centerx, int centery, int flip, float r, float g, float b, float a):
        cdef _Sprite sprite, *spritep


        if canvas is None:
            sprite.texture = NULL
        else:
            sprite.texture = canvas._surfacehw

        sprite.src.x = sx
        sprite.src.y = sy
        sprite.src.w = sw
        sprite.src.h = sh
        sprite.dst.x = dx
        sprite.dst.y = dy
        sprite.dst.w = dw
        sprite.dst.h = dh
        sprite.angle = angle
        sprite.center.x = centerx
        sprite.center.y = centery
        sprite.flip = <SDL_RendererFlip>flip
        sprite.z = z
        sprite.r = <Uint8>(r*255.0)
        sprite.g = <Uint8>(g*255.0)
        sprite.b = <Uint8>(b*255.0)
        sprite.a = <Uint8>(a*255.0)
        sprite.dirty = True
        sprite.free = False
        sprite.interactive = interactive
        sprite.rawEvents = rawEvents
        sprite.floating = floating

        if obj is not None:
            sprite.component = <PyObject*> obj
        else:
            sprite.component = NULL

        Py_XINCREF(sprite.component)


        if self.free_sprites.size() > 0:
            spritep = self.free_sprites.back()
            self.free_sprites.pop_back()
            spritep[0] = sprite
        else:
            self.active_sprites.push_back(sprite)
            spritep = &self.active_sprites.back()

        self._indexSprite(spritep)

        return spritep

    cpdef Sprite addSprite(self,  obj, bint interactive, bint rawEvents, bint floating, Canvas canvas, int z, int sx, int sy, int sw, int sh, int dx, int dy, int dw, int dh, double angle, int centerx, int centery, int flip, float r, float g, float b, float a):
        cdef Sprite sprite_wrap = Sprite()
        sprite_wrap.sprite = self._addSprite(obj, interactive, rawEvents, floating, canvas, z, sx, sy, sw, sh, dx, dy, dw, dh, angle, centerx, centery, flip, r, g, b, a)
        return sprite_wrap

    cdef bint _removeSprite(self, _Sprite *sprite):
        cdef deque[_Sprite].iterator iter
        if self._unindexSprite(sprite):
            Py_XDECREF(sprite.component)
            self.free_sprites.push_back(sprite)
            sprite.free = True
        return False

    cpdef bint removeSprite(self, Sprite sprite_w):
        cdef _Sprite *sprite = sprite_w.sprite
        return self._removeSprite(sprite)

    cdef bint _spriteZ(self, _Sprite *sprite, int z):
        cdef deque[Sprite_p] *ds
        cdef deque_Sprite_iterator iter
        cdef zmap_iterator ziter = self.zmap.begin()

        sprite.z = z
        while ziter != self.zmap.end():
            ds = &deref(ziter).second
            iter = ds.begin()
            while iter != ds.end():
                if deref(iter) == sprite:
                    ds.erase(iter)
                    self._indexSprite(sprite)
                    self.dirty = True
                    return True
                inc(iter)
            inc(ziter)
        return False

    cpdef bint spriteZ(self, Sprite sprite_w, int z):
        cdef _Sprite *sprite = sprite_w.sprite
        return self._spriteZ(sprite, z)

    cpdef bint spriteSrc(self, Sprite sprite_w, int x, int y, int w, int h):
        cdef _Sprite *sprite = sprite_w.sprite
        return self._spriteSrc(sprite, x, y, w, h)

    cdef bint _spriteRot(self, _Sprite *sprite, double angle, int centerx, int centery, int flip) nogil:
        sprite.angle = angle
        sprite.center.x = centerx
        sprite.center.y = centery
        sprite.flip = <SDL_RendererFlip>flip
        sprite.dirty = True
        return True

    cdef bint _spriteColor(self, _Sprite *sprite, Uint8 r, Uint8 g, Uint8 b, Uint8 a) nogil:
        sprite.r = r
        sprite.g = g
        sprite.b = b
        sprite.a = a
        return True

    cdef bint _spriteSrc(self, _Sprite *sprite, int x, int y, int w, int h):
        sprite.src.x = x
        sprite.src.y = y
        sprite.src.w = w
        sprite.src.h = h
        sprite.dirty = True
        return True

    cdef bint _spriteDst(self, _Sprite *sprite, int x, int y, int w, int h, bint floating) nogil:
        sprite.dst.x = x
        sprite.dst.y = y
        sprite.dst.w = w
        sprite.dst.h = h
        sprite.floating = floating
        sprite.dirty = True
        return True

    cdef bint _spriteInteractive(self, _Sprite *sprite, bint interactive) nogil:
        sprite.interactive = interactive
        return True

    cpdef bint spriteDst(self, Sprite sprite_w, int x, int y, int w, int h, bint floating):
        cdef _Sprite *sprite = sprite_w.sprite
        return self._spriteDst(sprite, x, y, w, h, floating)

    cpdef bint spriteRot(self, Sprite sprite_w, double angle, int centerx, int centery, int flip):
        cdef _Sprite *sprite = sprite_w.sprite
        return self._spriteRot(sprite, angle, centerx, centery, flip)

    cpdef bint spriteColor(self, Sprite sprite_w, float r, float g, float b, float a):
        cdef _Sprite *sprite = sprite_w.sprite
        if r < 0:
            r = 0
        elif r > 1.0:
            r = 1.0

        if g < 0:
            g = 0
        elif g > 1.0:
            g = 1.0

        if b < 0:
            b = 0
        elif b > 1.0:
            b = 1.0

        if a < 0:
            a = 0
        elif a > 1.0:
            a = 1.0

        return self._spriteColor(sprite, <Uint8>(r*255.0), <Uint8>(g*255.0), <Uint8>(b*255.0), <Uint8>(a*255.0))

    cpdef bint spriteInteractive(self, Sprite sprite_w, bint interactive):
        cdef _Sprite *sprite = sprite_w.sprite
        return self._spriteInteractive(sprite, interactive)

    cdef void updateTexture(self, SDL_Texture *oldt, SDL_Texture *newt) nogil:
        cdef int i, numsprites = self.active_sprites.size()
        cdef Sprite_p sprite

        for i in prange(numsprites, nogil=True):
            sprite = &self.active_sprites.at(i)
            if sprite.texture == oldt:
                sprite.texture = newt

    property screenSize:
        def __get__(self):
            """ Return the width,height of the screen """
            return self._width, self._height

    property sceneSize:
        def __get__(self):
            """ Return the width,height of the scene """
            return self._native_size_w, self._native_size_h
        def __set__(self, value):
            self.setSceneSize(value[0], value[1])

    property scroll:
        def __get__(self):
            """ Return the scrolling of the scene in scene coordinates"""
            return self._scroll_x, self._scroll_y
        def __set__(self, value):
            self.scrollTo(value[0], value[1])

    property scale:
        def __get__(self):
            """ Return the scaling factor of the scene """
            return self._scale_x, self._scale_y

    cpdef getTimestamp(self):
        """ Return the current frame timestamp in ms """
        return self.frameTimestamp

    cpdef checkRate(self, Uint32 lastTime, Uint32 rate):
        """ Check if for a given frame rate in hz enough time in milliseconds has elapsed since lastTime"""
        return self.frameTimestamp - lastTime > 60000/rate

    cpdef checkLapse(self, Uint32 lastTime, Uint32 lapse):
        """ Check that a given time lapse in milliseconds has passed since lastTime"""
        return self.frameTimestamp - lastTime > lapse

    cpdef setNativeResolution(self, double w=-1.0, double h=-1.0, bint keep_aspect=1, bint autoscale=1):
        """ This function receives the scene native resolution. Based on it, it sets the scaling factor to the screen to fit the scene """
        self._native_res_w = w
        self._native_res_h = h
        self._keep_aspect = keep_aspect
        if autoscale:
            self._calculateScale(w,h,self._width, self._height, keep_aspect)
        else:
            self._calculateScale(self._width,self._height,self._width, self._height, keep_aspect)

    cpdef centerScene(self):
        """ Scroll the scene so it's centered on the screen"""
        self.centerOnScenePoint(self._native_size_w/2.0, self._native_size_h/2.0)

    cpdef centerOnScenePoint(self, double sx, double sy):
        """ Center scene around the given scene point"""
        self.centerOnScreenPoint(<int>(sx*self._scale_x),<int>(sy*self._scale_y))

    cpdef centerOnScreenPoint(self, int sx, int sy):
        """ Center scene around the given screen point"""
        self.scrollTo(sx-self._width/2,sy-self._height/2)

    cdef PointD _screenToScene(self, int sx, int sy):
        cdef PointD p
        p.x = <double>(sx+self._scroll_x)/self._scale_x
        p.y = <double>(sy+self._scroll_y)/self._scale_y
        return p

    cpdef tuple screenToScene(self, int sx, int sy):
        """ Scale a point in screen coordinates to scene coordinates """
        cdef PointD p = self._screenToScene(sx,sy)
        return p.x,p.y

    cpdef tuple sceneToScreen(self, double sx, double sy):
        """ Scale a point in scene coordinates to screen coordinates """
        return (sx*self._scale_x)-self._scroll_x,(sy*self._scale_y)-self._scroll_y

    cpdef setSceneSize(self, int w, int h):
        """ This function receives the scene size. Based on it, it controls the scrolling allowed """
        self._native_size_w = w
        self._native_size_h = h

    cpdef _calculateScale(self, double scene_w, double scene_h, int screen_w, int screen_h, bint keep_aspect=1):
        cdef double sx, sy
        self.dirty = True
        if scene_w > 0.0 and scene_h > 0.0:
            sx = <double>screen_w/scene_w
            sy = <double>screen_h/scene_h
            if keep_aspect:
                # Choose the higher scaling
                if sx > sy:
                    sy = sx
                else:
                    sx = sy
            self._scale_x = sx
            self._scale_y = sy
        else:
            self._scale_x = 1.0
            self._scale_y = 1.0

    cpdef windowResized(self):
        """ The window was resized, update our internal w,h reference """
        cdef _Sprite *sprite
        cdef deque[_Sprite].iterator iter, iter_end

        screen_w = self._width
        screen_h = self._height
        SDL_GetWindowSize(self.window, &self._width, &self._height)
        SDL_RenderSetViewport(self.renderer, NULL)
        debug('windowResized: new window size is %d x %d' % (self._width, self._height))

        if screen_w != self._width or screen_h != self._height:
            new_sx = <int>(self._scroll_x * self._width/screen_w if screen_w != 0 else 0)
            new_sy = <int>(self._scroll_y * self._height/screen_h if screen_h != 0 else 0)
            # Adjust scaling
            self._calculateScale(self._native_res_w, self._native_res_h, self._width, self._height, self._keep_aspect)
            # Always scroll after adjusting scale!
            #debug("windowResized: requesting new scroll point %dx%d" %(new_sx,new_sy))
            self.scrollTo(new_sx, new_sy)

            iter = self.active_sprites.begin()
            iter_last  = self.active_sprites.end()
            while iter != iter_last:
                sprite = &deref(iter)
                if not sprite.free and sprite.component != NULL:
                    obj = <object>sprite.component
                    obj.event(EVENT_ETHEREAL_WINDOW_RESIZED, self._width, self._height)
                inc(iter)

    cpdef scrollBy(self, int deltax, int deltay):
        """ Scroll the screen by deltax,deltay. deltax/y are in screen coordinates"""
        cdef int sx = self._scroll_x - deltax
        cdef int sy = self._scroll_y - deltay

        self.scrollTo(sx,sy)

    cpdef scrollTo(self, int sx, int sy):
        """ sx,sy are screen coordinates
        They can range from 0 to the screen scaled max size of the scene minus the screen size
        """
        cdef int max_w, max_h
        max_w = <int>(self._native_size_w*self._scale_x - self._width)
        max_h = <int>(self._native_size_h*self._scale_y - self._height)
        #debug("GOT A REQUEST TO SCROLL TO %dx%d" % (sx,sy))

        if sx < 0:
            sx = 0
        elif sx > max_w:
            sx = max_w

        if sy < 0:
            sy = 0
        elif sy > max_h:
            sy = max_h

        if self._scroll_x != sx or self._scroll_y != sy:
            self.dirty = True
            #print "SCROLL", sx, sy
            self._scroll_x = sx
            self._scroll_y = sy
            self.processEvent(EVENT_ETHEREAL_SCROLL, self._scroll_x, self._scroll_y)

    cpdef scaleBy(self, int delta):
        """ delta is a value in pixel area (width*height)"""
        cdef double factor = <double> delta / <double> (self._width*self._height)
        self.scaleByFactor(1.0+factor)

    cpdef scaleByFactor(self, double factor):
        """ Apply a scaling factor"""
        cdef double scale_x = self._scale_x * factor
        cdef double scale_y = self._scale_y * factor

        self.scaleTo(scale_x, scale_y)

    cpdef scaleTo(self, double scale_x, double scale_y):
        if self._native_size_w*scale_x < self._width:
            scale_x = self._width / self._native_size_w

        if self._native_size_h*scale_y < self._height:
            scale_y = self._height / self._native_size_h

        if self._keep_aspect:
            if scale_x > scale_y:
                scale_y = scale_x
            else:
                scale_x = scale_y

        self._scale_x = scale_x
        self._scale_y = scale_y
        self.dirty = True

        #print "SCALE", self._scale_x,self._scale_y
        # Adjust scrolling if needed
        self.scrollBy(0,0)


    cpdef cleanup(self):
        """ Remove free sprites if they are not in use"""
        cdef _Sprite *sprite
        cdef int i, numsprites
        cdef deque[_Sprite].iterator iter, iter_end

        if self.active_sprites.size() == self.free_sprites.size():
            # All active sprites are freed, so we can modify pointers at will
            iter = self.active_sprites.begin()
            iter_end = self.active_sprites.end()
            while iter != iter_end:
                sprite = &deref(iter)
                Py_XDECREF(sprite.component)
                inc(iter)

            self.active_sprites.resize(0)
            self.free_sprites.resize(0)

    def __dealloc__(self):
        self.free()

    cpdef free(self):
        if not self.released:
            debug('Releasing Sprites')
            # Release sprites

            del self.active_sprites
            del self.free_sprites
            del self.zmap

            debug('Releasing SDL renderer')
            if self.renderer != NULL:
                SDL_DestroyRenderer(self.renderer)
                self.renderer = NULL
            if self.window != NULL:
                SDL_DestroyWindow(self.window)
                self.window = NULL

            self.released = True



    property width:
        def __get__(self):
            return self._width

    property height:
        def __get__(self):
            return self._height

    property isDoubleBuffered:
        def __get__(self):
            return self._doublebuffered

    property userCanScroll:
        def __get__(self):
            return self._userCanScroll
        def __set__(self, value):
            self._userCanScroll = value

    property userCanZoom:
        def __get__(self):
            return self._userCanZoom
        def __set__(self, value):
            self._userCanZoom = value

    cpdef clear(self, x, y, w, h):
        self.ctx.clearRect(x,y,w,h);

    cpdef clearRect(self, rect):
        return self.clear(rect[0], rect[1], rect[2], rect[3])

    cdef flip(self):
        """ Show the contents of the window in a coordinated manner"""
        SDL_RenderPresent(self.renderer)
        if self._doublebuffered:
            SDL_SetRenderDrawColor(self.renderer, 0, 0, 0, 255);
            SDL_RenderClear(self.renderer);


    cpdef isVisible(self):
        if self.window != NULL:
            return SDL_GetWindowFlags(self.window) & SDL_WINDOW_SHOWN != 0

        return False


    cdef processEvent(self, EventType action, int x, int y):
        cdef zmap_iterator ziter, ziter_last
        cdef deque[Sprite_p] *ds
        cdef deque[Sprite_p].iterator iter, iter_last
        cdef Sprite_p sprite
        cdef bint continuePropagation = True, captureEvent = False
        cdef object captor = None
        cdef bint ethereal = action > EVENT_TOUCH_LAST

        cdef PointD scenePoint = self._screenToScene(x,y)

        ziter = self.zmap.begin()
        ziter_last = self.zmap.end()
        while ziter != ziter_last:
            ds = &deref(ziter).second
            iter = ds.begin()
            iter_last = ds.end()
            while iter != iter_last:
                sprite = deref(iter)
                if sprite.interactive or ethereal:
                    component = <object>sprite.component
                    if sprite.floating:
                        continuePropagation, captureEvent = component.event(action, x, y)
                    else:
                        continuePropagation, captureEvent = component.event(action, scenePoint.x, scenePoint.y)
                    if not ethereal:
                        if captureEvent:
                            captor = component
                            break
                        if not continuePropagation:
                            break
                inc(iter)
            inc (ziter)

        return continuePropagation or ethereal, captureEvent and not ethereal, captor

    cdef bint captureScreenJPEG(self, unsigned char **jpegBuffer, unsigned long *jpegSize) nogil:
        """ Capture the screen and compress it with jpeg """
        #if BIG_ENDIAN
        cdef SDL_Surface *surface = SDL_CreateRGBSurface(0, self._width, self._height, 32, 0xFF000000, 0x00FF0000, 0x0000FF00, 0x000000FF)
        #else
        cdef SDL_Surface *surface = SDL_CreateRGBSurface(0, self._width, self._height, 32, 0x000000FF, 0x0000FF00, 0x00FF0000, 0xFF000000 )
        #endif

        if surface:
            if SDL_RenderReadPixels(self.renderer, NULL, surface.format.format, surface.pixels, surface.pitch) == 0:
                if tjCompress2(self.tjh, <unsigned char *>surface.pixels, self._width, surface.pitch, self._height, TJPF_RGBA, jpegBuffer, jpegSize, TJSAMP_444, 100, 0) == 0:
                    SDL_FreeSurface(surface)
                    return True
            SDL_FreeSurface(surface)

        return False

    cdef bint releaseCapturedScreenBufferJPEG(self, unsigned char *jpegBuffer) nogil:
        tjFree(jpegBuffer)
        return True

    cdef bint _renderWalkAreas(self):
        cdef _Scene scene
        cdef WalkAreaVertexIterator walkAreasIt
        cdef _WalkAreaVertex *wav0, *wav1, *wav2
        cdef int ndx, x1, x2, y1, y2

        scene = <_Scene>Gilbert().scene
        walkAreasIt = scene.walkAreas.begin()

        ndx = 0

        if self.renderWalkAreasRDir: self.renderWalkAreasR +=self.renderWalkAreasRStep
        else: self.renderWalkAreasR-=self.renderWalkAreasRStep

        if self.renderWalkAreasGDir: self.renderWalkAreasG +=self.renderWalkAreasGStep
        else: self.renderWalkAreasG-=self.renderWalkAreasGStep

        if self.renderWalkAreasBDir: self.renderWalkAreasB +=self.renderWalkAreasBStep
        else: self.renderWalkAreasB-=self.renderWalkAreasBStep

        if self.renderWalkAreasR > self.renderWalkAreasRMax:
            self.renderWalkAreasR = self.renderWalkAreasRMax
            self.renderWalkAreasRDir = not self.renderWalkAreasRDir
        elif  self.renderWalkAreasR < self.renderWalkAreasRMin:
            self.renderWalkAreasR = self.renderWalkAreasRMin
            self.renderWalkAreasRDir = not self.renderWalkAreasRDir

        if self.renderWalkAreasG > self.renderWalkAreasGMax:
            self.renderWalkAreasG = self.renderWalkAreasGMax
            self.renderWalkAreasGDir = not self.renderWalkAreasGDir
        elif  self.renderWalkAreasG < self.renderWalkAreasGMin:
            self.renderWalkAreasG = self.renderWalkAreasGMin
            self.renderWalkAreasGDir = not self.renderWalkAreasGDir

        if self.renderWalkAreasB > self.renderWalkAreasBMax:
            self.renderWalkAreasB = self.renderWalkAreasBMax
            self.renderWalkAreasBDir = not self.renderWalkAreasBDir
        elif  self.renderWalkAreasB < self.renderWalkAreasBMin:
            self.renderWalkAreasB = self.renderWalkAreasBMin
            self.renderWalkAreasBDir = not self.renderWalkAreasBDir

        SDL_SetRenderDrawBlendMode(self.renderer, SDL_BLENDMODE_NONE)
        SDL_SetRenderDrawColor(self.renderer, self.renderWalkAreasR, self.renderWalkAreasG, self.renderWalkAreasB, 255)
        while walkAreasIt != scene.walkAreas.end():
            wav1 = &deref(walkAreasIt)
            if ndx == 0:
                wav0 = wav1
                inc(walkAreasIt)
                if walkAreasIt == scene.walkAreas.end():
                    break
                ndx+=1
                wav1 = &deref(walkAreasIt)
                wav2 = wav0
                
            x1 = <int> ((wav1.x*self._scale_x)-self._scroll_x)
            x2 = <int> ((wav2.x*self._scale_x)-self._scroll_x)
            y1 = <int> ((wav1.y*self._scale_y)-self._scroll_y)
            y2 = <int> ((wav2.y*self._scale_y)-self._scroll_y)

            SDL_RenderDrawLine(self.renderer, x1, y1, x2, y2)

            ndx+=1
            if ndx >= wav1.numVertexs:
                wav2 = wav0
                ndx = -1
            else:
                inc(walkAreasIt)
                wav2 = wav1

    cdef bint event(self, SDL_Event *event):
        """
        Pass raw SDL events to sprites that require them (Rocket for example)
        :param sdlev: SDL event
        """
        cdef _Sprite *sprite
        cdef deque[_Sprite].iterator iter, iter_end

        iter = self.active_sprites.begin()
        iter_last  = self.active_sprites.end()
        while iter != iter_last:
            sprite = &deref(iter)
            if not sprite.free and sprite.rawEvents:
                obj = <RenderableComponent>sprite.component
                obj.rawEvent(event)
            inc(iter)


#OLD UPDATE ROUTINE THAT's DIRTY RECT BASED. KEPT HERE FOR FUTURE GENERATIONS ENJOYMENT ¿?
#    cpdef update(self):
#    """ Update the screen by rendering the entities that intersect the dirty rectangles """
#    cdef Rect nr, ir, r
#    cdef int z
#
#    if self.frameTimestamp == 0.0:
#    raise Exception ('You have to call preUpdate before calling update')
#
#    if self._target.isDoubleBuffered:
#    # Double buffered systems force us to draw all the screen in every frame as there's no delta updating possible.
#    self.dirtyAll()
#
#    # In the following, screen coordinates refers to a set of coordinates that start in 0,0 and go to (screen width-1, screen height-1)
#    # Scene coordinates are the logical entity coordinates, which relate to the screen via scale and scroll modifiers.
#    # What we do here is basically put everything in scene coordinates first, see what we have to render, then move those rectangles back to screen coordinates to render them.
#
#    # Let's start building a rectangle that holds the part of the scene we want to show
#    # screen is the rectangle that holds the piece of scene that we will show. We still have to apply scaling to it.
#    screen_w = self._width
#    screen_h = self._height
#    screen = Rect((self._scroll_x, self._scroll_y, screen_w, screen_h))
#
#    rects = []
#
#    # Apply the overall scale setting if needed.
#    if self._scale_x != 1.0 or self._scale_y != 1.0:
#    doScale = True
#    # Convert screen coordinates to unscaled absolute coordinates
#    screen.scale(1.0/self._scale_x, 1.0/self._scale_y)
#    else:
#    doScale = False
#
#    # At this point, screen contains the rectangle in scene coordinates that we will show, everything that falls inside it gets on the screen.
#    # Now we get all the dirty rectangles reported by the entities, and we determine which ones intersect with the screen, discarding everything else.
#    if self.dirtyRects != None:
#    for dr in self.dirtyRects:
#    # dr is in scene coordinates
#    # Intersect the rect with the screen rectangle in scene coordinates
#    ir = screen.intersection(Rect(dr))
#    if ir != None:
#    # There's some intersection, append it to the list of rectangles to be rendered.
#    rects.append(ir)
#    else:
#    # Set all the screen as dirty
#    rects.append(screen)
#
#    gilbert = Gilbert()
#    # Get a list of the z index of the entities in the scenes, we will traverse it in increasing order
#    zindexs = gilbert.entitiesByZ.keys()
#    if len(zindexs) >0:
#    zindexs.sort()
#
#    # Iterate over the dirty rects that fall on the viewable area and draw them
#    for r in rects:
#    #print "DIRTY RECTANGLE:", r
#    # r is in scene coordinates, already intersected with the scaled & scrolled screen rectangle
#    for z in zindexs:
#    for entity in gilbert.entitiesByZ[z]:
#    # Intersect the entity rectangle with the dirty rectangle
#    # nr is in scene coordinates
#    nr = Rect(entity.getRect())
#    #print entity.id, 'nr: ', nr, 'r:', r
#    # ir is the intersection, in scene coordinates
#    ir = r.intersection(nr)
#    #print "Intersect r ", r, " with nr ", nr, " results in ", ir
#    if ir != None:
#    # There's an intersection, go over the entity areas, and see what parts of those fall inside the intersected rect.
#    # This areas is what we end up rendering.
#    nx, ny = entity.position
#    for a in entity.getFrameAreas():
#    # a is a frame area, it's format is [sx, sy, dx, dy, w, h]
#    # sx,sy -> coordinates in the atlas
#    # dx,dy -> entity coordinates where to put this
#    # w,h -> size of the rectangle to blit
#    sx,sy,dx,dy,w,h = a
#
#
#    # Create nr, a rectangle with the destination location in scene coordinates  (scene coords = entity coords+entity position)
#    nr = Rect((dx+nx, dy+ny, w, h))
#
#    #print entity.id, ' r:', r, ' nr :', nr, 'Frame Area:', sx,sy,dx,dy,w,h
#
#    ir = r.intersection(nr)
#    if ir != None:
#    # ir is now the intersection of the frame area (moved to the proper location in the scene) with the dirty rectangle, in scene coordinates
#    src_r = ir.copy()
#    dst_r = ir.copy()
#
#    # src_r is in scene coordinates, created by intersecting the destination rectangle with the dirty rectangle in scene coordinates
#    # We need to move it to the proper position on the source canvas
#    # We adjust it to entity coordinates by substracting the entity position
#    # Then, we substract the dx,dy coordinates (as they were used to construct nr and we don't need those)
#    # Finally we add sx,sy to put the rectangle in the correct position in the canvas
#    # This operations as completed in one step, and we end up with a source rectangle properly intersected with r, in source canvas coordinates
#    src_r.move(sx-nx-dx, sy-ny-dy)
#
#    # dst_r is in scene coordinates, we will adjust it to screen coordinates
#    # Now we apply the scale factor
#    if doScale:
#    #Scale the dst_r values
#    dst_r.scale(self._scale_x, self._scale_y)
#
#    # Apply scrolling
#    dst_r.move(-self._scroll_x, -self._scroll_y)
#
#    # Perform the blitting if the src and dst rectangles have w,h > 0
#    if src_r.width > 0 and src_r.height >0 and dst_r.width>0 and dst_r.height > 0:
#    if entity.center == None:
#    self._target.blitCanvas(entity.canvas, dst_r.left, dst_r.top, dst_r.width, dst_r.height, src_r.left, src_r.top, src_r.width, src_r.height, entity.angle, False, 0, 0, (1 if entity.fliph else 0) + (2 if entity.flipv else 0) )
#    else:
#    self._target.blitCanvas(entity.canvas, dst_r.left, dst_r.top, dst_r.width, dst_r.height, src_r.left, src_r.top, src_r.width, src_r.height, entity.angle, True, entity.center[0], entity.center[1], (1 if entity.fliph else 0) + (2 if entity.flipv else 0))
#    #raw_input("Press Enter to continue...")
#    self._target.flip()
#    self.dirtyNone()
#    # Calculate how long it's been since the pre update until now.
#    self.frameLapse = getTime() - self.frameTimestamp
#    self.frameTimestamp = 0.0
#
#   def reset(self):
#            """ Reset the renderer, mark everything as clean """
#        self.dirtyNone()
#
#   cpdef dirty(self, int x, int y, int w, int h):
#        """ Mark the area that starts at x,y with size w,h as dirty """
#        if self.dirtyRects != None:
#            self.dirtyRects.append((x,y,w,h))
#
#   def dirtyAll(self):
#        """ Dirty up all the screen """
#        self.dirtyRects = None
#
#   def dirtyNone(self):
#        """ Remove all dirty rectangles """
#        self.dirtyRects = []
#    property needsRects:
#        def __get__(self):
#            """ Answer whether dirty rectangles are needed or discarded (due to double buffering for example) """
#            return not self._target.isDoubleBuffered
