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

module dmdscript.derror;

import dmdscript.script;
import dmdscript.dobject;
import dmdscript.dfunction;
import dmdscript.value;
import dmdscript.dnative;
import dmdscript.text;
import dmdscript.property;


// Comes from MAKE_HRESULT(SEVERITY_ERROR, FACILITY_CONTROL, 0)
const uint FACILITY = 0x800A0000;

/* ===================== Derror_constructor ==================== */

class DerrorConstructor : Dfunction
{
    this()
    {
        super(1, Dfunction.getPrototype);
    }

    override DError* Construct(ref CallContext cc, out Value ret,
                               Value[] arglist)
    {
        // ECMA 15.7.2
        Dobject o;
        Value* m;
        Value* n;
        Value vemptystring;

        vemptystring.putVstring(null);
        switch(arglist.length)
        {
        case 0:         // ECMA doesn't say what we do if m is undefined
            m = &vemptystring;
            n = &vundefined;
            break;
        case 1:
            m = &arglist[0];
            if(m.isNumber())
            {
                n = m;
                m = &vemptystring;
            }
            else
                n = &vundefined;
            break;
        default:
            m = &arglist[0];
            n = &arglist[1];
            break;
        }
        o = new Derror(m, n);
        ret.putVobject(o);
        return null;
    }

    override DError* Call(ref CallContext cc, Dobject othis, out Value ret,
                          Value[] arglist)
    {
        // ECMA v3 15.11.1
        return Construct(cc, ret, arglist);
    }
}


/* ===================== Derror_prototype_toString =============== */

DError* Derror_prototype_toString(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.11.4.3
    // Return implementation defined string
    Value* v;

    //writef("Error.prototype.toString()\n");
    v = othis.Get(Text.message, cc);
    if(!v)
        v = &vundefined;
    ret.putVstring(othis.Get(Text.name, cc).toString()~": "~v.toString());
    return null;
}

/* ===================== Derror_prototype ==================== */

class DerrorPrototype : Derror
{
    this()
    {
        super(Dobject.getPrototype);
        Dobject f = Dfunction.getPrototype;
        //d_string m = d_string_ctor(DTEXT("Error.prototype.message"));

        CallContext cc;
        Put(Text.constructor, Derror_constructor,
            Property.Attribute.DontEnum, cc);

        static enum NativeFunctionData[] nfd =
        [
            { Text.toString, &Derror_prototype_toString, 0 },
        ];

        DnativeFunction.initialize(this, nfd, Property.Attribute.None);

        Put(Text.name, Text.Error, Property.Attribute.None, cc);
        Put(Text.message, Text.Empty, Property.Attribute.None, cc);
        Put(Text.description, Text.Empty, Property.Attribute.None, cc);
        Put(Text.number, cast(d_number)(/*FACILITY |*/ 0),
            Property.Attribute.None, cc);
    }
}


/* ===================== Derror ==================== */

class Derror : Dobject
{
    this(Value * m, Value * v2)
    {
        super(getPrototype());
        classname = Text.Error;

        immutable(char)[] msg;
        msg = m.toString();
        CallContext cc;
        Put(Text.message, msg, Property.Attribute.None, cc);
        Put(Text.description, msg, Property.Attribute.None, cc);
        if(m.isString())
        {
        }
        else if(m.isNumber())
        {
            d_number n = m.toNumber();
            n = cast(d_number)(/*FACILITY |*/ cast(int)n);
            Put(Text.number, n, Property.Attribute.None, cc);
        }
        if(v2.isString())
        {
            Put(Text.description, v2.toString, Property.Attribute.None, cc);
            Put(Text.message, v2.toString, Property.Attribute.None, cc);
        }
        else if(v2.isNumber())
        {
            d_number n = v2.toNumber();
            n = cast(d_number)(/*FACILITY |*/ cast(int)n);
            Put(Text.number, n, Property.Attribute.None, cc);
        }
    }

    this(Dobject prototype)
    {
        super(prototype);
        classname = Text.Error;
    }

    static Dfunction getConstructor()
    {
        return Derror_constructor;
    }

    static Dobject getPrototype()
    {
        return Derror_prototype;
    }

    static void initialize()
    {
        Derror_constructor = new DerrorConstructor();
        Derror_prototype = new DerrorPrototype();

        CallContext cc;
        Derror_constructor.Put(Text.prototype, Derror_prototype,
                               Property.Attribute.DontEnum |
                               Property.Attribute.DontDelete |
                               Property.Attribute.ReadOnly, cc);
    }
}

private Dfunction Derror_constructor;
private Dobject Derror_prototype;

