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

import dmdscript.dobject : Dobject;
import dmdscript.dfunction : Dconstructor;
import dmdscript.callcontext : CallContext;
import dmdscript.dnative : DnativeFunction, DFD = DnativeFunctionDescriptor;
import dmdscript.value : DError, Value;

debug import std.stdio;

//------------------------------------------------------------------------------
///
class D0(alias TEXT_D1) : D0base
{
    import dmdscript.dfunction : Dfunction;
    import dmdscript.dobject : Initializer;

    enum Text = TEXT_D1;

    this(string_t m)
    {
        super(TEXT_D1, getPrototype, m);
    }

    this(ScriptException exception)
    {
        super(getPrototype, exception);
        assert (getPrototype !is null);
    }

    mixin Initializer!D0_constructor _Initializer;

package static:

    //
    void initFuncs()
    {
        import dmdscript.property : Property;

        _Initializer.initFuncs(TEXT_D1, &newD0);

        _class_prototype.DefineOwnProperty(Key.name, TEXT_D1,
                                           Property.Attribute.None);
        auto s = TEXT_D1 ~ ".prototype.message";
        _class_prototype.DefineOwnProperty(Key.message, s,
                                           Property.Attribute.None);
        _class_prototype.DefineOwnProperty(Key.description, s,
                                           Property.Attribute.None);
        _class_prototype.DefineOwnProperty(Key.number, 0,
                                           Property.Attribute.None);
    }

private static:

    Dobject newD0(string_t s)
    {
        return new D0(s);
    }
}

alias syntaxerror = D0!"SyntaxError";
alias evalerror = D0!"EvalError";
alias referenceerror = D0!"ReferenceError";
alias rangeerror = D0!"RangeError";
alias typeerror = D0!"TypeError";
alias urierror = D0!"URIError";

//==============================================================================
package:

class D0base : Dobject
{
    import dmdscript.primitive : string_t, Key;
    import dmdscript.exception : ScriptException;

    ScriptException exception;

    protected this(Dobject prototype)
    {
        super(prototype, Key.Error);
    }

    protected this(string_t typename, Dobject prototype, string_t m)
    {
        import dmdscript.property : Property;

        this(prototype);

        DefineOwnProperty(Key.message, m, Property.Attribute.None);
        DefineOwnProperty(Key.description, m, Property.Attribute.None);
        DefineOwnProperty(Key.number, cast(double)0, Property.Attribute.None);
        exception = new ScriptException(typename, m);
    }

    protected this(Dobject prototype, ScriptException exception)
    {
        import dmdscript.property : Property;

        this(prototype);
        assert(exception !is null);
        this.exception = exception;

        DefineOwnProperty(Key.message, exception.msg, Property.Attribute.None);
        DefineOwnProperty(Key.description, exception.toString,
                          Property.Attribute.None);
        // DefineOwnProperty(Key.number, cast(double)exception.code,
        //                   Property.Attribute.None);
    }
}


//==============================================================================
private:

//------------------------------------------------------------------------------
class D0_constructor : Dconstructor
{
    import dmdscript.callcontext : CallContext;
    import dmdscript.value : DError, Value;
    import dmdscript.dglobal : undefined;
    import dmdscript.primitive : string_t;

    Dobject function(string_t) newD0;

    this(string_t text_d1, Dobject function(string_t) newD0)
    {
        super(text_d1, 1, Dfunction.getPrototype);
        this.newD0 = newD0;
    }

    override DError* Construct(ref CallContext cc, out Value ret,
                               Value[] arglist)
    {
        // ECMA 15.11.7.2
        Value* m;
        Dobject o;
        string_t s;

        m = (arglist.length) ? &arglist[0] : &undefined;
        // ECMA doesn't say what we do if m is undefined
        if(m.isUndefined())
            s = classname;
        else
            s = m.toString();
        o = (*newD0)(s);
        ret.put(o);
        return null;
    }

    override DError* Call(ref CallContext cc, Dobject othis, out Value ret,
                          Value[] arglist)
    {
        // ECMA v3 15.11.7.1
        return Construct(cc, ret, arglist);
    }
}

//------------------------------------------------------------------------------
//
@DFD(0)
DError* toString(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import dmdscript.primitive : Key;
    if (auto d0 = cast(D0base)othis)
        ret.put(d0.exception.toString);
    else
        ret.put(othis.Get(Key.message, cc));
    return null;
}

//
@DFD(0)
DError* valueOf(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import dmdscript.primitive : Key;
    ret.put(othis.Get(Key.number, cc));
    return null;
}
