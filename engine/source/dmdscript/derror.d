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

import dmdscript.primitive;
import dmdscript.script;
import dmdscript.dobject;
import dmdscript.dfunction;
import dmdscript.value;
import dmdscript.dnative;
import dmdscript.key;
import dmdscript.property;


// Comes from MAKE_HRESULT(SEVERITY_ERROR, FACILITY_CONTROL, 0)
const uint FACILITY = 0x800A0000;

/* ===================== Derror_constructor ==================== */

class DerrorConstructor : Dconstructor
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

        vemptystring.put(Text.Empty);
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
        ret.put(o);
        return null;
    }
}


/* ===================== Derror_prototype_toString =============== */
@DnativeFunctionDescriptor(Key.toString, 0)
DError* Derror_prototype_toString(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.11.4.3
    // Return implementation defined string
    Value* v;

    //writef("Error.prototype.toString()\n");
    v = othis.Get(Key.message, cc);
    if(!v)
        v = &vundefined;
    ret.put(othis.Get(Key.name, cc).toString()~": "~v.toString());
    return null;
}
/* ===================== Derror_prototype ==================== */
/*
class DerrorPrototype : Derror
{
    this()
    {
        super(Dobject.getPrototype);
        Dobject f = Dfunction.getPrototype;
        //d_string m = d_string_ctor(DTEXT("Error.prototype.message"));

        DefineOwnProperty(Key.constructor, Derror_constructor,
               Property.Attribute.DontEnum);

        static enum NativeFunctionData[] nfd =
        [
            { Key.toString, &Derror_prototype_toString, 0 },
        ];

        DnativeFunction.initialize(this, nfd, Property.Attribute.None);

        DefineOwnProperty(Key.name, Key.Error, Property.Attribute.None);
        DefineOwnProperty(Key.message, Text.Empty, Property.Attribute.None);
        DefineOwnProperty(Key.description, Text.Empty, Property.Attribute.None);
        DefineOwnProperty(Key.number, cast(double)(FACILITY | 0),
               Property.Attribute.None);
    }
}
//*/

/* ===================== Derror ==================== */

class Derror : Dobject
{
    import dmdscript.dobject : Initializer;

    this(Value * m, Value * v2)
    {
        super(getPrototype, Key.Error);

        immutable(char)[] msg;
        msg = m.toString();
        CallContext cc;
        Set(Key.message, msg, Property.Attribute.None, cc);
        Set(Key.description, msg, Property.Attribute.None, cc);
        if(m.isString())
        {
        }
        else if(m.isNumber())
        {
            double n = m.toNumber(cc);
            n = cast(double)(/*FACILITY |*/ cast(int)n);
            Set(Key.number, n, Property.Attribute.None, cc);
        }
        if(v2.isString())
        {
            Set(Key.description, v2.toString, Property.Attribute.None, cc);
            Set(Key.message, v2.toString, Property.Attribute.None, cc);
        }
        else if(v2.isNumber())
        {
            double n = v2.toNumber(cc);
            n = cast(double)(/*FACILITY |*/ cast(int)n);
            Set(Key.number, n, Property.Attribute.None, cc);
        }
    }

    this(Dobject prototype)
    {
        super(prototype, Key.Error);
    }

public static:
    mixin Initializer!DerrorConstructor _Initializer;

    void initPrototype()
    {
        _Initializer.initPrototype;

        _prototype.DefineOwnProperty(Key.name, Key.Error,
                                     Property.Attribute.None);
        _prototype.DefineOwnProperty(Key.message, Text.Empty,
                                     Property.Attribute.None);
        _prototype.DefineOwnProperty(Key.description, Text.Empty,
                                     Property.Attribute.None);
        _prototype.DefineOwnProperty(Key.number, cast(double)(/*FACILITY |*/ 0),
                                     Property.Attribute.None);
    }

/*
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

        Derror_constructor.DefineOwnProperty(Key.prototype, Derror_prototype,
                                  Property.Attribute.DontEnum |
                                  Property.Attribute.DontDelete |
                                  Property.Attribute.ReadOnly);
    }
*/
}

// private Dfunction Derror_constructor;
// private Dobject Derror_prototype;

