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
import dmdscript.dfunction : Dfunction;


//------------------------------------------------------------------------------
///
class D0(alias TEXT_D1) : D0base
{
    enum Text = TEXT_D1;

    private this(Dobject prototype)
    {
        super(prototype);
    }

    this(string_t m)
    {
        super(D0.getPrototype, m);
    }

    this(ScriptException exception)
    {
        super(D0.getPrototype, exception);
    }

public static:
    //
    Dfunction getConstructor()
    {
        return _ctor;
    }

    //
    Dobject getPrototype()
    {
        return _prototype;
    }

    //
    void init()
    {
        import dmdscript.property : Property;

        _ctor = new D0_constructor(TEXT_D1, &newD0);

        _prototype = new Dobject();

        _ctor.DefineOwnProperty(Key.prototype, _prototype,
                                Property.Attribute.DontEnum |
                                Property.Attribute.DontDelete |
                                Property.Attribute.ReadOnly);

        _prototype.DefineOwnProperty(Key.constructor, _ctor,
                                     Property.Attribute.DontEnum);
        _prototype.DefineOwnProperty(Key.name, TEXT_D1,
                                     Property.Attribute.None);
        auto s = TEXT_D1 ~ ".prototype.message";
        _prototype.DefineOwnProperty(Key.message, s,
                                     Property.Attribute.None);
        _prototype.DefineOwnProperty(Key.description, s,
                                     Property.Attribute.None);
        _prototype.DefineOwnProperty(Key.number, cast(double)0,
                                     Property.Attribute.None);

    }
private static:
    Dobject _prototype;
    Dfunction _ctor;

    Dobject newD0(string_t s)
    {
        return new D0(s);
    }
}

alias syntaxerror = D0!(Key.SyntaxError);
alias evalerror = D0!(Key.EvalError);
alias referenceerror = D0!(Key.ReferenceError);
alias rangeerror = D0!(Key.RangeError);
alias typeerror = D0!(Key.TypeError);
alias urierror = D0!(Key.URIError);

//==============================================================================
package:

class D0base : Dobject
{
    import dmdscript.primitive : string_t;
    import dmdscript.exception : ScriptException;

    ScriptException exception;

    protected this(Dobject prototype)
    {
        super(prototype, Key.Error);
    }

    protected this(Dobject prototype, string_t m)
    {
        import dmdscript.property : Property;

        this(prototype);

        DefineOwnProperty(Key.message, m, Property.Attribute.None);
        DefineOwnProperty(Key.description, m, Property.Attribute.None);
        DefineOwnProperty(Key.number, cast(double)0, Property.Attribute.None);
        exception = new ScriptException(m);
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

import dmdscript.primitive : StringKey, PKey = Key;
enum Key : StringKey
{
    prototype = PKey.prototype,
    constructor = PKey.constructor,
    message = PKey.message,
    description = PKey.description,
    name = PKey.name,
    number = PKey.number,
    Error = PKey.Error,

    EvalError = StringKey("EvalError"),
    RangeError = StringKey("RangeError"),
    ReferenceError = StringKey("ReferenceError"),
    SyntaxError = StringKey("SyntaxError"),
    TypeError = StringKey("TypeError"),
    URIError = StringKey("URIError"),
}

//------------------------------------------------------------------------------
class D0_constructor : Dfunction
{
    import dmdscript.callcontext : CallContext;
    import dmdscript.value : DError, Value;
    import dmdscript.dglobal : undefined;
    import dmdscript.primitive : string_t;

    string_t text_d1;
    Dobject function(string_t) newD0;

    this(string_t text_d1, Dobject function(string_t) newD0)
    {
        super(1, Dfunction.getPrototype);
        this.text_d1 = text_d1;
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
            s = text_d1;
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

