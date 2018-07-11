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
module dmdscript.property;


debug import std.stdio;

//==============================================================================
///
final class PropTable
{
    import dmdscript.errmsgs: CannotPutError;
    import dmdscript.value: Value;
    import dmdscript.derror: Derror;
    import dmdscript.primitive: PropertyKey;
    import dmdscript.dobject: Dobject;
    import dmdscript.dfunction : Dfunction;
    import dmdscript.RandAA: RandAA;
    import dmdscript.callcontext: CallContext;

    ///
    alias Table = RandAA!(PropertyKey, Property*, false);
    private alias PA = Property.Attribute;

    //--------------------------------------------------------------------
    ///
    @safe pure nothrow
    this()
    {
        _table = new Table;
    }

    //--------------------------------------------------------------------
    ///
    auto opApply(T)(scope T dg)
    {
        import std.traits : ParameterTypeTuple;
        int result;
        foreach (ref PropertyKey k, Property* p; _table)
        {
            if (0 == (p._attr & PA.DontEnum))
            {
                static if      (1 == ParameterTypeTuple!T.length)
                    result = dg(p);
                else static if (2 == ParameterTypeTuple!T.length)
                    result = dg(k, p);
                else static assert (0);
                if (result)
                    break;
            }
        }
        return result;
    }

    //--------------------------------------------------------------------
    /**
    Look up name and get its corresponding Property.
    Return null if not found.
    */
    @trusted @nogc pure nothrow
    Property* getProperty(in ref PropertyKey key)
    {
        if (auto p = _table.findExistingAlt(key, key.hash))
            return *p;

        for (auto t = _previous; t !is null; t = t._previous)
        {
            if (auto p = t._table.findExistingAlt(key, key.hash))
                return *p;
        }
        return null;
    }

    //--------------------------------------------------------------------
    ///
    @safe @nogc pure nothrow
    Property* getOwnProperty(in ref PropertyKey k)
    {
        if (auto p = _table.findExistingAlt(k, k.hash))
            return *p;
        else
            return null;
    }

    /// ditto
    @trusted @nogc pure nothrow
    Value* getOwnData(in PropertyKey key)
    {
        if (auto prop = _table.findExistingAlt(key, key.hash))
        {
            if ((*prop).isAccessor)
                return null;
            return (*prop).getAsData;
        }
        return null;
    }

    //--------------------------------------------------------------------
    ///
    nothrow
    Derror get(in ref PropertyKey key, out Value ret, Dobject othis,
               CallContext* cc)
    {
        if (auto p = getProperty(key))
            return p.get(ret, othis, cc);
        else
        {
            ret.putSignalingUndefined(key);
            return null;
        }
    }

    //--------------------------------------------------------------------
    ///
    nothrow
    Derror set(in ref PropertyKey key, ref Value value, Dobject othis,
               in Property.Attribute a, CallContext* cc)
    {
        assert (_table !is null);

        if      (auto p = _table.findExistingAlt(key, key.hash))
            return (*p).set(value, othis, a, cc);
        else if (auto p = getProperty(SpecialSymbols.opAssign))
            return p.set(value, othis, a, cc);
        else if (a & PA.DontExtend)
        {
            if (a & PA.Silent)
                return null;
            else
                return CannotPutError(cc);
        }
        else
        {
            for (auto t = _previous; t !is null; t = t._previous)
            {
                if (auto p = t._table.findExistingAlt(key, key.hash))
                {
                    if      ((*p).isAccessor)
                        return (*p).set(value, othis, a, cc);
                    else if ((*p).writable)
                        break;
                    else if (a & PA.Silent)
                        return null;
                    else
                        return CannotPutError(cc);
                }
            }
            auto prop = new Property(value, a);
            _table.insertAlt(key, prop, key.hash);
            return null;
        }
    }

    //--------------------------------------------------------------------
    ///
    @trusted pure nothrow
    bool config(in ref PropertyKey key, Property* prop, in bool extensible)
    {
        if (auto p = toConfig(key, prop, extensible))
            return (*p).config(*prop);
        else
            return false;
    }

    /// ditto
    @trusted nothrow
    bool configGetter(in ref PropertyKey key, Dfunction getter,
                      in Property.Attribute a)
    {
        auto prop = new Property(getter, null, a);
        if (auto p = toConfig(key, prop, 0 == (a & PA.DontExtend)))
        {
            if (a & PA.DontOverwrite)
                return getter is p._Get;

            auto na = cast(PA)a;
            if (!p.canBeAccessor(na))
                return false;

            p.configGetterForce(getter, na);
            return true;
        }
        return false;
    }

