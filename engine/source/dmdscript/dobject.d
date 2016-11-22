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
        super(1, Dfunction.getPrototype);
        if(Dobject.getPrototype)
        {
            Put(Text.prototype, Dobject.getPrototype,
                Property.Attribute.DontEnum |
                Property.Attribute.DontDelete |
                Property.Attribute.ReadOnly);
        }
    }

    override DError* Construct(ref CallContext cc, out Value ret,
                               Value[] arglist)
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

        ret.putVobject(o);
        return null;
    }

    override DError* Call(ref CallContext cc, Dobject othis, out Value ret,
                          Value[] arglist)
    {
        Dobject o;
        DError* result;

        // ECMA 15.2.1
        if(arglist.length == 0)
        {
            result = Construct(cc, ret, arglist);
        }
        else
        {
            auto v = arglist.ptr;
            if(v.isUndefinedOrNull)
                result = Construct(cc, ret, arglist);
            else
            {
                o = v.toObject;
                ret.putVobject(o);
                result = null;
            }
        }
        return result;
    }
}


/* ===================== Dobject_prototype_toString ================ */

DError* Dobject_prototype_toString(
    Dobject pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
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

DError* Dobject_prototype_toLocaleString(
    Dobject pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.2.4.3
    //	"This function returns the result of calling toString()."

    Value* v;

    //writef("Dobject.prototype.toLocaleString(ret = %x)\n", ret);
    v = othis.Get(Text.toString);
    if(v && !v.isPrimitive())   // if it's an Object
    {
        DError* a;
        Dobject o;

        o = v.object;
        a = o.Call(cc, othis, ret, arglist);
        if(a)                   // if exception was thrown
            return a;
    }
    return null;
}

/* ===================== Dobject_prototype_valueOf ================ */

DError* Dobject_prototype_valueOf(
    Dobject pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    ret.putVobject(othis);
    return null;
}

/* ===================== Dobject_prototype_toSource ================ */

DError* Dobject_prototype_toSource(
    Dobject pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    d_string buf;
    int any;

    buf = "{";
    any = 0;
    foreach(Value key, Property p; othis.proptable)
    {
        if(!(p.attributes &
             (Property.Attribute.DontEnum | Property.Attribute.Deleted)))
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

DError* Dobject_prototype_hasOwnProperty(
    Dobject pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.2.4.5
    Value* v;

    v = arglist.length ? &arglist[0] : &vundefined;
    ret.putVboolean(othis.proptable.hasownproperty(*v, 0));
    return null;
}

/* ===================== Dobject_prototype_isPrototypeOf ================ */

DError* Dobject_prototype_isPrototypeOf(
    Dobject pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
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

DError* Dobject_prototype_propertyIsEnumerable(
    Dobject pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.2.4.7
    Value* v;

    v = arglist.length ? &arglist[0] : &vundefined;
    ret.putVboolean(othis.proptable.hasownproperty(*v, 1));
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
    PropTable proptable;
    string classname;
    Value value;

    @safe pure nothrow
    this(Dobject prototype)
    {
        signature = DOBJECT_SIGNATURE;

        proptable = new PropTable;
        Prototype(prototype);
        classname = Text.Object;
        value.putVobject(this);
    }

    final @property @safe @nogc pure nothrow
    Dobject Prototype() // [[GetPrototypeOf]]
    {
        return internal_prototype;
    }

    final @property @safe @nogc pure nothrow
    bool Prototype(Dobject prototype) // [[SetPrototypeOf]]
    {
        internal_prototype = prototype;
        if (prototype !is null)
        {
            proptable.previous = prototype.proptable;
            debug checkCircularPrototype;
        }
        return true;
    }

    @disable
    @property @safe @nogc pure nothrow
    bool isExtensible() const // [[IsExtensible]]
    {
        return true;
    }

    @disable
    @property @safe @nogc pure nothrow
    bool preventExtensions() const // [[PreventExtensions]]
    {
        return false;
    }

    Value* Get(in d_string PropertyName)
    {
        return Get(PropertyName, Value.calcHash(PropertyName));
    }

    Value* Get(ref Identifier id)
    {
        return proptable.get(id.value, id.value.hash);
    }

    Value* Get(in d_string PropertyName, in size_t hash)
    {
        return proptable.get(PropertyName, hash);
    }

    Value* Get(in d_uint32 index)
    {
        Value* v;

        v = proptable.get(index);
        //    if (!v)
        //	v = &vundefined;
        return v;
    }

    Value* Get(in d_uint32 index, ref Value vindex)
    {
        return proptable.get(vindex, Value.calcHash(index));
    }

    DError* Put(in d_string PropertyName, ref Value value,
                in Property.Attribute attributes)
    {
        // ECMA 8.6.2.2
        proptable.put(PropertyName, value, attributes);
        return null;
    }

    DError* Put(ref Identifier key, ref Value value,
                in Property.Attribute attributes)
    {
        // ECMA 8.6.2.2
        proptable.put(key.value, key.value.hash, value, attributes);
        return null;
    }

    DError* Put(in d_string PropertyName, Dobject o,
                in Property.Attribute attributes)
    {
        // ECMA 8.6.2.2
        Value v;
        v.putVobject(o);

        proptable.put(PropertyName, v, attributes);
        return null;
    }

    DError* Put(in d_string PropertyName, in d_number n,
                in Property.Attribute attributes)
    {
        // ECMA 8.6.2.2
        Value v;
        v.putVnumber(n);

        proptable.put(PropertyName, v, attributes);
        return null;
    }

    DError* Put(in d_string PropertyName, in d_string s,
                in Property.Attribute attributes)
    {
        // ECMA 8.6.2.2
        Value v;
        v.putVstring(s);

        proptable.put(PropertyName, v, attributes);
        return null;
    }

    DError* Put(in d_uint32 index, ref Value vindex, ref Value value,
                in Property.Attribute attributes)
    {
        // ECMA 8.6.2.2
        proptable.put(vindex, Value.calcHash(index), value, attributes);
        return null;
    }

    DError* Put(in d_uint32 index, ref Value value,
                in Property.Attribute attributes)
    {
        // ECMA 8.6.2.2
        proptable.put(index, value, attributes);
        return null;
    }

    DError* PutDefault(out Value value)
    {
        // Not ECMA, Microsoft extension
        return NoDefaultPutError;
    }

    DError* put_Value(out Value ret, Value[] arglist)
    {
        // Not ECMA, Microsoft extension
        return FunctionNotLvalueError;
    }

    int CanPut(in d_string PropertyName)
    {
        // ECMA 8.6.2.3
        return proptable.canput(PropertyName);
    }

    int HasProperty(in d_string PropertyName)
    {
        // ECMA 8.6.2.4
        return proptable.hasproperty(PropertyName);
    }

    /***********************************
     * Return:
     *	TRUE	not found or successful delete
     *	FALSE	property is marked with DontDelete attribute
     */
    int Delete(in d_string PropertyName)
    {
        // ECMA 8.6.2.5
        return proptable.del(PropertyName);
    }

    int Delete(in d_uint32 index)
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

    final @trusted
    DError* DefaultValue(out Value ret, in d_string Hint)
    {
        Dobject o;
        Value* v;
        static enum d_string[2] table = [Text.toString, Text.valueOf];
        int i = 0;                      // initializer necessary for /W4

        // ECMA 8.6.2.6

        if(Hint == Value.TypeName.String ||
           (Hint == null && this.isDdate()))
        {
            i = 0;
        }
        else if(Hint == Value.TypeName.Number ||
                Hint == null)
        {
            i = 1;
        }
        else
            assert(0);

        for(int j = 0; j < 2; j++)
        {
            d_string htab = table[i];

            v = Get(htab, Value.calcHash(htab));

            if(v && !v.isPrimitive())   // if it's an Object
            {
                DError* a;
                CallContext *cc;

                o = v.object;
                cc = Program.getProgram().callcontext;
                a = o.Call(*cc, this, ret, null);
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

    DError* Construct(ref CallContext cc, out Value ret, Value[] arglist)
    {
        return SNoConstructError(classname);
    }

    DError* Call(ref CallContext cc, Dobject othis, out Value ret,
                 Value[] arglist)
    {
        return SNoCallError(classname);
    }

    DError* HasInstance(out Value ret, ref Value v)
    {   // ECMA v3 8.6.2
        return SNoInstanceError(classname);
    }

    d_string getTypeof()
    {   // ECMA 11.4.3
        return Text.object;
    }


    final @safe @nogc pure nothrow
    int isClass(d_string classname) const
    {
        return this.classname == classname;
    }

    final @safe @nogc pure nothrow
    int isDarray() const
    {
        return isClass(Text.Array);
    }
    final @safe @nogc pure nothrow
    int isDdate() const
    {
        return isClass(Text.Date);
    }
    final @safe @nogc pure nothrow
    int isDregexp() const
    {
        return isClass(Text.RegExp);
    }

    @safe @nogc pure nothrow
    int isDarguments() const
    {
        return false;
    }
    @safe @nogc pure nothrow
    int isCatch() const
    {
        return false;
    }
    @safe @nogc pure nothrow
    int isFinally() const
    {
        return false;
    }

    final @trusted
    DError* putIterator(out Value v)
    {
        auto i = new Iterator;

        i.ctor(this);
        v.putViterator(i);
        return null;
    }

    Property* getOwnProperty(ref Value key)
    {
        assert(proptable !is null);
        return proptable.getProperty(key);
    }

    @safe pure nothrow
    Value[] OwnPropertyKeys()
    {
        assert(proptable !is null);
        return proptable.keys;
    }

    @disable
    bool DefineOwnProperty(ref Value key, ref Property desc)
    {
        assert(proptable !is null);
        if      (auto p = proptable.getProperty(key))
        {
            if (desc.canOverwriteTo(*p))
            {
                desc.overwriteTo(*p);
                return true;
            }
        }
        else if (!isExtensible)
        {
            
            return false;
        }
        else
        {
        }

        return false;
    }

private:
    Dobject internal_prototype;
    enum uint DOBJECT_SIGNATURE = 0xAA31EE31;
    uint signature;

    invariant()
    {
        assert(signature == DOBJECT_SIGNATURE);
    }

    // See_Also:
    // Ecma-272-v7:6.1.7.3 Invariants of the Essential Internal Methods
    debug @trusted @nogc pure nothrow
    void checkCircularPrototype() const
    {
        for (auto ite = cast(Dobject)internal_prototype; ite !is null;
             ite = ite.internal_prototype)
            assert(this !is ite);
        if (internal_prototype !is null)
            internal_prototype.checkCircularPrototype;
    }

public static:
    @safe @nogc nothrow
    Dfunction getConstructor()
    {
        return _constructor;
    }

    @safe @nogc nothrow
    Dobject getPrototype()
    {
        return _prototype;
    }

    void initialize()
    {
        _prototype = new DobjectPrototype();
        Dfunction.initialize();
        _constructor = new DobjectConstructor();

        Dobject op = _prototype;
        Dobject f = Dfunction.getPrototype;

        op.Put(Text.constructor, _constructor,
               Property.Attribute.DontEnum);

        static enum NativeFunctionData[] nfd =
        [
            { Text.toString, &Dobject_prototype_toString, 0 },
            { Text.toLocaleString, &Dobject_prototype_toLocaleString, 0 },
            { Text.toSource, &Dobject_prototype_toSource, 0 },
            { Text.valueOf, &Dobject_prototype_valueOf, 0 },
            { Text.hasOwnProperty, &Dobject_prototype_hasOwnProperty, 1 },
            { Text.isPrototypeOf, &Dobject_prototype_isPrototypeOf, 0 },
            { Text.propertyIsEnumerable,
              &Dobject_prototype_propertyIsEnumerable, 0 },
        ];

        DnativeFunction.initialize(op, nfd, Property.Attribute.DontEnum);
    }

private:
    Dfunction _constructor;
    Dobject _prototype;
}


/*********************************************
 * Initialize the built-in's.
 */
void dobject_init()
{
    if(Dobject.getPrototype !is null)
        return;                 // already initialized for this thread

    Dobject.initialize();
    Dboolean.initialize();
    Dstring.initialize();
    Dnumber.initialize();
    Darray.initialize();
    Dmath.initialize();
    Ddate.initialize();
    Dregexp.initialize();
    Derror.initialize();


    syntaxerror.D0.init;
    evalerror.D0.init;
    referenceerror.D0.init;
    rangeerror.D0.init;
    typeerror.D0.init;
    urierror.D0.init;
}
/*Not used anyway
void dobject_term()
{

    memset(&program, 0, ThreadContext.sizeof - Thread.sizeof);
}
*/
