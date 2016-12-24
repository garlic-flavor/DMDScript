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

//------------------------------------------------------------------------------
/**
This structure represents the environment about the current running function.
*/
struct VariableScope
{
    import dmdscript.dobject : Dobject;
    import dmdscript.dfunction : Dfunction;
    import dmdscript.functiondefinition : FunctionDefinition;

    Dobject variable; /// Outermost searching field composing the function.
    Dfunction caller; /// The object who calls the function.
    FunctionDefinition callerf; /// The definition of the function.
    Dobject callerothis; /// The object that contains the caller.

    /// The constructor for calling CallContext.pushFunctionScope.
    @safe @nogc pure nothrow
    this(Dobject variable, Dfunction caller, FunctionDefinition callerf,
         Dobject callerothis)
    {
        assert (variable !is null);
        assert (caller !is null);
        assert (callerf !is null);
        assert (callerothis !is null);

        this.variable = variable;
        this.caller = caller;
        this.callerf = callerf;
        this.callerothis = callerothis;
    }

    /// The constructor for calling CallContext.pushEvalScope.
    @safe @nogc pure nothrow
    this(Dfunction caller, FunctionDefinition callerf)
    {
        assert (caller !is null);
        assert (callerf !is null);
        this.caller = caller;
        this.callerf = callerf;
    }

    ///
    @safe @nogc pure nothrow
    this(FunctionDefinition callerf)
    {
        assert (callerf !is null);
        this.callerf = callerf;
    }

    ///
    @safe pure
    string toString() const
    {
        import std.conv : text;
        string name;
        if (callerf !is null && callerf.name !is null)
            name = callerf.name.toString;
        return text("{name=", name, ", scoperoot=", scoperoot, ", prevlength="
                    , prevlength, "}");
    }

    //====================================================================
private:
    size_t scoperoot;
    size_t prevlength;

    @safe @nogc pure nothrow
    this(Dobject variable, Dfunction caller, FunctionDefinition callerf,
         Dobject callerothis, size_t scoperoot, size_t prevlength)
    {
        assert (variable !is null);
        assert (callerothis !is null);
        assert (prevlength <= scoperoot);

        this.variable = variable;
        this.caller = caller;
        this.callerf = callerf;
        this.callerothis = callerothis;
        this.scoperoot = scoperoot;
        this.prevlength = prevlength;
    }
}


//------------------------------------------------------------------------------
///
struct CallContext
{
    import dmdscript.primitive : string_t;
    import dmdscript.dobject : Dobject;
    import dmdscript.property : PropertyKey, Property;
    import dmdscript.value : Value, DError;
    import dmdscript.dfunction : Dfunction;

    //--------------------------------------------------------------------
    /**
    Params:
        global = The outermost searching field.
     */
    @safe pure nothrow
    this(Dobject global)
    {
        _scopex = ScopeStack(global);
    }

    //--------------------------------------------------------------------
    /// Get the outermost searching field.
    @property @safe @nogc pure nothrow
    inout(Dobject) global() inout
    {
        return _scopex.global;
    }

    //--------------------------------------------------------------------
    /** Get the current interrupting flag.

    When this is true, dmdscript.opcodes.IR.call will return immediately.
    */
    @property @safe @nogc pure nothrow
    bool isInterrupting() const
    {
        return _interrupt;
    }

    /// Make the interrupting flag to true.
    @property @safe @nogc pure nothrow
    void interrupt()
    {
        _interrupt = true;
    }

    //--------------------------------------------------------------------
    /** Search a variable in the current scope chain.

    Params:
        key   = The name of the variable.
        pthis = The field that contains the searched variable.
    */
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
    /** Assign to a variable in the current scope chain.

    Or, define the variable in global field.
    */
    DError* set(K)(in auto ref K key, ref Value value,
                   Property.Attribute attr = Property.Attribute.None)
        if (PropertyKey.IsKey!K)
    {
        return _scopex.set(this, key, value, attr);
    }

    //--------------------------------------------------------------------
    /// Define/Assign a variable in the current innermost field.
    DError* setThis(K)(in auto ref K key, ref Value value,
                       Property.Attribute attr)
        if (PropertyKey.IsKey!K)
    {
        return _scopex.setThis(this, key, value, attr);
    }

    //--------------------------------------------------------------------
    /// Get the current innermost field that compose a function.
    @property @safe @nogc pure nothrow
    inout(Dobject) variable() inout
    {
        return _scopex.variable;
    }

    //--------------------------------------------------------------------
    /// Get the object who calls the current function.
    @property @safe @nogc pure nothrow
    inout(Dfunction) caller() inout
    {
        return _scopex.caller;
    }

    //--------------------------------------------------------------------
    ///
    @property @safe @nogc pure nothrow
    inout(Dobject) callerothis() inout
    {
        return _scopex.callerothis;
    }