    /// ditto
    @trusted nothrow
    bool configSetter(in ref PropertyKey key, Dfunction setter,
                      in Property.Attribute a)
    {
        auto prop = new Property(null, setter, a);
        if (auto p = toConfig(key, prop, 0 == (a & PA.DontExtend)))
        {
            if (a & PA.DontOverwrite)
                return setter is p._Set;

            auto na = cast(PA)a;
            if (!p.canBeAccessor(na))
                return false;

            p.configSetterForce(setter, na);
            return true;
        }
        return false;
    }

    //--------------------------------------------------------------------
    ///
    @trusted @nogc pure nothrow
    bool canset(in ref PropertyKey key) const
    {
        auto t = cast(PropTable)this;
        do
        {
            if (auto p = t._table.findExistingAlt(key, key.hash))
            {
                if ((*p).isAccessor)
                    return (*p).configurable;
                else
                    return (*p).writable;
            }
            t = t._previous;
        } while(t !is null);
        return true;                    // success
    }

    //--------------------------------------------------------------------
    ///
    @safe nothrow
    bool del(in ref PropertyKey key)
    {
        if(auto p = _table.findExistingAlt(key, key.hash))
        {
            if (!(*p).deletable)
                return false;
            try _table.remove(p);
            catch (Exception) return false;
        }
        return true;                    // not found
    }

    //--------------------------------------------------------------------
    ///
    @property @safe pure nothrow
    PropertyKey[] keys()
    {
        return _table.keys;
    }

    ///
    @property @safe @nogc pure nothrow
    size_t length() const
    {
        return _table.length;
    }

    ///
    @property @safe @nogc pure nothrow
    void previous(PropTable p)
    {
        _previous = p;
    }

    //====================================================================
private:
    Table _table;
    PropTable _previous;

    @trusted pure nothrow
    Property* toConfig(in ref PropertyKey key, Property* prop,
                       bool extensible)
    {
        if      (auto p = _table.findExistingAlt(key, key.hash))
        {
            if (!(*p).configurable || !(*p).writable)
                return null;
            else
                return *p;
        }
        else if (!extensible)
            return null;

        for (auto t = _previous; t !is null; t = t._previous)
        {
            if (auto p = t._table.findExistingAlt(key, key.hash))
            {
                if (!(*p).configurable || !(*p).writable)
                    return null;
            }
        }

        _table.insertAlt(key, prop, key.hash);
        return prop;
    }
}

//------------------------------------------------------------------------------
/// See_Also: Ecma-262-v7/6.1.7.1/Property Attributes
///                      /6.2.4
struct Property
{
    import dmdscript.value: Value;
    import dmdscript.dfunction: Dfunction;
    import dmdscript.dobject: Dobject;
    import dmdscript.callcontext: CallContext;
    import dmdscript.drealm: Drealm;
    import dmdscript.derror: Derror;
    import dmdscript.errmsgs: CannotPutError;

    /// attribute flags
    enum Attribute : uint
    {
        // attr & mask is to be stored.
        None           = 0x0000,
        ReadOnly       = 0x0001,
        DontEnum       = 0x0002,
        DontDelete     = 0x0004,
        DontConfig     = 0x0008, //

        Accessor       = 0x8000, // This is an Accessor Property.

        // the argument may contain.
        DontExtend     = 0x0010, // make new if absence
        DontOverwrite  = 0x0020, //
        Silent         = 0x0040, //

        // internal use.
        _mask          = 0x800f,
    }
    private alias A = Attribute;

    //--------------------------------------------------------------------
    ///
    this(in Attribute a)
    {
        _attr = a;
    }

    ///
    @trusted @nogc pure nothrow
    this(ref Value v, in Attribute a)
    {
        _value = v;
        _attr = a & ~A.Accessor;
    }

    //--------------------------------------------------------------------
    @trusted @nogc pure nothrow
    this(Dfunction getter, Dfunction setter, in Attribute a)
    {
        _Get = getter;
        _Set = setter;
        _attr = a | A.Accessor;
    }

    // See_Also: Ecma-262-v7/6.2.4.5
    nothrow
    this(CallContext* cc, Dobject obj)
    {
        assert(obj);

        _attr = getAttribute(obj, cc);
        Value v;
        Derror err;
        Dobject o;
        err = obj.Get(Key.value, v, cc);
        if (err is null && !v.isEmpty)
        {
            _value = v;
            _attr = _attr & ~A.Accessor;
        }
        else
        {
            _Get = null;
            _Set = null;

            err = obj.Get(Key.get, v, cc);
            if (err is null && !v.isEmpty)
            {
                v.to(o, cc);
                _Get = cast(Dfunction)o;
            }

            err = obj.Get(Key.set, v, cc);
            if (err is null && !v.isEmpty)
            {
                v.to(o, cc);
                _Set = cast(Dfunction)o;
            }

            if (_Get !is null || _Set !is null)
                _attr = _attr | A.Accessor;
            else
            {
                _value.put(obj);
                _attr = _attr & ~A.Accessor;
            }
        }
    }

