#Copyright (c) 2010-2012, Gabriel Jacobo
#All rights reserved.
#Permission to use this file is granted under the conditions of the Ignifuga Game Engine License
#whose terms are available in the LICENSE file or at http://www.ignifuga.org/license

# Ignifuga Game Engine
# Spine component
# Author: Gabriel Jacobo <gabriel@mdqinc.com>

from ignifuga.backends.sdl.SDL cimport *
from ignifuga.backends.sdl.Renderer cimport Renderer, RenderableComponent, _Sprite as _RendererSprite
from ignifuga.backends.GameLoopBase cimport EventType, EVENT_ETHEREAL_WINDOW_RESIZED

cdef extern from "spine/spine.h":
    ctypedef struct Atlas
    ctypedef struct SkeletonJson
    ctypedef struct SkeletonData
    ctypedef struct AnimationStateData
    ctypedef struct AnimationState

    ctypedef struct Bone:
        float x, y
        float rotation
        float scaleX, scaleY

        float m00, m01, worldX
        float m10, m11, worldY
        float worldRotation
        float worldScaleX, worldScaleY

    ctypedef struct Skeleton:
        float r, g, b, a
        float time
        bint flipX, flipY
        Bone* root

    cdef Atlas* Atlas_readAtlasFile(char *path, void *param)
    cdef SkeletonJson* SkeletonJson_create(Atlas*)
    cdef SkeletonData* SkeletonJson_readSkeletonDataFile(SkeletonJson*, char*)
    cdef void SkeletonJson_dispose(SkeletonJson*)
    cdef AnimationStateData* AnimationStateData_create(SkeletonData*)
    cdef void AnimationStateData_setMixByName(AnimationStateData*, char*, char*, float)
    cdef void AnimationState_setAnimationByName (AnimationState* self, char* animationName, bint loop)
    cdef void AnimationState_addAnimationByName (AnimationState* self, char* animationName, bint loop, float delay)
    cdef void Skeleton_setToSetupPose(Skeleton*)
    cdef void Skeleton_updateWorldTransform(Skeleton*)
    cdef void SkeletonData_dispose(SkeletonData*)
    cdef void Atlas_dispose(Atlas*)

cdef extern from "spine/spine-sdl2.h" namespace "spine":
    cdef cppclass SkeletonDrawable:
        void SkeletonDrawable(SkeletonData*, AnimationStateData*)
        Skeleton* skeleton
        AnimationState* state
        float timeScale
        void update (Uint64 now)
        void draw (SDL_Renderer *renderer)

cdef class _SpineComponent(RenderableComponent):
    cdef bint released
    cdef _RendererSprite *_rendererSprite
    cdef Renderer renderer

    cdef Atlas* atlas
    cdef SkeletonData *skeletonData
    cdef SkeletonDrawable *drawable
    #cdef AnimationStateData* stateData

    cpdef init(self)
    cpdef free(self)
    cpdef update(self, unsigned long now)
    cpdef show(self)
    cpdef hide(self)
    cdef bint render(self)
    cdef bint rawEvent(self, SDL_Event *event)
    cpdef event(self, EventType action, int sx, int sy)
    cpdef updateSize(self)
    cpdef loadSpine(self)
    cpdef unloadSpine(self)
    cpdef rootBoneX(self, float x)
    cpdef rootBoneY(self, float y)
