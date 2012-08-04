/**
	Main header for the FileWatcher class. Declares all implementation
	classes to reduce compilation overhead.

	@author James Wynn
	@date 4/15/2009

	Copyright (c) 2009 James Wynn (james@jameswynn.com)

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in
	all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
	THE SOFTWARE.
*/

#ifndef _FW_FILEWATCHER_H_
#define _FW_FILEWATCHER_H_
#pragma once

#include <string>
#include <stdexcept>

#define FILEWATCHER_PLATFORM_NONE 0
#define FILEWATCHER_PLATFORM_WIN32 1
#define FILEWATCHER_PLATFORM_LINUX 2
#define FILEWATCHER_PLATFORM_KQUEUE 3

#if defined(__APPLE_CC__) || defined(BSD)
#include <TargetConditionals.h>
#endif

#if defined(_WIN32)
#	define FILEWATCHER_PLATFORM FILEWATCHER_PLATFORM_WIN32
#elif defined(__linux__)
#	define FILEWATCHER_PLATFORM FILEWATCHER_PLATFORM_LINUX
#elif (defined(__APPLE_CC__) || defined(BSD)) && TARGET_OS_IPHONE == 0 && TARGET_IPHONE_SIMULATOR == 0
#   define FILEWATCHER_PLATFORM FILEWATCHER_PLATFORM_KQUEUE
#else
#   define FILEWATCHER_PLATFORM FILEWATCHER_PLATFORM_NONE
#endif


#if FILEWATCHER_PLATFORM != FILEWATCHER_PLATFORM_NONE

extern "C" {
#include "SDL2/SDL.h"
}

#endif

namespace FW
{
	/// Type for a string
	typedef std::string String;
	/// Type for a watch id
	typedef unsigned long WatchID;

	// forward declarations
	class FileWatcherImpl;
	class FileWatchListener;

	/// Base exception class
	/// @class Exception
	class Exception : public std::runtime_error
	{
	public:
		Exception(const String& message)
			: std::runtime_error(message)
		{}
	};

	/// Exception thrown when a file is not found.
	/// @class FileNotFoundException
	class FileNotFoundException : public Exception
	{
	public:
		FileNotFoundException()
			: Exception("File not found")
		{}

		FileNotFoundException(const String& filename)
			: Exception("File not found (" + filename + ")")
		{}
	};

	/// Actions to listen for. Rename will send two events, one for
	/// the deletion of the old file, and one for the creation of the
	/// new file.
	namespace Actions
	{
		enum Action
		{
			/// Sent when a file is created or renamed
			Add = 1,
			/// Sent when a file is deleted or renamed
			Delete = 2,
			/// Sent when a file is modified
			Modified = 4
		};
	};
	typedef Actions::Action Action;

	/// Listens to files and directories and dispatches events
	/// to notify the parent program of the changes.
	/// @class FileWatcher
	class FileWatcher
	{
	public:
		///
		///
		FileWatcher();

		///
		///
		virtual ~FileWatcher();

		/// Add a directory watch. Same as the other addWatch, but doesn't have recursive option.
		/// For backwards compatibility.
		/// @exception FileNotFoundException Thrown when the requested directory does not exist
		WatchID addWatch(const String& directory, FileWatchListener* watcher);

		/// Add a directory watch
		/// @exception FileNotFoundException Thrown when the requested directory does not exist
		WatchID addWatch(const String& directory, FileWatchListener* watcher, bool recursive);

		/// Remove a directory watch. This is a brute force search O(nlogn).
		void removeWatch(const String& directory);

		/// Remove a directory watch. This is a map lookup O(logn).
		void removeWatch(WatchID watchid);

		/// Updates the watcher. Must be called often.
		void update();

	private:
		/// The implementation
		FileWatcherImpl* mImpl;

	};//end FileWatcher


	/// Basic interface for listening for file events.
	/// @class FileWatchListener
	class FileWatchListener
	{
	public:
		FileWatchListener() {}
		virtual ~FileWatchListener() {}

		/// Handles the action file action
		/// @param watchid The watch id for the directory
		/// @param dir The directory
		/// @param filename The filename that was accessed (not full path)
		/// @param action Action that was performed
		virtual void handleFileAction(WatchID watchid, const String& dir, const String& filename, Action action) = 0;

	};//class FileWatchListener
#if FILEWATCHER_PLATFORM != FILEWATCHER_PLATFORM_NONE
	class FileWatchListenerIgnifuga : public FileWatchListener
	{
	    void handleFileAction(WatchID watchid, const String& dir, const String& filename, Action action) {
            SDL_Event event;
            event.type = SDL_USEREVENT;
            event.user.code = action;
            event.user.data1 = (void*)dir.c_str();
            event.user.data2 = (void*)filename.c_str();
            SDL_PushEvent(&event);
	    }
	};
#endif // FILEWATCHER_PLATFORM != FILEWATCHER_PLATFORM_NONE
};//namespace FW

#endif//_FW_FILEWATCHER_H_
