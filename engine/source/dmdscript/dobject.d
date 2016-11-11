/* Digital Mars DMDScript source code.
 * Copyright (c) 2000-2002 by Chromium Communications
 * D version Copyright (c) 2004-2010 by Digital Mars
 * Distributed under the Boost Software License, Version 1.0.
 * (See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
 * written by Walter Bright
 * http://www.digitalmars.com
 *
 * D2 port by Dmitry Olshansky 
 *
 * DMDScript is implemented in the D Programming Language,
 * http://www.digitalmars.com/d/
 *
 * For a C++ implementation of DMDScript, including COM support, see
 * http://www.digitalmars.com/dscript/cppscript.html
 */

module dmdscript.dobject;

import dmdscript.script;
import dmdscript.value;
import dmdscript.dfunction;
import dmdscript.property;
import dmdscript.threadcontext;
import dmdscript.iterator;
import dmdscript.identifier;
import dmdscript.errmsgs;
import dmdscript.text;
import dmdscript.program;

import dmdscript.dboolean;
import dmdscript.dstring;
import dmdscript.dnumber;
import dmdscript.darray;
import dmdscript.dmath;
import dmdscript.ddate;
import dmdscript.dregexp;
import dmdscript.derror;
import dmdscript.dnative;

import dmdscript.protoerror;

//debug = LOG;

/************************** Dobject_constructor *************************/

class DobjectConstructor : Dfunction
{
    this()
    {
        super(1, Dfunction_prototype);
        if(Dobject_prototype)
            Put(Text.prototype, Dobject_prototype, DontEnum | DontDelete | ReadOnly);
    }

    override Status* Construct(CallContext* cc, Value* ret, Value[] arglist)
    {
        Dobject o;
        Value* v;

        // ECMA 15.2.2
        if(arglist.length == 0)
        {
            o = new Dobject(Dobject.getPrototype());
        }
        else
        {
            v = &arglist[0];
            if(v.isPrimitive())
            {
                if(v.isUndefinedOrNull())
                {
                    o = new Dobject(Dobject.getPrototype());
                }
                else
                    o = v.toObject();
            }
            else
                o = v.toObject();
        }
        //printf("constructed object o=%p, v=%p,'%s'\n", o, v,v.getType());
        ret.putVobject(o);
        return null;
    }

