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
import dmdscript.value: Value;
import dmdscript.dfunction: Dconstructor;
import dmdscript.errmsgs;
import dmdscript.dnative: DnativeFunction, ArgList,
    DFD = DnativeFunctionDescriptor;
import dmdscript.drealm: Drealm;
import dmdscript.callcontext: CallContext;
import dmdscript.derror: Derror;

//==============================================================================
///
class Dboolean : Dobject
{
private:
    nothrow
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

    nothrow
    Dboolean opCall(bool b = false)
    {
        return new Dboolean(classPrototype, b);
    }

    override Derror Construct(CallContext* cc, out Value ret,
                               Value[] arglist)
    {
        // ECMA 15.6.2
        bool b;
        Dobject o;
        Derror e;

        if (0 < arglist.length)
            e = arglist[0].to(b, cc);
        else
            b = false;

        o = opCall(b);
        ret.put(o);
        return e;
    }

    override Derror Call(CallContext* cc, Dobject othis, out Value ret,
                          Value[] arglist)
    {
        // ECMA 15.6.1
        bool b;
        Derror e;

        if (0 < arglist.length)
            e = arglist[0].to(b, cc);
        else
            b = false;

        ret.put(b);
        return e;
    }
}

//==============================================================================
private:


//------------------------------------------------------------------------------
@DFD(0)
Derror toString(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    // othis must be a Boolean
    if (auto db = cast(Dboolean)othis)
    {
        string s;
        db.value.to(s, cc);
        ret.put(s);
    }
    else
    {
        ret.putVundefined;
        return FunctionWantsBoolError(cc, Key.toString, othis.classname);
    }
    return null;
}

//------------------------------------------------------------------------------
@DFD(0)
Derror valueOf(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
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
        return FunctionWantsBoolError(cc, Key.valueOf, othis.classname);
    }
    return null;
}
