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

cdef extern from "spine-sdl2/spine.h" namespace "spine":
    cdef cppclass Atlas:
        Atlas (SDL_Renderer *r, const char *begin, const char *end) except +

    cdef cppclass SkeletonData:
        pass

    cdef cppclass BaseSkeleton:
        pass

    cdef cppclass Animation:
        void apply (BaseSkeleton *skeleton, float time, bint loop)

    cdef cppclass BoneData:
        pass

    cdef cppclass Bone:
        BoneData *data
        Bone *parent
        float x, y
        float rotation
        float scaleX, scaleY

        float m00, m01, worldX
        float m10, m11, worldY
        float worldRotation
        float worldScaleX, worldScaleY

        Bone (BoneData *data) except +
        void setToBindPose ()
        void updateWorldTransform (bint flipX, bint flipY)

    cdef cppclass SkeletonJson:
        SkeletonJson (Atlas *atlas) except +
        SkeletonData* readSkeletonData (const char *begin, const char *end)
        Animation* readAnimation (const char *begin, const char *end, const SkeletonData *skeletonData)
        float scale
        bint flipY

    cdef cppclass Skeleton:
        Skeleton (SkeletonData *skeletonData)
        SkeletonData *data
        float r, g, b, a
        float time
        bint flipX, flipY

        void updateWorldTransform ()
        void setToBindPose ()
        void setBonesToBindPose ()
        void setSlotsToBindPose ()

        void draw (SDL_Renderer *renderer)

        Bone *getRootBone ()
        #Bone* findBone (const std::string &boneName)
        # int findBoneIndex (const std::string &boneName)
        #
        # Slot* findSlot (const std::string &slotName)
        # int findSlotIndex (const std::string &slotName)
        #
        # void setSkin (const std::string &skinName)
        # void setSkin (Skin *newSkin)
        #
        # Attachment* getAttachment (const std::string &slotName, const std::string &attachmentName);
        # Attachment* getAttachment (int slotIndex, const std::string &attachmentName);
        # void setAttachment (const std::string &slotName, const std::string &attachmentName);


cdef class _SpineComponent(RenderableComponent):
    cdef bint released
    cdef _RendererSprite *_rendererSprite
    cdef Renderer renderer
    cdef Skeleton *skeleton
    cdef SkeletonData *skeletonData
    cdef Animation *animation
    cdef Atlas *atlas

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
