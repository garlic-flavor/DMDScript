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
///
alias PCall = Derror function(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist);

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
        try return (*pcall)(this, cc, othis, ret, arglist);
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

    enum Type
    {
        Prototype = 0x00,
        Static    = 0x01,
        Getter    = 0x02,
        Setter    = 0x04,
    }

    uint length;  /// is a number of arguments.
    Type type = Type.Prototype; ///
    string realName; ///
    Property.Attribute attr; ///

    this (uint l, Type t = Type.Prototype, string rn = null,
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
        realName = rn;
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
        import dmdscript.primitive : PropertyKey;
        import dmdscript.value : Value;

        static assert (1 < ARGS.length, "bad arguments");
        static assert (is(typeof(ARGS[0]) : string), "bad key");

        enum key = PropertyKey(ARGS[0]);

        auto value = Value(ARGS[1]);

        o.DefineOwnProperty(key, value, prop);

        installConstants!(ARGS[2..$])(o, prop);
    }
}


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

    template selectFunc(alias F)
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

        static if      (is(typeof(&F) == PCall))
            enum selectFunc = _impl!(__traits(getAttributes, F));
        else
            enum selectFunc = false;
    }


    foreach(one; __traits(derivedMembers, M))
    {
        static if      (is(typeof(__traits(getMember, M, one))))
            alias desc = selectFunc!(__traits(getMember, M, one));
        else
            alias desc = void;

        static if      (is(typeof(desc) == DFD))
        {
            static if ((desc.type & DFD.Type.Static) == is(T : Dconstructor))
            {
                static if (0 < desc.realName.length)
                    enum name = PropertyKey(desc.realName);
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
        }
    }
}

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
