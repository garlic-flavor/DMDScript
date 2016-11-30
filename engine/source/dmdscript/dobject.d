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
import dmdscript.value : Value, DError, vundefined;
import dmdscript.dfunction : Dfunction, Dconstructor;
import dmdscript.dnative : DnativeFunction;
import dmdscript.errmsgs;
import dmdscript.text;

//debug = LOG;

/************************** Dobject_constructor *************************/

class DobjectConstructor : Dconstructor
{
    this()
    {
        import dmdscript.property : Property;

        super(1, Dfunction.getPrototype);
        if(Dobject.getPrototype)
        {
            DefineOwnProperty(Text.prototype, Dobject.getPrototype,
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

        ret.put(o);
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
                ret.put(o);
                result = null;
            }
        }
        return result;
    }
}


/* ===================== Dobject_prototype_toString ================ */

DError* Dobject_prototype_toString(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
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
    ret.put(str);
    return null;
}

/* ===================== Dobject_prototype_toLocaleString ================ */

DError* Dobject_prototype_toLocaleString(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.2.4.3
    //	"This function returns the result of calling toString()."

    Value* v;

    //writef("Dobject.prototype.toLocaleString(ret = %x)\n", ret);
    v = othis.Get(Text.toString, cc);
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
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    ret.put(othis);
    return null;
}

/* ===================== Dobject_prototype_toSource ================ */

DError* Dobject_prototype_toSource(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import dmdscript.property : Property;

    d_string buf;
    int any;

    buf = "{";
    any = 0;
    foreach(Value key, Property p; othis.proptable)
    {
        if (p.enumerable /*&& p.deleted /* not used?*/)
        {
            if(any)
                buf ~= ',';
            any = 1;
            buf ~= key.toString();
            buf ~= ':';
            buf ~= p.get(cc, othis).toSource(cc);
        }
    }
    buf ~= '}';
    ret.put(buf);
    return null;
}

/* ===================== Dobject_prototype_hasOwnProperty ================ */

DError* Dobject_prototype_hasOwnProperty(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.2.4.5
    Value* v;

    v = arglist.length ? &arglist[0] : &vundefined;
    ret.put(othis.proptable.getOwnProperty(*v, 0) !is null);
    return null;
}

/* ===================== Dobject_prototype_isPrototypeOf ================ */

DError* Dobject_prototype_isPrototypeOf(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
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

    ret.put(result);
    return null;
}

/* ===================== Dobject_prototype_propertyIsEnumerable ================ */

