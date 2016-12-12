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

module dmdscript.callcontext;

debug import std.stdio;
//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

//
struct CallContext
{
    import dmdscript.dobject : Dobject;
    import dmdscript.program : Program;
    import dmdscript.dfunction : Dfunction;
    import dmdscript.functiondefinition : FunctionDefinition;
    import dmdscript.property : PropertyKey;
    import dmdscript.value : Value;

    // current scope chain
    Dobject[] scopex;

    // object for variable instantiation (is scopex[scoperoot-1] is scopex[$-1])
    Dobject variable;

    // global object (is scopex[globalroot - 1])
    Dobject global;

    // number of entries in scope[] starting from 0 to copy onto new scopes
    const uint scoperoot;

    // number of entries in scope[] starting from 0
    // that are in the "global" context. Always <= scoperoot
    const uint globalroot;

    // points to the last named function added as an event
    // void* lastnamedfunc;

    Program prog;
    Dobject callerothis;         // caller's othis
    Dfunction caller;            // caller function object
    FunctionDefinition callerf;

    bool Interrupt;  // !=0 if cancelled due to interrupt

    //--------------------------------------------------------------------
    ///
    @safe pure nothrow
    this(Program prog, Dobject global)
    {
        scopex = [global];
        variable = global;
        this.global = global;
        scoperoot = 1;
        globalroot = 1;
        this.prog = prog;
    }

    //--------------------------------------------------------------------
    ///
    @safe pure nothrow
    this(ref CallContext cc, Dobject variable, Dfunction caller,
         FunctionDefinition callerf)
    {
        scopex = cc.scopex ~ variable;
        this.variable = variable;
        global = cc.global;
        scoperoot = cc.scoperoot + 1;
        globalroot = cc.globalroot;
        callerothis = cc.callerothis;
        prog = cc.prog;
        this.caller = caller;
        this.callerf = callerf;
    }

    //--------------------------------------------------------------------
    ///
    Value* get(K)(in auto ref K key, out Dobject pthis)
        if (PropertyKey.IsKey!K)
    {
        Value* v;
        Dobject o;

        for (size_t d = scopex.length; ; --d)
        {
            if (0 < d)
            {
                o = scopex[d-1];
                v = o.Get(key, this);
                if (v !is null)
                    break;
            }
            else
            {
                o = null;
                break;
            }
        }

        pthis = o;
        return v;
    }

    //--------------------------------------------------------------------
    ///
    Value* get(K)(in auto ref K key)
        if (PropertyKey.IsKey!K)
    {
        for (size_t d = scopex.length; 0 < d; --d)
        {
            if (auto v = scopex[d-1].Get(key, this))
                return v;
        }

        return null;
    }

    //--------------------------------------------------------------------
    ///
    void put(K)(in auto ref K key, ref Value value)
        if (PropertyKey.IsKey!K)
    {
        import dmdscript.property : Property;

        assert(0 < globalroot);

        for (size_t d = scopex.length; ; --d)
        {
            if (globalroot < d)
            {
                auto o = scopex[d-1];
                if (auto v = o.Get(key, this))
                {
                    v.checkReference;
                    o.Set(key, value, Property.Attribute.None, this);
                    break;
                }
            }
            else
            {
                scopex[globalroot-1].Set(key, value, Property.Attribute.None,
                                         this);
                break;
            }
        }
    }
}

