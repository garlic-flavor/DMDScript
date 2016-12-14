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
module dmdscript.dboundfunction;

import dmdscript.dobject : Dobject;

//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// NOT IMPLEMENTED YET.
class DboundFunction : Dobject
{
    import dmdscript.primitive : tstring, Text;
    import dmdscript.dfunction : Dfunction;
    import dmdscript.value : Value, DError;
    import dmdscript.callcontext : CallContext;

    Dfunction BoundTargetFunction;
    Dobject BoundThis;
    Value[] BoundArguments;

    override
    DError* Call(ref CallContext cc, Dobject othis, out Value ret,
                 Value[] arglist)
    {
        assert(BoundTargetFunction !is null);
        return BoundTargetFunction.Call(cc, othis, ret, arglist);
    }

    override
    tstring getTypeof() const
    {
        return Text._function;
    }

    override
    string toString()
    {
        return "not implemented yet.";
    }
}
