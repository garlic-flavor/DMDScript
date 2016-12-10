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

import dmdscript.script : CallContext;
import dmdscript.dobject : Dobject;
import dmdscript.dfunction : Dfunction;
import dmdscript.value : Value, DError;
debug import std.stdio;

//------------------------------------------------------------------------------
///
struct DnativeFunctionDescriptor
{
    import dmdscript.key : Key;

    enum Type
    {
        Prototype,
        Static,
    }

    Key name;     ///
    uint length;  ///
    Type type = Type.Prototype; ///

public static:
    import dmdscript.property : Property;
    ///
    void install(alias M)(
        Dobject o, Property.Attribute prop = Property.Attribute.DontEnum,
        Type type = Type.Prototype)
    {
        foreach(one; __traits(allMembers, M))
        {
            static if (is(typeof(__traits(getMember, M, one))))
                enum desc = select!(__traits(getMember, M, one));
            else
                enum desc = false;

            static if (is(typeof(desc) == DnativeFunctionDescriptor))
            {
                if (type == desc.type)
                {
                    o.DefineOwnProperty(
                        desc.name,
                        new DnativeFunction(
                            &__traits(getMember, M, one),
                            desc.name, desc.length, Dfunction.getPrototype),
                        prop);
                }
            }
        }

    }

private static:
    import dmdscript.script : CallContext;
    import dmdscript.value : Value, DError;

    //
    alias PCall = DError* function(DnativeFunction pthis,
                                   ref CallContext cc,
                                   Dobject othis,
                                   out Value ret,
                                   Value[] arglist);
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
struct DnativeVariableDescriptor
{
    import dmdscript.key : Key;

    enum Type
    {
        Prototype,
        Static,
    }

    Key name;
    Type type = Type.Prototype;

public static:
    import dmdscript.property : Property;

    void install(alias M)(
        Dobject o, Property.Attribute prop = Property.Attribute.None,
        Type type = Type.Prototype)
    {
        foreach(one; __traits(allMembers, M))
        {
            static if (is(typeof(__traits(getMember, M, one))))
                enum desc = select!(__traits(getMember, M, one));
            else
                enum desc = false;

            static if (is(typeof(desc) == DnativeVariableDescriptor))
            {
                if (type == desc.type)
                {
                    o.DefineOwnProperty(
                        desc.name, __traits(getMember, M, one), prop);
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
            else static if (is(typeof(T[0]) == DnativeVariableDescriptor))
                enum _impl = T[0];
            else
                enum _impl = _impl!(T[1..$]);
        }
        enum select = _impl!(__traits(getAttributes, F));
    }
}


/******************* DnativeFunction ****************************/

alias PCall = DError* function(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist);

struct NativeFunctionData
{
    import dmdscript.property : StringKey;

    StringKey str;
    PCall     pcall;
    uint      length;
}

class DnativeFunction : Dfunction
{
    import dmdscript.primitive : tstring;
    import dmdscript.property : Property;

    PCall pcall;

    this(PCall func, tstring name, uint length)
    {
        super(length);
        this.name = name;
        pcall = func;
    }

    this(PCall func, tstring name, uint length, Dobject o)
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

    /*********************************
     * Initalize table of native functions designed
     * to go in as properties of o.
     */

    static void initialize(Dobject o, NativeFunctionData[] nfd,
                           Property.Attribute attributes)
    {
        Dobject f = Dfunction.getPrototype();
        for(size_t i = 0; i < nfd.length; i++)
        {
            NativeFunctionData* n = &nfd[i];

            o.DefineOwnProperty(n.str, new DnativeFunction(n.pcall, n.str, n.length, f),
                     attributes);
        }
    }

}
