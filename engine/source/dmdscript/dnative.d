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


module dmdscript.dnative;

import dmdscript.dobject: Dobject;
import dmdscript.dfunction: Dfunction;
import dmdscript.value: Value;
import dmdscript.property: Property;
import dmdscript.drealm: Drealm;
import dmdscript.callcontext: CallContext;
import dmdscript.derror: Derror;
debug import std.stdio;

//------------------------------------------------------------------------------
struct ArgList
{
    Value[] entity;
    alias entity this;

    @safe @nogc pure nothrow
    this(Value[] a)
    {
        entity = a;
    }

    @safe @nogc nothrow
    ref Value opIndex(size_t i)
    {
        if (i < entity.length)
            return entity[i];
        else
            return _ud;
    }

    // @property @safe @nogc pure nothrow
    // Value[] opSlice()
    // {
    //     return _args[];
    // }


    // @property @safe @nogc pure nothrow
    // size_t length() const
    // {
    //     return _args.length;
    // }

    import dmdscript.value: vundefined;
    private static Value _ud = vundefined;

    invariant
    {
        assert (_ud.isUndefined);
    }
}

//------------------------------------------------------------------------------
///
alias PCall = Derror function(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist);

//------------------------------------------------------------------------------
///
class DnativeFunction : Dfunction
{
    import dmdscript.property: Property;
    import dmdscript.primitive: PropertyKey;

    PCall pcall;

    this(Dobject prototype, PropertyKey name, uint length, PCall func)
    {
        super(prototype, name, length);
        pcall = func;
    }

    override Derror Call(CallContext* cc, Dobject othis, out Value ret,
                          Value[] arglist)
    {
        try return (*pcall)(this, cc, othis, ret, ArgList(arglist));
        catch (Throwable t)
        {
            auto msg = Value("D error");
            return new Derror(t, msg);
        }
    }
}

//------------------------------------------------------------------------------
///
struct DnativeFunctionDescriptor
{
    import dmdscript.property : Property;
    import dmdscript.primitive: PropertyKey;

    enum Type
    {
        Prototype = 0x00,
        Static    = 0x01,
        Getter    = 0x02,
        Setter    = 0x04,
    }

    uint length;  /// is a number of arguments.
    Type type = Type.Prototype; ///
    PropertyKey realName; ///
    Property.Attribute attr; ///

    this (uint l, Type t = Type.Prototype, string rn = null,
          Property.Attribute attr = Property.Attribute.None)
    {
        length = l;
        type = t;
        if (0 < rn.length)
            realName = PropertyKey(rn);
        attr = attr;
    }

    this (uint l, Type t,  PropertyKey rn,
          Property.Attribute attr = Property.Attribute.None)
    {
        length = l;
        type = t;
        realName = rn;
        attr = attr;
    }

    this (uint l, string rn, Type t = Type.Prototype,
          Property.Attribute attr = Property.Attribute.None)
    {
        length = l;
        type = t;
        realName = PropertyKey(rn);
        attr = attr;
    }

    this (uint l, PropertyKey rn, Type t = Type.Prototype,
          Property.Attribute attr = Property.Attribute.None)
    {
        length = l;
        type = t;
        realName = rn;
        attr = attr;
    }

    this (Property.Attribute attr, Type t = Type.Prototype)
    {
        length = 0;
        type = t;
        attr = attr;
    }
}

//------------------------------------------------------------------------------
///
void installConstants(ARGS...)(
    Dobject o, Property.Attribute prop = Property.Attribute.DontEnum |
                                         Property.Attribute.DontDelete |
                                         Property.Attribute.ReadOnly)

{
    static if      (0 == ARGS.length){}
    else
    {
        import std.exception: enforce;
        import dmdscript.primitive : PropertyKey;
        import dmdscript.value : Value;

        static assert (1 < ARGS.length, "bad arguments");
        static assert (is(typeof(ARGS[0]) : string), "bad key");

        enum key = PropertyKey(ARGS[0]);

        auto value = Value(ARGS[1]);

        o.DefineOwnProperty(key, value, prop).enforce(ARGS[0]);

        installConstants!(ARGS[2..$])(o, prop);
    }
}


//------------------------------------------------------------------------------
///
void install(alias M, T)(
    T o, Dobject functionPrototype,
    Property.Attribute prop = Property.Attribute.DontEnum)
{
    import dmdscript.primitive : PropertyKey;
    import dmdscript.dfunction : Dconstructor, Dfunction;
    alias DFD = DnativeFunctionDescriptor;

    assert (o !is null);
    assert (functionPrototype !is null);

    Dfunction f;
    Value val;

    template selectDFD(alias A)
    {
        template _impl(T...)
        {
            static if      (0 == T.length)
                enum _impl = false;
            else static if (is(typeof(T[0]) == DFD))
                enum _impl = T[0];
            else
                enum _impl = _impl!(T[1..$]);
        }
        enum selectDFD = _impl!(__traits(getAttributes, A));
    }

    template isStruct(alias A)
    {
        enum isStruct = is(A == struct);
    }

    static Dfunction getMember(alias U, string mem)(
        PropertyKey name, size_t len, Dobject fp)
    {
        static if (__traits(hasMember, U, mem))
        {
            return new DnativeFunction(
                fp, name, len, &__traits(getMember, U, mem));
        }
        else
            return null;
    }

    foreach(one; __traits(derivedMembers, M))
    {
        static if (!__traits(compiles, __traits(getMember, M, one))){}
        else
        {
            alias desc = selectDFD!(__traits(getMember, M, one));
            static if (is(typeof(desc) == DFD))
            {
                static if ((desc.type & DFD.Type.Static) ==
                           is (T : Dconstructor))
                {
                    static if (is(typeof(&__traits(getMember, M, one)) ==
                                  PCall))
                    {
                        static if (desc.realName.hasString)
                            enum name = desc.realName;
                        else
                            enum name = PropertyKey(one);

                        //
                        f = new DnativeFunction(
                            functionPrototype, PropertyKey(one), desc.length,
                            &__traits(getMember, M, one));

                        static if      (desc.type & DFD.Type.Getter)
                            o.SetGetter(name, f, prop | desc.attr);
                        else static if (desc.type & DFD.Type.Setter)
                            o.SetSetter(name, f, prop | desc.attr);
                        else
                        {
                            val.put(f);
                            o.DefineOwnProperty(name, val, prop | desc.attr);
                        }

                    }
                    else static if (isStruct!(__traits(getMember, M, one)))
                    {
                        auto name = __traits(getMember, M, one).name;
                        auto getter = getMember!(
                            __traits(getMember, M, one), "getter")(
                                name, 0, functionPrototype);
                        auto setter = getMember!(
                            __traits(getMember, M, one), "setter")(
                                name, 1, functionPrototype);
                        auto p = new Property(getter, setter, prop | desc.attr);
                        o.DefineOwnProperty(name, p);
                    }
                    else static assert (
                        0, "'" ~ one ~ "' is not a valid member for " ~
                        "DnativeFunctionDescriptor");
                }
            }

        }
    }
}

//------------------------------------------------------------------------------
void install(Dobject o, string key, Dobject p,
             Property.Attribute attr = Property.Attribute.DontEnum)
{
    import dmdscript.primitive: PropertyKey;

    PropertyKey k;
    Value val;
    val.put(p);
    k = key.PropertyKey;
    o.DefineOwnProperty(k, val, attr);
}

