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

import dmdscript.dobject : Dobject;

//------------------------------------------------------------------------------
///
class DefinedFunctionScope
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

    //::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
private:
    Dfunction _caller;
    FunctionDefinition _callerf;
    Dobject _callerothis;
}


//------------------------------------------------------------------------------
///
class CallContext
{
    import std.array : Appender;
    import dmdscript.primitive : PropertyKey;
    import dmdscript.property : Property;
    import dmdscript.value : Value, DError;
    import dmdscript.dfunction : Dfunction;
    import dmdscript.dglobal : Dglobal;

    //--------------------------------------------------------------------
    /**
    Params:
        global = The outermost searching field.
     */
    @safe pure nothrow
    this(Dglobal global)
    {
        _dglobal = global;
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

    @property @safe @nogc pure nothrow
    inout(Dglobal) dglobal() inout
    {
        return _dglobal;
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
    Value* get(in ref PropertyKey key, out Dobject pthis)
    {
        return _current.get(this, key, pthis);
    }

    /// ditto
    Value* get(in ref PropertyKey key)
    {
        return _current.get(this, key);
    }

    //--------------------------------------------------------------------
    /** Assign to a variable in the current scope chain.

    Or, define the variable in global field.
    */
    DError* set(in ref PropertyKey key, ref Value value,
                   Property.Attribute attr = Property.Attribute.None)
    {
        return _current.set(this, key, value, attr);
    }

    //--------------------------------------------------------------------
    /// Define/Assign a variable in the current innermost field.
    DError* setThis(in ref PropertyKey key, ref Value value,
                       Property.Attribute attr)
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
    void push(DefinedFunctionScope s)
    {
        _current = s;
        _scopex.put(_current);
    }

    //--------------------------------------------------------------------
    /*
    Following the IR.call, this should be called by the parameter that same with
    the one for the prior pushFunctionScope/pushEvalScope calling.
    */
    @trusted pure
    bool pop(DefinedFunctionScope s)
    {
        if (_current !is s)
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
                if (f.name !is null)
                {
                    err.addTrace(f.name.toString);
                    break;
                }
            }
        }
    }

    //--------------------------------------------------------------------
    ///
    string[] searchSimilarWord(string name)
    {
        return _current.searchSimilarWord(this, name);
    }
    /// ditto
    string[] searchSimilarWord(Dobject target, string name)
    {
        import std.string : soundexer;
        auto key = name.soundexer;
        return .searchSimilarWord(this, target, key);
    }

    //::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
private:
    Dglobal _dglobal;
    Appender!(DefinedFunctionScope[]) _scopex;
    DefinedFunctionScope _current;      // current scope chain
    bool _interrupt;        // !=0 if cancelled due to interrupt

    invariant
    {
        assert (_current !is null);
        assert (0 < _scopex.data.length);
        assert (_scopex.data[$-1] is _current);
    }

    //::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
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

    //::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
private debug:
    Program _prog;
}

//::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
private:

//..............................................................................
//
struct Stack
{
    import std.array : Appender;
    import dmdscript.primitive : PropertyKey;
    import dmdscript.property : Property;
    import dmdscript.value : Value, DError;

    //--------------------------------------------------------------------
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

    //--------------------------------------------------------------------
    //
    @property @safe @nogc pure nothrow
    inout(Dobject)[] stack() inout
    {
        return _stack.data;
    }

    //--------------------------------------------------------------------
    //
    @property @safe @nogc pure nothrow
    inout(Dobject) global() inout
    {
        assert (0 < _stack.data.length);
        return _stack.data[0];
    }

    //--------------------------------------------------------------------
    //
    @property @safe @nogc pure nothrow
    inout(Dobject) rootScope() inout
    {
        assert (0 < _initialSize);
        assert (_initialSize <= _stack.data.length);
        return _stack.data[_initialSize - 1];
    }

    //--------------------------------------------------------------------
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

    //--------------------------------------------------------------------
    //
    @property @safe @nogc pure nothrow
    bool isRoot() const
    {
        return _stack.data.length <= _initialSize;
    }

    //--------------------------------------------------------------------
    //
    @safe pure nothrow
    void push(Dobject o)
    {
        _stack.put(o);
    }

    //--------------------------------------------------------------------
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

    //--------------------------------------------------------------------
    //
    Value* get(CallContext cc, in ref PropertyKey key, out Dobject pthis)
    {
        Value* v;
        Dobject o;

        auto stack = _stack.data;
        for (size_t d = stack.length; ; --d)
        {
            if (0 < d)
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
    Value* get(CallContext cc, in ref PropertyKey key)
    {
        auto stack = _stack.data;
        for (size_t d = stack.length; 0 < d; --d)
        {
            if (auto v = stack[d-1].Get(key, cc))
                return v;
        }
        return null;
    }

    //--------------------------------------------------------------------
    //
    DError* set(CallContext cc, in ref PropertyKey key, ref Value value,
                   Property.Attribute attr = Property.Attribute.None)
    {
        import dmdscript.property : Property;

        auto stack = _stack.data;
        assert (0 < stack.length);

        for (size_t d = stack.length; ; --d)
        {
            if (0 < d)
            {
                auto o = stack[d - 1];
                if (auto v = o.Get(key, cc))
                {
                    if (auto err = v.checkReference(cc))
                        return err;
                    else
                        return o.Set(key, value, attr, cc);
                }
            }
            else
            {
                return stack[0].Set(key, value, attr, cc);
            }
        }
    }

    //--------------------------------------------------------------------
    //
    DError* setThis(CallContext cc, in ref PropertyKey key, ref Value value,
                    Property.Attribute attr)
    {
        assert (0 < _initialSize);
        assert (_initialSize <= _stack.data.length);
        return _stack.data[_initialSize - 1].Set(key, value, attr, cc);
    }

    //--------------------------------------------------------------------
    //
    DError* setThisLocal(CallContext cc, in ref PropertyKey key,
                         ref Value value, Property.Attribute attr)
    {
        assert (0 < _stack.data.length);
        return _stack.data[$-1].Set(key, value, attr, cc);
    }

    //--------------------------------------------------------------------
    //
    string[] searchSimilarWord(CallContext cc, string name)
    {
        import std.string : soundexer;
        import std.array : join;

        Appender!(string[][]) result;

        auto key = name.soundexer;
        foreach_reverse (one; _stack.data)
        {
            if (auto r = .searchSimilarWord(cc, one, key))
                result.put(r);
        }
        return result.data.join;
    }

    //::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
private:
    immutable size_t _initialSize;
    Appender!(Dobject[]) _stack;
}

//..............................................................................
//
string[] searchSimilarWord(CallContext cc, Dobject target,
                             in ref char[4] key)
{
    import std.array : Appender;
    import std.string : soundexer;

    Appender!(string[]) result;
    foreach (one; target.OwnPropertyKeys)
    {
        auto name = one.toString;
        if (name.soundexer == key) result.put(name);
    }
    if (auto p = target.GetPrototypeOf)
        return result.data ~ searchSimilarWord(cc, p, key);
    else
        return result.data;
}
