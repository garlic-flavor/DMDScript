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
import dmdscript.property : Property;
debug import std.stdio;

//------------------------------------------------------------------------------
///
alias PCall = DError* function(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist);

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

public static:

    void install(T, string M = __MODULE__)
        (T o, Property.Attribute prop = Property.Attribute.DontEnum)
    {
        mixin("import " ~ M ~ ";");
        install!(mixin(M), T)(o, prop);
    }

private static:

    import dmdscript.callcontext : CallContext;
    import dmdscript.value : Value, DError;

    ///
    void install(alias M, T)(
        T o, Property.Attribute prop = Property.Attribute.DontEnum)
    {
        import dmdscript.primitive : PropertyKey;
        import dmdscript.dfunction : Dconstructor;
        Dfunction f;
        Value val;
        foreach(one; __traits(derivedMembers, M))
        {
            static if      (is(typeof(__traits(getMember, M, one))))
                alias desc = select!(__traits(getMember, M, one));
            else
                alias desc = void;

            static if      (is(typeof(desc) == DnativeFunctionDescriptor))
            {
                static if ((desc.type & Type.Static) ==
                           is(T : Dconstructor))
                {
                    static if (0 < desc.realName.length)
                        enum name = PropertyKey(desc.realName);
                    else
                        enum name = PropertyKey(one);
                    f = new DnativeFunction(
                        &__traits(getMember, M, one),
                        one, desc.length, Dfunction.getPrototype);

                    static if      (desc.type & Type.Getter)
                        o.SetGetter(name, f, prop | desc.attr);
                    else static if (desc.type & Type.Setter)
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
        static if      (is(typeof(&F) == PCall))
            enum select = _impl!(__traits(getAttributes, F));
        else
            enum select = false;
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

