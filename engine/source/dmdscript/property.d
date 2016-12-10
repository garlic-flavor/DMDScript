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
// PropertyKey must have a pre-calculated hash value.
struct PropertyKey
{
    import dmdscript.value : Value;
    import dmdscript.identifier : Identifier;
    import dmdscript.primitive : tchar, tstring;
    template IsKey(K)
    {
        enum IsKey = is(K : PropertyKey) || is(K : StringKey) ||
            is(T : Value) || is(K : tstring) || is(K : uint);
    }

    Value value;
    alias value this;

    @safe @nogc pure nothrow
    this(T)(in auto ref T arg) if (IsKey!T && !is(T : Value))
    {
        value.put(arg, calcHash(arg));
    }

    @safe @nogc pure nothrow
    this(T)(in ref auto T arg, in size_t hash) if (IsKey!T)
    {
        value.put(arg, hash);
    }

    @safe
    this(T : Value)(ref T arg)
    {
        value.put(arg, arg.toHash);
    }

    @safe @nogc pure nothrow
    void put(T)(T arg) if (Value.IsPrimitiveType!T)
    {
        value.put(arg, calcHash(arg));
    }

    @safe @nogc pure nothrow
    void put(T)(T arg, size_t h) if (Value.IsPrimitiveType!T)
    {
        value.put(arg, h);
    }

    @safe @nogc pure nothrow
    size_t toHash() const
    {
        return value.hash;
    }

    @safe
    bool opEquals(in ref PropertyKey rvalue) const
    {
        return hash == rvalue.hash && value == rvalue.value;
    }

static:

    @safe @nogc pure nothrow
    size_t calcHash(in size_t u)
    {
        static if      (size_t.sizeof == 4)
            return u ^ 0x55555555;
        else static if (size_t.sizeof == 8) // Is this OK?
            return u ^ 0x5555555555555555;
        else static assert(0);
    }

    @safe @nogc pure nothrow
    size_t calcHash(in double d)
    {
        return calcHash(cast(size_t)d);
    }

    static @trusted @nogc pure nothrow
    size_t calcHash(in tstring s)
    {
        size_t hash;

        /* If it looks like an array index, hash it to the
         * same value as if it was an array index.
         * This means that "1234" hashes to the same value as 1234.
         */
        hash = 0;
        foreach(tchar c; s)
        {
            switch(c)
            {
            case '0':       hash *= 10;             break;
            case '1':       hash = hash * 10 + 1;   break;

            case '2':
            case '3':
            case '4':
            case '5':
            case '6':
            case '7':
            case '8':
            case '9':
                hash = hash * 10 + (c - '0');
                break;

            default:
            {
                uint len = s.length;
                ubyte* str = cast(ubyte*)s.ptr;

                hash = 0;
                while(1)
                {
                    switch(len)
                    {
                    case 0:
                        break;

                    case 1:
                        hash *= 9;
                        hash += *cast(ubyte*)str;
                        break;

                    case 2:
                        hash *= 9;
                        if (__ctfe)
                            hash += str[0..2].toNative!ushort;
                        else
                            hash += *cast(ushort*)str;
                        break;

                    case 3:
                        hash *= 9;
                        if (__ctfe)
                            hash += (str[0..2].toNative!ushort << 8) +
                                (cast(ubyte*)str)[2];
                        else
                            hash += (*cast(ushort*)str << 8) +
                                (cast(ubyte*)str)[2];
                        break;

                    default:
                        hash *= 9;
                        if (__ctfe)
                            hash += str[0..4].toNative!uint;
                        else
                            hash += *cast(uint*)str;
                        str += 4;
                        len -= 4;
                        continue;
                    }
                    break;
                }
                break;
            }
            // return s.hash;
            }
        }
        return calcHash(hash);
    }

    //
    @safe @nogc pure nothrow
    size_t calcHash(inout ref StringKey key)
    {
        return key.hash;
    }
}

//==============================================================================
//
struct StringKey
{
    import dmdscript.primitive : tstring;
    import dmdscript.identifier : Identifier;

    //
    tstring entity;
    alias entity this;

    //
    @safe @nogc pure nothrow
    this(tstring str)
    {
        entity = str;
        if (__ctfe)
            _hash = PropertyKey.calcHash(entity);
    }

    //
    @safe @nogc pure nothrow
    this(tstring str, size_t h)
    {
        entity = str;
        _hash = h;
    }

    //
    @safe @nogc pure nothrow
    this(in ref PropertyKey pk)
    {
        entity = pk.text;
        _hash = pk.toHash;
    }

    //
    @safe pure nothrow
    this(in uint idx)
    {
        import std.conv : to;
        entity = idx.to!tstring;
        if (__ctfe)
            _hash = PropertyKey.calcHash(entity);
    }

    //
    @property @safe @nogc pure nothrow
    size_t hash() const
    {
        if (0 < _hash)
            return _hash;
        return PropertyKey.calcHash(entity);
    }

    //
    @property @safe @nogc pure nothrow
    size_t hash()
    {
        if (0 == _hash)
            _hash = PropertyKey.calcHash(entity);
        return _hash;
    }

    //
    @property @safe @nogc pure nothrow
    size_t calculatedHash() const
    {
        return _hash;
    }

    //
    @safe @nogc pure nothrow
    bool opEquals(in ref StringKey rvalue) const
    {
        return entity == rvalue.entity;
    }

    //
    @safe @nogc pure nothrow
    bool opEquals(in tstring rvalue) const
    {
        return entity == rvalue;
    }

private:
    size_t _hash;
}

