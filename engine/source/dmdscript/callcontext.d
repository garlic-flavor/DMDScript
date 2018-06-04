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
struct CallContext
{
    import dmdscript.drealm: Drealm;
    import dmdscript.property: Property;
    import dmdscript.dfunction: Dfunction;
    import dmdscript.value: Value, DError;
    import dmdscript.primitive: PropertyKey;
    import dmdscript.functiondefinition: FunctionDefinition;

    /* Get current realm environment.

       This couldn't be null.
     */
    @property @safe @nogc pure nothrow
    inout(Drealm) realm() inout
    {
        return _realm;
    }

    //--------------------------------------------------------------------
    /** Get the object who calls the current function.

        This could be null.
     */
    @property @safe @nogc pure nothrow
    inout(Dfunction) caller() inout
    {
        return _caller;
    }

    /** Get the function definition that current code is in.

        This could be null, before any function is called.
     */
    @property @safe @nogc pure nothrow
    inout(FunctionDefinition) callerf() inout
    {
        return _callerf;
    }

    /** Get the object that contains the caller function as its member.

        This could be null.
     */
    @property @safe @nogc pure nothrow
    inout(Dobject) callerothis() inout
    {
        return _callerothis;
    }

    /** Get current strict mode.
     */
    @property @safe @nogc pure nothrow
    bool strictMode() const
    {
        return _strictMode;
    }

    /** Get the object that compose global scope.

        This equals to realm.
     */
    @property @safe @nogc pure nothrow
    inout(Dobject) global() inout
    {
        return _realm;
    }

    /** Get scopes chain duplicated.

        This couldn't be null
     */
    @property @safe
    Scope* save()
    {
        Scope* ret, ite;
        ret = newScope(_scope.obj, null);
        ite = ret;
        for (auto s = _scope.next; s !is null; s = s.next)
        {
            ite.next = newScope(s.obj, null);
            ite = ite.next;
        }
        return ret;
    }

    //--------------------------------------------------------------------
    /** Get the current innermost field that compose a function.
     */
    @property @safe @nogc pure nothrow
    inout(Dobject) variable() inout
    {
        assert (_rootScope !is null);
        return _rootScope.obj;
    }

    /** Get the object that isn't Catch nor Try.

        This is called from dmdscript.opcodes.IR.call.
     */
    @safe @nogc pure nothrow
    Dobject getNonFakeObject()
    {
        for (auto s = _scope; s !is null; s = s.next)
        {
            assert (s.obj !is null);
            if (s.obj.getTypeof !is null)
                return s.obj;
        }
        assert (0);
    }

    /** Return true if current scope is the innermost function scope.
     */
    @property @safe @nogc pure nothrow
    bool isRoot() const
    {
        return _scope is _rootScope;
    }

    //--------------------------------------------------------------------
    /** Search a variable in current scope chain.

        Params:
            key   = The name of the variable.
            pthis = The field that contains the searched variable.
    */
    Value* get (in ref PropertyKey key, out Dobject pthis)
    {
        Value* v;
        Dobject o;
        for (auto s = _scope; s !is null; s = s.next)
        {
            o = s.obj;
            assert (o !is null);
            v = o.Get(key, &this);
            if (v !is null)
            {
                pthis = o;
                return v;
            }
        }

        pthis = null;
        return null;
    }
    /// ditto
    Value* get (in ref PropertyKey key)
    {
        Value* v;
        for (auto s = _scope; s !is null; s = s.next)
        {
            assert (s.obj);
            v = s.obj.Get(key, &this);
            if (v !is null)
                return v;
        }
        return null;
    }

    //--------------------------------------------------------------------
    /** Assign to a variable in current scope chain.

        Or, define the variable in the global field.

        Params:
            key   =
            value =
            attr  =
    */
    DError* set (in ref PropertyKey key, ref Value value,
                 Property.Attribute attr = Property.Attribute.None)
    {
        import dmdscript.errmsgs: CannotAssignToBeforeDeclarationError;

        Value* v;
        Dobject o;
        assert (_scope !is null);
        for (auto s = _scope; ; s = s.next)
        {
            o = s.obj;
            assert (o !is null);
            v = o.Get(key, &this);
            if (v !is null)
            {
                if (auto err = v.checkReference(_realm))
                    return err;
                else
                    return o.Set (key, value, attr, &this);
            }

            if      (s.next !is null){}
            else if (_strictMode)
            {
                return CannotAssignToBeforeDeclarationError(
                    _realm, key.toString);
            }
            else
                return o.Set(key, value, attr, &this);
        }

        assert (0);
    }

