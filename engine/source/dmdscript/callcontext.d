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
//==============================================================================
///
struct CallContext
{
    import dmdscript.dobject : Dobject;
    import dmdscript.program : Program;
    import dmdscript.property : PropertyKey, Property;
    import dmdscript.value : Value, DError;

    //--------------------------------------------------------------------
    ///
    @safe pure nothrow
    this(Program prog, Dobject global)
    {
        _scopex = ScopeStack(global);
        _prog = prog;
    }

    //--------------------------------------------------------------------
    ///
    @property @safe @nogc pure nothrow
    ref inout(ScopeStack) scopex() inout
    {
        return _scopex;
    }

    ///
    @property @safe @nogc pure nothrow
    inout(Program) program() inout
    {
        return _prog;
    }

    ///
    @property @safe @nogc pure nothrow
    bool isInterrupting() const
    {
        return _interrupt;
    }

    ///
    @property @safe @nogc pure nothrow
    void interrupt()
    {
        _interrupt = true;
    }

    //--------------------------------------------------------------------
    /// Search a variable in current scope chain.
    Value* get(K)(in auto ref K key, out Dobject pthis)
        if (PropertyKey.IsKey!K)
    {
        return _scopex.get(this, key, pthis);
    }

    /// ditto
    Value* get(K)(in auto ref K key)
        if (PropertyKey.IsKey!K)
    {
        return _scopex.get(this, key);
    }

    //--------------------------------------------------------------------
    /// Assign a variable in current scope chain.
    /// Or, define a variable in global.
    DError* set(K)(in auto ref K key, ref Value value,
                   Property.Attribute attr = Property.Attribute.None)
        if (PropertyKey.IsKey!K)
    {
        return _scopex.set(this, key, value, attr);
    }

    //--------------------------------------------------------------------
    /// Define/Assign a variable in current variable's scope.
    DError* setThis(K)(in auto ref K key, ref Value value,
                       Property.Attribute attr)
        if (PropertyKey.IsKey!K)
    {
        return _scopex.setThis(this, key, value, attr);
    }

private:
    ScopeStack _scopex;     /// current scope chain
    Program _prog;
    bool _interrupt;        /// !=0 if cancelled due to interrupt
}


//==============================================================================
/*
function func1()
{
    if (true)
    {
        func2();
    }
}

+------+------+------+------+---- --- -- -
|      |      |      |      |
|global|func1 |  if  |func2 |              ----  _stack
|      |      |      |      |
+------+------+------+------+---- --- -- -
      /  ____/             /
     /  /  _______________/
    /  /  /
  [1][2][4][...                            ----  _scopes.scoperoot

1. _stack represents a variable searching chain.
2. _scopes.scoperoot indicates the point on _stack,
   and it means that _stack[_scopes[x].scoperoot - 1] is a function's root
   variable searching scope.
*/
///
struct ScopeStack
{
    import std.array : Appender;
    import dmdscript.dobject : Dobject;
    import dmdscript.dfunction : Dfunction;
    import dmdscript.functiondefinition : FunctionDefinition;
    import dmdscript.property : Property, PropertyKey;
    import dmdscript.value : Value, DError;

    //--------------------------------------------------------------------
    ///
    @property @safe @nogc pure nothrow
    inout(Dobject) global() inout
    {
        return _global;
    }

    ///
    @property @safe @nogc pure nothrow
    inout(Dobject) variable() inout
    {
        return _variable.variable;
    }

    ///
    @property @safe @nogc pure nothrow
    inout(Dfunction) caller() inout
    {
        return _variable.caller;
    }

    ///
    @property @safe @nogc pure nothrow
    inout(Dobject) callerothis() inout
    {
        return _variable.callerothis;
    }

    ///
    @property @safe @nogc pure nothrow
    inout(Dobject)[] stack() inout
    {
        return _stack.data;
    }

    ///
    @property @safe @nogc pure nothrow
    bool isVariableRoot() const
    {
        return _stack.data.length <= _variable.scoperoot;
    }

    /// Get a Dobject that is not a Catch nor a Finally.
    @safe @nogc pure nothrow
    inout(Dobject) getNonFakeObject() inout
    {
        auto stack = _stack.data;
        for (size_t d = stack.length; _variable.scoperoot <= d; --d)
        {
            auto o = stack[d - 1];
            if (o.getTypeof !is null)
                return o;
        }
        assert(0);
    }

