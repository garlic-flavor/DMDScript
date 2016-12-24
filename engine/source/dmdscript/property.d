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
/// PropertyKey must have a pre-calculated hash value.
struct PropertyKey
{
    import dmdscript.value : Value;
    import dmdscript.primitive : string_t, StringKey;

    ///
    template IsKey(K)
    {
        enum IsKey = is(K : PropertyKey) || is(K : StringKey) ||
            is(T : Value) || is(K : string_t) || is(K : uint);
    }

    Value value; ///
    alias value this;

    //--------------------------------------------------------------------
    ///
    @safe @nogc pure nothrow
    this(T)(in auto ref T arg) if (IsKey!T && !is(T : Value))
    {
        value.put(arg, calcHash(arg));
    }
    /// ditto
    @safe @nogc pure nothrow
    this(T)(in ref auto T arg, in size_t hash) if (IsKey!T)
    {
        value.put(arg, hash);
    }
    /// ditto
    @safe
    this(T : Value)(ref T arg)
    {
        value.put(arg, arg.toHash);
    }

    //--------------------------------------------------------------------
    ///
    @safe @nogc pure nothrow
    void put(T)(T arg) if (Value.IsPrimitiveType!T)
    {
        value.put(arg, calcHash(arg));
    }
    /// ditto
    @safe @nogc pure nothrow
    void put(T)(T arg, size_t h) if (Value.IsPrimitiveType!T)
    {
        value.put(arg, h);
    }

    //--------------------------------------------------------------------
    ///
    @safe @nogc pure nothrow
    size_t toHash() const
    {
        return value.hash;
    }

    //--------------------------------------------------------------------
    ///
    @safe
    bool opEquals(in ref PropertyKey rvalue) const
    {
        return hash == rvalue.hash && value == rvalue.value;
    }

    //--------------------------------------------------------------------
    ///
    @safe @nogc pure nothrow
    StringKey toStringKey() const
    {
        return StringKey(value.text, value.hash);
    }

    //====================================================================
static:

    //
    alias calcHash = dmdscript.primitive.calcHash;

    //
    @safe @nogc pure nothrow
    size_t calcHash(inout ref StringKey key)
    {
        return key.hash;
    }
}

//==============================================================================

//==============================================================================
/// See_Also: Ecma-262-v7/6.1.7.1/Property Attributes
///                      /6.2.4
struct Property
{
    import dmdscript.value : Value, DError;
    import dmdscript.dfunction : Dfunction;
    import dmdscript.dobject : Dobject;
    import dmdscript.callcontext : CallContext;

    /// attribute flags
    enum Attribute : uint
    {
        None           = 0x0000,
        ReadOnly       = 0x0001,
        DontEnum       = 0x0002,
        DontDelete     = 0x0004,
        // Internal       = 0x0008,
        // Deleted        = 0x0010,
        // Locked         = 0x0020,
        DontOverride   = 0x0040, // pseudo for an argument of a setter method
        // KeyWord        = 0x0080,
        // DebugFree      = 0x0100, // for debugging help
        Instantiate    = 0x0200, // For COM named item namespace support

        DontConfig     = 0x0400, //

        Accessor       = 0x8000, // This is an Accessor Property.
    }

    ///
    template IsValue(V)
    {
        enum IsValue = is(V : Value) || Value.IsPrimitiveType!V;
    }

    //--------------------------------------------------------------------
    ///
    @trusted @nogc pure nothrow
    this(T)(auto ref T v, in Attribute a) if (IsValue!T)
    {
        _value.put(v);
        _attr = a & ~Attribute.Accessor & ~Attribute.DontOverride;
    }

    //--------------------------------------------------------------------
    @trusted @nogc pure nothrow
    this(Dfunction getter, Dfunction setter, in Attribute a)
    {
        _Get = getter;
        _Set = setter;
        _attr = a | Attribute.Accessor & ~Attribute.DontOverride &
            ~Attribute.ReadOnly;
    }