DError* Dobject_prototype_propertyIsEnumerable(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.2.4.7
    Value* v;

    v = arglist.length ? &arglist[0] : &vundefined;
    if (auto p = othis.proptable.getOwnProperty(*v, v.toHash))
        ret.put(p.enumerable);
    else
        ret.put(false);
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
    import dmdscript.property : Property, PropTable;
    import dmdscript.identifier : Identifier;

    PropTable proptable;
    d_string classname;
    Value value;

    //
    @safe pure nothrow
    this(Dobject prototype)
    {
        signature = DOBJECT_SIGNATURE;

        proptable = new PropTable;
        SetPrototypeOf(prototype);
        classname = Text.Object;
        value.put(this);
    }

    //
    // See_Also: Ecma-262-v7/6.1.7.2 - 6.1.7.3
    //

    //
    final @property @safe @nogc pure nothrow
    Dobject GetPrototypeOf()
    {
        return internal_prototype;
    }

    //
    final @property @safe @nogc pure nothrow
    bool SetPrototypeOf(Dobject prototype)
    {
        if (!_extensible)
            return false;
        internal_prototype = prototype;
        if (prototype !is null)
        {
            proptable.previous = prototype.proptable;
            debug _checkCircularPrototypeChain;
        }
        return true;
    }

    //
    final @property @safe @nogc pure nothrow
    bool IsExtensible() const
    {
        return _extensible;
    }

    //
    final @safe @nogc pure nothrow
    bool preventExtensions()
    {
        _extensible = false;
        return true;
    }

    //
    @safe
    Property* GetOwnProperty(ref Value key)
    {
        return proptable.getOwnProperty(key, key.toHash);
    }

    //
    bool HasProperty(in d_string name)
    {
        // ECMA 8.6.2.4
        Value key;
        key.put(name);
        return proptable.getProperty(key, Value.calcHash(name)) !is null;
    }

    //--------------------------------------------------------------------
    //
    Value* Get(in d_string PropertyName, ref CallContext cc)
    {
        return Get(PropertyName, Value.calcHash(PropertyName), cc);
    }

    //
    Value* Get(ref Identifier id, ref CallContext cc)
    {
        return proptable.get(id.value, id.value.hash, cc, this);
    }

    //
    Value* Get(in d_string PropertyName, in size_t hash, ref CallContext cc)
    {
        Value key;
        key.put(PropertyName);
        return proptable.get(key, hash, cc, this);
    }

    //
    Value* Get(in d_uint32 index, ref CallContext cc)
    {
        Value* v;

        Value key;
        key.put(index);
        v = proptable.get(key, Value.calcHash(index), cc, this);
        //    if (!v)
        //	v = &vundefined;
        return v;
    }

    //
    Value* Get(in d_uint32 index, ref Value vindex, ref CallContext cc)
    {
        return proptable.get(vindex, Value.calcHash(index), cc, this);
    }

    //--------------------------------------------------------------------
    //
    DError* Set(in d_string PropertyName, ref Value value,
                in Property.Attribute attributes, ref CallContext cc)
    {
        // ECMA 8.6.2.2
        Value key;
        key.put(PropertyName);
        return proptable.set(key, Value.calcHash(PropertyName), value,
                             attributes, cc, this);
    }

    //
    DError* Set(ref Identifier key, ref Value value,
                in Property.Attribute attributes, ref CallContext cc)
    {
        // ECMA 8.6.2.2
        return proptable.set(key.value, key.value.hash, value, attributes,
                             cc, this);
    }

    //
    DError* Set(in d_string name, Dobject value,
                in Property.Attribute attributes, ref CallContext cc)
    {
        // ECMA 8.6.2.2
        Value key;
        key.put(name);
        Value v;
        v.put(value);

        return proptable.set(key, Value.calcHash(name), v, attributes,
                             cc, this);
    }

    //
    DError* Set(in d_string PropertyName, in d_number n,
                in Property.Attribute attributes, ref CallContext cc)
    {
        // ECMA 8.6.2.2
        Value key;
        key.put(PropertyName);
        Value v;
        v.put(n);

        return proptable.set(key, Value.calcHash(PropertyName), v, attributes,
                             cc, this);
    }

    //
    DError* Set(in d_string PropertyName, in d_string s,
                in Property.Attribute attributes, ref CallContext cc)
    {
        // ECMA 8.6.2.2
        Value key;
        key.put(PropertyName);
        Value v;
        v.put(s);

        return proptable.set(key, Value.calcHash(PropertyName), v, attributes,
                             cc, this);
    }

    //
    DError* Set(in d_uint32 index, ref Value vindex, ref Value value,
                in Property.Attribute attributes, ref CallContext cc)
    {
        // ECMA 8.6.2.2
        return proptable.set(vindex, Value.calcHash(index), value, attributes,
                             cc, this);
    }

    //
    DError* Set(in d_uint32 index, ref Value value,
                in Property.Attribute attributes, ref CallContext cc)
    {
        // ECMA 8.6.2.2
        Value key;
        key.put(index);
        return proptable.set(key, Value.calcHash(index), value, attributes,
                             cc, this);
    }

    //--------------------------------------------------------------------
    //
    /***********************************
     * Return:
     *	TRUE	not found or successful delete
     *	FALSE	property is marked with DontDelete attribute
     */
    bool Delete(in d_string PropertyName)
    {
        // ECMA 8.6.2.5
        Value key;
        key.put(PropertyName);
        return proptable.del(key);
    }

    //
    bool Delete(in d_uint32 index)
    {
        // ECMA 8.6.2.5
        Value key;
        key.put(index);
        return proptable.del(key);
    }


    //--------------------------------------------------------------------
    //
    bool DefineOwnProperty(T : Value)(in d_string PropertyName, ref T value,
                                      in Property.Attribute attributes)
    {
        if (!_extensible)
            return false;
        Value key;
        key.put(PropertyName);
        return proptable.config(key, Value.calcHash(PropertyName), value,
                                attributes);
    }

    //
    bool DefineOwnProperty(T : Value)(
        in d_string PropertyName, in size_t hash, ref T value,
        in Property.Attribute attributes)
    {
        if (!_extensible)
            return false;
        Value key;
        key.put(PropertyName);
        return proptable.config(key, hash, value, attributes);
    }

    //
    bool DefineOwnProperty(T)(in d_string PropertyName, T v,
                              in Property.Attribute attributes)
        if (is(T : Dobject) || is(T : d_number) || is(T : d_string))
    {
        if (!_extensible)
            return false;

        Value value;
        value.put(v);

        Value key;
        key.put(PropertyName);

        return proptable.config(key, Value.calcHash(PropertyName), value,
                                attributes);
    }

    //
    @safe pure nothrow
    Value[] OwnPropertyKeys()
    {
        return proptable.keys;
    }

    DError* Call(ref CallContext cc, Dobject othis, out Value ret,
                 Value[] arglist)
    {
        return SNoCallError(classname);
    }

    DError* Construct(ref CallContext cc, out Value ret, Value[] arglist)
    {
        return SNoConstructError(classname);
    }

    //--------------------------------------------------------------------

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
        Value key;
        key.put(PropertyName);
        return proptable.canset(key, Value.calcHash(PropertyName));
    }

    int implementsDelete()
    {
        // ECMA 8.6.2 says every object implements [[Delete]],
        // but ECMA 11.4.1 says that some objects may not.
        // Assume the former is correct.
        return true;
    }

    final @trusted
    DError* DefaultValue(ref CallContext cc, out Value ret, in d_string Hint)
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

            v = Get(htab, Value.calcHash(htab), cc);

            if(v && !v.isPrimitive())   // if it's an Object
            {
                DError* a;
                //CallContext* cc2;

                o = v.object;
                //cc2 = &Program.getProgram().callcontext;
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

    DError* HasInstance(ref CallContext cc, out Value ret, ref Value v)
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
        import dmdscript.iterator : Iterator;

        auto i = new Iterator;

        i.ctor(this);
        v.put(i);
        return null;
    }

    @disable
    bool DefineOwnProperty(ref Value key, ref Property desc)
    {
        // assert(proptable !is null);
        // if      (auto p = proptable.getProperty(key))
        // {
        //     if (p.canOverrideWith(desc))
        //     {
        //         p.overrideWith(desc);
        //         return true;
        //     }
        // }
        // else if (!isExtensible)
        // {

        //     return false;
        // }
        // else
        // {
        // }

        return false;
    }