    //--------------------------------------------------------------------
    ///
    @safe pure nothrow
    void pushVariableScope(Dobject variable, Dfunction caller,
                           FunctionDefinition callerf, Dobject callerothis)
    {
        assert (variable !is null);

        _stack.put(variable);
        _scopes.put(VariableScope(_stack.data.length, variable,
                                  caller, callerf, callerothis));
        _variable = &_scopes.data[$-1];
    }

    ///
    @safe pure
    bool popVariableScope()
    {
        auto sd = _scopes.data;
        if (sd.length <= GLOBAL_ROOT)
            return false;

        assert (GLOBAL_ROOT < _variable.scoperoot);

        _stack.shrinkTo(_variable.scoperoot - 1);
        _scopes.shrinkTo(sd.length - 1);
        _variable = &_scopes.data[$-1];
        return true;
    }

    //--------------------------------------------------------------------
    ///
    @safe pure nothrow
    void push(Dobject obj)
    {
        _stack.put(obj);
    }

    ///
    @safe pure
    Dobject pop()
    {
        auto sd = _stack.data;
        auto len = sd.length;
        if (len <= _variable.scoperoot)
            return null;

        auto ret = sd[len - 1];
        _stack.shrinkTo(len - 1);
        return ret;
    }


    //--------------------------------------------------------------------
    ///
    Value* get(K)(ref CallContext cc, in auto ref K key, out Dobject pthis)
        if (PropertyKey.IsKey!K)
    {
        Value* v;
        Dobject o;

        auto stack = _stack.data;
        for (size_t d = stack.length; ; --d)
        {
            if (GLOBAL_ROOT <= d)
            {
                o = stack[d - 1];
                v = o.Get(key, cc);
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

    ///
    Value* get(K)(ref CallContext cc, in auto ref K key)
        if (PropertyKey.IsKey!K)
    {
        auto stack = _stack.data;
        for (size_t d = stack.length; GLOBAL_ROOT <= d; --d)
        {
            if (auto v = stack[d-1].Get(key, cc))
                return v;
        }
        return null;
    }

    //--------------------------------------------------------------------
    ///
    DError* set(K)(ref CallContext cc, in auto ref K key, ref Value value,
                   Property.Attribute attr = Property.Attribute.None)
    {
        import dmdscript.property : Property;

        auto stack = _stack.data;
        for (size_t d = stack.length; ; --d)
        {
            if (GLOBAL_ROOT < d)
            {
                auto o = stack[d - 1];
                if (auto v = o.Get(key, cc))
                {
                    v.checkReference;
                    return o.Set(key, value, attr, cc);
                }
            }
            else
            {
                return _global.Set(key, value, attr, cc);
            }
        }
    }

    ///
    DError* setThis(K)(ref CallContext cc, in auto ref K key, ref Value value,
                       Property.Attribute attr)
    {
        assert(_variable.variable !is null);
        return _variable.variable.Set(key, value, attr, cc);
    }

    debug
    string dump()
    {
        import std.conv : text;
        import std.array : Appender;
        Appender!string buf;

        buf.put(text("{ stack.length = ", _stack.data.length, "\n"));
        buf.put(text("  scopes.length = ", _scopes.data.length, "\n"));
        buf.put(text("  scoperoot = ", _variable.scoperoot, "}"));

        return buf.data;
    }


    //====================================================================
private:
    enum GLOBAL_ROOT = 1;

    struct VariableScope
    {
        size_t scoperoot;
        Dobject variable;
        Dfunction caller;
        FunctionDefinition callerf; // not used, now.
        Dobject callerothis;
    }

    Dobject _global;
    VariableScope* _variable;
    Appender!(Dobject[]) _stack;
    Appender!(VariableScope[]) _scopes;

    invariant
    {
        assert (_global !is null);

        assert (_variable !is null);
        assert (GLOBAL_ROOT <= _variable.scoperoot);
        assert (_variable.variable !is null);

        assert (0 < _stack.data.length);
        assert (0 < _scopes.data.length);
    }

    ///
    @safe pure nothrow
    this(Dobject global)
    {
        assert (global !is null);

        _global = global;
        _stack.put(global);
        _scopes.put(VariableScope(GLOBAL_ROOT, global, null, null, global));
        _variable = &_scopes.data[$-1];
    }
}
