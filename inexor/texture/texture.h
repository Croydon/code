/// @file Main texture loading and organizing routines + main texture structures.

#ifndef INEXOR_TEX_TEXTURE_H
#define INEXOR_TEX_TEXTURE_H

//#include "texture/textureslot.h" moved to below
#include "inexor/texture/texsettings.h"

/// Structure holding the Raw Pixel Data and minimum image info.
/// Used when loading/modifying a texture.
struct ImageData
{
    int w, h, bpp, levels, align, pitch;
    GLenum compressed;
    uchar *data;
    void *owner;
    void(*freefunc)(void *);

    ImageData()
        : data(NULL), owner(NULL), freefunc(NULL)
    {}


    ImageData(int nw, int nh, int nbpp, int nlevels = 1, int nalign = 0, GLenum ncompressed = GL_FALSE)
    {
        setdata(NULL, nw, nh, nbpp, nlevels, nalign, ncompressed);
    }

    ImageData(int nw, int nh, int nbpp, uchar *data)
        : owner(NULL), freefunc(NULL)
    {
        setdata(data, nw, nh, nbpp);
    }

    ImageData(SDL_Surface *s) { wrap(s); }
    ~ImageData() { cleanup(); }

    void setdata(uchar *ndata, int nw, int nh, int nbpp, int nlevels = 1, int nalign = 0, GLenum ncompressed = GL_FALSE)
    {
        w = nw;
        h = nh;
        bpp = nbpp;
        levels = nlevels;
        align = nalign;
        pitch = align ? 0 : w*bpp;
        compressed = ncompressed;
        data = ndata ? ndata : new uchar[calcsize()];
        if(!ndata) { owner = this; freefunc = NULL; }
    }

    int calclevelsize(int level) const { return ((max(w >> level, 1) + align - 1) / align)*((max(h >> level, 1) + align - 1) / align)*bpp; }

    int calcsize() const
    {
        if(!align) return w*h*bpp;
        int lw = w, lh = h,
            size = 0;
        loopi(levels)
        {
            if(lw <= 0) lw = 1;
            if(lh <= 0) lh = 1;
            size += ((lw + align - 1) / align)*((lh + align - 1) / align)*bpp;
            if(lw*lh == 1) break;
            lw >>= 1;
            lh >>= 1;
        }
        return size;
    }

    void disown()
    {
        data = NULL;
        owner = NULL;
        freefunc = NULL;
    }

    void cleanup()
    {
        if(owner == this) delete[] data;
        else if(freefunc) (*freefunc)(owner);
        disown();
    }

    void replace(ImageData &d)
    {
        cleanup();
        *this = d;
        if(owner == &d) owner = this;
        d.disown();
    }

    void wrap(SDL_Surface *s)
    {
        setdata((uchar *)s->pixels, s->w, s->h, s->format->BytesPerPixel);
        pitch = s->pitch;
        owner = s;
        freefunc = (void(*)(void *))SDL_FreeSurface;
    }
};


#include "inexor/texture/slot.h"

/// Different Texture Types.
enum
{
    TEX_DIFFUSE = 0,
    TEX_UNKNOWN,
    TEX_DECAL,
    TEX_NORMAL,
    TEX_GLOW,
    TEX_SPEC,
    TEX_DEPTH,
    TEX_ENVMAP,
    TEX_NUM
};

/// A Texture entry, holding info about a texture on the GPU.
struct Texture
{
    enum
    {
        IMAGE = 0,
        CUBEMAP = 1,
        TYPE = 0xFF,

        STUB = 1 << 8,
        TRANSIENT = 1 << 9,
        COMPRESSED = 1 << 10,
        ALPHA = 1 << 11,
        FLAGS = 0xFF00
    };

    char *name;
    int type, w, h, xs, ys, bpp, clamp;
    bool mipmap, canreduce;
    GLuint id;
    uchar *alphamask;

    Texture() : alphamask(NULL) {}
};

/// Global used to specify this texture has not be found.
extern Texture *notexture;

extern int texalign(void *data, int w, int bpp);
extern void cleanuptexture(Texture *t);
extern uchar *loadalphamask(Texture *t);
extern void setuptexparameters(int tnum, void *pixels, int clamp, int filter, GLenum format = GL_RGB, GLenum target = GL_TEXTURE_2D);
extern void createtexture(int tnum, int w, int h, void *pixels, int clamp, int filter, GLenum component = GL_RGB, GLenum target = GL_TEXTURE_2D, int pw = 0, int ph = 0, int pitch = 0, bool resize = true, GLenum format = GL_FALSE);
extern void createcompressedtexture(int tnum, int w, int h, uchar *data, int align, int blocksize, int levels, int clamp, int filter, GLenum format, GLenum subtarget);
extern bool reloadtexture(Texture &tex);
extern bool reloadtexture(const char *name);
extern void setuptexcompress();

extern Texture *textureload(const char *name, int clamp = 0, bool mipit = true, bool msg = true, bool threadsafe = false);
extern bool texturedata(ImageData &d, const char *tname, Slot::Tex *tex = NULL, bool msg = true, int *compress = NULL);
extern Texture *newtexture(Texture *t, const char *rname, ImageData &s, int clamp = 0, bool mipit = true, bool canreduce = false, bool transient = false, int compress = 0);

extern bool loadimage(const char *filename, ImageData &image);

// Texture Registry:
extern Texture *registertexture(const char *name);
extern Texture *gettexture(const char *name);

#endif // INEXOR_TEX_TEXTURE_H