    // See_Also: Ecma-262-v7/6.2.4.5
    // this(CallContext* cc, ref Value v, Dobject obj)
    // {
    //     _attr = getAttribute(obj, cc) & ~A.Accessor & A._mask;
    //     _value = v;
    // }

    //

    /*
    See_Also: Ecma-262-v7/9.1.6.3 ValidateAndApplyPropertyDescriptor.
    */
    @property @nogc pure nothrow
    Attribute attribute() const
    {
        return _attr;
    }

    @property @nogc pure nothrow
    void attribute(Attribute a)
    {
        _attr = (_attr & A.Accessor) | (a & ~A.Accessor);
    }

    //--------------------------------------------------------------------
    ///
    @trusted @nogc pure nothrow
    bool canBeData(ref Attribute a) const
    {
        auto na = a & ~A.Accessor;

        if      (a & A.DontOverwrite)
            return false;
        else if (_attr & Attribute.Accessor)
        {
            if (_attr & Attribute.DontConfig)
                return false;
        }
        else if ((_attr & A.DontConfig) || _attr & A.ReadOnly &&
                 (_attr | A.ReadOnly) != na)
                return false;

        a = na;
        return true;
    }
    /// ditto
    @trusted @nogc pure nothrow
    bool canBeAccessor(ref Attribute a) const
    {
        auto na = a | A.Accessor;

        if      (a & A.DontOverwrite)
            return false;
        else if (_attr & A.Accessor)
        {
            if ((_attr & A.DontConfig) && _attr != na)
                return false;
        }
        else if ((_attr & A.DontConfig) || (_attr & A.ReadOnly))
            return false;

        a = na;
        return true;
    }

    //--------------------------------------------------------------------
    ///
    @safe @nogc pure nothrow
    bool config (ref Property p)
    {
        auto na = p._attr;
        if      (na & A.DontOverwrite)
            return false;
        else if (p.isAccessor ? canBeAccessor(na) : canBeData(na))
        {
            this = p;
            return true;
        }
        else if (na & A.Silent)
            return true;
        else
            return this == p;
    }

    /// ditto
    @trusted @nogc pure nothrow
    private void configSetterForce(Dfunction setter, in Attribute a)
    {
        _Set = setter;
        _attr = a | A.Accessor;
    }
    /// ditto
    @trusted @nogc pure nothrow
    private void configGetterForce(Dfunction getter, in Attribute a)
    {
        _Get = getter;
        _attr = a | A.Accessor;
    }

    //--------------------------------------------------------------------
    ///
    nothrow
    Derror get(out Value ret, Dobject othis, CallContext* cc)
    {
        if (_attr & A.Accessor)
        {
            if (_Get !is null)
                return _Get.Call(cc, othis, ret, null);
        }
        else
            ret = _value;

        return null;
    }

    ///
    @property @trusted @nogc pure nothrow
    Value* getAsData()
    {
        assert ((_attr & A.Accessor) == 0);
        return &_value;
    }

    //--------------------------------------------------------------------
    ///
    nothrow
    Derror set(ref Value v, Dobject othis, in Attribute a, CallContext* cc)
    {
        if      (a & A.DontOverwrite)
            return null;
        else if (_attr & A.Accessor)
        {
            if      (_Set !is null)
            {
                Value ret;
                return _Set.Call(cc, othis, ret, [v]);
            }
            else if (a & A.Silent)
                return null;
            else
                return CannotPutError(cc);
        }
        else if      (0 == (_attr & A.ReadOnly))
        {
            _value.put(v);
            return null;
        }
        else if (a & A.Silent)
            return null;
        else
            return CannotPutError(cc);
    }

    //--------------------------------------------------------------------
    ///
    @property @safe @nogc pure nothrow
    bool isAccessor() const
    {
        return 0 != (_attr & A.Accessor);
    }

    ///
    @property @safe @nogc pure nothrow
    bool isNoneAttribute() const
    {
        return A.None == _attr;
    }

    ///
    @property @safe @nogc pure nothrow
    bool writable() const
    {
        return 0 == (_attr & A.ReadOnly);
    }

    ///
    @safe @nogc pure nothrow
    void preventExtensions()
    {
        if (_attr & A.Accessor)
            _attr |= A.DontConfig;
        else
            _attr |= A.ReadOnly;
    }

    ///
    @property @safe @nogc pure nothrow
    bool enumerable() const
    {
        return 0 == (_attr & A.DontEnum);
    }

