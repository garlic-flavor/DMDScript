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

// import dmdscript.script;
// import dmdscript.value;
// import dmdscript.identifier;
// import dmdscript.dobject;

// import dmdscript.RandAA;

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
        Deleted        = 0x0010,
        // Locked         = 0x0020,
        DontOverride   = 0x0040, // pseudo for an argument of a setter method
        KeyWord        = 0x0080,
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

    @property @safe @nogc pure nothrow
    Attribute attributes() const
    {
        return _attr;
    }

    //
    @trusted @nogc pure nothrow
    bool canExtendWith(ref Value v, ref Attribute a)
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
    bool canExtendWith(Dfunction getter, Dfunction setter, ref Attribute a)
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
    bool extend(ref Value v, Attribute a)
    {
        if (canExtendWith(v, a))
        {
            _attr = a;
            _value = v;
            return true;
        }
        return false;
    }

    //
    @trusted @nogc pure nothrow
    bool extend(Dfunction getter, Dfunction setter, Attribute a)
    {
        auto na = a;
        if (canExtendWith(getter, setter, a))
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
                    return null;
                }
            }
        }
        else
            return &_value;

        return null;
    }

    //
    DError* set(ref Value v, in Attribute attr,
                ref CallContext cc, Dobject othis,)
    {
        if (_attr & Attribute.Accessor)
        {
            if (_Set !is null)
            {
                Value ret;
                return _Set.Call(cc, othis, ret, [v]);
            }
            else
                return null;
        }
        else if (0 == (_attr & Attribute.ReadOnly))
            _value = v;
        return null;
    }

    //
    @property @safe @nogc pure nothrow
    bool isAccessor() const
    {
        return 0 == (_attr & Attribute.Accessor);
    }

    //
    @property @safe @nogc pure nothrow
    bool isKeyWord() const
    {
        return 0 == (_attr & Attribute.KeyWord);
    }

    //
    @property @safe @nogc pure nothrow
    bool writable() const
    {
        return 0 == (_attr & Attribute.ReadOnly);
    }

    //
    @safe @nogc pure nothrow
    void preventExtending()
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

    deprecated @property
    auto ref value() inout
    {
        return _value;
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
    @safe
    Property* getProperty(ref Value key)
    {
        return _getProperty(key, key.toHash);
    }

    Value* get(ref Value key, in size_t hash, ref CallContext cc, Dobject othis)
    {
        if (auto p = _getProperty(key, hash))
            p.get(cc, othis);
        return null;
    }

    Value* get(in d_uint32 index, ref CallContext cc, Dobject othis)
    {
        Value key;

        key.putVnumber(index);
        if (auto p = _getProperty(key, Value.calcHash(index)))
            p.get(cc, othis);
        return null;
    }

    Value* get(in d_string name, in size_t hash, ref CallContext cc,
               Dobject othis)
    {
        Value key;

        key.putVstring(name);
        if (auto p = _getProperty(key, hash))
            p.get(cc, othis);
        return null;
    }

    /*******************************
     * Determine if property exists for this object.
     * The enumerable flag means the DontEnum attribute cannot be set.
     */
    @safe
    bool hasownproperty(ref Value key, in int enumerable)
    {
        if (auto p = key in _table)
            return !enumerable || p.enumerable;
        return false;
    }

    @trusted
    int hasproperty(in d_string name)
    {
        Value key;
        key.putVstring(name);
        return _hasproperty(key, key.toHash) is null ? 0 : 1;
    }

    Value* put(ref Value key, size_t hash, ref Value value,
               in Property.Attribute attributes)
    {
        assert(key.toHash == hash);

        if (auto p = _table.findExistingAlt(key, hash))
        {
            auto na = cast(Property.Attribute)attributes;
            if (!p.canExtendWith(value, na))
            {
                if (p.isKeyWord)
                    return null;
                return &vundefined;
            }

            for (auto t = _previous; t !is null; t = t._previous)
            {
                if (auto p2 = t._table.findExistingAlt(key, hash))
                {
                    if (!p2.writable || (p.isAccessor && !p.configurable))
                    {
                        p.preventExtending;
                        return &vundefined;
                    }
                    break;
                }
            }

            p.extend(value, na);

            return null;
        }
        else
        {
            auto p = Property(value, attributes);
            _table.insertAlt(key, p, hash);
            return null;
        }
    }

    @trusted
    Value* put(in d_string name, ref Value value,
               in Property.Attribute attributes)
    {
        Value key;

        key.putVstring(name);
        return put(key, Value.calcHash(name), value, attributes);
    }

    @trusted
    Value* put(in d_uint32 index, ref Value value,
               in Property.Attribute attributes)
    {
        Value key;

        key.putVnumber(index);
        return put(key, Value.calcHash(index), value, attributes);
    }

    @trusted
    Value* put(in d_uint32 index, in d_string str,
               in Property.Attribute attributes)
    {
        Value key;
        Value value;

        key.putVnumber(index);
        value.putVstring(str);
        return put(key, Value.calcHash(index), value, attributes);
    }

    @trusted
    int canput(in d_string name)
    {
        Value v;

        v.putVstring(name);

        return _canput(v, v.toHash);
    }

    @trusted
    int del(d_string name)
    {
        Value v;

        v.putVstring(name);
        return _del(v);
    }

    @trusted
    int del(d_uint32 index)
    {
        Value v;

        v.putVnumber(index);
        return _del(v);
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
    Property* _getProperty(ref Value key, in size_t hash)
    {
        assert(key.toHash == hash);
        for (auto t = this; t !is null; t = t._previous)
        {
            if (auto p = t._table.findExistingAlt(key, hash))
                return p;
        }
        return null;
    }

    @safe
    Property* _hasproperty(ref Value key, in size_t hash)
    {
        for (auto t = this; t !is null; t = t._previous)
        {
            if (auto p = t._table.findExistingAlt(key, hash))
                return p;
        }
        return null;
    }

    @safe
    int _canput(ref Value key, size_t hash)
    {
        Property* p;
        PropTable t;

        t = this;
        do
        {
            //p = *key in t.table;
             p = t._table.findExistingAlt(key, hash);
            if(p)
            {
                return p.writable;
            }
            t = t._previous;
        } while(t);
        return true;                    // success
    }

    @safe
    int _del(ref Value key)
    {
        Property* p;

        p = key in _table;
        if(p)
        {
            if(!p.deletable)
                return false;
            _table.remove(key);
        }
        return true;                    // not found
    }

}



