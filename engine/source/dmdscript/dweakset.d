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

module dmdscript.dweakset;
import dmdscript.dfunction : Dconstructor;
import dmdscript.dobject : Dobject;
import dmdscript.dnative : DnativeFunction, DFD = DnativeFunctionDescriptor;
import dmdscript.value : DError, Value;
import dmdscript.drealm: Drealm;

//==============================================================================
///
class DweakSet : Dobject
{
private:
    this(Dobject prototype)
    {
        import dmdscript.primitive : Key;
        super(prototype, Key.WeakSet);
    }
}


class DweakSetConstructor : Dconstructor
{
    this(Dobject superClassPrototype, Dobject functionPrototype)
    {
        import dmdscript.primitive : Key;
        super(new Dobject(superClassPrototype), functionPrototype,
              Key.WeakSet, 1);
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
@DFD()
DError* add(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD()
DError* clear(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1, DFD.Type.Prototype, "delete")
DError* _delete(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD()
DError* entries(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1)
DError* forEach(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1)
DError* get(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1)
DError* has(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD
DError* keys(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1)
DError* set(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD
DError* size(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD
DError* values(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

