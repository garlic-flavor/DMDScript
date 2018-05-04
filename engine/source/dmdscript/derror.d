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

import dmdscript.primitive : Key;
import dmdscript.callcontext : CallContext;
import dmdscript.dobject : Dobject;
import dmdscript.dfunction : Dconstructor;
import dmdscript.value : Value, DError;
import dmdscript.dnative : DnativeFunction, DFD = DnativeFunctionDescriptor;

//==============================================================================
///
class Derror : Dobject
{
    import dmdscript.dobject : Initializer;
    import dmdscript.property : Property;

    this(ref CallContext cc, Value* m, Value* v2)
    {
        super(getPrototype, Key.Error);

        string msg;
        msg = m.toString(cc);
        auto val = Value(msg);
        Set(Key.message, val, Property.Attribute.None, cc);
        Set(Key.description, val, Property.Attribute.None, cc);
        if(m.isString())
        {
        }
        else if(m.isNumber)
        {
            double n = m.toNumber(cc);
            n = cast(double)(/*FACILITY |*/ cast(int)n);
            val.put(n);
            Set(Key.number, val, Property.Attribute.None, cc);
        }
        if(v2.isString)
        {
            Set(Key.description, *v2, Property.Attribute.None, cc);
            Set(Key.message, *v2, Property.Attribute.None, cc);
        }
        else if(v2.isNumber)
        {
            double n = v2.toNumber(cc);
            n = cast(double)(/*FACILITY |*/ cast(int)n);
            val.put(n);
            Set(Key.number, val, Property.Attribute.None, cc);
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
        import dmdscript.primitive : Text;
        import dmdscript.property : Property;

        _Initializer.initPrototype;

        Value val;
        val.put(Key.Error);
        _class_prototype.DefineOwnProperty(Key.name, val,
                                           Property.Attribute.None);
        val.put(Text.Empty);
        _class_prototype.DefineOwnProperty(Key.message, val,
                                           Property.Attribute.None);
        _class_prototype.DefineOwnProperty(Key.description, val,
                                           Property.Attribute.None);
        val.put(0);
        _class_prototype.DefineOwnProperty(Key.number, val,
                                           Property.Attribute.None);
    }
}

//==============================================================================
private:

// Comes from MAKE_HRESULT(SEVERITY_ERROR, FACILITY_CONTROL, 0)
const uint FACILITY = 0x800A0000;

//------------------------------------------------------------------------------
class DerrorConstructor : Dconstructor
{
    this()
    {
        super(1, Dfunction.getPrototype);
    }

    override DError* Construct(ref CallContext cc, out Value ret,
                               Value[] arglist)
    {
        import dmdscript.dglobal : undefined;
        import dmdscript.primitive : Text;

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
            n = &undefined;
            break;
        case 1:
            m = &arglist[0];
            if(m.isNumber())
            {
                n = m;
                m = &vemptystring;
            }
            else
                n = &undefined;
            break;
        default:
            m = &arglist[0];
            n = &arglist[1];
            break;
        }
        o = new Derror(cc, m, n);
        ret.put(o);
        return null;
    }
}


//------------------------------------------------------------------------------
@DFD(0)
DError* toString(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import dmdscript.dglobal : undefined;

    // ECMA v3 15.11.4.3
    // Return implementation defined string
    Value* v;

    //writef("Error.prototype.toString()\n");
    v = othis.Get(Key.message, cc);
    if(!v)
        v = &undefined;
    ret.put(othis.Get(Key.name, cc).toString(cc) ~ ": " ~ v.toString(cc));
    return null;
}

