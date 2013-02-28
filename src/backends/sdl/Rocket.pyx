#!/usr/bin/env python
#Copyright (c) 2010-2012, Gabriel Jacobo
#All rights reserved.
#Permission to use this file is granted under the conditions of the Ignifuga Game Engine License
#whose terms are available in the LICENSE file or at http://www.ignifuga.org/license

#if ROCKET

# libRocket Cython wrapper
from ignifuga.backends.sdl.Rocket cimport *
from ignifuga.Log import debug, error
from ignifuga.components.Viewable import Viewable
from ignifuga.backends.sdl.Renderer cimport Renderer
from ignifuga.Gilbert import Gilbert
from ignifuga.pQuery import pQuery

cdef class _RocketComponent:
    """ A Rocket context and document wrapper"""
    def __init__(self):
        self.doc = NULL
        self.released = False
        self.rocketCtx = NULL
        self.renderer = None

    cpdef init(self):
        # Initialize Rocket
        cdef bytes name
        cdef Renderer renderer
        self.renderer = <Renderer>Gilbert().renderer

        debug('Starting Rocket Instance')
        name = bytes(self.id)
        self.rocketCtx = RocketInit(self.renderer.renderer, name, self._width_pre, self._height_pre)
        debug('Rocket Instance Started')

        # These two imports are done here to ensure the Rocket <-> Python bindings are prepared to be used
        # They should NOT be imported elsewhere before than here, after the Rocket core initialization is done
        import _rocketcore
        import _rocketcontrols

    def __dealloc__(self):
        self.free()

    cpdef free(self):
        if not self.released:
            RocketFree(self.rocketCtx)
            self.released = True

    cpdef _loadDocument(self, filename):
        cdef bytes bFilename = bytes(filename)
        # TODO: Load this through the DataManager and use Rocket's LoadDocumentFromMemory
        self.doc = self.rocketCtx.LoadDocument( String(<char*>bFilename) )

    cpdef loadFont(self, filename):
        cdef bytes bFilename = bytes(filename)
        LoadFontFace(String(<char*>bFilename))

    cpdef _unloadDocument(self):
        if self.doc != NULL:
            self.rocketCtx.UnloadDocument(self.doc)
            self.doc.Close()
            self.doc = NULL

    cpdef getContext(self):
        cdef PyObject *nms
        if self.doc != NULL:
            nms = GetDocumentNamespace(self.doc)
            dnms = <object> nms
            Py_XDECREF(nms)
            return dnms
        return None

    cpdef update(self, now):
        self.rocketCtx.Update()

    cdef bint render(self):
        self.rocketCtx.Render()
        return True

    cdef bint rawEvent(self, SDL_Event *event):
        InjectRocket(self.rocketCtx, event[0])
        return True

    cpdef event(self, EventType action, int sx, int sy):
        if action == EVENT_ETHEREAL_WINDOW_RESIZED:
            self.updateSize()

    cpdef updateSize(self):
        if self.renderer is not None:
            if self.sizeType == 'window':
                # width and height are a percentage of the window size
                self._width_src = self._width_pre = <int> (self._width * self.renderer._width / 100.0) if self._width != None else self.renderer._width
                self._height_src = self._height_pre = <int> (self._height * self.renderer._height / 100.0) if self._height != None else self.renderer._height
            elif self.sizeType == 'scene':
                # width and height are a percentage of the scene size
                self._width_src = self._width_pre = <int> (self._width * self.renderer._native_size_w / 100.0) if self._width != None else self.renderer._native_size_w
                self._height_src = self._height_pre = <int> (self._height * self.renderer._native_size_h / 100.0) if self._height != None else self.renderer._native_size_h
            else:
                self._width_src = self._width_pre = self._width if self._width != None else 0
                self._height_src = self._height_pre = self._height if self._height != None else 0

            self.rocketCtx.SetDimensions(Vector2i(self._width_pre, self._height_pre))

    cpdef show(self):
        if self.doc != NULL and not self.doc.IsVisible():
            self.doc.Show(FOCUS)

        if self._rendererSprite == NULL and self._active:
            # TODO: Make libRocket and this component support and x,y position different from 0,0 (so it can behave as a sprite does)
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
        if self.doc != NULL and self.doc.IsVisible():
            self.doc.Hide()

        if self._rendererSprite != NULL:
            self.renderer._removeSprite(self._rendererSprite)
            self._rendererSprite = NULL

