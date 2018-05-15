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

import dmdscript.errmsgs;

debug import std.stdio;

//==============================================================================
///
final class PropTable
{
    import dmdscript.value : Value, DError;
    import dmdscript.primitive : PropertyKey;
    import dmdscript.dobject : Dobject;
    import dmdscript.callcontext : CallContext;
    import dmdscript.dfunction : Dfunction;
    import dmdscript.RandAA : RandAA;

    ///
    alias Table = RandAA!(PropertyKey, Property, false);

    static struct SpecialSymbols
    {
    static:
        PropertyKey opAssign;

        static this()
        {
            opAssign = PropertyKey.symbol("opAssign");
        }
    }


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
    Property* getProperty(in ref PropertyKey key)
    {
        for (auto t = cast(PropTable)this; t !is null; t = t._previous)
        {
            if (auto p = t._table.findExistingAlt(key, key.hash))
                return cast(typeof(return))p;
        }
        return null;
    }

    @trusted
    Value* getOwnData(in PropertyKey key)
    {
        if (auto prop = _table.findExistingAlt(key, key.hash))
        {
            assert(!prop.isAccessor);
            return &prop._value;
        }
        return null;
    }

    //--------------------------------------------------------------------
    ///
    @safe
    Property* getOwnProperty(in ref PropertyKey k)
    {
        return _table.findExistingAlt(k, k.hash);
    }

    //--------------------------------------------------------------------
    ///
    Value* get(in ref PropertyKey key, CallContext cc, Dobject othis)
    {
        if (auto p = getProperty(key))
            return p.get(cc, othis);
        return null;
    }

    //--------------------------------------------------------------------
    ///
    DError* set(in ref PropertyKey key, ref Value value,
                in Property.Attribute attributes,
                CallContext cc, Dobject othis, in bool extensible)
    {
        if      (auto p = _table.findExistingAlt(key, key.hash))
        {
            auto na = cast(Property.Attribute)attributes;
            if (!p.canSetValue(na))
            {
                if (p.IsSilence)
                    return null;
                else
                    return CannotPutError(cc); // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
            }
            if (!_canExtend(key))
            {
                if (p.IsSilence)
                    return null;
                else
                    return CannotPutError(cc); // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
            }

            return p.setForce(value, cc, othis);
        }
        else if (auto p = getProperty(SpecialSymbols.opAssign))
        {
            auto na = cast(Property.Attribute)attributes;
            if (!p.canSetValue(na))
            {
                if (p.IsSilence)
                    return null;
                else
                    return CannotPutError(cc); //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
            }
            return p.setForce(value, cc, othis);
        }
        else if (extensible)
        {
            auto p = Property(value, attributes);
            _table.insertAlt(key, p, key.hash);
            return null;
        }
        else
        {
            return CannotPutError(cc);
        }
    }

    //--------------------------------------------------------------------
    ///
    @safe
    bool config(in ref PropertyKey key, ref Property prop, in bool extensible)
    {
        if      (auto p = _table.findExistingAlt(key, key.hash))
        {
            return p.config(prop);
        }
        else if (extensible)
        {
            _table.insertAlt(key, prop, key.hash);
            return true;
        }
        else
            return false;
    }


    ///
    @safe
    bool config(in ref PropertyKey key, in Property.Attribute attributes,
                in bool extensible)
    {

        if      (auto p = _table.findExistingAlt(key, key.hash))
        {
            return p.config(attributes);
        }
        else if (extensible)
        {
            if (!_canExtend(key))
            {
                return false;
            }

            Value v;
            auto p = Property(v, attributes);
            _table.insertAlt(key, p, key.hash);
        }
        else
            return false;
        return true;
    }