    //--------------------------------------------------------------------
    /** Get the stack of searching fields.

    scopex[0] is the outermost searching field (== global).
    scopex[$-1] is the innermost searching field.
    */
    @property @safe @nogc pure nothrow
    inout(Dobject)[] scopes() inout
    {
        return _scopex.stack;
    }

    //--------------------------------------------------------------------
    ///
    @safe @nogc pure nothrow
    inout(Dobject) getNonFakeObject() inout
    {
        return _scopex.getNonFakeObject;
    }

    //--------------------------------------------------------------------
    /**
    Calling this followed by calling IR.call, provides an ordinary function
    calling.

    A parameter s can be on the stack, not on the heap.
    */
    @safe pure nothrow
    void pushFunctionScope(ref VariableScope s)
    {
        _scopex.pushFunctionScope(s);
    }

    //--------------------------------------------------------------------
    /**
    Calling this followed by calling IR.call, provides the execution that is
    like an 'eval' calling.
    */
    @safe pure nothrow
    void pushEvalScope(ref VariableScope s)
    {
        _scopex.pushEvalScope(s);
    }

    //--------------------------------------------------------------------
    /*
    Following the IR.call, this should be called by the parameter that same with
    the one for the prior pushFunctionScope/pushEvalScope calling.
    */
    @safe pure
    bool popVariableScope(ref VariableScope s)
    {
        return _scopex.popVariableScope(s);
    }

    //--------------------------------------------------------------------
    /// Stack the object composing a scope block.
    @safe pure nothrow
    void pushScope(Dobject obj)
    {
        _scopex.push(obj);
    }

    //--------------------------------------------------------------------
    /** Remove the innermost searching field composing a scope block.
    And returns that object.

    When the innermost field is composing a function or an eval, no object will
    be removed form the stack, and a null will be returned.
    */
    // @safe pure
    Dobject popScope()
    {
        return _scopex.pop;
    }

    //--------------------------------------------------------------------
    /// Add stack tracing information to the DError.
    void addTraceInfoTo(DError* err)
    {
        _scopex.addTraceInfoTo(err);
    }


    //--------------------------------------------------------------------
    ///
    string_t[] searchSimilarWord(string_t name)
    {
        return _scopex.searchSimilarWord(this, name);
    }
    /// ditto
    string_t[] searchSimilarWord(Dobject target, string_t name)
    {
        import std.string : soundexer;
        auto key = name.soundexer;
        return ScopeStack.searchSimilarWord(this, target, key);
    }

private:
    ScopeStack _scopex;     // current scope chain
    bool _interrupt;        // !=0 if cancelled due to interrupt


package debug:

    import dmdscript.program : Program;

    //
    @property @safe @nogc pure nothrow
    Program.DumpMode dumpMode() const
    {
        return _prog !is null ? _prog.dumpMode : Program.DumpMode.None;
    }

    //
    @property @safe @nogc pure nothrow
    void program(Program p)
    {
        _prog = p;
    }

    string dump()
    {
        return _scopex.dump;
    }

private debug:
    Program _prog;
}

//==============================================================================
private:

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

1. _stack represents a variable's searching chain.
2. _scopes.scoperoot indicates the point on _stack,
   and it means that _stack[_scopes[x].scoperoot - 1] is a function's root
   variable searching scope.
*/
//
struct ScopeStack
{
    import std.array : Appender;
    import dmdscript.dobject : Dobject;
    import dmdscript.dfunction : Dfunction;
    import dmdscript.property : Property, PropertyKey;
    import dmdscript.value : Value, DError;
    import dmdscript.primitive : string_t;

    //
    @safe pure nothrow
    this(Dobject global)
    {
        assert (global !is null);

        _global = global;
        _stack.put(global);
        _variable = new VariableScope(global, null, null, global,
                                      GLOBAL_ROOT, GLOBAL_ROOT);
        _scopes.put(_variable);
    }

    //
    @property @safe @nogc pure nothrow
    inout(Dobject) global() inout
    {
        return _global;
    }

    //
    @property @safe @nogc pure nothrow
    inout(Dobject) variable() inout
    {
        return _variable.variable;
    }

    //
    @property @safe @nogc pure nothrow
    inout(Dfunction) caller() inout
    {
        return _variable.caller;
    }

    //
    @property @safe @nogc pure nothrow
    inout(Dobject) callerothis() inout
    {
        return _variable.callerothis;
    }

    //
    @property @safe @nogc pure nothrow
    inout(Dobject)[] stack() inout
    {
        return _stack.data;
    }

    //
    @property @safe @nogc pure nothrow
    bool isVariableRoot() const
    {
        return _stack.data.length <= _variable.scoperoot;
    }

    //--------------------------------------------------------------------
    // Get a Dobject that is not a Catch nor a Finally.
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
    //
    @trusted pure nothrow
    void pushFunctionScope(ref VariableScope s)
    {
        assert (s.variable !is null);
        assert (s.callerothis !is null);

        s.prevlength = _stack.data.length;
        _stack.put(s.variable);
        s.scoperoot = _stack.data.length;

        _scopes.put(&s);
        _variable = &s;

        assert (_variable.scoperoot <= _stack.data.length);
        assert (_variable.prevlength < _stack.data.length);
    }

