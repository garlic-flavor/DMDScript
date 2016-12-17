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

import dmdscript.primitive : Key;
import dmdscript.callcontext : CallContext;
import dmdscript.dobject : Dobject;
import dmdscript.value : DError, Value;
import dmdscript.dfunction : Dconstructor;
import dmdscript.errmsgs;
import dmdscript.dnative : DnativeFunction, DFD = DnativeFunctionDescriptor;

//==============================================================================
///
class Dboolean : Dobject
{
    import dmdscript.dobject : Initializer;

    this(bool b)
    {
        super(Dboolean.getPrototype, Key.Boolean);
        value.put(b);
    }

    this(Dobject prototype)
    {
        super(prototype, Key.Boolean);
        value.put(false);
    }

    mixin Initializer!DbooleanConstructor;
}


//==============================================================================
private:

//------------------------------------------------------------------------------
class DbooleanConstructor : Dconstructor
{
    this()
    {
        super(Key.Boolean, 1, Dfunction.getPrototype);
    }

    override DError* Construct(ref CallContext cc, out Value ret,
                               Value[] arglist)
    {
        // ECMA 15.6.2
        bool b;
        Dobject o;

        b = (arglist.length) ? arglist[0].toBoolean() : false;
        o = new Dboolean(b);
        ret.put(o);
        return null;
    }

    override DError* Call(ref CallContext cc, Dobject othis, out Value ret,
                          Value[] arglist)
    {
        // ECMA 15.6.1
        bool b;

        b = (arglist.length) ? arglist[0].toBoolean() : false;
        ret.put(b);
        return null;
    }
}


//------------------------------------------------------------------------------
@DFD(0)
DError* toString(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // othis must be a Boolean
    if (auto db = cast(Dboolean)othis)
    {
        ret.put(db.value.toString);
    }
    else
    {
        ret.putVundefined;
        return FunctionWantsBoolError(Key.toString, othis.classname);
    }
    return null;
}

//------------------------------------------------------------------------------
@DFD(0)
DError* valueOf(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
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
        return FunctionWantsBoolError(Key.valueOf, othis.classname);
    }
    return null;
}
