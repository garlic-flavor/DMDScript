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

import dmdscript.dfunction: Dconstructor;
import dmdscript.dobject: Dobject;
import dmdscript.dnative: DnativeFunction, DFD = DnativeFunctionDescriptor;
import dmdscript.value: DError, Value;
import dmdscript.drealm: Drealm;

//==============================================================================
///
class DarrayBuffer : Dobject
{

private:
    this(Dobject prototype)
    {
        import dmdscript.primitive : Key;
        super(prototype, Key.Map);
    }
}

//
class DarrayBufferConstructor : Dconstructor
{
    this(Dobject superClassPrototype, Dobject functionPrototype)
    {
        import dmdscript.primitive: Key;
        super(new Dobject(superClassPrototype), functionPrototype,
              Key.ArrayBuffer, 1);

        install(functionPrototype);
    }

    override DError* Construct(Drealm realm, out Value ret,
                               Value[] arglist)
    {
        assert (0);
    }
}

//==============================================================================
private:

//
@DFD(1, DFD.Type.Static)
DError* isView(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}


//
@DFD()
DError* byteLength(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(2)
DError* slice(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}
