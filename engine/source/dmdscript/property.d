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

//
struct PropertyKey
{
    import dmdscript.value : Value;
    import dmdscript.identifier : Identifier;

    Value value;
    alias value this;

    @safe @nogc pure nothrow
    this(T)(T arg) if (Value.CanContain!T)
    {
        value.put(arg, Value.calcHash(arg));
    }

    @safe @nogc pure nothrow
    this(T)(T arg, in size_t h) if (Value.CanContain!T)
    {
        value.put(arg, h);
    }

    @safe @nogc pure nothrow
    this(T : Identifier)(ref T arg)
    {
        value = arg.value;
    }

    @safe
    this(T : Value)(ref T arg)
    {
        value.put(arg, arg.toHash);
    }

    @safe @nogc pure nothrow
    this(T : Value)(ref T arg, in size_t hash)
    {
        value.put(arg, hash);
    }

    @safe @nogc pure nothrow
    void put(T)(T arg) if (Value.CanContain!T)
    {
        value.put(arg, Value.calcHash(arg));
    }

    @safe @nogc pure nothrow
    void put(T)(T arg, size_t h) if (Value.CanContain!T)
    {
        value.put(arg, h);
    }

    @safe @nogc pure nothrow
    size_t toHash() const
    {
        return value.hash;
    }
}

