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

import dmdscript.script;
import dmdscript.value;
import dmdscript.identifier;
import dmdscript.dobject;

import dmdscript.RandAA;

debug import std.stdio;

// See_Also: Ecma-262-v7:6.1.7.1 Property Attributes
struct Property
{
    import dmdscript.dfunction : Dfunction;

    // attribute flags
    enum Attribute : uint
    {
        None           = 0x0000,
        ReadOnly       = 0x0001,
        DontEnum       = 0x0002,
        DontDelete     = 0x0004,
        Internal       = 0x0008,
        Deleted        = 0x0010,
        Locked         = 0x0020,
        DontOverride   = 0x0040, // pseudo for an argument of a setter method
        KeyWord        = 0x0080,
        DebugFree      = 0x0100, // for debugging help
        Instantiate    = 0x0200, // For COM named item namespace support

        DontChangeAttr = 0x0400,
        DontConfig     = 0x0800, // "don't change data or accessor."

        Accessor       = 0x8000, // This is an Accessor Property.
    }
    union
    {
        Value value;
        struct // for an Accessor Property.
        {
            Dfunction Get;
            Dfunction Set;
        }
    }

    Attribute  attributes;

    @trusted @nogc pure nothrow
    this(ref Value v, in Attribute attr)
    {
        value = v;
        attributes = attr;
    }

    @property @safe @nogc pure nothrow
    bool writable() const
    {
        return (0 == (attributes & Attribute.Accessor)) &&
            (0 == (attributes & Attribute.ReadOnly));
    }

    @property @safe @nogc pure nothrow
    bool enumerable() const
    {
        return 0 == (attributes & Attribute.DontEnum);
    }

    @property @safe @nogc pure nothrow
    bool deletable() const
    {
        return 0 == (attributes & Attribute.DontDelete);
    }

    @property @safe @nogc pure nothrow
    bool canChangeAttribute() const
    {
        return 0 == (attributes & Attribute.DontChangeAttr);
    }

    @property @safe @nogc pure nothrow
    bool configurable() const
    {
        enum mask = Attribute.DontDelete | Attribute.DontConfig |
            Attribute.DontChangeAttr;
        return (attributes & mask) != mask;
    }

    @safe @nogc pure nothrow
    bool canOverwriteTo(in ref Property p) const
    {
        if      (p.configurable)
            return true;
        else if (p.writable && !writable)
            return true;
        else if (attributes == p.attributes)
            return true;
        return false;
    }

    @trusted @nogc pure nothrow
    void overwriteTo(ref Property target)
    {

        // Attribute attr;
        // if (0 == (p.attributes & Attribute.DontOverride))
        //     attr = attributes;
        // else
        //     attr = p.attributes | (attributes & Attribute.ReadOnly);

        // if (attr & Attribute.Accessor)
        // {
        //     if (0 == (attr & Attribute.DontOverride))
        //     {
        //         p.Get = Get;
        //         p.Set = Set;
        //     }
        // }
        // else
        // {
        //     if (0 == (attr & Attribute.ReadOnly))
        //         p.value = value;
        // }
        // p.attributes = attr;
    }
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
    @safe pure nothrow
    this()
    {
        table = new RandAA!(Value, Property);
    }


    int opApply(scope int delegate(ref Property) dg)
    {
        return table.opApply(dg);
    }

    int opApply(scope int delegate(ref Value, ref Property) dg)
    {
        return table.opApply(dg);
    }

    /*******************************
     * Look up name and get its corresponding Property.
     * Return null if not found.
     */
    @safe
    Property* getProperty(ref Value key)
    {
        return getProperty(key, key.toHash);
    }

//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// To_Do: implement Accessor version.
    Value* get(ref Value key, in size_t hash/*, ref CallContext cc, Dobject othis*/)
    {
        if (auto p = getProperty(key, hash))
        {
            // if (p.attributes & Property.Attribute.Accessor)
            // {
            //     assert(p.Get !is null);
            //     auto ret = new Value;
            //     auto err = p.Get.Call(cc, othis, *ret, null);
            //     debug if (err !is null)
            //         throw err.toScriptException;

            //     if (err !is null)
            //         return null;
            //     else
            //         return ret;
            // }
            // else
                return &p.value;
        }
        return null;
    }

