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
module dmdscript.dbigint;

import dmdscript.dobject: Dobject;
import dmdscript.dfunction: Dconstructor;
import dmdscript.value: Value, DError;
import dmdscript.callcontext: CallContext;
import dmdscript.dnative: DFD = DnativeFunctionDescriptor, DnativeFunction;

//==============================================================================
///
class DbigInt: Dobject
{
    import std.bigint: BigInt;

private:
    this (Dobject prototype, BigInt* pbi)
    {
        import dmdscript.primitive: Key;
        super(prototype, Key.BigInt);
        value.put(pbi);
    }
}

//------------------------------------------------------------------------------
class DbigIntConstructor: Dconstructor
{
    import std.bigint: BigInt;

    this (Dobject superClassPrototype, Dobject functionPrototype)
    {
        import dmdscript.primitive: Key;
        super (new Dobject(superClassPrototype), functionPrototype,
               Key.BigInt, 1);

        install(functionPrototype);
    }

    DbigInt opCall(BigInt* pbi)
    {
        return new DbigInt(classPrototype, pbi);
    }

    override
    DError* Construct (CallContext* cc, out Value ret, Value[] arglist)
    {
        BigInt* pbi;
        Dobject o;

        assert (0);
    }

    override
    DError* Call (CallContext* cc, Dobject othis, out Value ret,
                  Value[] arglist)
    {
        assert (0);
    }
}

//
@DFD(0)
DError* valueOf(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import dmdscript.primitive: Key;
    import dmdscript.errmsgs: FunctionWantsNumberError;

    if (auto dbi = cast(DbigInt)othis)
    {
        ret = dbi.value;
    }
    else
    {
        ret.putVundefined;
        return FunctionWantsNumberError(cc, Key.valueOf, othis.classname);
    }
    return null;
}
