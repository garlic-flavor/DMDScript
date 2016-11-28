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


module dmdscript.dnative;

import dmdscript.script;
import dmdscript.dobject;
import dmdscript.dfunction;
import dmdscript.value;
import dmdscript.property;

/******************* DnativeFunction ****************************/

alias PCall = DError* function(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist);

struct NativeFunctionData
{
    d_string str;
    PCall     pcall;
    d_uint32  length;
}

class DnativeFunction : Dfunction
{
    PCall pcall;

    this(PCall func, d_string name, d_uint32 length)
    {
        super(length);
        this.name = name;
        pcall = func;
    }

    this(PCall func, d_string name, d_uint32 length, Dobject o)
    {
        super(length, o);
        this.name = name;
        pcall = func;
    }

    override DError* Call(ref CallContext cc, Dobject othis, out Value ret,
                          Value[] arglist)
    {
        return (*pcall)(this, cc, othis, ret, arglist);
    }

    /*********************************
     * Initalize table of native functions designed
     * to go in as properties of o.
     */

    static void initialize(Dobject o, NativeFunctionData[] nfd,
                           Property.Attribute attributes)
    {
        Dobject f = Dfunction.getPrototype();
        for(size_t i = 0; i < nfd.length; i++)
        {
            NativeFunctionData* n = &nfd[i];

            o.config(n.str, new DnativeFunction(n.pcall, n.str, n.length, f),
                     attributes);
        }
    }
}
