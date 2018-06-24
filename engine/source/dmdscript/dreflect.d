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

module dmdscript.dreflect;

import dmdscript.dfunction : Dconstructor;
import dmdscript.dobject : Dobject;
import dmdscript.dnative : DnativeFunction, DFD = DnativeFunctionDescriptor;
import dmdscript.value : Value;
import dmdscript.drealm: Drealm;
import dmdscript.callcontext: CallContext;
import dmdscript.derror: Derror;

//==============================================================================
///
class Dreflect : Dobject
{
private:
    this(Dobject prototype)
    {
        import dmdscript.primitive : Key;
        super(prototype, Key.Reflect);
    }
}

//
class DreflectConstructor : Dconstructor
{
    this(Dobject superClassPrototype, Dobject functionPrototype)
    {
        import dmdscript.primitive : Key;
        super(new Dobject(superClassPrototype), functionPrototype,
              Key.Promise, 1);
        install(functionPrototype);
    }

    override Derror* Construct(CallContext* cc, out Value ret,
                               Value[] arglist)
    {
        assert (0);
    }
}


//==============================================================================
private:

//
@DFD(1, DFD.Type.Static)
Derror* apply(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(3, DFD.Type.Static)
Derror* defineProperty(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(2, DFD.Type.Static)
Derror* deleteProperty(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(2, DFD.Type.Static)
Derror* get(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(2, DFD.Type.Static)
Derror* getOwnPropertyDescriptor(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(2, DFD.Type.Static)
Derror* getPrototypeOf(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1, DFD.Type.Static)
Derror* has(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1, DFD.Type.Static)
Derror* isExtensible(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1, DFD.Type.Static)
Derror* ownKeys(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1, DFD.Type.Static)
Derror* preventExtensions(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(3, DFD.Type.Static)
Derror* set(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(2, DFD.Type.Static)
Derror* setPrototypeOf(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}


//
@DFD(1, DFD.Type.Prototype, "catch")
Derror* _catch(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(2)
Derror* then(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