    //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    // implement this.
    // See_Also: Ecma-262-v7/6.2.4.5
    @disable
    this(ref CallContext cc, Dobject obj)
    {
        import dmdscript.errmsgs;
        bool valueOrWritable = false;

        assert(obj);
        if (auto v = obj.Get(Key.enumerable, cc))
        {
            if (!v.toBoolean)
                _attr |= Attribute.DontEnum;
        }
        else
            _attr |= Attribute.DontEnum;

        if (auto v = obj.Get(Key.configurable, cc))
        {
            if (!v.toBoolean)
                _attr |= Attribute.DontConfig;
        }
        else
            _attr |= Attribute.DontConfig;

        if (auto v = obj.Get(Key.value, cc))
        {
            _value = *v;
            valueOrWritable = true;
        }

        if (auto v = obj.Get(Key.writable, cc))
        {
            if (!v.toBoolean)
                _attr |= Attribute.ReadOnly;
            valueOrWritable = true;
        }
        else
            _attr |= Attribute.ReadOnly;

        if (auto v = obj.Get(Key.get, cc))
        {
            if (valueOrWritable)
                throw CannotPutError.toScriptException(cc); // !!!!!!!!!!!!!!!
            _attr |= Attribute.Accessor;
            _Get = cast(Dfunction)v.toObject;
            if (_Get is null)
                throw CannotPutError.toScriptException(cc); // !!!!!!!!!!!!!!!
        }

        if (auto v = obj.Get(Key.set, cc))
        {
            if (valueOrWritable)
                throw CannotPutError.toScriptException(cc); // !!!!!!!!!!!!!!!
            _attr |= Attribute.Accessor;
            _Set = cast(Dfunction)v.toObject;
            if (_Set is null)
                throw CannotPutError.toScriptException(cc); // !!!!!!!!!!!!!!!
        }
    }

    /*
    See_Also: Ecma-262-v7/9.1.6.3 ValidateAndApplyPropertyDescriptor.
    */

    //--------------------------------------------------------------------
    ///
    @trusted @nogc pure nothrow
    bool canBeData(ref Attribute a) const
    {
        auto na = a & ~Attribute.Accessor & ~Attribute.DontOverride;

        if (_attr & Attribute.Accessor)
        {
            if (a & Attribute.DontOverride)
                return false;

            if (_attr & Attribute.DontConfig)
                return false;
        }
        else
        {
            if ((a & Attribute.DontOverride) && !_value.isEmpty)
                return false;

            if ((_attr & Attribute.DontConfig) && _attr != na &&
                (~_attr & na) != Attribute.ReadOnly)
                return false;
        }
        a = na;
        return true;
    }
    /// ditto
    @trusted @nogc pure nothrow
    bool canBeAccessor(ref Attribute a) const
    {
        auto na = a | Attribute.Accessor & ~Attribute.DontOverride &
            ~Attribute.ReadOnly;

        if (_attr & Attribute.Accessor)
        {
            if ((a & Attribute.DontOverride) && _Get !is null && _Set !is null)
                return false;

            if ((_attr & Attribute.DontConfig) && _attr != na)
                return false;
        }
        else
        {
            if ((a & Attribute.DontOverride) && !_value.isEmpty)
                return false;

            if ((_attr & Attribute.DontConfig) || (_attr & Attribute.ReadOnly))
                return false;
        }
        a = na;
        return true;
    }

