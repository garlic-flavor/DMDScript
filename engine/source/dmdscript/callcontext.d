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

import dmdscript.primitive : string_t, char_t;
import dmdscript.dobject : Dobject;

//------------------------------------------------------------------------------
///
struct DefinedFunctionScope
{
    import dmdscript.dfunction : Dfunction;
    import dmdscript.functiondefinition : FunctionDefinition;

    Stack _stack;      ///
    alias _stack this; ///

    ///
    @safe pure nothrow
    this(Dobject[] superScopes, Dobject actobj, Dfunction caller,
         FunctionDefinition callerf, Dobject callerothis)
    {
        assert (callerothis !is null);

        _stack = Stack(superScopes, actobj);
        _caller = caller;
        _callerf = callerf;
        _callerothis = callerothis;
    }


    @property @safe @nogc pure nothrow
    {
        ///
        inout(Dfunction) caller() inout
        {
            return _caller;
        }

        ///
        inout(FunctionDefinition) callerf() inout
        {
            return _callerf;
        }

        ///
        inout(Dobject) callerothis() inout
        {
            return _callerothis;
        }
    }

private:
    Dfunction _caller;
    FunctionDefinition _callerf;
    Dobject _callerothis;
}


//------------------------------------------------------------------------------
///
struct CallContext
{
    import std.array : Appender;
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
        _current = new DefinedFunctionScope(null, global, null, null, global);
        _scopex.put(_current);
    }

    //--------------------------------------------------------------------
    /// Get the outermost searching field.
    @property @safe @nogc pure nothrow
    inout(Dobject) global() inout
    {
        return _current.global;
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
        return _current.get(this, key, pthis);
    }

    /// ditto
    Value* get(K)(in auto ref K key)
        if (PropertyKey.IsKey!K)
    {
        return _current.get(this, key);
    }

    //--------------------------------------------------------------------
    /** Assign to a variable in the current scope chain.

    Or, define the variable in global field.
    */
    DError* set(K)(in auto ref K key, ref Value value,
                   Property.Attribute attr = Property.Attribute.None)
        if (PropertyKey.IsKey!K)
    {
        return _current.set(this, key, value, attr);
    }

    //--------------------------------------------------------------------
    /// Define/Assign a variable in the current innermost field.
    DError* setThis(K)(in auto ref K key, ref Value value,
                       Property.Attribute attr)
        if (PropertyKey.IsKey!K)
    {
        return _current.setThis(this, key, value, attr);
    }

    //--------------------------------------------------------------------
    /// Get the current innermost field that compose a function.
    @property @safe @nogc pure nothrow
    inout(Dobject) variable() inout
    {
        return _current.rootScope;
    }

    //--------------------------------------------------------------------
    /// Get the object who calls the current function.
    @property @safe @nogc pure nothrow
    inout(Dfunction) caller() inout
    {
        return _current.caller;
    }

    //--------------------------------------------------------------------
    ///
    @property @safe @nogc pure nothrow
    inout(Dobject) callerothis() inout
    {
        return _current.callerothis;
    }

    //--------------------------------------------------------------------
    /** Get the stack of searching fields.

    scopex[0] is the outermost searching field (== global).
    scopex[$-1] is the innermost searching field.
    */
    @property @safe @nogc pure nothrow
    inout(Dobject)[] scopes() inout
    {
        return _current.stack;
    }

    //--------------------------------------------------------------------
    ///
    @safe @nogc pure nothrow
    inout(Dobject) getNonFakeObject() inout
    {
        return _current.getNonFakeObject;
    }

    //--------------------------------------------------------------------
    /**
    Calling this followed by calling IR.call, provides an ordinary function
    calling.

    A parameter s can be on the stack, not on the heap.
    */
    @trusted pure nothrow
    void push(ref DefinedFunctionScope s)
    {
        _current = &s;
        _scopex.put(_current);
    }

    //--------------------------------------------------------------------
    /*
    Following the IR.call, this should be called by the parameter that same with
    the one for the prior pushFunctionScope/pushEvalScope calling.
    */
    @trusted pure
    bool pop(ref DefinedFunctionScope s)
    {
        if (_current !is &s)
            return false;

        assert (1 < _scopex.data.length);

        _scopex.shrinkTo(_scopex.data.length - 1);
        _current = _scopex.data[$-1];
        return true;
    }

    //--------------------------------------------------------------------
    /// Stack the object composing a scope block.
    @safe pure nothrow
    void push(Dobject obj)
    {
        _current.push(obj);
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
        return _current.pop;
    }

    //--------------------------------------------------------------------
    /// Add stack tracing information to the DError.
    void addTraceInfoTo(DError* err)
    {
        assert (err !is null);

        foreach_reverse(ref one; _scopex.data)
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
    ///
    string_t[] searchSimilarWord(string_t name)
    {
        return _current.searchSimilarWord(this, name);
    }
    /// ditto
    string_t[] searchSimilarWord(Dobject target, string_t name)
    {
        import std.string : soundexer;
        auto key = name.soundexer;
        return .searchSimilarWord(this, target, key);
    }

    //====================================================================
private:
    Appender!(DefinedFunctionScope*[]) _scopex;
    DefinedFunctionScope* _current;      // current scope chain
    bool _interrupt;        // !=0 if cancelled due to interrupt

    invariant
    {
        assert (_current !is null);
        assert (0 < _scopex.data.length);
        assert (_scopex.data[$-1] is _current);
    }

    //====================================================================
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

    //====================================================================
private debug:
    Program _prog;
}