class RocketComponent(Viewable, _RocketComponent):
    """ A viewable component based on a Rocket document wrapper"""
    PROPERTIES = Viewable.PROPERTIES + []
    def __init__(self, id=None, entity=None, active=True, frequency=15.0,  **data):
        # Default values
        self._loadDefaults({
            'file': None,
            'document': None,
            'docCtx': None,
            'fonts': [],
            'pQuery': None,
            'sizeType': 'window', # window, scene, [px, None]
            '_actions': [],
            '_float': True
        })

        super(RocketComponent, self).__init__(id, entity, active, frequency, **data)
        _RocketComponent.__init__(self)

    def init(self, **data):
        """ Initialize the required external data """
        self.renderer = Gilbert().renderer
        _RocketComponent.init(self)

        for font in self.fonts:
            self.loadFont(font)

        self.unloadDocument()
        self.loadDocument(self.file)

        super(RocketComponent, self).init(**data)

        self.updateSize()
        self.show()

    def free(self, **kwargs):
        self.hide()
        self.unloadDocument()
        Gilbert().dataManager.removeListener(self.file, self)
        super(RocketComponent, self).free(**kwargs)

    def update(self, now, **data):
        _RocketComponent.update(self, now)

    def loadDocument(self, filename):
        self._loadDocument(filename)
        Gilbert().dataManager.addListener(self.file, self)
        self.docCtx = self.getContext()

        # Make a document context with a few useful variables.
        # These should match those set up in the Scene.py Scene::init method.
        self.docCtx['parent'] = self
        self.docCtx['Gilbert'] = Gilbert()
        self.docCtx['Scene'] = self.docCtx['Gilbert'].scene
        self.docCtx['DataManager'] = self.docCtx['Gilbert'].dataManager
        self.docCtx['Renderer'] = self.docCtx['Gilbert'].renderer

        def _pQuery(selector, context=None):
            if context is None:
                context = pQuery(self.docCtx['document'])

            return pQuery(selector, context)

        self.document = self.docCtx['document']
        self.document.parent = self
        self.pQuery = _pQuery
        self.docCtx['pQuery'] = _pQuery
        self.docCtx['_'] = _pQuery

        if 'onLoad' in self.docCtx:
            self.docCtx['onLoad']()

    def unloadDocument(self):

        if self.docCtx is not None and 'onUnload' in self.docCtx:
            self.docCtx['onUnload']()
        self._unloadDocument()
        if self.docCtx is not None:
            del self.docCtx['parent']
            del self.docCtx['Gilbert']
            del self.docCtx['Scene']
            del self.docCtx['DataManager']
            del self.docCtx['Renderer']
            del self.docCtx['pQuery']
            del self.docCtx['_']
            self.docCtx = None


    def reload(self, url):
        self.unloadDocument()
        self.file = url
        self.loadDocument(self.file)
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
        #TODO: Allow RocketComponents that don't float and that can be moved from 0,0
        Viewable.x.fset(self, 0)

    @Viewable.y.setter
    def y(self, new_y):
        #TODO: Allow RocketComponents that don't float and that can be moved from 0,0
        Viewable.y.fset(self, 0)

    @Viewable.float.setter
    def float(self, new_float):
        #TODO: Allow RocketComponents that don't float and that can be moved from 0,0
        Viewable.float.fset(self, True)

    def updateSize(self):
        _RocketComponent.updateSize(self)

    # These functions allow assigning an Action component to this Rocket component.
    # This is technically outside the entity->components model, but as we want to use the same codebase
    # to work on entities and on Rocket document elements, we do some minor hacking here.
    def remove(self, action):
        if action in self._actions:
            self._actions.remove(action)
    def add(self, action):
        if action not in self._actions:
            self._actions.append(action)

#endif
