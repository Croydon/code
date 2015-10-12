/// @file Slotsets are used to load and organize texture-slots chunk wise.
///

#include "inexor/shared/filesystem.h"
#include "inexor/texture/slotset.h"

namespace inexor {
    namespace slotset {

        struct jsontextype {
            const char *name;
            int type;
        } jsontextypes[TEX_NUM] = {
            { "diffuse", TEX_DIFFUSE },
            { "other", TEX_UNKNOWN },
            { "decal", TEX_DECAL },
            { "normal", TEX_NORMAL },
            { "glow", TEX_GLOW },
            { "spec", TEX_SPEC },
            { "depth", TEX_DEPTH },
            { "envmap", TEX_ENVMAP }
        }; //todo: int gettype() function and const char *getjsontex to not iterate over TEX_NUM

        /// Add all texture entries to the Slottexture.
        /// @return true on success.
        bool addimagefiles(Slot &s, JSON *j)
        {
            loopi(TEX_NUM) //check for all 8 kind of textures
            {
                JSON *sub = j->getchild(jsontextypes[i].name);
                //if(i == TEX_DIFFUSE && !sub) return false; else // no diffuse texture: other stuff wont work?
                if(!sub) continue;
                char *name = sub->valuestring;
                if(!name) continue;
                s.texmask |= 1 << i;
                Slot::Tex &st = s.sts.add();
                st.type = i;
                st.combined = -1;
                st.t = NULL;
                filesystem::getmedianame(st.name, name, DIR_TEXTURE, sub);
                path(st.name);
            }

            JSON *grass = j->getchild("grass"); // seperate entry, not in sts
            if(grass && grass->valuestring)
            {
                s.autograss = new string;
                filesystem::getmedianame(s.autograss, grass->valuestring, DIR_TEXTURE, grass);
                formatstring(s.autograss)("<ffskip><premul>%s", s.autograss); // prefix
            }

            return s.sts.length() != 0;
        }

        /// Add all size/rotation/offset/scroll modifiers.
        void addvslotparams(Slot &s, JSON *j)
        {
            JSON *scale = j->getchild("scale"), *rot = j->getchild("rotation"), *offset = j->getchild("offset"),
            *scroll = j->getchild("scroll"), *alpha = j->getchild("alpha"), *color = j->getchild("color");

            VSlot &vs = *emptyvslot(s);
            vs.reset();
            vs.rotation = rot ? clamp(rot->valueint, 0, 5) : 0;
            vs.scale = scale ? scale->valuefloat : 1;

            if(offset)
            {
                JSON *x = offset->getchild("x"), *y = offset->getchild("y");
                vs.xoffset = x ? max(x->valueint, 0) : 0;
                vs.yoffset = y ? max(y->valueint, 0) : 0;
            }

            if(scroll)
            {
                JSON *x = scroll->getchild("x"), *y = scroll->getchild("y");
                vs.scrollS = x ? x->valuefloat / 1000.0f : 0;
                vs.scrollT = y ? y->valuefloat / 1000.0f : 0;
            }

            if(alpha)
            {
                JSON *front = alpha->getchild("front"), *back = alpha->getchild("back");
                vs.alphafront = front ? clamp(front->valuefloat, 0.0f, 1.0f) : 0.5f; //todo
                vs.alphaback = back ? clamp(back->valuefloat, 0.0f, 1.0f) : 0;
            }

            if(color)
            {
                JSON *red = color->getchild("red"), *green = color->getchild("green"), *blue = color->getchild("blue");
                float r = red ? clamp(red->valuefloat, 0.0f, 1.0f) : 0.0f;
                float g = green ? clamp(green->valuefloat, 0.0f, 1.0f) : 0.0f;
                float b = blue ? clamp(blue->valuefloat, 0.0f, 1.0f) : 0.0f;

                vs.colorscale = vec(r, g, b);
            }

            propagatevslot(&vs, (1 << VSLOT_NUM) - 1); // apply vslot changes
        }

        void slotset::addslot(JSON *j)
        {
            if(!j || texs.length() >= 0x10000) return;

            Slot &s = *texs.add(new texentry(new Slot(texs.length())))->slot;
            s.loaded = false;

            if(!addimagefiles(s, j)) return; // no textures found

            JSON *shad = j->getchild("shader");
            setslotshader(s, shad); // TODO: multithread

            addvslotparams(s, j); // other parameters
        }

