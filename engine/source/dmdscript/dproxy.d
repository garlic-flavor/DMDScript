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

import dmdscript.dfunction : Dconstructor;
import dmdscript.dobject : Dobject;
import dmdscript.dnative : DnativeFunction, DFD = DnativeFunctionDescriptor;
import dmdscript.value : DError, Value;
import dmdscript.callcontext : CallContext;

//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// NOT IMPLEMENTED YET.
class Dproxy : Dobject
{
    import dmdscript.dfunction : Dfunction;
    import dmdscript.dobject : Initializer;

    this()
    {
        super(null);
    }

    this(Dobject prototype)
    {
        import dmdscript.primitive : Key;
        super(prototype, Key.Proxy);
    }

    mixin Initializer!DproxyConstructor;
private:

    Dfunction _getPrototypeOf;
    Dfunction _setPrototypeOf;
    Dfunction _isExtensible;
    Dfunction _preventExtensions;
    Dfunction _getOwnPropertyDescriptor;
    Dfunction _has;
    Dfunction _get;
    Dfunction _set;
    Dfunction _deleteProperty;
    Dfunction _DefineProperty;
    Dfunction _ownkeys;
    Dfunction _apply;
    Dfunction _construct;
}

//==============================================================================
private:

//
@DFD(2, DFD.Type.Static)
DError* revocable(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

class DproxyConstructor : Dconstructor
{
    this()
    {
        import dmdscript.primitive : Key;
        super(Key.Proxy, 1, Dfunction.getPrototype);
    }

    override DError* Construct(ref CallContext cc, out Value ret,
                               Value[] arglist)
    {
        assert (0);
    }
}