//==============================================================================
private:

//
struct Stack
{
    import std.array : Appender;
    import dmdscript.property : PropertyKey, Property;
    import dmdscript.value : Value, DError;

    //
    @safe pure nothrow
    this(Dobject[] superScopes, Dobject root)
    {
        assert (root !is null);

        _stack.reserve(superScopes.length + 1);
        _stack.put(superScopes);
        _stack.put(root);

        _initialSize = _stack.data.length;
    }

    //
    @property @safe @nogc pure nothrow
    inout(Dobject)[] stack() inout
    {
        return _stack.data;
    }

    //
    @property @safe @nogc pure nothrow
    inout(Dobject) global() inout
    {
        assert (0 < _stack.data.length);
        return _stack.data[0];
    }

    //
    @property @safe @nogc pure nothrow
    inout(Dobject) rootScope() inout
    {
        assert (0 < _initialSize);
        assert (_initialSize <= _stack.data.length);
        return _stack.data[_initialSize - 1];
    }

    //
    @safe @nogc pure nothrow
    inout(Dobject) getNonFakeObject() inout
    {
        auto data = _stack.data;
        for (auto i = data.length; _initialSize <= i; --i)
        {
            auto o = stack[i-1];
            if (o.getTypeof !is null)
                return o;
        }
        assert (0);
    }

    //
    @property @safe @nogc pure nothrow
    bool isRoot() const
    {
        return _stack.data.length <= _initialSize;
    }

    //
    @safe pure nothrow
    void push(Dobject o)
    {
        _stack.put(o);
    }

    //
    @safe pure
    Dobject pop()
    {
        auto data = _stack.data;
        if (data.length <= _initialSize)
            return null;

        auto ret = data[$-1];
        _stack.shrinkTo(data.length - 1);
        return ret;
    }

    //
    Value* get(K)(ref CallContext cc, in auto ref K key, out Dobject pthis)
        if (PropertyKey.IsKey!K)
    {
        Value* v;
        Dobject o;

        static if (is(K : PropertyKey))
            alias k = key;
        else
            auto k = PropertyKey(key);

        auto stack = _stack.data;
        for (size_t d = stack.length; ; --d)
        {
            if (0 < d)
            {
                o = stack[d - 1];
                v = o.Get(k, cc);
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

    //
    Value* get(K)(ref CallContext cc, in auto ref K key)
        if (PropertyKey.IsKey!K)
    {
        static if (is(K : PropertyKey))
            alias k = key;
        else
            auto k = PropertyKey(key);

        auto stack = _stack.data;
        for (size_t d = stack.length; 0 < d; --d)
        {
            if (auto v = stack[d-1].Get(k, cc))
                return v;
        }
        return null;
    }

    //
    DError* set(K)(ref CallContext cc, in auto ref K key, ref Value value,
                   Property.Attribute attr = Property.Attribute.None)
    {
        import dmdscript.property : Property;

        auto stack = _stack.data;
        assert (0 < stack.length);

        static if (is(K : PropertyKey))
            alias k = key;
        else
            auto k = PropertyKey(key);

        for (size_t d = stack.length; ; --d)
        {
            if (0 < d)
            {
                auto o = stack[d - 1];
                if (auto v = o.Get(k, cc))
                {
                    v.checkReference;
                    return o.Set(k, value, attr, cc);
                }
            }
            else
            {
                return stack[0].Set(k, value, attr, cc);
            }
        }
    }

    //
    DError* setThis(K)(ref CallContext cc, in auto ref K key, ref Value value,
                       Property.Attribute attr)
    {
        assert (0 < _initialSize);
        assert (_initialSize <= _stack.data.length);
        return _stack.data[_initialSize - 1].Set(key, value, attr, cc);
    }

    //
    string_t[] searchSimilarWord(ref CallContext cc, string_t name)
    {
        import std.string : soundexer;
        import std.array : join;

        Appender!(string_t[][]) result;

        auto key = name.soundexer;
        foreach_reverse (one; _stack.data)
        {
            if (auto r = .searchSimilarWord(cc, one, key))
                result.put(r);
        }
        return result.data.join;
    }

private:
    immutable size_t _initialSize;
    Appender!(Dobject[]) _stack;
}

//
string_t[] searchSimilarWord(ref CallContext cc, Dobject target,
                             in ref char_t[4] key)
{
    import std.array : Appender;
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