    //--------------------------------------------------------------------
    ///
    @safe @nogc pure nothrow
    bool config(Attribute a)
    {
        if (_attr & Attribute.Accessor)
        {
            if (canBeAccessor(a))
            {
                _attr = a;
                return true;
            }
        }
        else
        {
            if (canBeData(a))
            {
                _attr = a;
                return true;
            }
        }
        return false;
    }
    /// ditto
    @trusted @nogc pure nothrow
    bool config(T)(auto ref T v, Attribute a) if (IsValue!T)
    {
        if      (canBeData(a))
        {
            _attr = a;
            _value.put(v);
            return true;
        }
        else if (_attr & Attribute.Accessor)
            return false;
        else
            return _value == v;
    }

/*
    /// ditto
    bool configGetter(Dfunction getter, Attribute a)
    {
        if      (canBeAccessor(a))
        {
            _attr = a;
            _Get = getter;
            return true;
        }
        else if (_attr & Attribute.Accessor)
            return _Get is getter;
        else
            return false;

    }
    /// ditto
    bool configSetter(Dfunction setter, Attribute a)
    {
        if      (canBeAccessor(a))
        {
            _attr = a;
            _Set = setter;
            return true;
        }
        else if (_attr & Attribute.Accessor)
            return _Set is setter;
        else
            return false;

    }
*/

    /// ditto
    @trusted @nogc pure nothrow
    private void configSetterForce(Dfunction setter, in Attribute a)
    {
        _Set = setter;
        _attr = a;
    }
    /// ditto
    @trusted @nogc pure nothrow
    private void configGetterForce(Dfunction getter, in Attribute a)
    {
        _Get = getter;
        _attr = a;
    }

    //--------------------------------------------------------------------
    ///
    Value* get(ref CallContext cc, Dobject othis)
    {
        if (_attr & Attribute.Accessor)
        {
            if (_Get !is null)
            {
                auto ret = new Value;
                auto err = _Get.Call(cc, othis, *ret, null);
                if (err is null)
                    return ret;
                else
                {
                    debug throw err.toScriptException(cc);
                    else return null;
                }
            }
        }
        else
            return &_value;

        return null;
    }

    //--------------------------------------------------------------------
    ///
    bool canSetValue(ref Attribute a)
    {
        if (_attr & Attribute.Accessor)
        {
            if (a & Attribute.DontOverride)
                return false;

            if ((_attr & Attribute.DontConfig) &&
                _attr != (a | Attribute.Accessor & ~Attribute.ReadOnly))
                return false;

            a = a | Attribute.Accessor & ~Attribute.ReadOnly;
        }
        else
        {
            if ((a & Attribute.DontOverride) && !_value.isEmpty)
                return false;

            if (_attr & Attribute.ReadOnly)
                return false;

            if ((_attr & Attribute.DontConfig) &&
                _attr != (a & ~Attribute.DontOverride & ~Attribute.Accessor &
                          ~Attribute.ReadOnly))
                return false;

            a = a & ~Attribute.Accessor & ~Attribute.DontOverride;
        }
        return true;
    }

    //--------------------------------------------------------------------
    ///
    DError* set(T)(auto ref T _v, Attribute a,
                   ref CallContext cc, Dobject othis,)
        if (IsValue!T)
    {
        if (!canSetValue(a))
            return null;

        _attr = a;
        if (_attr & Attribute.Accessor)
        {
            if (_Set !is null)
            {
                Value ret;
                static if (is(T : Value))
                    alias v = _v;
                else
                    auto v = Value(_v);
                return _Set.Call(cc, othis, ret, [v]);
            }
        }
        else
        {
            _value.put(_v);
        }
        return null;
    }

    //--------------------------------------------------------------------
    ///
    @property @safe @nogc pure nothrow
    bool isAccessor() const
    {
        return 0 != (_attr & Attribute.Accessor);
    }

    ///
    @property @safe @nogc pure nothrow
    bool isNoneAttribute() const
    {
        return Attribute.None == _attr;
    }

    ///
    @property @safe @nogc pure nothrow
    bool writable() const
    {
        return 0 == (_attr & Attribute.ReadOnly);
    }

    ///
    @safe @nogc pure nothrow
    void preventExtensions()
    {
        if (_attr & Attribute.Accessor)
            _attr |= Attribute.DontConfig;
        else
            _attr |= Attribute.ReadOnly;
    }

