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


module dmdscript.protoerror;

import dmdscript.dobject: Dobject;
import dmdscript.dfunction: Dconstructor;
import dmdscript.dnative: DnativeFunction, DFD = DnativeFunctionDescriptor;
import dmdscript.value: DError, Value;
import dmdscript.exception: ScriptException;
import dmdscript.drealm: Drealm;
import dmdscript.callcontext: CallContext;

debug import std.stdio;

//------------------------------------------------------------------------------
///
class D0(alias Text) : D0base
{
    import dmdscript.dfunction : Dfunction;
    import dmdscript.primitive : PropertyKey;

    this(Dobject prototype, string m)
    {
        super(prototype, Text, m);
    }


// deprecated
//     this(Dobject prototype, Throwable t)
//     {
//         if (auto se = cast(ScriptException)t)
//             super(prototype, se);
//         else
//             super(prototype,
//                   new ScriptException("Unexpected exception", t));

//         assert (GetPrototypeOf !is null);
//     }
}

//------------------------------------------------------------------------------
class D0_constructor(alias TEXT_D1) : Dconstructor
{
    import dmdscript.primitive: PropertyKey;
    import dmdscript.value: DError, Value;
    import dmdscript.drealm: undefined;

    enum Text = PropertyKey(TEXT_D1);
    alias Type = D0!Text;

    this(Dobject superPrototype, Dobject functionPrototype)
    {
        import dmdscript.property: Property;
        import dmdscript.primitive: Key;

        super(new Dobject(superPrototype), functionPrototype, Text, 1);

        install(functionPrototype);

        Value val;
        val.put(Text);
        DefineOwnProperty(Key.name, val, Property.Attribute.None);
        val.put(Text ~ ".prototype.message");
        DefineOwnProperty(Key.message, val, Property.Attribute.None);
        DefineOwnProperty(Key.description, val, Property.Attribute.None);
        // val.put(0);
        // cp.DefineOwnProperty(Key.number, val, Property.Attribute.None);
    }

    override DError* Construct(CallContext* cc, out Value ret,
                               Value[] arglist)
    {
        // ECMA 15.11.7.2
        Value* m;
        Dobject o;
        string s;

        m = (arglist.length) ? &arglist[0] : &undefined;
        // ECMA doesn't say what we do if m is undefined
        if(m.isUndefined())
            s = classname;
        else
            s = m.toString(cc);
        o = opCall(s);
        ret.put(o);
        return null;
    }

    override DError* Call(CallContext* cc, Dobject othis, out Value ret,
                          Value[] arglist)
    {
        // ECMA v3 15.11.7.1
        return Construct(cc, ret, arglist);
    }

    Type opCall(ARGS...)(ARGS args)
    {
        return new Type(classPrototype, args);
    }
}


alias SyntaxError = D0_constructor!"SyntaxError";
alias EvalError = D0_constructor!"EvalError";
alias ReferenceError = D0_constructor!"ReferenceError";
alias RangeError = D0_constructor!"RangeError";
alias TypeError = D0_constructor!"TypeError";
alias UriError = D0_constructor!"URIError";

//==============================================================================
package:

class D0base : Dobject
{
    import dmdscript.primitive : Key, PropertyKey;
    import dmdscript.exception : ScriptException;

    this(Dobject prototype, PropertyKey typename, string m)
    {
        import dmdscript.property : Property;

        super(prototype, typename);

        value.put(0);
        DefineOwnProperty(Key.number, value, Property.Attribute.None);

        value.put(m);
        DefineOwnProperty(Key.message, value, Property.Attribute.None);
        DefineOwnProperty(Key.description, value, Property.Attribute.None);
    }
}


//==============================================================================
private:

//------------------------------------------------------------------------------
//
@DFD(0)
DError* toString(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import dmdscript.primitive : Key;
    if (auto d0 = cast(D0base)othis)
        ret.put(d0.value.toString);
    else
        ret.put(othis.Get(Key.message, cc));
    return null;
}

//
@DFD(0)
DError* valueOf(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import dmdscript.primitive : Key;
    ret.put(othis.Get(Key.number, cc));
    return null;
}
