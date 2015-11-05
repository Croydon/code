/// @file main header file for legacy code.

#ifndef __CUBE_H__
#define __CUBE_H__

#define _FILE_OFFSET_BITS 64

#ifdef __GNUC__
  #define gamma __gamma
#endif

#ifdef WIN32  // we define our own math constants (PI, ln(2)...)
  #define _USE_MATH_DEFINES
#endif
#include <math.h>

#ifdef __GNUC__
  #undef gamma
#endif

// essentiall C standard libraries
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <stdarg.h>
#include <limits.h>
#include <assert.h>
#include <time.h>


#ifdef WIN32
  #ifndef WIN32_LEAN_AND_MEAN // only include very important win API core, not inflicting other libs.
	#define WIN32_LEAN_AND_MEAN
  #endif

  #include "windows.h"

#endif


/// SDL (Simple DirectMedia Layer) - General Rendering/sound/events/threads
#ifndef STANDALONE
  #include <SDL.h>
  #include <SDL_opengl.h>
#endif

/// ENET: reliable UDP networking library
#include <enet/enet.h>

/// ZLIB compression library (used e.g. for map compression)
#include <zlib.h>

#include "inexor/shared/tools.h"
#include "inexor/shared/geom.h"
#include "inexor/shared/ents.h"
#include "inexor/shared/command.h"

#ifndef STANDALONE
#include "inexor/engine/glexts.h"
#include "inexor/engine/glemu.h"
#endif

/// header files for communication between the game and Cube engine
#include "inexor/shared/iengine.h"
#include "inexor/shared/igame.h"


#endif // __CUBE_H__

