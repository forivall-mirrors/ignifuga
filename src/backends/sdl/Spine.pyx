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

    def __dealloc__(self):
        self.free()

    cpdef init(self):
        self.renderer = <Renderer>Gilbert().renderer
        self.loadSpine()

    cpdef free(self):
        if not self.released:
            self.unloadSpine()
            self.released = True

    cpdef update(self, unsigned long now):
        self.drawable.update(now)

    cdef bint render(self):
        self.drawable.draw(self.renderer.renderer)

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
        cdef SkeletonJson* json
        cdef Skeleton* skeleton
        cdef AnimationStateData* stateData

        self.atlas = Atlas_readAtlasFile(self.atlasFile, self.renderer.renderer)
        json = SkeletonJson_create(self.atlas)
        self.skeletonData = SkeletonJson_readSkeletonDataFile(json, self.skeletonFile)
        SkeletonJson_dispose(json)

        stateData = AnimationStateData_create(self.skeletonData)
        AnimationStateData_setMixByName(stateData, "walk", "jump", 0.2)
        AnimationStateData_setMixByName(stateData, "jump", "walk", 0.4)

        self.drawable = new SkeletonDrawable(self.skeletonData, stateData)
        self.drawable.timeScale = 1

        skeleton = self.drawable.skeleton
        skeleton.flipX = False
        skeleton.flipY = False
        Skeleton_setToSetupPose(skeleton)

        skeleton.root.x = self._x
        skeleton.root.y = self._y
        Skeleton_updateWorldTransform(skeleton)

        AnimationState_setAnimationByName(self.drawable.state, "walk", True)
        AnimationState_addAnimationByName(self.drawable.state, "jump", False, 0)
        AnimationState_addAnimationByName(self.drawable.state, "walk", True, 0)
        AnimationState_addAnimationByName(self.drawable.state, "jump", False, 3)
        AnimationState_addAnimationByName(self.drawable.state, "walk", True, 0)
        AnimationState_addAnimationByName(self.drawable.state, NULL, True, 0)
        AnimationState_addAnimationByName(self.drawable.state, "walk", False, 1)

        Gilbert().dataManager.addListener(self.atlasFile, self)
        Gilbert().dataManager.addListener(self.skeletonFile, self)

    cpdef unloadSpine(self):
        SkeletonData_dispose(self.skeletonData)
        self.skeletonData = NULL

        Atlas_dispose(self.atlas)
        self.atlas = NULL

        del self.drawable
        self.drawable = NULL

        Gilbert().dataManager.removeListener(self.atlasFile, self)
        Gilbert().dataManager.removeListener(self.skeletonFile, self)

    cpdef rootBoneX(self, float x):
        if self.drawable != NULL:
             self.drawable.skeleton.root.x = x

    cpdef rootBoneY(self, float y):
        if self.drawable != NULL:
            self.drawable.skeleton.root.y = y


class Spine(Viewable, _SpineComponent):
    """ A viewable component based on a Rocket document wrapper"""
    PROPERTIES = Viewable.PROPERTIES + []
    def __init__(self, id=None, entity=None, active=True, frequency=15.0,  **data):
        # Default values
        self._loadDefaults({
            'atlasFile': None,
            'skeletonFile': None
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