    ///
    @property @safe @nogc pure nothrow
    bool enumerable() const
    {
        return 0 == (_attr & Attribute.DontEnum);
    }

    ///
    @property @safe @nogc pure nothrow
    bool deletable() const
    {
        return 0 == (_attr & (Attribute.DontDelete | Attribute.DontConfig));
    }

    ///
    @property @safe @nogc pure nothrow
    bool configurable() const
    {
        return 0 == (_attr & Attribute.DontConfig);
    }

    /// See_Also: Ecma-262-v7/6.2.4.1
    @property @trusted @nogc pure nothrow
    bool IsAccessorDescriptor() const
    {
        if (0 == (_attr & Attribute.Accessor))
            return false;
        if (_Get is null && _Set is null)
            return false;
        return true;
    }

    /// See_Also: Ecma-262-v7/6.2.4.2
    @property @trusted @nogc pure nothrow
    bool IsDataDescriptor() const
    {
        if (_attr & Attribute.Accessor)
            return false;
        if (_value.isEmpty && (_attr & Attribute.ReadOnly))
            return false;
        return true;
    }

    /// See_Also: Ecma-262-v7/6.2.4.3
    @property @safe @nogc pure nothrow
    bool IsGenericDescriptor() const
    {
        return !IsAccessorDescriptor && !IsDataDescriptor;
    }

    //--------------------------------------------------------------------
    /// See_Also: Ecma-262-v7/6.2.4.4
    @disable
    Dobject toObject()
    {
        import std.exception : enforce;
        enum Attr = Attribute.None;

        auto obj = new Dobject(Dobject.getPrototype);
        Value tmp;
        bool r;
        if (_attr & Attribute.Accessor)
        {
            tmp.put(_Get);
            obj.DefineOwnProperty(Key.get, tmp, Attr).enforce;
            tmp.put(_Set);
            obj.DefineOwnProperty(Key.set, tmp, Attr).enforce;
        }
        else
        {
            obj.DefineOwnProperty(Key.value, _value, Attr)
                .enforce;
            tmp.put(0 == (_attr & Attribute.ReadOnly));
            obj.DefineOwnProperty(Key.writable, tmp, Attr)
                .enforce;
        }
        tmp.put(0 == (_attr & Attribute.DontEnum));
        obj.DefineOwnProperty(Key.enumerable, tmp, Attr)
            .enforce;
        tmp.put(0 == (_attr & Attribute.DontConfig));
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
public static:

    // See_Also: Ecma-262-v7/6.2.4.6
    @disable
    Property* CompletePropertyDescriptor(Property* desc)
    {
        assert(desc);
        return desc;
    }
}

//==============================================================================
///
final class PropTable
{
    import dmdscript.value : Value, DError, vundefined;
    import dmdscript.primitive : string_t;
    import dmdscript.dobject : Dobject;
    import dmdscript.callcontext : CallContext;
    import dmdscript.dfunction : Dfunction;
    import dmdscript.RandAA : RandAA;

    ///
    template IsKeyValue(K, V)
    {
        enum IsKeyValue = PropertyKey.IsKey!K && Property.IsValue!V;
    }

    ///
    alias Table = RandAA!(PropertyKey, Property, false);

    //--------------------------------------------------------------------
    ///
    @safe pure nothrow
    this()
    {
        _table = new Table;
    }

    //--------------------------------------------------------------------
    ///
    int opApply(scope int delegate(ref Property) dg)
    {
        return _table.opApply(dg);
    }
    /// ditto
    int opApply(scope int delegate(ref PropertyKey, ref Property) dg)
    {
        return _table.opApply(dg);
    }

    //--------------------------------------------------------------------
    /**
    Look up name and get its corresponding Property.
    Return null if not found.
    */
    @trusted
    Property* getProperty(K)(in auto ref K k)
        if (PropertyKey.IsKey!K)
    {
        static if (is(K : PropertyKey))
            alias key = k;
        else
            auto key = PropertyKey(k);

        for (auto t = cast(PropTable)this; t !is null; t = t._previous)
        {
            if (auto p = t._table.findExistingAlt(key, key.hash))
                return cast(typeof(return))p;
        }
        return null;
    }