// See_Also: Ecma-262-v7/6.1.7.1/Property Attributes
//                      /6.2.4
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

    //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    // implement this.
    // See_Also: Ecma-262-v7/6.2.4.5
    @disable
    this(ref CallContext cc, Dobject obj)
    {
        import dmdscript.text : Text;
        import dmdscript.errmsgs;
        bool valueOrWritable = false;

        assert(obj);
        if (auto v = obj.Get(Text.enumerable, Text.enumerable.hash, cc))
        {
            if (!v.toBoolean)
                _attr |= Attribute.DontEnum;
        }
        else
            _attr |= Attribute.DontEnum;

        if (auto v = obj.Get(Text.configurable, Text.configurable.hash, cc))
        {
            if (!v.toBoolean)
                _attr |= Attribute.DontConfig;
        }
        else
            _attr |= Attribute.DontConfig;

        if (auto v = obj.Get(Text.value, Text.value.hash, cc))
        {
            _value = *v;
            valueOrWritable = true;
        }

        if (auto v = obj.Get(Text.writable, Text.writable.hash, cc))
        {
            if (!v.toBoolean)
                _attr |= Attribute.ReadOnly;
            valueOrWritable = true;
        }
        else
            _attr |= Attribute.ReadOnly;

        if (auto v = obj.Get(Text.get, Text.get.hash, cc))
        {
            if (valueOrWritable)
                throw CannotPutError.toScriptException; // !!!!!!!!!!!!!!!!!!!
            _attr |= Attribute.Accessor;
            _Get = cast(Dfunction)v.toObject;
            if (_Get is null)
                throw CannotPutError.toScriptException; // !!!!!!!!!!!!!!!!!!!
        }

        if (auto v = obj.Get(Text.set, Text.set.hash, cc))
        {
            if (valueOrWritable)
                throw CannotPutError.toScriptException; // !!!!!!!!!!!!!!!!!!!
            _attr |= Attribute.Accessor;
            _Set = cast(Dfunction)v.toObject;
            if (_Set is null)
                throw CannotPutError.toScriptException; // !!!!!!!!!!!!!!!!!!!
        }
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

    // See_Also: Ecma-262-v7/6.2.4.1
    @property @trusted @nogc pure nothrow
    bool isAccessorDescriptor() const
    {
        if (0 == (_attr & Attribute.Accessor))
            return false;
        if (_Get is null && _Set is null)
            return false;
        return true;
    }

    // See_Also: Ecma-262-v7/6.2.4.2
    @property @trusted @nogc pure nothrow
    bool isDataDescriptor() const
    {
        if (_attr & Attribute.Accessor)
            return false;
        if (_value.isEmpty && (_attr & Attribute.ReadOnly))
            return false;
        return true;
    }

    // See_Also: Ecma-262-v7/6.2.4.3
    @property @safe @nogc pure nothrow
    bool isGenericDescriptor() const
    {
        return !isAccessorDescriptor && !isDataDescriptor;
    }

    // See_Also: Ecma-262-v7/6.2.4.4
    Dobject toObject()
    {
        import std.exception : enforce;
        import dmdscript.text : Text;
        enum Attr = Attribute.None;

        auto obj = new Dobject(Dobject.getPrototype);
        Value tmp;
        bool r;
        if (_attr & Attribute.Accessor)
        {
            tmp.put(_Get);
            obj.DefineOwnProperty(Text.get, Text.get.hash, tmp, Attr).enforce;
            tmp.put(_Set);
            obj.DefineOwnProperty(Text.set, Text.get.hash, tmp, Attr).enforce;
        }
        else
        {
            obj.DefineOwnProperty(Text.value, Text.value.hash, _value, Attr)
                .enforce;
            tmp.put(0 == (_attr & Attribute.ReadOnly));
            obj.DefineOwnProperty(Text.writable, Text.writable.hash, tmp, Attr)
                .enforce;
        }
        tmp.put(0 == (_attr & Attribute.DontEnum));
        obj.DefineOwnProperty(Text.enumerable, Text.enumerable.hash, tmp, Attr)
            .enforce;
        tmp.put(0 == (_attr & Attribute.DontConfig));
        obj.DefineOwnProperty(Text.configurable, Text.configurable.hash, tmp,
                              Attr).enforce;
        return obj;
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


public static:

    // See_Also: Ecma-262-v7/6.2.4.6
    @disable
    Property* CompletePropertyDescriptor(Property* desc)
    {
        assert(desc);
        return desc;
    }
}

//
final class PropTable
{
    import dmdscript.dobject : Dobject;
    import dmdscript.script : CallContext, d_uint32, d_string;
    import dmdscript.value : Value, DError;
    import dmdscript.RandAA : RandAA;

    //
    @safe pure nothrow
    this()
    {
        _table = new RandAA!(PropertyKey, Property);
    }

    //
    int opApply(scope int delegate(ref Property) dg)
    {
        return _table.opApply(dg);
    }

    //
    int opApply(scope int delegate(ref PropertyKey, ref Property) dg)
    {
        return _table.opApply(dg);
    }

    /*******************************
     * Look up name and get its corresponding Property.
     * Return null if not found.
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

    //
    @safe
    Property* getOwnProperty(in ref PropertyKey key)
    {
        return _table.findExistingAlt(key, key.hash);
    }

    Value* get(in ref PropertyKey key, ref CallContext cc, Dobject othis)
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

    //
    DError* set(in ref PropertyKey key, ref Value value,
                in Property.Attribute attributes,
                ref CallContext cc, Dobject othis)
    {
        import dmdscript.errmsgs;

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

    //
    @safe
    bool config(in ref PropertyKey key, in Property.Attribute attributes)
    {
        import dmdscript.value : vundefined;

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

    //
    @safe
    bool config(in ref PropertyKey key, ref Value value,
                in Property.Attribute attributes)
    {
        if (auto p = _table.findExistingAlt(key, key.hash))
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
        }
        else
        {
            if (!_canExtend(key))
            {
                return false;
            }

            auto p = Property(value, attributes);
            _table.insertAlt(key, p, key.hash);
        }
        return true;
    }

    //
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

    @safe
    bool del(ref PropertyKey key)
    {
        if(auto p = _table.findExistingAlt(key, key.hash))
        {
            if(!p.deletable)
                return false;
            _table.remove(key, key.hash);
        }
        return true;                    // not found
    }

    @property @safe pure nothrow
    PropertyKey[] keys()
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
    Property* opBinaryRight(string OP : "in")(auto ref PropertyKey index)
    {
        return _table.findExistingAlt(index, index.hash);
    }

private:
    RandAA!(PropertyKey, Property) _table;
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



