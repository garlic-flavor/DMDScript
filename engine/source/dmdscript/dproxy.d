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

module dmdscript.dproxy;

import dmdscript.primitive : PKey = Key, PropertyKey;
import dmdscript.dfunction : Dconstructor;
import dmdscript.dobject : Dobject;
import dmdscript.dnative : DnativeFunction, DFD = DnativeFunctionDescriptor;
import dmdscript.value : DError, Value;
import dmdscript.callcontext : CallContext;
import dmdscript.errmsgs;
import dmdscript.property : Property, PropTable;

//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// NOT IMPLEMENTED YET.
class Dproxy : Dobject
{
    import dmdscript.dfunction : Dfunction;

private:
    this(Dobject prototype, CallContext cc, Dobject prop)
    {
        super(prototype, Key.Proxy);

        if (auto ret = prop.Get(Key.set, cc))
        {
            if (auto func = cast(Dfunction)ret.toObject(cc))
            {
                SetSetter(PropTable.SpecialSymbols.opAssign, func,
                          Property.Attribute.DontEnum);
            }
        }

    }

}

class DproxyConstructor : Dconstructor
{
    this(Dobject superClassPrototype, Dobject functionPrototype)
    {
        import dmdscript.primitive : Key;
        super(new Dobject(superClassPrototype), functionPrototype,
              Key.Proxy, 1);
        install(functionPrototype);
    }

    override DError* Construct(CallContext cc, out Value ret,
                               Value[] arglist)
    {
        Dobject proto, attr;

        if (0 < arglist.length)
            proto = arglist[0].toObject(cc);
        else
            proto = new Dobject(null);

        if (1 < arglist.length)
            attr = arglist[1].toObject(cc);
        else
            attr = new Dobject(null);

        ret.put(new Dproxy(proto, cc, attr));
        return null;
    }
}

//==============================================================================
private:

enum Key : PropertyKey
{
    Proxy = PKey.Symbol,

    set = PropertyKey("set"),
}

//
@DFD(2, DFD.Type.Static)
DError* revocable(
    DnativeFunction pthis, CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