    //--------------------------------------------------------------------
    //
    @trusted pure nothrow
    void pushEvalScope(ref VariableScope s)
    {
        assert (s.variable is null);
        assert (s.callerothis is null);

        s.prevlength = s.scoperoot = _stack.data.length;
        s.variable = _variable.variable;
        s.callerothis = _variable.callerothis;

        _scopes.put(&s);
        _variable = &s;

        assert (_variable.scoperoot <= _stack.data.length);
        assert (_variable.prevlength <= _stack.data.length);
    }

    //--------------------------------------------------------------------
    //
   @trusted pure
    bool popVariableScope(ref VariableScope s)
    {
        assert (_variable is &s);

        auto sd = _scopes.data;
        if (sd.length <= GLOBAL_ROOT)
            return false;

        assert (GLOBAL_ROOT <= _variable.prevlength);

        _stack.shrinkTo(_variable.prevlength);
        _scopes.shrinkTo(sd.length - 1);
        assert(0 < _scopes.data.length);
        _variable = _scopes.data[$-1];
        return true;
    }

    //--------------------------------------------------------------------
    //
    @safe pure nothrow
    void push(Dobject obj)
    {
        _stack.put(obj);
    }

    //--------------------------------------------------------------------
    //
    @safe pure
    Dobject pop()
    {
        auto sd = _stack.data;
        auto len = sd.length;

        if (len <= _variable.scoperoot)
            return null;

        auto ret = sd[len - 1];
        _stack.shrinkTo(len - 1);

        assert (_variable.scoperoot <= _stack.data.length);
        return ret;
    }

    //--------------------------------------------------------------------
    //
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

    //--------------------------------------------------------------------
    //
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
    //
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

    //--------------------------------------------------------------------
    //
    DError* setThis(K)(ref CallContext cc, in auto ref K key, ref Value value,
                       Property.Attribute attr)
    {
        assert(_variable.variable !is null);
        return _variable.variable.Set(key, value, attr, cc);
    }

    //--------------------------------------------------------------------
    //
    @safe @nogc pure nothrow
    void addTraceInfoTo(DError* err) const
    {
        assert (err !is null);

        foreach_reverse(ref one; _scopes.data)
        {
            if (auto f = one.callerf)
            {
                err.addTrace(f.sourcename,
                             f.name !is null ? f.name.toString : null,
                             f.srctext);
                if (0 < f.sourcename.length)
                    break;
            }
        }
    }

    //--------------------------------------------------------------------
    string_t[] searchSimilarWord(ref CallContext cc, string_t name)
    {
        import std.string : soundexer;
        import std.array : Appender, join;

        Appender!(string_t[][]) result;

        auto key = name.soundexer;
        foreach_reverse (one; _stack.data)
        {
            if (auto r = searchSimilarWord(cc, one, key))
                result.put(r);
        }
        return result.data.join;
    }

    static string_t[] searchSimilarWord(ref CallContext cc, Dobject target,
                                        in ref char[4] key)
    {
        import std.string : soundexer;

        Appender!(string_t[]) result;
        foreach (one; target.OwnPropertyKeys)
        {
            auto name = one.toString(cc);
            if (name.soundexer == key)
                result.put(name);
        }
        if (auto p = target.GetPrototypeOf)
            return result.data ~ searchSimilarWord(cc, p, key);
        else
            return result.data;
    }


    //====================================================================
private:
    enum GLOBAL_ROOT = 1;

    Dobject _global;
    VariableScope* _variable;
    Appender!(Dobject[]) _stack;
    Appender!(VariableScope*[]) _scopes;

    invariant
    {
        import std.conv : to;

        assert (_global !is null);

        assert (_variable !is null, "variable is null");
        assert (GLOBAL_ROOT <= _variable.scoperoot, "_variable.scoperoot is " ~
            _variable.scoperoot.to!string);
        assert (_variable.variable !is null);
        assert (_variable.scoperoot <= _stack.data.length,
                _variable.scoperoot.to!string ~ " < " ~
                _stack.data.length.to!string);
        assert (_variable.prevlength <= _stack.data.length,
            _variable.prevlength.to!string);

        assert (_variable.callerothis !is null);
        assert (_variable.prevlength <= _variable.scoperoot);

        assert (0 < _stack.data.length);
        assert (0 < _scopes.data.length);
    }

    //==========================================================
package debug:

    //
    @safe pure
    string dump() const
    {
        import std.conv : text;
        import std.array : Appender;
        Appender!string buf;

        buf.put(text("{ stack.length = ", _stack.data.length, "\n",
                     "  scopes = "));
        foreach(one; _scopes.data)
            buf.put(text(*one));

        buf.put(text("}"));

        return buf.data;
    }
}
