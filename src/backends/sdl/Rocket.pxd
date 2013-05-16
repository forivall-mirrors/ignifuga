#!/usr/bin/env python
#Copyright (c) 2010-2012, Gabriel Jacobo
#All rights reserved.
#Permission to use this file is granted under the conditions of the Ignifuga Game Engine License
#whose terms are available in the LICENSE file or at http://www.ignifuga.org/license


# libRocket Cython wrapper

from ignifuga.backends.sdl.SDL cimport *
from ignifuga.backends.sdl.Renderer cimport Renderer, RenderableComponent, _Sprite as _RendererSprite
from ignifuga.backends.GameLoopBase cimport EventType, EVENT_ETHEREAL_WINDOW_RESIZED
from cpython cimport PyObject

cdef extern from "Rocket/Core/ElementDocument.h" namespace "Rocket::Core::ElementDocument":
    ctypedef enum FocusFlags:
        NONE = 0
        FOCUS = (1 << 1)
        MODAL = (1 << 2)

cdef extern from "Rocket/Core/ElementDocument.h" namespace "Rocket::Core":
    cdef cppclass ElementDocument:

        Context* GetContext()
        void SetTitle(String& title)
        String& GetTitle() 
        String& GetSourceURL() 
        #void SetStyleSheet(StyleSheet* style_sheet)
        #virtual StyleSheet* GetStyleSheet() 
        void PullToFront()
        void PushToBack()
        void Show(int focus_flags)
        void Hide()
        void Close()
        #Element* CreateElement( String& name)
        #ElementText* CreateTextNode( String& text)
        bint IsModal()
        #virtual void LoadScript(Stream* stream,  String& source_name)
        void UpdateLayout()
        void UpdatePosition()
        void LockLayout(bint lock)
        Context* GetContext()
        bint IsVisible()

cdef extern from "Rocket/Core/String.h" namespace "Rocket::Core":
    cdef cppclass String:
        String(char* string)

cdef extern from "Rocket/Core/String.h" namespace "Rocket::Core":
    cdef cppclass Vector2i:
        Vector2i(int x, int y)

cdef extern from "Rocket/Core/FontDatabase.h" namespace "Rocket::Core::FontDatabase":
    bint LoadFontFace(String& file_name) # static method of Rocket::Core::FontDatabase

cdef extern from "Rocket/Core/Context.h" namespace "Rocket::Core":
    cdef cppclass Context:
        bint Update()
        bint Render()
        ElementDocument* CreateDocument(String& tag)
        ElementDocument* LoadDocument(String& document_path)
        ElementDocument* LoadDocumentFromMemory(String& string)
        void UnloadDocument(ElementDocument* document)
        void UnloadAllDocuments()
        void SetDimensions(Vector2i& dimensions)

cdef extern from "backends/sdl/RocketGlue.hpp":
    Context* RocketInit(SDL_Renderer *renderer, const char *name, int width, int height)
    void RocketFree(Context *ctx)
    void RocketShutdown()
    PyObject* GetDocumentNamespace(ElementDocument* document)
    void InjectRocket( Context* context, SDL_Event& event )

cdef class _RocketComponent (RenderableComponent):
    cdef ElementDocument *doc
    cdef bint released
    cdef Context *rocketCtx
    cdef _RendererSprite *_rendererSprite
    cdef Renderer renderer
    # cdef SDL_Window *window

    cpdef init(self)
    cpdef free(self)
    cpdef update(self, now)

    cpdef _loadDocument(self, filename)
    cpdef _unloadDocument(self)
    cpdef loadFont(self, filename)
    cpdef getContext(self)
    cpdef show(self)
    cpdef hide(self)
    cdef bint render(self)
    cdef bint rawEvent(self, SDL_Event *event)
    cpdef event(self, EventType action, int sx, int sy)

    cpdef updateSize(self)