    override Status* Call(CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
    {
        Dobject o;
        Status* result;

        // ECMA 15.2.1
        if(arglist.length == 0)
        {
            result = Construct(cc, ret, arglist);
        }
        else
        {
            Value* v;

            v = &arglist[0];
            if(v.isUndefinedOrNull())
                result = Construct(cc, ret, arglist);
            else
            {
                o = v.toObject();
                ret.putVobject(o);
                result = null;
            }
        }
        return result;
    }
}


/* ===================== Dobject_prototype_toString ================ */

Status* Dobject_prototype_toString(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
    import std.format : format;

    d_string s;
    d_string str;

    //debug (LOG) writef("Dobject.prototype.toString(ret = %x)\n", ret);

    s = othis.classname;
/+
    // Should we do [object] or [object Object]?
    if (s == Text.Object)
        string = Text.bobjectb;
    else
 +/
    str = format("[object %s]", s);
    ret.putVstring(str);
    return null;
}

/* ===================== Dobject_prototype_toLocaleString ================ */

Status* Dobject_prototype_toLocaleString(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA v3 15.2.4.3
    //	"This function returns the result of calling toString()."

    Value* v;

    //writef("Dobject.prototype.toLocaleString(ret = %x)\n", ret);
    v = othis.Get(Text.toString);
    if(v && !v.isPrimitive())   // if it's an Object
    {
        Status* a;
        Dobject o;

        o = v.object;
        a = o.Call(cc, othis, ret, arglist);
        if(a)                   // if exception was thrown
            return a;
    }
    return null;
}

/* ===================== Dobject_prototype_valueOf ================ */

Status* Dobject_prototype_valueOf(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
    ret.putVobject(othis);
    return null;
}

/* ===================== Dobject_prototype_toSource ================ */

Status* Dobject_prototype_toSource(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
    d_string buf;
    int any;

    //writef("Dobject.prototype.toSource(this = %p, ret = %p)\n", this, ret);

    buf = "{";
    any = 0;
    foreach(Value key, Property p; *othis.proptable)
    {
        if(!(p.attributes & (DontEnum | Deleted)))
        {
            if(any)
                buf ~= ',';
            any = 1;
            buf ~= key.toString();
            buf ~= ':';
            buf ~= p.value.toSource();
        }
    }
    buf ~= '}';
    ret.putVstring(buf);
    return null;
}

/* ===================== Dobject_prototype_hasOwnProperty ================ */

Status* Dobject_prototype_hasOwnProperty(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA v3 15.2.4.5
    Value* v;

    v = arglist.length ? &arglist[0] : &vundefined;
    ret.putVboolean(othis.proptable.hasownproperty(v, 0));
    return null;
}

/* ===================== Dobject_prototype_isPrototypeOf ================ */

Status* Dobject_prototype_isPrototypeOf(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA v3 15.2.4.6
    d_boolean result = false;
    Value* v;
    Dobject o;

    v = arglist.length ? &arglist[0] : &vundefined;
    if(!v.isPrimitive())
    {
        o = v.toObject();
        for(;; )
        {
            o = o.internal_prototype;
            if(!o)
                break;
            if(o == othis)
            {
                result = true;
                break;
            }
        }
    }

    ret.putVboolean(result);
    return null;
}

/* ===================== Dobject_prototype_propertyIsEnumerable ================ */

Status* Dobject_prototype_propertyIsEnumerable(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA v3 15.2.4.7
    Value* v;

    v = arglist.length ? &arglist[0] : &vundefined;
    ret.putVboolean(othis.proptable.hasownproperty(v, 1));
    return null;
}

/* ===================== Dobject_prototype ========================= */

class DobjectPrototype : Dobject
{
    this()
    {
        super(null);
    }
}


/* ====================== Dobject ======================= */

class Dobject
{
    PropTable* proptable;
    Dobject internal_prototype;
    string classname;
    Value value;

    enum uint DOBJECT_SIGNATURE = 0xAA31EE31;
    uint signature;

    invariant()
    {
        assert(signature == DOBJECT_SIGNATURE);
    }

    this(Dobject prototype)
    {
        //writef("new Dobject = %x, prototype = %x, line = %d, file = '%s'\n", this, prototype, GC.line, ascii2unicode(GC.file));
        //writef("Dobject(prototype = %p)\n", prototype);
        proptable = new PropTable;
        internal_prototype = prototype;
        if(prototype)
            proptable.previous = prototype.proptable;
        classname = Text.Object;
        value.putVobject(this);

        signature = DOBJECT_SIGNATURE;
    }

    Dobject Prototype()
    {
        return internal_prototype;
    }

    Value* Get(d_string PropertyName)
    {
        return Get(PropertyName, Value.calcHash(PropertyName));
    }

    Value* Get(Identifier* id)
    {
        Value* v;

        //writefln("Dobject.Get(this = %x, '%s', hash = %x)", cast(uint)cast(void*)this, PropertyName, hash);
        //writef("\tinternal_prototype = %p\n", this.internal_prototype);
        //writef("\tDfunction.getPrototype() = %p\n", Dfunction.getPrototype());
        v = proptable.get(&id.value, id.value.hash);
        //if (v) writef("found it %p\n", v.object);
        return v;
    }

    Value* Get(d_string PropertyName, uint hash)
    {
        Value* v;

        //writefln("Dobject.Get(this = %x, '%s', hash = %x)", cast(uint)cast(void*)this, PropertyName, hash);
        //writef("\tinternal_prototype = %p\n", this.internal_prototype);
        //writef("\tDfunction.getPrototype() = %p\n", Dfunction.getPrototype());
        v = proptable.get(PropertyName, hash);
        //if (v) writef("found it %p\n", v.object);
        return v;
    }

    Value* Get(d_uint32 index)
    {
        Value* v;

        v = proptable.get(index);
        //    if (!v)
        //	v = &vundefined;
        return v;
    }