private:
    Dobject internal_prototype;
    bool _extensible = true;
    enum uint DOBJECT_SIGNATURE = 0xAA31EE31;
    uint signature;

    invariant()
    {
        assert(signature == DOBJECT_SIGNATURE);
    }

    // See_Also:
    // Ecma-272-v7:6.1.7.3 Invariants of the Essential Internal Methods
    debug @trusted @nogc pure nothrow
    void _checkCircularPrototypeChain() const
    {
        for (auto ite = cast(Dobject)internal_prototype; ite !is null;
             ite = ite.internal_prototype)
            assert(this !is ite);
        if (internal_prototype !is null)
            internal_prototype._checkCircularPrototypeChain;
    }

public static:
    @safe @nogc nothrow
    Dfunction getConstructor()
    {
        assert(_constructor !is null);
        return _constructor;
    }

    @safe @nogc nothrow
    Dobject getPrototype()
    {
        assert(_prototype !is null);
        return _prototype;
    }

    void initialize()
    {
        import dmdscript.dnative : NativeFunctionData;

        _prototype = new DobjectPrototype();
        Dfunction.initialize();
        _constructor = new DobjectConstructor();

        Dobject op = _prototype;
        Dobject f = Dfunction.getPrototype;

        op.DefineOwnProperty(Text.constructor, _constructor, Property.Attribute.DontEnum);

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

private static:
    Dfunction _constructor;
    Dobject _prototype;
}


/*********************************************
 * Initialize the built-in's.
 */
void dobject_init()
{
    import dmdscript.dboolean : Dboolean;
    import dmdscript.dstring : Dstring;
    import dmdscript.dnumber : Dnumber;
    import dmdscript.darray : Darray;
    import dmdscript.dmath : Dmath;
    import dmdscript.ddate : Ddate;
    import dmdscript.dregexp : Dregexp;
    import dmdscript.derror : Derror;
    import dmdscript.protoerror : syntaxerror, evalerror, referenceerror,
        rangeerror, typeerror, urierror;

    if(Dobject._prototype !is null)
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


    syntaxerror.D0.init();
    evalerror.D0.init();
    referenceerror.D0.init();
    rangeerror.D0.init();
    typeerror.D0.init();
    urierror.D0.init();
}