    //--------------------------------------------------------------------
    ///
    @safe
    Property* getOwnProperty(K)(in auto ref K k) if (PropertyKey.IsKey!K)
    {
        static if (is(K : PropertyKey))
            alias key = k;
        else
            auto key = PropertyKey(k);

        return _table.findExistingAlt(key, key.hash);
    }

    //--------------------------------------------------------------------
    ///
    Value* get(K)(in auto ref K key, ref CallContext cc, Dobject othis)
        if (PropertyKey.IsKey!K)
    {
        if (auto p = getProperty(key))
            return p.get(cc, othis);
        return null;
    }

/+
    /*******************************
     * Determine if property exists for this object.
     * The enumerable flag means the DontEnum attribute cannot be set.
     */
    deprecated
    @safe
    bool hasownproperty(ref Value key, in int enumerable)
    {
        if (auto p = key in _table)
            return !enumerable || p.enumerable;
        return false;
    }

    deprecated
    @safe
    Property* hasproperty(in ref Value key, in size_t hash)
    {
        for (auto t = this; t !is null; t = t._previous)
        {
            if (auto p = t._table.findExistingAlt(key, hash))
                return p;
        }
        return null;
    }
+/
    //--------------------------------------------------------------------
    ///
    DError* set(K, V)(in auto ref K k, auto ref V value,
                in Property.Attribute attributes,
                ref CallContext cc, Dobject othis)
        if (IsKeyValue!(K, V))
    {
        import dmdscript.errmsgs;

        static if (is(K : PropertyKey))
            alias key = k;
        else
            auto key = PrpertyKey(k);

        if (auto p = _table.findExistingAlt(key, key.hash))
        {
            auto na = cast(Property.Attribute)attributes;
            if (!p.canSetValue(na))
            {
/* not used?
                if (p.isKeyWord)
                    return null;
*/
                return CannotPutError; // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
            }

            if (!_canExtend(key))
            {
                p.preventExtensions;
                return CannotPutError; // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
            }

            return p.set(value, attributes, cc, othis);
        }
        else
        {
            if (!_canExtend(key))
            {
                return CannotPutError;
            }

            auto p = Property(value, attributes);
            _table.insertAlt(key, p, key.hash);
            return null;
        }
    }

    //--------------------------------------------------------------------
    ///
    @safe
    bool config(K)(in auto ref K k, in Property.Attribute attributes)
        if (PropertyKey.IsKey!K)
    {
        static if (is(K : PropertyKey))
            alias key = k;
        else
            auto key = PropertyKey(k);

        if (auto p = _table.findExistingAlt(key, key.hash))
        {
            return p.config(attributes);
        }
        else
        {
            if (!_canExtend(key))
            {
                return false;
            }

            auto p = Property(vundefined, attributes);
            _table.insertAlt(key, p, key.hash);
        }
        return true;
    }

    /// ditto
    @safe
    bool config(K, V)(in auto ref K k, auto ref V value,
                      in Property.Attribute attributes, in bool extensible)
        if (IsKeyValue!(K, V))
    {
        static if (is(K : PropertyKey))
            alias key = k;
        else
            auto key = PropertyKey(k);

        if      (auto p = _table.findExistingAlt(key, key.hash))
        {
            auto na = cast(Property.Attribute)attributes;
            if (!p.canBeData(na))
            {
                return false;
            }

            if (!_canExtend(key))
            {
                p.preventExtensions;
                return false;
            }

            *p = Property(value, na);

            return true;
        }
        else if (extensible)
        {
            if (!_canExtend(key))
            {
                return false;
            }

            auto p = Property(value, attributes);
            _table.insertAlt(key, p, key.hash);

            return true;
        }
        else
            return false;
    }