    Value* get(in d_uint32 index)
    {
        Value key;

        key.putVnumber(index);
        return get(key, Value.calcHash(index));
    }

    Value* get(in d_string name, in size_t hash)
    {
        Value key;

        key.putVstring(name);
        return get(key, hash);
    }

    /*******************************
     * Determine if property exists for this object.
     * The enumerable flag means the DontEnum attribute cannot be set.
     */
    @safe
    int hasownproperty(ref Value key, in int enumerable)
    {
        Property* p;

        p = key in table;
        return p && (!enumerable ||
                     !(p.attributes & Property.Attribute.DontEnum));
    }

    @trusted
    int hasproperty(in d_string name)
    {
        Value v;
        v.putVstring(name);

        return hasproperty(v);
    }

/+
    Value* put(ref Value key, size_t hash, ref Property value)
    {
        
    }
+/


    @trusted
    Value* put(ref Value key, size_t hash, ref Value value,
               in Property.Attribute attributes)
    {
        Property* p;
        p = table.findExistingAlt(key, hash);

        if(p)
        {
            Lx:
            if(attributes & Property.Attribute.DontOverride &&
               p.value.vtype != Value.Type.RefError ||
               p.attributes & Property.Attribute.ReadOnly)
            {
                if(p.attributes & Property.Attribute.KeyWord)
                    return null;
                return &vundefined;
            }

            auto t = _previous;
            if(t)
            {
                do
                {
                    Property* q;
                    //q = *key in t.table;
                    q = t.table.findExistingAlt(key, hash);
                    if(q)
                    {
                        if(q.attributes & Property.Attribute.ReadOnly)
                        {
                            p.attributes |= Property.Attribute.ReadOnly;
                            return &vundefined;
                        }
                        break;
                    }
                    t = t._previous;
                } while(t);
            }

            // Overwrite property with new value
            p.value = value;
            p.attributes =
                (attributes & ~Property.Attribute.DontOverride) |
                (p.attributes & (Property.Attribute.DontDelete |
                                 Property.Attribute.DontEnum));
            return null;
        }
        else
        {
            //table[*key] = Property(attributes & ~DontOverride,*value);
            auto v = Property(value,
                              (attributes & ~Property.Attribute.DontOverride));
            table.insertAlt(key, v, hash);
            return null; // success
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

        return canput(v, v.toHash);
    }

    @trusted
    int del(d_string name)
    {
        Value v;

        v.putVstring(name);
        return del(v);
    }

    @trusted
    int del(d_uint32 index)
    {
        Value v;

        v.putVnumber(index);
        return del(v);
    }

    @property @safe pure nothrow
    Value[] keys()
    {
        return table.keys;
    }

    @property @safe @nogc pure nothrow
    size_t length() const
    {
        return table !is null ? table.length : 0;
    }

    @property @safe @nogc pure nothrow
    void previous(PropTable p)
    {
        _previous = p;
    }

    @safe
    Property* opBinaryRight(string OP : "in")(auto ref Value index)
    {
        return table !is null ? index in table : null;
    }

private:
    RandAA!(Value, Property) table;
    PropTable _previous;

    @safe
    Property* getProperty(ref Value key, in size_t hash)
    {
        assert(key.toHash == hash);
        for (auto t = this; t !is null; t = t._previous)
        {
            if (auto p = t.table.findExistingAlt(key, hash))
                return p;
        }
        return null;
    }

    @safe
    int hasproperty(ref Value key)
    {
        return (key in table) !is null ||
            (_previous && _previous.hasproperty(key));
    }

    @safe
    int canput(ref Value key, size_t hash)
    {
        Property* p;
        PropTable t;

        t = this;
        do
        {
            //p = *key in t.table;
             p = t.table.findExistingAlt(key, hash);
            if(p)
            {
                return (p.attributes & Property.Attribute.ReadOnly)
                       ? false : true;
            }
            t = t._previous;
        } while(t);
        return true;                    // success
    }

    @safe
    int del(ref Value key)
    {
        Property* p;

        p = key in table;
        if(p)
        {
            if(p.attributes & Property.Attribute.DontDelete)
                return false;
            table.remove(key);
        }
        return true;                    // not found
    }

}



