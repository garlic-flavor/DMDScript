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
import dmdscript.value: Value;
import dmdscript.drealm: Drealm;
import dmdscript.callcontext: CallContext;
import dmdscript.derror: Derror, onError;

debug import std.stdio;

//------------------------------------------------------------------------------
///
class D0(alias Text) : Dobject
{
    import dmdscript.dfunction : Dfunction;
    import dmdscript.primitive : PropertyKey;

    @safe pure nothrow
    this(Dobject p, ref Value v)
    {
        import dmdscript.primitive: Key;
        import dmdscript.property: Property;
        alias PA = Property.Attribute;

        super(p, Text);
        DefineOwnProperty(Key.message, v, PA.None);
    }
}


//------------------------------------------------------------------------------
class D0_constructor(alias TEXT_D1) : Dconstructor
{
    import dmdscript.primitive: PropertyKey;
    import dmdscript.value: Value;
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

    override Derror Construct(CallContext* cc, out Value ret,
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
            m.to(s, cc);
        o = opCall(s);
        ret.put(o);
        return null;
    }

    override Derror Call(CallContext* cc, Dobject othis, out Value ret,
                          Value[] arglist)
    {
        // ECMA v3 15.11.7.1
        return Construct(cc, ret, arglist);
    }

    @safe pure nothrow
    Type opCall(string msg)
    {
        Value v;
        v.put(msg);
        return new Type(classPrototype, v);
    }
}


alias SyntaxError = D0_constructor!"SyntaxError";
alias EvalError = D0_constructor!"EvalError";
alias ReferenceError = D0_constructor!"ReferenceError";
alias RangeError = D0_constructor!"RangeError";
alias TypeError = D0_constructor!"TypeError";
alias UriError = D0_constructor!"URIError";

//------------------------------------------------------------------------------
Dobject toError(string type, string msg, Drealm realm)
{
    switch (type)
    {
    case SyntaxError.Text:
        return realm.dSyntaxError(msg);
    case ReferenceError.Text:
        return realm.dReferenceError(msg);
    case RangeError.Text:
        return realm.dRangeError(msg);
    case TypeError.Text:
        return realm.dTypeError(msg);
    case UriError.Text:
        return realm.dUriError(msg);
    default:
        return realm.dEvalError(msg);
    }
    assert (0);
}


//==============================================================================
private:

//------------------------------------------------------------------------------
//
@DFD(0)
Derror toString(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.conv: text;
    import dmdscript.primitive: Key;

    Derror err;
    Value* v;
    string message;

    if (othis.Get(Key.message, v, cc).onError(err))
        return err;

    if (v !is null)
        v.to(message, cc);

    ret.put(text(othis.classname, " : ", message));
    // import dmdscript.primitive : Key;
    // if (auto d0 = cast(DError)othis)
    //     ret.put(d0.value.toString);
    // else
    // {
    //     Value* v;
    //     if (auto err = othis.Get(Key.message, cc, v))
    //         return err;
    //     if (v !is null)
    //         ret = *v;
    // }
    return null;
}

//
@DFD(0)
Derror valueOf(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import dmdscript.primitive : Key;
    Value* v;
    if (auto err = othis.Get(Key.number, v, cc))
        return err;
    ret = *v;
    return null;
}