    /// ditto
    @safe
    bool configGetter(K)(in auto ref K k, Dfunction getter,
                         in Property.Attribute attributes, in bool extensible)
        if (PropertyKey.IsKey!K)
    {
        static if (is(K : PropertyKey))
            alias key = k;
        else
            auto key = PropertyKey(k);

        if      (auto p = _table.findExistingAlt(key, key.hash))
        {
            auto na = cast(Property.Attribute)attributes;
            if (!p.canBeAccessor(na))
            {
                return false;
            }

            if (!_canExtend(key))
            {
                p.preventExtensions;
                return false;
            }

            p.configGetterForce(getter, na);

            return true;
        }
        else if (extensible)
        {
            if (!_canExtend(key))
            {
                return false;
            }

            auto p = Property(getter, null, attributes);
            _table.insertAlt(key, p, key.hash);

            return true;
        }
        else
            return false;
    }

    /// ditto
    @safe
    bool configSetter(K)(in auto ref K k, Dfunction setter,
                         in Property.Attribute attributes, in bool extensible)
        if (PropertyKey.IsKey!K)
    {
        static if (is(K : PropertyKey))
            alias key = k;
        else
            auto key = PropertyKey(k);

        if      (auto p = _table.findExistingAlt(key, key.hash))
        {
            auto na = cast(Property.Attribute)attributes;
            if (!p.canBeAccessor(na))
            {
                return false;
            }

            if (!_canExtend(key))
            {
                p.preventExtensions;
                return false;
            }

            p.configSetterForce(setter, na);

            return true;
        }
        else if (extensible)
        {
            if (!_canExtend(key))
            {
                return false;
            }

            auto p = Property(null, setter, attributes);
            _table.insertAlt(key, p, key.hash);

            return true;
        }
        else
            return false;
    }

    //--------------------------------------------------------------------
    ///
    @trusted
    bool canset(K)(in auto ref K k) const
        if (PropertyKey.IsKey!K)
    {
        static if (is(K : PropertyKey))
            alias key = k;
        else
            auto key = PropertyKey(k);

        auto t = cast(PropTable)this;
        do
        {
            if (auto p = t._table.findExistingAlt(key, key.hash))
            {
                if (p.isAccessor)
                    return p.configurable;
                else
                    return p.writable;
            }
            t = t._previous;
        } while(t !is null);
        return true;                    // success
    }

    //--------------------------------------------------------------------
    ///
    @safe
    bool del(K)(in auto ref K k)
    {
        static if (is(K : PropertyKey))
            alias key = k;
        else
            auto key = PropertyKey(k);

        if(auto p = _table.findExistingAlt(key, key.hash))
        {
            if(!p.deletable)
                return false;
            _table.remove(key, key.hash);
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

    //--------------------------------------------------------------------
    ///
    @safe
    Property* opBinaryRight(string OP : "in", K)(in auto ref K k)
        if (PropertyKey.IsKey!K)
    {
        static if (is(K : PropertyKey))
            alias key = k;
        else
            auto key = PropertyKey(k);

        return _table.findExistingAlt(key, key.hash);
    }

    //====================================================================
private:
    Table _table;
    PropTable _previous;

    @trusted
    bool _canExtend(in ref PropertyKey key) const
    {
        for (auto t = cast(PropTable)_previous; t !is null; t = t._previous)
        {
            if (auto p = t._table.findExistingAlt(key, key.hash))
            {
                if (p.isAccessor)
                    return p.configurable;
                else
                    return p.writable;
            }
        }
        return true;
    }
}

//==============================================================================
private:

import dmdscript.primitive : StringKey, PKey = Key;
enum Key : StringKey
{
    value = PKey.value,

    writable = StringKey("writable"),
    get = StringKey("get"),
    set = StringKey("set"),
    enumerable = StringKey("enumerable"),
    configurable = StringKey("configurable"),
}

