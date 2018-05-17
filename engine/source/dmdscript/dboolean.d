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

module dmdscript.dboolean;

import dmdscript.primitive: Key;
import dmdscript.dobject: Dobject;
import dmdscript.value: DError, Value;
import dmdscript.dfunction: Dconstructor;
import dmdscript.errmsgs;
import dmdscript.dnative: DnativeFunction, DFD = DnativeFunctionDescriptor;
import dmdscript.drealm: Drealm;

//==============================================================================
///
class Dboolean : Dobject
{
private:
    this(Dobject prototype, bool b = false)
    {
        super(prototype, Key.Boolean);
        value.put(b);
    }
}


//------------------------------------------------------------------------------
class DbooleanConstructor : Dconstructor
{
    this(Dobject superClassPrototype, Dobject functionPrototype)
    {
        super(new Dobject(superClassPrototype), functionPrototype,
              Key.Boolean, 1);
        install(functionPrototype);
    }

    Dboolean opCall(bool b = false)
    {
        return new Dboolean(classPrototype, b);
    }

    override DError* Construct(Drealm realm, out Value ret,
                               Value[] arglist)
    {
        // ECMA 15.6.2
        bool b;
        Dobject o;

        b = (arglist.length) ? arglist[0].toBoolean() : false;
        o = opCall(b);
        ret.put(o);
        return null;
    }

    override DError* Call(Drealm realm, Dobject othis, out Value ret,
                          Value[] arglist)
    {
        // ECMA 15.6.1
        bool b;

        b = (arglist.length) ? arglist[0].toBoolean() : false;
        ret.put(b);
        return null;
    }
}

//==============================================================================
private:


//------------------------------------------------------------------------------
@DFD(0)
DError* toString(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    // othis must be a Boolean
    if (auto db = cast(Dboolean)othis)
    {
        ret.put(db.value.toString(realm));
    }
    else
    {
        ret.putVundefined;
        return FunctionWantsBoolError(realm, Key.toString, othis.classname);
    }
    return null;
}

//------------------------------------------------------------------------------
@DFD(0)
DError* valueOf(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    //FuncLog f("Boolean.prototype.valueOf()");
    //logflag = 1;

    // othis must be a Boolean
    if (auto db = cast(Dboolean)othis)
    {
        ret = db.value;
    }
    else
    {
        ret.putVundefined;
        return FunctionWantsBoolError(realm, Key.valueOf, othis.classname);
    }
    return null;
}