    //--------------------------------------------------------------------
    /** Define/Assign a variable in current innermost field.

        Params:
            key   =
            value =
            attr  =
     */
    DError* setThis(in ref PropertyKey key, ref Value value,
                    Property.Attribute attr)
    {
        assert (_rootScope !is null);
        assert (_rootScope.obj !is null);
        return _rootScope.obj.Set(key, value, attr, &this);
    }

    /** Remove the innermost searching field composing a scope block.
    And returns that object.

    When the innermost field is composing a function or an eval, no object will
    be removed form the stack, and a null will be returned.
    */
    @safe
    Dobject pop()
    {
        auto s = _scope;
        assert (s !is null);
        if (s is _rootScope)
            return null;

        auto obj = s.obj;
        assert (obj !is null);

        _scope = _scope.next;
        dtor (s);
        return obj;
    }

    /** Push new block scope.

        Params:
            o = the object that composes a scope.
     */
    @safe
    void push (Dobject o)
    {
        assert (o !is null);
        _scope = newScope(o, _scope);
    }

    /** Get words that similar with name, for debugging purpose.

        Params:
            name =
     */
    string[] searchSimilarWord (string name)
    {
        import std.string: soundexer;
        import std.array: join, Appender;

        Appender!(string[][]) result;

        auto key = name.soundexer;
        for (auto s = _scope; s !is null; s = s.next)
        {
            if (auto r = .searchSimilarWord(s.obj, key))
                result.put(r);
        }
        return result.data.join;
    }

    /** Get words that similar with name being in inside of target's prototype
        chain.

        Params:
            target =
            name   =
     */
    string[] searchSimilarWord (Dobject target, string name)
    {
        import std.string: soundexer;
        auto key = name.soundexer;
        return .searchSimilarWord(target, key);
    }

package:
    /* This is called from dmdscript.opcodes.IR.call.
     */
    void addTraceInfoTo(DError* err)
    {
        assert (err !is null);
        assert (_callerf !is null);

        string name = "";
        if (_callerf !is null && _callerf.name !is null)
            name = _callerf.name.toString;


        err.addInfo (_realm.id, name, _callerf.strictMode);
    }

private:
    Drealm _realm;
    Dfunction _caller;
    FunctionDefinition _callerf;
    Dobject _callerothis;
    bool _strictMode;

    CallContext* _next;
    Scope* _scope;
    Scope* _rootScope;

    @safe @nogc nothrow
    void zero()
    {
        _realm = null;
        _caller = null;
        _callerf = null;
        _callerothis = null;
        _strictMode = false;

        _next = null;
        _scope = null;
        if (_rootScope !is null)
            dtor (_rootScope);
    }

    @safe @nogc pure nothrow
    void initialize (Drealm realm, CallContext* outerCC, Dfunction caller,
                     FunctionDefinition callerf, Dobject callerothis, Scope* s,
                     bool strictMode)
    {
        assert (realm !is null);
        assert (s !is null);

        _realm = realm;
        _caller = caller;
        _callerf = callerf;
        _strictMode = strictMode;
        _callerothis = callerothis;

        _next = outerCC;
        _scope = s;
        _rootScope = s;
    }

public static:

    /** This struct contains the object composing a block scope.
     */
    struct Scope
    {
        Dobject obj;
        Scope* next;
    }

    /** This allocates Scope struct, for speedup.
     */
    @safe
    void reserve (size_t num)
    {
        auto ite = _freeScope;
        if      (0 == num)
            return;
        else if (ite is null)
            ite = _freeScope = new Scope;

        for (size_t i = 1; i < num; ++i)
        {
            if (ite.next is null)
                ite.next = new Scope;
            ite = ite.next;
        }
    }

    /** Push a function scope.
     */
    @safe
    CallContext* push (CallContext* outerCC, Dobject actobj, Dfunction caller,
                       FunctionDefinition callerf, Dobject callerothis)
    {
        assert (outerCC !is null);
        assert (callerf !is null);
        return newCC (outerCC.realm, outerCC, caller, callerf, callerothis,
                      newScope(actobj, outerCC._scope), callerf.strictMode);
    }

    /// ditto
    @safe
    CallContext* push (CallContext* outerCC, Scope* s, Dobject actobj,
                       Dfunction caller, FunctionDefinition callerf,
                       Dobject callerothis)
    {
        assert (outerCC !is null);
        assert (callerf !is null);
        return newCC (outerCC.realm, outerCC, caller, callerf, callerothis,
                      newScope(actobj, s), callerf.strictMode);
    }

    /// ditto
    @safe
    CallContext* push (Drealm realm, FunctionDefinition callerf)
    {
        assert (realm !is null);
        assert (callerf !is null);
        return newCC (realm, null, null, callerf, realm, newScope(realm, null),
                      callerf.strictMode);
    }

