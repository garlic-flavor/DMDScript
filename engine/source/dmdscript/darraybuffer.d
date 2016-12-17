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

module dmdscript.darraybuffer;

import dmdscript.dfunction : Dconstructor;
import dmdscript.dobject : Dobject;
import dmdscript.dnative : DnativeFunction, DFD = DnativeFunctionDescriptor;
import dmdscript.value : DError, Value;
import dmdscript.callcontext : CallContext;

//==============================================================================
///
class DarrayBuffer : Dobject
{
    import dmdscript.dobject : Initializer;

    this()
    {
        this(getPrototype);
    }

    this(Dobject prototype)
    {
        import dmdscript.primitive : Key;
        super(prototype, Key.Map);
    }

    mixin Initializer!DarrayBufferConstructor;
}


//==============================================================================
private:

//
@DFD(1, DFD.Type.Static)
DError* isView(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
class DarrayBufferConstructor : Dconstructor
{
    this()
    {
        import dmdscript.primitive : Key;
        super(Key.ArrayBuffer, 1, Dfunction.getPrototype);
    }

    override DError* Construct(ref CallContext cc, out Value ret,
                               Value[] arglist)
    {
        assert (0);
    }
}

//
@DFD()
DError* byteLength(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(2)
DError* slice(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}