        void slotset::addslot(const char *filename)
        {
            if(!filename || !*filename) return;
            JSON *j = loadjson(filename);
            if(!j) {
                conoutf("could not load texture slot definition %s", filename);
                return;
            }

            addtexture(j);
            delete j;
        }

        void slotset::checkload()
        {
            loopv(texs)
            {
                texentry *t = texs[i];
                int diff = t->slot->texmask & ~t->loadmask; // All textures which havent been loaded yet
                if(!diff) continue;
                loopk(TEX_NUM)
                {
                    if(k >= t->slot->sts.length()) break; // out of range
                    if(!(diff & (1 << k))) continue; // not in diff
                    Slot::Tex &curimg = t->slot->sts[k];
                    curimg.t = gettexture(curimg.name);
                    if(curimg.t) t->loadmask |= 1 << k; //save to loadmask on success
                }
            }
            settings = new texsettings(); //use the settings we currently have for the whole loading.
        }

        void slotset::load()
        {
            loopv(texs)
            {
                texentry *t = texs[i];
                t->slot->load(false, settings); //conterminates any threadsafety effords so far.
                loopk(TEX_NUM)
                {
                    if(k >= t->slot->sts.length()) break; // out of range
                    if(t->needregister & (1 << k)) registertexture(t->slot->sts[k].name);
                }
            }
        }

        void slotset::mount(bool initial = false)
        {
            if(initial) texturereset(0);
            loopv(texs)
            {
                slots.add(texs[i]->slot);
                texs[i]->mounted = true;
            }
        }

        void slotset::unmount()
        {
            if(!texs[0]) return;
            int start = 0;
            loopv(slots)
            {
                if(slots[i] == texs[0]->slot) start = i;
            }

            texturereset(start, texs.length());

            loopv(texs) texs[i]->mounted = false;
        }

        /// Creates a slotset with all textures from a "textures" child of given JSON structure.
        /// @sideeffects allocates memory for a new slotset
        slotset *newslotset(JSON *parent)
        {
            if(!parent) return NULL;
            JSON *j = parent->getchild("textures");
            if(!j) return NULL;
            slotset *t = new slotset();

            loopi(j->numchilds())
            {
                const char *name = j->getchildstring(i);
                defformatstring(fn) ("%s", name);
                if(name[0]!='/') formatstring(fn)("%s", makerelpath(parentdir(j->currentfile), name)); //relative path to current folder
                t->addtexture(fn);
            }
            return t;
        }

        bool loadset(const char *name)
        {
            string fname;
            filesystem::getmedianame(fname, name, DIR_TEXTURE);
            JSON *j = loadjson(fname);
            if(!j) { conoutf("could not load %s slotset", name); return false; }
            slotset *t = newslotset(j);

            delete j;
            t->echoall();
            t->checkload();
            t->load();
            t->registerload();
            t->mount();
            //delete t;
            return true;
        }
        COMMAND(loadset, "s");

        /// Scan Texturedir for slotsets and load those sets.
        void scantexturedir()
        {
            vector<char *> files;
            listfiles(texturedir, "json", files, true, false, true);
            conoutf("Loaded %d texture configuration files", files.length());

            if(!files.length()) return;
            slotset *t = new slotset();
            loopv(files) t->addtexture(files[i]);

            t->checkload();
            t->load();
            t->registerload();
            t->mount();
        }
        COMMAND(scantexturedir, "");

        /// Guess a shader according to the used textures, allocates string.
        /// @param texmask a bitmaks containing the loaded textures
        const char *guessworldshader(int texmask)
        {
            // "bumpenvspecmapparallaxglowworld" with all textures

            string shader;
            shader[0] = '\0';
            if(texmask&(1 << TEX_NORMAL)) strcat(shader, "bump");
            if(texmask&(1 << TEX_ENVMAP)) strcat(shader, "env");
            if(texmask&(1 << TEX_SPEC))   strcat(shader, "specmap");
            if(texmask&(1 << TEX_DEPTH))  strcat(shader, "parallax");
            if(texmask&(1 << TEX_NORMAL)) strcat(shader, "glow");

            if(!shader[0]) strcat(shader, "std"); // use the stdworld shader

            strcat(shader, "world");

            return newstring(shader);
        }