    ///
    @property @safe @nogc pure nothrow
    bool deletable() const
    {
        return 0 == (_attr & (A.DontDelete | A.DontConfig));
    }

    ///
    @property @safe @nogc pure nothrow
    bool configurable() const
    {
        return 0 == (_attr & A.DontConfig);
    }

    // /// See_Also: Ecma-262-v7/6.2.4.1
    // @property @trusted @nogc pure nothrow
    // bool IsAccessorDescriptor() const
    // {
    //     if (0 == (_attr & A.Accessor))
    //         return false;
    //     if (_Get is null && _Set is null)
    //         return false;
    //     return true;
    // }

    // /// See_Also: Ecma-262-v7/6.2.4.2
    // @property @trusted @nogc pure nothrow
    // bool IsDataDescriptor() const
    // {
    //     if (_attr & A.Accessor)
    //         return false;
    //     if (_value.isEmpty && (_attr & A.ReadOnly))
    //         return false;
    //     return true;
    // }

    // /// See_Also: Ecma-262-v7/6.2.4.3
    // @property @safe @nogc pure nothrow
    // bool IsGenericDescriptor() const
    // {
    //     return !IsAccessorDescriptor && !IsDataDescriptor;
    // }

    //--------------------------------------------------------------------
    /// See_Also: Ecma-262-v7/6.2.4.4
    Dobject toObject(Drealm realm)
    {
        import std.exception : enforce;
        enum Attr = A.DontConfig;

        auto obj = realm.dObject();
        Value tmp;
        bool r;
        if (_attr & A.Accessor)
        {
            if (_Get !is null)
                tmp.put(_Get);
            else
                tmp.putVnull;
            obj.DefineOwnProperty(Key.get, tmp, Attr).enforce;

            if (_Set !is null)
                tmp.put(_Set);
            else
                tmp.putVnull;
            obj.DefineOwnProperty(Key.set, tmp, Attr).enforce;
        }
        else
        {
            obj.DefineOwnProperty(Key.value, _value, Attr).enforce;
            tmp.put(0 == (_attr & A.ReadOnly));
            obj.DefineOwnProperty(Key.writable, tmp, Attr).enforce;
        }
        tmp.put(0 == (_attr & A.DontEnum));
        obj.DefineOwnProperty(Key.enumerable, tmp, Attr).enforce;
        tmp.put(0 == (_attr & A.DontConfig));
        obj.DefineOwnProperty(Key.configurable, tmp, Attr).enforce;
        return obj;
    }

    //====================================================================
private:
    union
    {
        Value _value;
        struct // for an Accessor Property.
        {
            Dfunction _Get;
            Dfunction _Set;
        }
    }

    Attribute  _attr;

    //====================================================================
private static:

    nothrow
    Attribute getAttribute(Dobject obj, CallContext* cc)
    {
        bool valueOrWritable = false;
        assert(obj !is null);

        Attribute attr;
        Value v;
        Derror err;
        bool b;

        attr = A.ReadOnly | A.DontEnum | A.DontConfig;

        err = obj.Get(Key.enumerable, v, cc);
        if (err is null && !v.isEmpty)
        {
            err = v.to(b, cc);
            if (err is null && b)
                attr &= ~A.DontEnum;
        }

        err = obj.Get(Key.configurable, v, cc);
        if (err is null && !v.isEmpty)
        {
            err = v.to(b, cc);
            if (err is null && b)
                attr &= ~A.DontConfig;
        }

        err = obj.Get(Key.writable, v, cc);
        if (err is null && !v.isEmpty)
        {
            err = v.to(b, cc);
            if (err is null && b)
                attr &= ~A.ReadOnly;
        }

        return attr;
    }

}


//------------------------------------------------------------------------------
struct SpecialSymbols
{
    static this()
    {
        foreach (one; __traits(allMembers, typeof(this)))
        {
            static if (is(typeof((__traits(getMember, typeof(this), one)))
                          : PropertyKey))
            {
                __traits(getMember, typeof(this), one) =
                    PropertyKey.symbol(one);
            }
        }

    }

    static const:
    PropertyKey opAssign;
    PropertyKey toPrimitive;

    PropertyKey unscopables;
    PropertyKey iterator;
}



//==============================================================================
private:

import dmdscript.primitive : PropertyKey, PKey = Key;
enum Key : PropertyKey
{
    value = PKey.value,

    writable = PropertyKey("writable"),
    get = PropertyKey("get"),
    set = PropertyKey("set"),
    enumerable = PropertyKey("enumerable"),
    configurable = PropertyKey("configurable"),
    unwritable = PropertyKey("unwritable"),
}