    /// ditto
    @safe
    CallContext* push (Drealm realm, bool strictMode)
    {
        assert (realm !is null);
        return newCC (realm, null, null, null, null, newScope(realm, null),
                      strictMode);
    }

    /** Remove a function scope indicated by cc.

        This is called only for recycling an instance.
     */
    @safe
    CallContext* pop (ref CallContext* cc)
    {
        assert (cc !is null);
        auto outerCC = cc._next;
        dtor(cc);
        return outerCC;
    }


private static:
    CallContext* _freeCC;
    Scope* _freeScope;

    @safe
    CallContext* newCC(Drealm realm, CallContext* outerCC, Dfunction caller,
                       FunctionDefinition callerf, Dobject callerothis,
                       Scope* s, bool strictMode)
    {
        CallContext* cc;

        if (_freeCC is null)
            cc = new CallContext;
        else
        {
            cc = _freeCC;
            _freeCC = cc._next;
        }
        cc.initialize (realm, outerCC, caller, callerf, callerothis, s,
                       strictMode);
        return cc;
    }

    @safe @nogc nothrow
    void dtor (ref CallContext* cc)
    {
        assert (cc !is null);
        cc.zero;
        cc._next = _freeCC;
        _freeCC = cc;
        cc = null;
    }

    @safe
    Scope* newScope(Dobject actObj, Scope* next)
    {
        assert (actObj !is null);

        if (_freeScope is null)
            return new Scope(actObj, next);

        auto s = _freeScope;
        _freeScope = s.next;

        s.obj = actObj;
        s.next = next;
        return s;
    }

    @safe @nogc nothrow
    void dtor (ref Scope* s)
    {
        assert (s !is null);
        s.obj = null;
        s.next = _freeScope;
        _freeScope = s;
        s = null;
    }
}

//..............................................................................
//
private:
string[] searchSimilarWord(Dobject target, in ref char[4] key)
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
        return result.data ~ searchSimilarWord(p, key);
    else
        return result.data;
}

/+

//..............................................................................
//
struct Stack
{
    import std.array: Appender;
    import dmdscript.primitive: PropertyKey;
    import dmdscript.property: Property;
    import dmdscript.value: Value, DError;

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
    Value* get(Drealm realm, in ref PropertyKey key, out Dobject pthis)
    {
        Value* v;
        Dobject o;

        auto stack = _stack.data;
        for (size_t d = stack.length; ; --d)
        {
            if (0 < d)
            {
                o = stack[d - 1];
                v = o.Get(key, realm);
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
    Value* get(Drealm realm, in ref PropertyKey key)
    {
        auto stack = _stack.data;
        for (size_t d = stack.length; 0 < d; --d)
        {
            if (auto v = stack[d-1].Get(key, realm))
                return v;
        }
        return null;
    }

    //--------------------------------------------------------------------
    //
    DError* set(Drealm realm, in ref PropertyKey key, ref Value value,
                   Property.Attribute attr = Property.Attribute.None)
    {
        import dmdscript.property: Property;
        import dmdscript.errmsgs: CannotAssignToBeforeDeclarationError;

        auto stack = _stack.data;
        assert (0 < stack.length);

        for (size_t d = stack.length; ; --d)
        {
            if (0 < d)
            {
                auto o = stack[d - 1];
                if (auto v = o.Get(key, realm))
                {
                    if (auto err = v.checkReference(realm))
                        return err;
                    else
                        return o.Set(key, value, attr, realm);
                }
            }
            else if (realm.strictMode)
            {
                return CannotAssignToBeforeDeclarationError(
                    realm, key.toString);
            }
            else
            {
                return stack[0].Set(key, value, attr, realm);
            }
        }
    }

    //--------------------------------------------------------------------
    //
    DError* setThis(Drealm realm, in ref PropertyKey key, ref Value value,
                    Property.Attribute attr)
    {
        assert (0 < _initialSize);
        assert (_initialSize <= _stack.data.length);
        return _stack.data[_initialSize - 1].Set(key, value, attr, realm);
    }

    //--------------------------------------------------------------------
    //
    DError* setThisLocal(Drealm realm, in ref PropertyKey key,
                         ref Value value, Property.Attribute attr)
    {
        assert (0 < _stack.data.length);
        return _stack.data[$-1].Set(key, value, attr, realm);
    }

    //--------------------------------------------------------------------
    //
    string[] searchSimilarWord(Drealm realm, string name)
    {
        import std.string : soundexer;
        import std.array : join;

        Appender!(string[][]) result;

        auto key = name.soundexer;
        foreach_reverse (one; _stack.data)
        {
            if (auto r = .searchSimilarWord(realm, one, key))
                result.put(r);
        }
        return result.data.join;
    }

    //::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
private:
    immutable size_t _initialSize;
    Appender!(Dobject[]) _stack;
}
// +/
