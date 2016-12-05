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
import dmdscript.text : Key;

//debug = LOG;

//==============================================================================
class DobjectConstructor : Dconstructor
{
    this()
    {
        import dmdscript.property : Property;

        super(1, Dfunction.getPrototype);
        if(Dobject.getPrototype)
        {
            DefineOwnProperty(Key.prototype, Dobject.getPrototype,
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

//------------------------------------------------------------------------------
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

//------------------------------------------------------------------------------
DError* Dobject_prototype_toLocaleString(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.2.4.3
    //	"This function returns the result of calling toString()."

    Value* v;

    //writef("Dobject.prototype.toLocaleString(ret = %x)\n", ret);
    v = othis.Get(Key.toString, cc);
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

//------------------------------------------------------------------------------
DError* Dobject_prototype_valueOf(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    ret.put(othis);
    return null;
}

//------------------------------------------------------------------------------
DError* Dobject_prototype_toSource(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import dmdscript.property : Property, PropertyKey;

    d_string buf;
    int any;

    buf = "{";
    any = 0;
    foreach(PropertyKey key, Property p; othis.proptable)
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

//------------------------------------------------------------------------------
DError* Dobject_prototype_hasOwnProperty(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import dmdscript.property : PropertyKey;

    // ECMA v3 15.2.4.5
    auto key = PropertyKey(arglist.length ? arglist[0] : vundefined);
    ret.put(othis.proptable.getOwnProperty(key) !is null);
    return null;
}

//------------------------------------------------------------------------------
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

//------------------------------------------------------------------------------
DError* Dobject_prototype_propertyIsEnumerable(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import dmdscript.property : PropertyKey;
    // ECMA v3 15.2.4.7
    auto key = PropertyKey(arglist.length ? arglist[0] : vundefined);
    if (auto p = othis.proptable.getOwnProperty(key))
        ret.put(p.enumerable);
    else
        ret.put(false);
    return null;
}

//==============================================================================
class DobjectPrototype : Dobject
{
    this()
    {
        super(null);
    }
}


//==============================================================================
class Dobject
{
    import dmdscript.property : PropertyKey, Property, PropTable, StringKey;
    import dmdscript.identifier : Identifier;

    template IsKeyValue(K, V)
    {
        enum IsKeyValue = IsKey!K && IsValue!V;
    }

    PropTable proptable;
    Value value;

    //
    @safe pure nothrow
    this(Dobject prototype, d_string cn = Key.Object)
    {
        // signature = DOBJECT_SIGNATURE;

        proptable = new PropTable;
        SetPrototypeOf(prototype);
        _classname = cn;
        value.put(this);
    }

    //
    // See_Also: Ecma-262-v7/6.1.7.2 - 6.1.7.3
    //

    //--------------------------------------------------------------------
    // non-virtual
    final
    {
        //
        @property @safe @nogc pure nothrow
        d_string classname() const
        {
            return _classname;
        }

        //
        @property @safe @nogc pure nothrow
        Dobject GetPrototypeOf()
        {
            return internal_prototype;
        }

        //
        @property @safe @nogc pure nothrow
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
        @property @safe @nogc pure nothrow
        bool IsExtensible() const
        {
            return _extensible;
        }

        //
        @safe @nogc pure nothrow
        bool preventExtensions()
        {
            _extensible = false;
            return true;
        }

        Value* Get(K)(in auto ref K name, ref CallContext cc) if (IsKey!K)
        {
            static if      (is(K : PropertyKey))
            {
                if      (name.type == Value.Type.String)
                {
                    auto sk = StringKey(name);
                    return GetImpl(sk, cc);
                }
                else if (name.type == Value.Type.Number)
                {
                    auto index = cast(d_uint32)name.number;
                    return GetImpl(index, cc);
                }
                else
                {
//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// use errmsgs.
                    auto v = cast(Value)name.value;
                    throw new Exception("not a valid key ", v.toString);
                }
            }
            else static if (is(K : d_string))
            {
                auto sk = StringKey(name);
                return GetImpl(sk, cc);
            }
            else
                return GetImpl(name, cc);
        }

        DError* Set(K, V)(in auto ref K name, auto ref V value,
                          in Property.Attribute attributes, ref CallContext cc)
            if (IsKeyValue!(K, V))
        {
            // ECMA 8.6.2.2
            static if      (is(K : PropertyKey))
            {
                if      (name.type == Value.Type.String)
                {
                    auto sk = StringKey(name);
                    static if (is(V == Value))
                        return SetImpl(sk, value, attributes, cc);
                    else
                    {
                        auto v = Value(value);
                        return SetImpl(sk, v, attributes, cc);
                    }
                }
                else if (name.type == Value.Type.Number)
                {
                    auto index = cast(d_uint32)name.number;
                    static if (is(V == Value))
                        return SetImpl(index, value, attributes, cc);
                    else
                    {
                        auto v = Value(value);
                        return SetImpl(index, v, attributes, cc);
                    }
                }
                else
                {
//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// use errmsgs
                    auto v = cast(Value)name.value;
                    throw new Exception("not a valid key ", v.toString);
                }
            }
            else static if (is(K : d_string))
            {
                auto sk = StringKey(name);
                static if (is(V == Value))
                    return SetImpl(sk, value, attributes, cc);
                else
                {
                    auto v = Value(value);
                    return SetImpl(sk, v, attributes, cc);
                }
            }
            else
            {
                static if (is(V == Value))
                    return SetImpl(name, value, attributes, cc);
                else
                {
                    auto v = Value(value);
                    return SetImpl(name, v, attributes, cc);
                }
            }
        }
    }


    //--------------------------------------------------------------------
    // may virtual

    //
    @safe
    Property* GetOwnProperty(in StringKey PropertyName)
    {
        auto key = PropertyKey(PropertyName);
        return proptable.getOwnProperty(key);
    }

    //
    bool HasProperty(in d_string name)
    {
        // ECMA 8.6.2.4
        auto key = PropertyKey(name);
        return proptable.getProperty(key) !is null;
    }


    //--------------------------------------------------------------------

    //
    Value* GetImpl(in ref StringKey PropertyName, ref CallContext cc)
    {
        auto key = PropertyKey(PropertyName);
        return proptable.get(key, cc, this);
    }

    //
    Value* GetImpl(in d_uint32 index, ref CallContext cc)
    {
        Value* v;

        auto key = PropertyKey(index);
        v = proptable.get(key, cc, this);
        //    if (!v)
        //	v = &vundefined;
        return v;
    }

    //--------------------------------------------------------------------

    //
    DError* SetImpl(in ref StringKey PropertyName, ref Value value,
                in Property.Attribute attributes, ref CallContext cc)
    {
        // ECMA 8.6.2.2
        auto key = PropertyKey(PropertyName);
        return proptable.set(key, value, attributes, cc, this);
    }

    //
    DError* SetImpl(in d_uint32 index, ref Value value,
                    in Property.Attribute attributes, ref CallContext cc)
    {
        // ECMA 8.6.2.2
        auto key = PropertyKey(index);
        return proptable.set(key, value, attributes, cc, this);
    }

    //--------------------------------------------------------------------
    //
    /***********************************
     * Return:
     *	TRUE	not found or successful delete
     *	FALSE	property is marked with DontDelete attribute
     */
    bool Delete(in StringKey PropertyName)
    {
        // ECMA 8.6.2.5
        auto key = PropertyKey(PropertyName);
        return proptable.del(key);
    }

    //
    bool Delete(in d_uint32 index)
    {
        // ECMA 8.6.2.5
        auto key = PropertyKey(index);
        return proptable.del(key);
    }


    //--------------------------------------------------------------------
    //
    final
    bool DefineOwnProperty(in StringKey PropertyName,
                           in Property.Attribute attributes)
    {
        auto key = PropertyKey(PropertyName);
        return proptable.config(key, attributes);
    }

    //
    final
    bool DefineOwnProperty(T)(in auto ref StringKey PropertyName, auto ref T v,
                              in Property.Attribute attributes) if (IsValue!T)
    {
        if (!_extensible)
            return false;
        auto key = PropertyKey(PropertyName);

        static if (is(T == Value))
            return proptable.config(key, v, attributes);
        else
        {
            auto value = Value(v);
            return proptable.config(key, value, attributes);
        }
    }

    //
    final @safe pure nothrow
    PropertyKey[] OwnPropertyKeys()
    {
        return proptable.keys;
    }

    DError* Call(ref CallContext cc, Dobject othis, out Value ret,
                 Value[] arglist)
    {
        return SNoCallError(_classname);
    }

    DError* Construct(ref CallContext cc, out Value ret, Value[] arglist)
    {
        return SNoConstructError(_classname);
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
        auto key = PropertyKey(PropertyName);
        return proptable.canset(key);
    }

    int implementsDelete()
    {
        // ECMA 8.6.2 says every object implements [[Delete]],
        // but ECMA 11.4.1 says that some objects may not.
        // Assume the former is correct.
        return true;
    }

    final @trusted
    DError* DefaultValue(ref CallContext cc, out Value ret,
                         in Value.Type Hint = Value.Type.RefError)
    {
        import dmdscript.ddate : Ddate;

        Dobject o;
        Value* v;
        static enum d_string[2] table = [Key.toString, Key.valueOf];
        int i = 0;                      // initializer necessary for /W4

        // ECMA 8.6.2.6

        if(Hint == Value.Type.String ||
           (Hint == Value.Type.RefError && (cast(Ddate)this) !is null))
        {
            i = 0;
        }
        else if(Hint == Value.Type.Number ||
                Hint == Value.Type.RefError)
        {
            i = 1;
        }
        else
            assert(0);

        for(int j = 0; j < 2; j++)
        {
            auto htab = PropertyKey(table[i]);

            v = Get(htab, cc);

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
        return SNoInstanceError(_classname);
    }

    d_string getTypeof()
    {   // ECMA 11.4.3
        import dmdscript.text : Text;
        return Text.object;
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

    //
    deprecated
    @disable
    DError* CreateDataProperty(in StringKey PropertyName, ref Value value)
    {
        if (DefineOwnProperty(PropertyName, value, Property.Attribute.None))
            return null;
        else
            return CreateDataPropertyError;
    }

    //
    @disable
    DError* CreateMethodProperty(in StringKey PropertyName, ref Value value)
    {
        if (DefineOwnProperty(PropertyName, value, Property.Attribute.DontEnum))
            return null;
        else
            return CreateMethodPropertyError;
    }

    @disable
    void CreateDataPropertyOrThrow(in StringKey PropertyName, ref Value value)
    {
        if (!DefineOwnProperty(PropertyName, value, Property.Attribute.None))
            throw CreateDataPropertyError.toThrow;
    }

    @disable
    void DefinePropertyOrThrow(in StringKey PropertyName, ref Value value,
                               in Property.Attribute attr)
    {
        if (!DefineOwnProperty(PropertyName, value, attr))
            throw CreateMethodPropertyError.toThrow;
    }

    @disable
    void DefinePropertyOrThrow(in StringKey PropertyName,
                               in Property.Attribute attr)
    {
        if (!DefineOwnProperty(PropertyName, attr))
            throw CreateMethodPropertyError.toThrow;
    }

    @disable
    void DeletePropertyOrThrow(in StringKey PropertyName)
    {
        if (!Delete(PropertyName))
            throw CantDeleteError.toThrow(PropertyName);
    }


    @disable
    bool HasOwnProperty(in StringKey PropertyName)
    {
        return GetOwnProperty(PropertyName) !is null;
    }


    enum IntegrityLevel
    {
        zero, sealed, frozen,
    }

/+
    @disable
    bool SetIntegrityLevel(in IntegrityLevel il)
    {
        if (!preventExtensions)
            return false;
        auto keys = OwnPropertyKeys;
        if      (il == IntegrityLevel.sealed)
        {
            foreach(ref one; keys)
                DefinePropertyOrThrow(one, Property.Attribute.DontConfig);
        }
        else if (il == IntegrityLevel.flozen)
        {
            foreach(ref one; keys)
            {
                if (auto desc = GetOwnProperty(one))
                {
                    if (desc.isAccessorDescriptor)
                    {
                        DefinePropertyOrThrow(one,
                                              Property.Attribute.DontConfig);
                    }
                    else
                    {
                        DefinePropertyOrThrow(one,
                                              Property.Attribute.DontConfig |
                                              Property.Attribute.ReadOnly);
                    }
                }
            }
        }
        return true;
    }
+/

    @disable
    bool TestIntegrityLevel(in IntegrityLevel il)
    {
        return false;
    }


private:
    template IsKey(K)
    {
        enum IsKey = is(K : PropertyKey) || is(K : StringKey) ||
            is(K : d_string) || is(K : d_uint32);
    }

    template IsValue(V)
    {
        enum IsValue = is(V : Value) || Value.IsPrimitiveType!V;
    }

    d_string _classname;
    Dobject internal_prototype;
    bool _extensible = true;

    // I think these are not for D.
    // enum uint DOBJECT_SIGNATURE = 0xAA31EE31;
    // uint signature;
    // invariant()
    // {
    //     assert(signature == DOBJECT_SIGNATURE);
    // }

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

        op.DefineOwnProperty(Key.constructor, _constructor,
                             Property.Attribute.DontEnum);

        static enum NativeFunctionData[] nfd =
        [
            { Key.toString, &Dobject_prototype_toString, 0 },
            { Key.toLocaleString, &Dobject_prototype_toLocaleString, 0 },
            { Key.toSource, &Dobject_prototype_toSource, 0 },
            { Key.valueOf, &Dobject_prototype_valueOf, 0 },
            { Key.hasOwnProperty, &Dobject_prototype_hasOwnProperty, 1 },
            { Key.isPrototypeOf, &Dobject_prototype_isPrototypeOf, 0 },
            { Key.propertyIsEnumerable,
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
