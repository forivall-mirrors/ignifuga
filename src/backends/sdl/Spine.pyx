#Copyright (c) 2010-2012, Gabriel Jacobo
#All rights reserved.
#Permission to use this file is granted under the conditions of the Ignifuga Game Engine License
#whose terms are available in the LICENSE file or at http://www.ignifuga.org/license

# Ignifuga Game Engine
# Spine component
# Author: Gabriel Jacobo <gabriel@mdqinc.com>

from ignifuga.Gilbert import Gilbert
from ignifuga.components.Viewable import Viewable
from libc.string cimport strlen

cdef class _SpineComponent(RenderableComponent):
    def __init__ (self):
        self.released = False
        self._rendererSprite = NULL
        self.renderer = None
        self.skeleton = NULL

    def __dealloc__(self):
        self.free()

    cpdef init(self):
        self.renderer = <Renderer>Gilbert().renderer
        self.loadSpine()

    cpdef free(self):
        if not self.released:
            self.unloadSpine()
            del self.atlas
            del self.skeleton
            self.released = True

    cpdef update(self, unsigned long now):
        self.animation.apply(<BaseSkeleton*>self.skeleton, now/1000.0, True)
        self.skeleton.updateWorldTransform()

    cdef bint render(self):
        self.skeleton.draw(self.renderer.renderer)

    cdef bint rawEvent(self, SDL_Event *event):
        pass

    cpdef event(self, EventType action, int sx, int sy):
        pass

    cpdef updateSize(self):
        pass


    cpdef show(self):
        if self._rendererSprite == NULL and self._active:
            self._rendererSprite = self.renderer._addSprite(self, self.interactive, True, self._float, None,
                                                            self._z,
                                                            0, 0, self._width_src, self._height_src,
                                                            self._x, self._y, self._width_pre, self._height_pre,
                                                            self._angle,
                                                            self._center[0] if self._center != None else self._width_pre / 2,
                                                            self._center[1] if self._center != None else self._height_pre / 2,
                                                            (1 if self.fliph else 0) + (2 if self.flipv else 0),
                                                            self._red, self._green, self._blue, self._alpha)

    cpdef hide(self):
        if self._rendererSprite != NULL:
            self.renderer._removeSprite(self._rendererSprite)
            self._rendererSprite = NULL

    cpdef loadSpine(self):
        cdef SkeletonJson *sj
        cdef bytes data
        cdef char *strdata

        data = bytes(Gilbert().dataManager.loadFile(str(self.atlasFile)))
        strdata = data
        self.atlas = new Atlas(self.renderer.renderer, strdata, strdata + strlen(strdata))

        sj = new SkeletonJson(self.atlas)

        data = bytes(Gilbert().dataManager.loadFile(str(self.skeletonFile)))
        strdata = data
        self.skeletonData = sj.readSkeletonData(strdata, strdata + strlen(strdata))

        data = bytes(Gilbert().dataManager.loadFile(str(self.animationFile)))
        strdata = data
        self.animation = sj.readAnimation(strdata, strdata + strlen(strdata), self.skeletonData)

        self.skeleton = new Skeleton(self.skeletonData)
        self.skeleton.flipX = False
        self.skeleton.flipY = False
        self.skeleton.setToBindPose()

        self.rootBoneX(self._x)
        self.rootBoneY(self._y)

        del sj

        Gilbert().dataManager.addListener(self.atlasFile, self)
        Gilbert().dataManager.addListener(self.skeletonFile, self)
        Gilbert().dataManager.addListener(self.animationFile, self)

    cpdef unloadSpine(self):
        del self.atlas
        self.atlas = NULL
        del self.skeletonData
        self.skeletonData = NULL
        del self.animation
        self.animation = NULL
        Gilbert().dataManager.removeListener(self.atlasFile, self)
        Gilbert().dataManager.removeListener(self.skeletonFile, self)
        Gilbert().dataManager.removeListener(self.animationFile, self)

    cpdef rootBoneX(self, float x):
        if self.skeleton != NULL:
            self.skeleton.getRootBone().x = x

    cpdef rootBoneY(self, float y):
        if self.skeleton != NULL:
            self.skeleton.getRootBone().y = y




class Spine(Viewable, _SpineComponent):
    """ A viewable component based on a Rocket document wrapper"""
    PROPERTIES = Viewable.PROPERTIES + []
    def __init__(self, id=None, entity=None, active=True, frequency=15.0,  **data):
        # Default values
        self._loadDefaults({
            'atlasFile': None,
            'skeletonFile': None,
            'animationFile': None
        })

        super(Spine, self).__init__(id, entity, active, frequency, **data)
        _SpineComponent.__init__(self)

    def init(self, **data):
        """ Initialize the required external data """
        _SpineComponent.init(self)
        super(Spine, self).init(**data)

        self.updateSize()
        if self._visible:
            self.show()

    def free(self, **kwargs):
        self.hide()
        _SpineComponent.free(self)
        super(Spine, self).free(**kwargs)

    def update(self, now, **data):
        _SpineComponent.update(self, now)

    def reload(self, url):
        self.unloadSpine()
        self.loadSpine()
        if self._visible:
            self.show()

    @Viewable.visible.setter
    def visible(self, value):
        if value != self._visible:
            self._visible = value
            if self._visible:
                self.show()
            else:
                self.hide()


    @Viewable.x.setter
    def x(self, new_x):
        Viewable.x.fset(self, new_x)
        self.rootBoneX(self._x)

    @Viewable.y.setter
    def y(self, new_y):
        Viewable.y.fset(self, new_y)
        self.rootBoneY(self._y)

    @Viewable.float.setter
    def float(self, new_float):
        Viewable.float.fset(self, True)

    def updateSize(self):
        _SpineComponent.updateSize(self)


    #TODO: Handle flipping