    Value* Get(d_uint32 index, Value* vindex)
    {
        return proptable.get(vindex, Value.calcHash(index));
    }

    Status* Put(d_string PropertyName, Value* value, uint attributes)
    {
        // ECMA 8.6.2.2
        //writef("Dobject.Put(this = %p)\n", this);
        proptable.put(PropertyName, value, attributes);
        return null;
    }

    Status* Put(Identifier* key, Value* value, uint attributes)
    {
        // ECMA 8.6.2.2
        //writef("Dobject.Put(this = %p)\n", this);
        proptable.put(&key.value, key.value.hash, value, attributes);
        return null;
    }

    Status* Put(d_string PropertyName, Dobject o, uint attributes)
    {
        // ECMA 8.6.2.2
        Value v;
        v.putVobject(o);

        proptable.put(PropertyName, &v, attributes);
        return null;
    }

    Status* Put(d_string PropertyName, d_number n, uint attributes)
    {
        // ECMA 8.6.2.2
        Value v;
        v.putVnumber(n);

        proptable.put(PropertyName, &v, attributes);
        return null;
    }

    Status* Put(d_string PropertyName, d_string s, uint attributes)
    {
        // ECMA 8.6.2.2
        Value v;
        v.putVstring(s);

        proptable.put(PropertyName, &v, attributes);
        return null;
    }

    Status* Put(d_uint32 index, Value* vindex, Value* value, uint attributes)
    {
        // ECMA 8.6.2.2
        proptable.put(vindex, Value.calcHash(index), value, attributes);
        return null;
    }

    Status* Put(d_uint32 index, Value* value, uint attributes)
    {
        // ECMA 8.6.2.2
        proptable.put(index, value, attributes);
        return null;
    }

    Status* PutDefault(Value* value)
    {
        // Not ECMA, Microsoft extension
        //writef("Dobject.PutDefault(this = %p)\n", this);
        return NoDefaultPutError;
    }

    Status* put_Value(Value* ret, Value[] arglist)
    {
        // Not ECMA, Microsoft extension
        //writef("Dobject.put_Value(this = %p)\n", this);
        return FunctionNotLvalueError;
    }

    int CanPut(d_string PropertyName)
    {
        // ECMA 8.6.2.3
        return proptable.canput(PropertyName);
    }

    int HasProperty(d_string PropertyName)
    {
        // ECMA 8.6.2.4
        return proptable.hasproperty(PropertyName);
    }

    /***********************************
     * Return:
     *	TRUE	not found or successful delete
     *	FALSE	property is marked with DontDelete attribute
     */

    int Delete(d_string PropertyName)
    {
        // ECMA 8.6.2.5
        //writef("Dobject.Delete('%ls')\n", d_string_ptr(PropertyName));
        return proptable.del(PropertyName);
    }

    int Delete(d_uint32 index)
    {
        // ECMA 8.6.2.5
        return proptable.del(index);
    }

    int implementsDelete()
    {
        // ECMA 8.6.2 says every object implements [[Delete]],
        // but ECMA 11.4.1 says that some objects may not.
        // Assume the former is correct.
        return true;
    }

    Status* DefaultValue(Value* ret, d_string Hint)
    {
        Dobject o;
        Value* v;
        static enum d_string[2] table = [ Text.toString, Text.valueOf ];
        int i = 0;                      // initializer necessary for /W4

        // ECMA 8.6.2.6
        //writef("Dobject.DefaultValue(ret = %x, Hint = '%s')\n", cast(uint)ret, Hint);

        if(Hint == TypeString ||
           (Hint == null && this.isDdate()))
        {
            i = 0;
        }
        else if(Hint == TypeNumber ||
                Hint == null)
        {
            i = 1;
        }
        else
            assert(0);

        for(int j = 0; j < 2; j++)
        {
            d_string htab = table[i];

            //writefln("\ti = %d, htab = '%s'", i, htab);
            v = Get(htab, Value.calcHash(htab));
            //writefln("\tv = %x", cast(uint)v);
            if(v && !v.isPrimitive())   // if it's an Object
            {
                Status* a;
                CallContext *cc;

                //writefln("\tfound default value");
                o = v.object;
                cc = Program.getProgram().callcontext;
                a = o.Call(cc, this, ret, null);
                if(a)                   // if exception was thrown
                    return a;
                if(ret.isPrimitive)
                    return null;
            }
            i ^= 1;
        }
        return NoDefaultValueError;
        //ErrInfo errinfo;
        //return RuntimeError(&errinfo, DTEXT("no Default Value for object"));
    }