//==============================================================================
// See_Also: Ecma-262-v7/6.1.7.1/Property Attributes
//                      /6.2.4
struct Property
{
    import dmdscript.value : Value, DError;
    import dmdscript.dfunction : Dfunction;
    import dmdscript.dobject : Dobject;
    import dmdscript.script : CallContext;

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
    template IsValue(V)
    {
        enum IsValue = is(V : Value) || Value.IsPrimitiveType!V;
    }

    //
    @trusted @nogc pure nothrow
    this(T)(auto ref T v, in Attribute a) if (IsValue!T)
    {
        _value.put(v);
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
        import dmdscript.key : Key;
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
                throw CannotPutError.toScriptException; // !!!!!!!!!!!!!!!!!!!
            _attr |= Attribute.Accessor;
            _Get = cast(Dfunction)v.toObject;
            if (_Get is null)
                throw CannotPutError.toScriptException; // !!!!!!!!!!!!!!!!!!!
        }

        if (auto v = obj.Get(Key.set, cc))
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
    bool config(T)(auto ref T v, Attribute a) if (IsValue!T)
    {
        if (canBeData(a))
        {
            _attr = a;
            _value.put(v);
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
    DError* set(T)(auto ref T _v, in Attribute a,
                   ref CallContext cc, Dobject othis,)
        if (IsValue!T)
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
    bool IsAccessorDescriptor() const
    {
        if (0 == (_attr & Attribute.Accessor))
            return false;
        if (_Get is null && _Set is null)
            return false;
        return true;
    }

    // See_Also: Ecma-262-v7/6.2.4.2
    @property @trusted @nogc pure nothrow
    bool IsDataDescriptor() const
    {
        if (_attr & Attribute.Accessor)
            return false;
        if (_value.isEmpty && (_attr & Attribute.ReadOnly))
            return false;
        return true;
    }

    // See_Also: Ecma-262-v7/6.2.4.3
    @property @safe @nogc pure nothrow
    bool IsGenericDescriptor() const
    {
        return !IsAccessorDescriptor && !IsDataDescriptor;
    }

    // See_Also: Ecma-262-v7/6.2.4.4
    Dobject toObject()
    {
        import std.exception : enforce;
        import dmdscript.key : Key;
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

//==============================================================================
final class PropTable
{
    import dmdscript.value : Value, DError, vundefined;
    import dmdscript.primitive : tstring;
    import dmdscript.dobject : Dobject;
    import dmdscript.script : CallContext;
    import dmdscript.RandAA : RandAA;

    template IsKeyValue(K, V)
    {
        enum IsKeyValue = PropertyKey.IsKey!K && Property.IsValue!V;
    }

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

    //
    @safe
    Property* getOwnProperty(K)(in auto ref K k) if (PropertyKey.IsKey!K)
    {
        static if (is(K : PropertyKey))
            alias key = k;
        else
            auto key = PropertyKey(k);

        return _table.findExistingAlt(key, key.hash);
    }

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

    //
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

    //
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

    //
    @safe
    bool config(K, V)(in auto ref K k, auto ref V value,
                in Property.Attribute attributes)
        if (IsKeyValue!(K, V))
    {
        static if (is(K : PropertyKey))
            alias key = k;
        else
            auto key = PropertyKey(k);

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
    Property* opBinaryRight(string OP : "in", K)(in auto ref K k)
        if (PropertyKey.IsKey!K)
    {
        static if (is(K : PropertyKey))
            alias key = k;
        else
            auto key = PropertyKey(k);

        return _table.findExistingAlt(key, key.hash);
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

//==============================================================================
private:

// for Value.calcHash at CTFE.
@safe @nogc pure nothrow
T toNative(T, size_t N = T.sizeof)(in ubyte[] buf)
{
    assert(N <= buf.length);
    static if      (N == 1)
        return buf[0];
    else static if (N == 2)
    {
        version      (BigEndian)
            return ((cast(ushort)buf[0]) << 8) | (cast(ushort)buf[1]);
        else version (LittleEndian)
            return (cast(ushort)buf[0]) | ((cast(ushort)buf[1]) << 8);
        else static assert(0);
    }
    else static if (N == 4)
    {
        version      (BigEndian)
            return ((cast(uint)buf[0]) << 24) |
                   ((cast(uint)buf[1]) << 16) |
                   ((cast(uint)buf[2]) << 8) |
                   (cast(uint)buf[3]);
        else version (LittleEndian)
            return (cast(uint)buf[0]) |
                   ((cast(uint)buf[1]) << 8) |
                   ((cast(uint)buf[2]) << 16) |
                   ((cast(uint)buf[3]) << 24);
        else static assert(0);
    }
    else static if (N == 8)
    {
        version      (BigEndian)
            return ((cast(ulong)buf[0]) << 56) |
                   ((cast(ulong)buf[1]) << 48) |
                   ((cast(ulong)buf[2]) << 40) |
                   ((cast(ulong)buf[3]) << 32) |
                   ((cast(ulong)buf[4]) << 24) |
                   ((cast(ulong)buf[5]) << 16) |
                   ((cast(ulong)buf[6]) << 8) |
                   (cast(ulong)buf[7]);
        else version (LittleEndian)
            return (cast(ulong)buf[0]) |
                   ((cast(ulong)buf[1]) << 8) |
                   ((cast(ulong)buf[2]) << 16) |
                   ((cast(ulong)buf[3]) << 24) |
                   ((cast(ulong)buf[4]) << 32) |
                   ((cast(ulong)buf[5]) << 40) |
                   ((cast(ulong)buf[6]) << 48) |
                   ((cast(ulong)buf[7]) << 56);
        else static assert(0);
    }
    else static assert(0);
}
