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

// See_Also: Ecma-262-v7:6.1.7.1 Property Attributes
struct Property
{
    import dmdscript.dfunction : Dfunction;
    import dmdscript.dobject : Dobject;
    import dmdscript.script : CallContext;
    import dmdscript.value : Value, DError;

    // attribute flags
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

    //
    @trusted @nogc pure nothrow
    this(ref Value v, in Attribute a)
    {
        _value = v;
        _attr = a & ~Attribute.Accessor & ~Attribute.DontOverride;
    }

    //
    @trusted @nogc pure nothrow
    this(Dfunction getter, Dfunction setter, in Attribute a)
    {
        _Get = getter;
        _Set = setter;
        _attr = a | Attribute.Accessor & ~Attribute.DontOverride &
            ~Attribute.ReadOnly;
    }

    //
    @trusted @nogc pure nothrow
    bool canBeData(ref Attribute a)
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

    //
    @trusted @nogc pure nothrow
    bool canBeAccessor(ref Attribute a)
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


    //
    @trusted @nogc pure nothrow
    bool config(ref Value v, Attribute a)
    {
        if (canBeData(a))
        {
            _attr = a;
            _value = v;
            return true;
        }
        return false;
    }

    //
    @trusted @nogc pure nothrow
    bool config(Dfunction getter, Dfunction setter, Attribute a)
    {
        auto na = a;
        if (canBeAccessor(a))
        {
            _attr = a;
            _Get = getter;
            _Set = setter;
            return true;
        }
        return false;
    }

    //
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
                    debug throw err.toScriptException;
                    else return null;
                }
            }
        }
        else
            return &_value;

        return null;
    }

    //
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


    //
    DError* set(ref Value v, in Attribute a,
                ref CallContext cc, Dobject othis,)
    {
        auto na = cast(Attribute)a;
        if (!canSetValue(na))
            return null;

        _attr = na;
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
            _value = v;
        }
        return null;
    }

    //
    @property @safe @nogc pure nothrow
    bool isAccessor() const
    {
        return 0 == (_attr & Attribute.Accessor);
    }

    @property @safe @nogc pure nothrow
    bool isNoneAttribute() const
    {
        return Attribute.None == _attr;
    }

    //
    @property @safe @nogc pure nothrow
    bool writable() const
    {
        return 0 == (_attr & Attribute.ReadOnly);
    }

    //
    @safe @nogc pure nothrow
    void preventExtensions()
    {
        if (_attr & Attribute.Accessor)
            _attr |= Attribute.DontConfig;
        else
            _attr |= Attribute.ReadOnly;
    }

    //
    @property @safe @nogc pure nothrow
    bool enumerable() const
    {
        return 0 == (_attr & Attribute.DontEnum);
    }

    //
    @property @safe @nogc pure nothrow
    bool deletable() const
    {
        return 0 == (_attr & (Attribute.DontDelete | Attribute.DontConfig));
    }

    //
    @property @safe @nogc pure nothrow
    bool configurable() const
    {
        return 0 == (_attr & Attribute.DontConfig);
    }

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
}

// See_Also: Ecma-262-v7:6.2.4 The Property Descriptor Specification Type
/+
@safe @nogc pure nothrow
bool isAccessorDescriptor(in Property* desc)
{
    if (desc is null) return false;
    if (desc.Get is null && desc.Set is null) return false;
    return true;
}
@safe @nogc pure nothrow
bool isDataDescriptor(in Property* desc)
{
    if (desc is null) return false;
    if (desc.value.isUndefined && !desc.writable) return false;
    return true;
}
@safe @nogc pure nothrow
bool isGenericDescriptor(in Property* desc)
{
    if (desc is null) return false;
    if (!isAccessorDescriptor(desc) && !isDataDescriptor(desc)) return true;
    return false;
}

