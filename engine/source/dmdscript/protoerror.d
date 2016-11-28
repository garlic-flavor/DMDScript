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

import dmdscript.script;
import dmdscript.dobject;
import dmdscript.value;
import dmdscript.text;
import dmdscript.dfunction;
import dmdscript.property;
import dmdscript.derror;

int foo;        // cause this module to be linked in

/* ===================== D0_constructor ==================== */

class D0_constructor : Dfunction
{
    d_string text_d1;
    Dobject function(d_string) newD0;

    this(d_string text_d1, Dobject function(d_string) newD0)
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
        d_string s;

        m = (arglist.length) ? &arglist[0] : &vundefined;
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


package class D0base : Dobject
{
    ScriptException exception;

    protected this(Dobject prototype)
    {
        super(prototype);
        classname = Text.Error;
    }

    protected this(Dobject prototype, d_string m)
    {
        this(prototype);
        CallContext cc;
        Put(Text.message, m, Property.Attribute.None, cc);
        Put(Text.description, m, Property.Attribute.None, cc);
        Put(Text.number, cast(d_number)0, Property.Attribute.None, cc);
        exception = new ScriptException(m);
    }

    protected this(Dobject prototype, ScriptException exception)
    {
        this(prototype);
        assert(exception !is null);
        this.exception = exception;
        CallContext cc;
        Put(Text.message, exception.msg, Property.Attribute.None, cc);
        Put(Text.description, exception.toString, Property.Attribute.None, cc);
        Put(Text.number, cast(d_number)exception.code,
            Property.Attribute.None, cc);
    }
}

template proto(alias TEXT_D1)
{
    enum Text = TEXT_D1;

    private Dobject _prototype;
    private Dfunction _ctor;
    /* ===================== D0_prototype ==================== */

    class D0_prototype : D0
    {
        this()
        {
            super(Derror.getPrototype);

            d_string s;

            config(Text.constructor, _ctor, Property.Attribute.DontEnum);
            config(Text.name, TEXT_D1, Property.Attribute.None);
            s = TEXT_D1 ~ ".prototype.message";
            config(Text.message, s, Property.Attribute.None);
            config(Text.description, s, Property.Attribute.None);
            config(Text.number, cast(d_number)0, Property.Attribute.None);
        }
    }

    /* ===================== D0 ==================== */

    class D0 : D0base
    {
        private this(Dobject prototype)
        {
            super(prototype);
        }

        this(d_string m)
        {
            super(D0.getPrototype, m);
        }

        this(ScriptException exception)
        {
            super(D0.getPrototype, exception);
        }

        static Dfunction getConstructor()
        {
            return _ctor;
        }

        static Dobject getPrototype()
        {
            return _prototype;
        }

        static Dobject newD0(d_string s)
        {
            return new D0(s);
        }

        static void init()
        {
            Dfunction constructor = new D0_constructor(TEXT_D1, &newD0);
            _ctor = constructor;

            Dobject prototype = new D0_prototype();
            _prototype = prototype;

            constructor.config(Text.prototype, prototype,
                               Property.Attribute.DontEnum |
                               Property.Attribute.DontDelete |
                               Property.Attribute.ReadOnly);
        }
    }
}

alias proto!(Text.SyntaxError) syntaxerror;
alias proto!(Text.EvalError) evalerror;
alias proto!(Text.ReferenceError) referenceerror;
alias proto!(Text.RangeError) rangeerror;
alias proto!(Text.TypeError) typeerror;
alias proto!(Text.URIError) urierror;

