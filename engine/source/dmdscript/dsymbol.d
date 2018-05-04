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

module dmdscript.dsymbol;

import dmdscript.dobject : Dobject;
import dmdscript.dfunction : Dconstructor;
import dmdscript.dnative : DnativeFunction, DFD = DnativeFunctionDescriptor;
import dmdscript.callcontext : CallContext;
import dmdscript.value : DError, Value;


//==============================================================================
///
class Dsymbol : Dobject
{
    import dmdscript.primitive : Key;
    import dmdscript.dobject : Initializer;

    this(string desc)
    {
        super(Dsymbol.getPrototype, Key.Symbol);
        value.putVsymbol(desc);
    }

    this(ref Value desc)
    {
        super(Dsymbol.getPrototype, Key.Symbol);
        value = desc;
    }

    mixin Initializer!DsymbolConstructor;
}


//==============================================================================
private:

//
@DFD(1, DFD.Type.Static, "for")
DError* _for(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert(0);
}


//
class DsymbolConstructor : Dconstructor
{
    import dmdscript.dfunction : Dfunction;
    import dmdscript.primitive : Key;

    this()
    {
        super(Key.Symbol, 1, Dfunction.getPrototype);

       // DefineOwnProperty(Key.Iterator,,,
    }

    override DError* Construct(ref CallContext cc, out Value ret,
                               Value[] arglist)
    {
        assert (0);
    }

    override DError* Call(ref CallContext cc, Dobject othis, out Value ret,
                          Value[] arglist)
    {
        ret.putVsymbol(0 < arglist.length ? arglist[0].toString(cc) :
                                            Key.undefined.idup);
        return null;
    }
}