        /// Add VSlot depending entries to root.
        void createvslotentries(JSON *root, VSlot *vs)
        {
            if(vs->scale != 1.0f)
            {
                JSON *scale = JSON_CreateFloat(vs->scale);
                root->addchild("scale", scale);
            }
            if(vs->rotation)
            {
                JSON *rot = JSON_CreateInt(vs->rotation);
                root->addchild("rotation", rot);
            }
            if(vs->xoffset || vs->yoffset)
            {
                JSON *off = JSON_CreateObject();
                if(vs->xoffset) off->addchild("x", JSON_CreateInt(vs->xoffset));
                if(vs->yoffset) off->addchild("y", JSON_CreateInt(vs->yoffset));
                root->addchild("offset", off);
            }
            if(vs->scrollS || vs->scrollT)
            {
                JSON *scr = JSON_CreateObject();
                if(vs->scrollS) scr->addchild("x", JSON_CreateFloat(vs->scrollS));
                if(vs->scrollT) scr->addchild("y", JSON_CreateFloat(vs->scrollT));
                root->addchild("scroll", scr);
            }
            if(vs->alphafront != 0.5f || vs->alphaback)
            {
                JSON *alpha = JSON_CreateObject();
                if(vs->alphafront != 0.5f) alpha->addchild("front", JSON_CreateFloat(vs->alphafront));
                if(vs->alphaback) alpha->addchild("back", JSON_CreateFloat(vs->alphaback));
                root->addchild("alpha", alpha);
            }
            if(vs->colorscale != vec(1.0f, 1.0f, 1.0f))
            {
                JSON *col = JSON_CreateObject();
                col->addchild("red", JSON_CreateFloat(vs->colorscale.r));
                col->addchild("green", JSON_CreateFloat(vs->colorscale.g));
                col->addchild("blue", JSON_CreateFloat(vs->colorscale.b));
                root->addchild("color", col);
            }
        }

        /// Exporter for texture jsons for already loaded slots.
        /// Loaded probably through the legacy path.
        void gentexjsons()
        {
            loopvk(vslots)
            {
                VSlot *vs = vslots[k];
                Slot *s = vs->slot;
                if(!s) continue;

                JSON *root = JSON_CreateObject();

                string diffusefile; //name the json accordingly to the diffuse file

                JSON *shader; //add a "shader" entry
                const char *shaderguess = guessworldshader(s->texmask);
                if(strcmp(shaderguess, s->shader->name) && !strcmp(s->shader->name, "stdworld"))
                { // optimize wrong shader entry (e.g. using not as many info-textures as possible )
                    shader = JSON_CreateString(shaderguess);
                }
                else shader = JSON_CreateString(s->shader->name);
                root->addchild("shader", shader);

                loopv(s->sts) // add all textures
                {
                    Slot::Tex *st = &s->sts[i];
                    defformatstring(name)("%s", st->name);
                    cutdir(name);
                    JSON *tex = JSON_CreateString(name);
                    root->addchild(jsontextypes[st->type].name, tex);

                    if(st->type == TEX_DIFFUSE) copystring(diffusefile, st->name);
                }

                createvslotentries(root, vs);

                cutextension(diffusefile);
                defformatstring(fn)("%s.json", diffusefile);

                const char *found = findfile(path(fn), "w"); // do not overwrite stuff

                if(root->save(fn))  conoutf("generated %s", fn);

                delete[] shaderguess;
                delete root;
            }
        }
        COMMAND(gentexjsons, "");


        /// Echo all texture slots loaded.
        void debugslots()
        {
            int numtexs = 0;
            loopv(slots)
            {
                loopvk(slots[i]->sts) conoutf("%d (%d): %s", i, k, slots[i]->sts[k].name);
                numtexs += slots[i]->sts.length();
            }
            conoutf("%d slots taken..", slots.length());
            conoutf("having %d textures", numtexs);
        }
        COMMAND(debugslots, "");

    } // namespace slotset
}     // namespace inexor



// TODO:
// - make textures look into texturefolder by default [DONE]
// - cutextension, cutfolder, getextension [DONE]
// - revert make json chars always allocated [DONE]
// - rename json getchild .. to child getfloat.. to getchildfloat( [DONE]
// - refractor foralljson to have an independend variablename [DONE]
// - replace
// - loadalltextures
// - statistik erstellen -> sortieren
// - alle texturen -> map texturen -> map json
// - import command f�r "#arg1" :