    /// ditto
    @safe
    bool config(in ref PropertyKey key, ref Value value,
                in Property.Attribute attributes, in bool extensible)
    {
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
    bool configGetter(in ref PropertyKey key, Dfunction getter,
                      in Property.Attribute attributes, in bool extensible)
    {
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
    bool configSetter(in ref PropertyKey key, Dfunction setter,
                      in Property.Attribute attributes, in bool extensible)
    {
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
    bool canset(in ref PropertyKey key) const
    {
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
    bool del(in ref PropertyKey key)
    {
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
    Property* opBinaryRight(string OP : "in")(in ref PropertyKey key)
    {
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
package:

//------------------------------------------------------------------------------
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

        Silent         = 0x0800,
        SilentReadOnly = ReadOnly | Silent,
    }

    //--------------------------------------------------------------------
    ///
    @trusted @nogc pure nothrow
    this(ref Value v, in Attribute a)
    {
        _value = v;
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

    // See_Also: Ecma-262-v7/6.2.4.5
    this(Dobject obj, CallContext cc)
    {
        bool valueOrWritable = false;

        assert(obj);

        _attr = getAttribute(cc, obj);
        if (auto v = obj.Get(Key.value, cc))
        {
            _value = *v;
            valueOrWritable = true;
        }
        else
            valueOrWritable = 0 == (_attr & Attribute.ReadOnly);

        if (auto v = obj.Get(Key.get, cc))
        {
            if (valueOrWritable)
                throw CannotPutError.toThrow; // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
            _attr |= Attribute.Accessor;
            _Get = cast(Dfunction)v.toObject(cc);
            if (_Get is null)
                throw CannotPutError.toThrow; // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        }

        if (auto v = obj.Get(Key.set, cc))
        {
            if (valueOrWritable)
                throw CannotPutError.toThrow; // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
            _attr |= Attribute.Accessor;
            _Set = cast(Dfunction)v.toObject(cc);
            if (_Set is null)
                throw CannotPutError.toThrow; // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        }
    }

    // See_Also: Ecma-262-v7/6.2.4.5
    this(ref Value v, Dobject obj, CallContext cc)
    {
        _attr = getAttribute(cc, obj);
        _value = v;
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
        return 0 != (_attr & Attribute.Silent);
    }
    /// ditto
    @trusted
    bool config(ref Value v, Attribute a)
    {
        if      (canBeData(a))
        {
            _attr = a;
            _value = v;
            return true;
        }
        else if (_attr & Attribute.Accessor)
            return 0 != (_attr & Attribute.Silent);
        else
            return _value == v || (0 != (_attr & Attribute.Silent));
    }

    ///
    @safe @nogc pure nothrow
    bool config (ref Property p)
    {
        auto na = p._attr;
        if      (p.isAccessor ? canBeAccessor(na) : canBeData(na))
        {
            this = p;
            return true;
        }
        else if (_attr & Attribute.Silent)
            return true;
        else
            return this == p;
    }

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
    Value* get(CallContext cc, Dobject othis)
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
    bool canSetValue(ref Attribute a) const
    {
        if (_attr & Attribute.Accessor)
        {
            if (a & Attribute.DontOverride)
                return false;

            a = a | Attribute.Accessor & ~Attribute.ReadOnly
                & ~Attribute.Silent;
        }
        else
        {
            if ((a & Attribute.DontOverride) && !_value.isEmpty)
                return false;

            if (_attr & Attribute.ReadOnly)
                return false;

            a = a & ~Attribute.Accessor & ~Attribute.DontOverride
                & ~Attribute.Silent;
        }
        return true;
    }

    //--------------------------------------------------------------------
    ///
    DError* setForce(ref Value v, CallContext cc, Dobject othis,)
    {
        if (_attr & Attribute.Accessor)
        {
            if (_Set !is null)
            {
                Value ret;
                return _Set.Call(cc, othis, ret, [v]);
            }
        }
        else
        {
            _value.put(v);
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

    ///
    @property @safe @nogc pure nothrow
    bool IsSilence() const
    {
        return 0 != (_attr & Attribute.Silent);
    }

    //--------------------------------------------------------------------
    /// See_Also: Ecma-262-v7/6.2.4.4
    Dobject toObject(CallContext cc)
    {
        import std.exception : enforce;
        enum Attr = Attribute.DontConfig;

        auto obj = cc.dglobal.dObject();
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

private static:

    Attribute getAttribute(CallContext cc, Dobject obj)
    {
        bool valueOrWritable = false;
        assert(obj !is null);

        Attribute attr;
        if (auto v = obj.Get(Key.enumerable, cc))
        {
            if (!v.toBoolean)
                attr |= Attribute.DontEnum;
        }
        else
            attr |= Attribute.DontEnum;

        if (auto v = obj.Get(Key.configurable, cc))
        {
            if (!v.toBoolean)
                attr |= Attribute.DontConfig;
        }
        else
            attr |= Attribute.DontConfig;

        if (auto v = obj.Get(Key.writable, cc))
        {
            if (!v.toBoolean)
                attr |= Attribute.ReadOnly;
        }
        else
            attr |= Attribute.ReadOnly;

        return attr;
    }

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
}