    Status* Construct(CallContext* cc, Value* ret, Value[] arglist)
    {
        return SNoConstructError(classname);
    }

    Status* Call(CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
    {
        return SNoCallError(classname);
    }

    Status* HasInstance(Value* ret, Value* v)
    {   // ECMA v3 8.6.2
        return SNoInstanceError(classname);
    }

    d_string getTypeof()
    {   // ECMA 11.4.3
        return Text.object;
    }


    int isClass(d_string classname) const
    {
        return this.classname == classname;
    }

    int isDarray() const
    {
        return isClass(Text.Array);
    }
    int isDdate() const
    {
        return isClass(Text.Date);
    }
    int isDregexp() const
    {
        return isClass(Text.RegExp);
    }

    int isDarguments() const
    {
        return false;
    }
    int isCatch() const
    {
        return false;
    }
    int isFinally() const
    {
        return false;
    }

    ScriptException getException(Loc linnum)
    {
        Value v;
        v.putVobject(this);
        return new ScriptException(v.toString, null, null, linnum);
    }

    Status* putIterator(Value* v)
    {
        Iterator* i = new Iterator;

        i.ctor(this);
        v.putViterator(i);
        return null;
    }

    static Dfunction getConstructor()
    {
        return Dobject_constructor;
    }

    static Dobject getPrototype()
    {
        return Dobject_prototype;
    }

    static void initialize()
    {
        Dobject_prototype = new DobjectPrototype();
        Dfunction.initialize();
        Dobject_constructor = new DobjectConstructor();

        Dobject op = Dobject_prototype;
        Dobject f = Dfunction_prototype;

        op.Put(Text.constructor, Dobject_constructor, DontEnum);

        static enum NativeFunctionData[] nfd =
        [
            { Text.toString, &Dobject_prototype_toString, 0 },
            { Text.toLocaleString, &Dobject_prototype_toLocaleString, 0 },
            { Text.toSource, &Dobject_prototype_toSource, 0 },
            { Text.valueOf, &Dobject_prototype_valueOf, 0 },
            { Text.hasOwnProperty, &Dobject_prototype_hasOwnProperty, 1 },
            { Text.isPrototypeOf, &Dobject_prototype_isPrototypeOf, 0 },
            { Text.propertyIsEnumerable, &Dobject_prototype_propertyIsEnumerable, 0 },
        ];

        DnativeFunction.initialize(op, nfd, DontEnum);
    }
}


/*********************************************
 * Initialize the built-in's.
 */

void dobject_init()
{
    //writef("dobject_init(tc = %x)\n", cast(uint)tc);
    if(Dobject_prototype)
        return;                 // already initialized for this thread

    version(none)
    {
        writef("sizeof(Dobject) = %d\n", sizeof(Dobject));
        writef("sizeof(PropTable) = %d\n", sizeof(PropTable));
        writef("offsetof(proptable) = %d\n", offsetof(Dobject, proptable));
        writef("offsetof(internal_prototype) = %d\n", offsetof(Dobject, internal_prototype));
        writef("offsetof(classname) = %d\n", offsetof(Dobject, classname));
        writef("offsetof(value) = %d\n", offsetof(Dobject, value));
    }

    Dobject.initialize();
    Dboolean.initialize();
    Dstring.initialize();
    Dnumber.initialize();
    Darray.initialize();
    Dmath.initialize();
    Ddate.initialize();
    Dregexp.initialize();
    Derror.initialize();

    // Call registered initializer for each object type
    foreach(void function() fpinit; threadInitTable)
        (*fpinit)();
}
/*Not used anyway
void dobject_term()
{
    //writef("dobject_term(program = %x)\n", program);

    memset(&program, 0, ThreadContext.sizeof - Thread.sizeof);
}
*/
