
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

module dmdscript.identifier;

import dmdscript.script;
import dmdscript.value;

/* An Identifier is a special case of a Value - it is a V_STRING
 * and has the hash value computed and set.
 */

struct Identifier
{
    Value value;

    @trusted @nogc pure nothrow
    d_string toString() const
    {
        return value.text;
    }

    @trusted @nogc pure nothrow
    bool opEquals(ref const(Identifier) id) const
    {
        return this is id || value.text == id.value.text;
    }

    @trusted
    static Identifier* build(d_string s)
    {
        Identifier* id = new Identifier;
        id.value.putVstring(s);
        id.value.toHash();
        return id;
    }

    @safe @nogc pure nothrow
    uint toHash() const
    {
        return value.hash;
    }
}


