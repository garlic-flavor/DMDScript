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

import dmdscript.dobject: Dobject;
import dmdscript.dfunction: Dconstructor;
import dmdscript.dnative: DnativeFunction, DFD = DnativeFunctionDescriptor;
import dmdscript.value: DError, Value;
import dmdscript.drealm: Drealm;


//==============================================================================
///
class Dsymbol : Dobject
{
    import dmdscript.primitive : Key;

private:
    this(Dobject prototype, string desc)
    {
        super(prototype, Key.Symbol);
        value.putVsymbol(desc);
    }

    this(Dobject prototype, ref Value desc)
    {
        super(prototype, Key.Symbol);
        value = desc;
    }
}

//
class DsymbolConstructor : Dconstructor
{
    import dmdscript.dfunction : Dfunction;
    import dmdscript.primitive : Key;

    this(Dobject superClassPrototype, Dobject functionPrototype)
    {
        super(new Dobject(superClassPrototype), functionPrototype,
              Key.Symbol, 1);

        install(functionPrototype);
    }

    Dsymbol opCall(ARGS...)(ARGS args)
    {
        return new Dsymbol(classPrototype, args);
    }

    override DError* Construct(Drealm realm, out Value ret,
                               Value[] arglist)
    {
        assert (0);
    }

    override DError* Call(Drealm realm, Dobject othis, out Value ret,
                          Value[] arglist)
    {
        ret.putVsymbol(0 < arglist.length ? arglist[0].toString(realm) :
                                            Key.undefined.idup);
        return null;
    }
}

//==============================================================================
private:

//
@DFD(1, DFD.Type.Static, "for")
DError* _for(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert(0);
}


