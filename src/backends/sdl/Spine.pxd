#Copyright (c) 2010-2012, Gabriel Jacobo
#All rights reserved.
#Permission to use this file is granted under the conditions of the Ignifuga Game Engine License
#whose terms are available in the LICENSE file or at http://www.ignifuga.org/license

# Ignifuga Game Engine
# Spine component
# Author: Gabriel Jacobo <gabriel@mdqinc.com>

from SDL cimport SDL_Renderer

cdef extern from "spine-sdl2/spine.h" namespace "spine":
    cdef cppclass Atlas:
        Atlas (SDL_Renderer *r, const char *begin, const char *end) except +

    cdef cppclass SkeletonData:
        pass

    cdef cppclass BaseSkeleton:
        pass

    cdef cppclass Animation:
        void apply (BaseSkeleton *skeleton, float time, bint loop)

    cdef cppclass Bone:
        pass

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

        # Bone *getRootBone ();
        # Bone* findBone (const std::string &boneName)
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