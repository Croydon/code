/// string operations on filenames (INCOMPLETE! see e.g. stream.cpp).

#include "inexor/shared/filesystem.h"

/// Media paths ///

SVARP(mediadir, "media");
SVARP(mapdir, "media/map");
SVARP(texturedir, "media/texture");
SVARP(skyboxdir, "media/skybox");
SVARP(interfacedir, "media/interface");
SVARP(icondir, "media/interface/icon");
SVARP(musicdir, "media/music");

namespace inexor {
    namespace filesystem {

        /// Returns the specific media dir according to type.
        const char *getmediadir(int type)
        {
            switch(type)
            {
            case DIR_MEDIA:     return mediadir;
            case DIR_MAP:       return mapdir;
            case DIR_TEXTURE:   return texturedir;
            case DIR_SKYBOX:    return skyboxdir;
            case DIR_UI:        return interfacedir;
            case DIR_ICON:      return icondir;
            case DIR_MUSIC:     return musicdir;
            }
            return NULL;
        }

        /// Append the media directory specified by type to the basename.
        char *appendmediadir(char *output, const char *basename, int type, const char *extension)
        {

            //size_t dirlen = strlen(dir);
           // if(dirlen >= 2 && (dir[dirlen - 1] == '/' || dir[dirlen - 1] == '\\')) dir[dirlen - 1] = '\0';

            const char *dir = getmediadir(type);
            formatstring(output)("%s%s%s%s", dir && *dir ? dir : "", dir && *dir ? "/" : "", basename, extension ? extension : "");
            return output;
        }

        /// Get a media name either relative to the current file or the specific media folder according to type.
        /// @warning not threadsafe! (since makerelpath, parentdir and getcurexecdir are not + the dir-defintions are not)
        char *getmedianame(char *output, const char *basename, int type, JSON *j)
        {
            ASSERT(basename != NULL && strlen(basename)>=2);
            if(basename[0] == '/') appendmediadir(output, basename+1, type);
            else if(j && j->currentfile) {
                const char *dir = parentdir(j->currentfile);
                formatstring(output)("%s%s%s", *dir ? dir : "", *dir ? "/" : "", basename);
            }
            else if(!j) copystring(output, makerelpath(getcurexecdir(), basename));
            else copystring(output, basename);
            return output;
        }
    }
}
