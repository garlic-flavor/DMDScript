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

import dmdscript.callcontext : CallContext;
import dmdscript.dobject : Dobject;
import dmdscript.dfunction : Dfunction;
import dmdscript.value : Value, DError;
debug import std.stdio;

//------------------------------------------------------------------------------
///
alias PCall = DError* function(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist);


//------------------------------------------------------------------------------
///
struct DnativeFunctionDescriptor
{
    enum Type
    {
        Prototype,
        Static,
    }

    uint length;  /// is a number of arguments.
    Type type = Type.Prototype; ///
    string realName; ///

public static:
    import dmdscript.property : Property;
    ///
    void install(alias M, T)(
        T o, Property.Attribute prop = Property.Attribute.DontEnum)
    {
        import dmdscript.primitive : StringKey;
        import dmdscript.dfunction : Dconstructor;

        foreach(one; __traits(allMembers, M))
        {
            static if (is(typeof(__traits(getMember, M, one))))
                enum desc = select!(__traits(getMember, M, one));
            else
                enum desc = false;

            static if (is(typeof(desc) == DnativeFunctionDescriptor))
            {
                static if ((desc.type == Type.Static) ==
                           is(T : Dconstructor))
                {
                    static if (0 < desc.realName.length)
                        enum name = StringKey(desc.realName);
                    else
                        enum name = StringKey(one);

                    o.DefineOwnProperty(
                        name,
                        new DnativeFunction(
                            &__traits(getMember, M, one),
                            one, desc.length, Dfunction.getPrototype),
                        prop);
                }
            }
        }

    }

private static:
    import dmdscript.callcontext : CallContext;
    import dmdscript.value : Value, DError;

    //
    template select(alias F)
    {
        template _impl(T...)
        {
            static if      (0 == T.length)
                enum _impl = false;
            else static if (is(typeof(T[0]) == DnativeFunctionDescriptor))
                enum _impl = T[0];
            else
                enum _impl = _impl!(T[1..$]);
        }
        static if (is(typeof(&F) == PCall))
            enum select = _impl!(__traits(getAttributes, F));
        else
            enum select = false;
    }
}

//------------------------------------------------------------------------------
///
struct DconstantDescriptor
{
    import dmdscript.primitive : Key;

    enum Type
    {
        Prototype,
        Static,
    }

    Type type = Type.Prototype;
    string realName; ///

public static:
    import dmdscript.property : Property;

    void install(alias M, Type type = Type.Prototype)(
        Dobject o,
        Property.Attribute prop = Property.Attribute.DontEnum |
                                  Property.Attribute.DontDelete |
                                  Property.Attribute.ReadOnly)
    {
        foreach(one; __traits(allMembers, M))
        {
            static if (is(typeof(__traits(getMember, M, one))))
                enum desc = select!(__traits(getMember, M, one));
            else
                enum desc = false;

            static if (is(typeof(desc) == typeof(this)))
            {
                static if (type == desc.type)
                {
                    static if (0 < desc.realName.length)
                        enum name = StringKey(desc.realName);
                    else
                        enum name = StringKey(one);

                    o.DefineOwnProperty(name, __traits(getMember, M, one),
                                        prop);
                }
            }
        }
    }

private static:
    //
    template select(alias F)
    {
        template _impl(T...)
        {
            static if      (0 == T.length)
                enum _impl = false;
            else static if (is(typeof(T[0]) == typeof(this)))
                enum _impl = T[0];
            else
                enum _impl = _impl!(T[1..$]);
        }
        static if (is(typeof(__traits(getAttributes, F))))
            enum select = _impl!(__traits(getAttributes, F));
        else
            enum select = false;
    }
}


//------------------------------------------------------------------------------
///
class DnativeFunction : Dfunction
{
    import dmdscript.primitive : string_t;
    import dmdscript.property : Property;

    PCall pcall;

    this(PCall func, string_t name, uint length)
    {
        super(length);
        this.name = name;
        pcall = func;
    }

    this(PCall func, string_t name, uint length, Dobject o)
    {
        super(length, o);
        this.name = name;
        pcall = func;
    }

    override DError* Call(ref CallContext cc, Dobject othis, out Value ret,
                          Value[] arglist)
    {
        return (*pcall)(this, cc, othis, ret, arglist);
    }
}