Dobject toObject(Property* desc)
{
    if (desc is null) return null;

    auto obj = new Dobject(Dobject.getPrototype);
    assert(obj !is null);

    obj.Put("value", &(desc.value), Property.Attribute.None);

    Value v;
    v.putVboolean(desc.writable ? d_true : d_false);
    obj.Put("writable", &v, Property.Attribute.None);

    if (desc.Get !is null)
        obj.Put("get", desc.Get, Property.Attribute.None);
    if (desc.Set !is null)
        obj.Put("set", desc.Set, Property.Attribute.None);

    v.putVboolean(desc.enumerable ? d_true : d_false);
    obj.Put("enumerable", &v, Property.Attribute.None);

    v.putVboolean(desc.configurable ? d_true : d_false);
    obj.Put("configurable", &v, Property.Attribute.None);

    return obj;
}
+/
/*********************************** PropTable *********************/
final class PropTable
{
    import dmdscript.dobject : Dobject;
    import dmdscript.script : CallContext, d_uint32, d_string, vundefined;
    import dmdscript.value : Value;
    import dmdscript.RandAA : RandAA;

    //
    @safe pure nothrow
    this()
    {
        _table = new RandAA!(Value, Property);
    }

    //
    int opApply(scope int delegate(ref Property) dg)
    {
        return _table.opApply(dg);
    }

    //
    int opApply(scope int delegate(ref Value, ref Property) dg)
    {
        return _table.opApply(dg);
    }

    /*******************************
     * Look up name and get its corresponding Property.
     * Return null if not found.
     */
    @trusted
    Property* getProperty(in ref Value key, in size_t hash)
    {
        assert(Value.calcHash(key) == hash);
        for (auto t = cast(PropTable)this; t !is null; t = t._previous)
        {
            if (auto p = t._table.findExistingAlt(key, hash))
                return cast(typeof(return))p;
        }
        return null;
    }

    @safe
    Property* getOwnProperty(in ref Value key, in size_t hash)
    {
        return _table.findExistingAlt(key, hash);
    }

    Value* get(in ref Value key, in size_t hash, ref CallContext cc,
               Dobject othis)
    {
        if (auto p = getProperty(key, hash))
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

    Value* set(in ref Value key, in size_t hash, ref Value value,
               in Property.Attribute attributes,
               ref CallContext cc, Dobject othis)
    {
        assert(Value.calcHash(key) == hash);

        if (auto p = _table.findExistingAlt(key, hash))
        {
            auto na = cast(Property.Attribute)attributes;
            if (!p.canSetValue(na))
            {
/* not used?
                if (p.isKeyWord)
                    return null;
*/
                return &vundefined;
            }

            if (!_canExtend(key, hash))
            {
                p.preventExtensions;
                return &vundefined;
            }

            p.set(value, attributes, cc, othis);

            return null;
        }
        else
        {
            if (!_canExtend(key, hash))
            {
                return &vundefined;
            }

            auto p = Property(value, attributes);
            _table.insertAlt(key, p, hash);
            return null;
        }
    }

    //
    Value* config(in ref Value key, in size_t hash, ref Value value,
                  in Property.Attribute attributes)
    {
        assert(Value.calcHash(key) == hash);

        if (auto p = _table.findExistingAlt(key, hash))
        {
            auto na = cast(Property.Attribute)attributes;
            if (!p.canBeData(na))
            {
                return &vundefined;
            }

            if (!_canExtend(key, hash))
            {
                p.preventExtensions;
                return &vundefined;
            }

            *p = Property(value, na);

            return null;
        }
        else
        {
            if (!_canExtend(key, hash))
            {
                return &vundefined;
            }

            auto p = Property(value, attributes);
            _table.insertAlt(key, p, hash);
            return null;
        }
    }

    @safe
    bool canset(in ref Value key, in size_t hash)
    {
        auto t = this;
        do
        {
            if (auto p = t._table.findExistingAlt(key, hash))
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

    @safe
    bool del(ref Value key)
    {
        if(auto p = key in _table)
        {
            if(!p.deletable)
                return false;
            _table.remove(key);
        }
        return true;                    // not found
    }

    @property @safe pure nothrow
    Value[] keys()
    {
        return _table.keys;
    }

    @property @safe @nogc pure nothrow
    size_t length() const
    {
        return _table.length;
    }

    @property @safe @nogc pure nothrow
    void previous(PropTable p)
    {
        _previous = p;
    }

    @safe
    Property* opBinaryRight(string OP : "in")(auto ref Value index)
    {
        return index in _table;
    }

private:
    RandAA!(Value, Property) _table;
    PropTable _previous;

    @safe
    bool _canExtend(in ref Value key, size_t hash)
    {
        for (auto t = _previous; t !is null; t = t._previous)
        {
            if (auto p = t._table.findExistingAlt(key, hash))
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



