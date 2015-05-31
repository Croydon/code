/// 

#ifndef _TEX_FORMAT_H
#define _TEX_FORMAT_H

#include "engine.h" //bc hasTC
#include "texture/texsettings.h"

extern GLenum texformat(int bpp);
extern bool alphaformat(GLenum format);
extern GLenum uncompressedformat(GLenum format);
extern GLenum compressedformat(GLenum format, int w, int h, int force = 0);
extern GLenum textarget(GLenum subtarget);
extern int formatsize(GLenum format);

#endif _TEX_FORMAT_H
