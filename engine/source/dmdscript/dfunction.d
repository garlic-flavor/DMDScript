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


module dmdscript.dfunction;

import dmdscript.dobject: Dobject;
import dmdscript.value: Value;
import dmdscript.errmsgs;
import dmdscript.primitive: Key;
import dmdscript.dnative: DnativeFunction, DFD = DnativeFunctionDescriptor;
import dmdscript.callcontext: CallContext;
import dmdscript.derror: Derror;
debug import std.stdio;

//==============================================================================
///
abstract class Dfunction : Dobject
{
    import dmdscript.primitive : Text, Key, PropertyKey;
    import dmdscript.drealm: Drealm;

    @disable
    enum Kind
    {
        normal,
        classConstructor,
        generator,
    }

    @disable
    enum ConstructorKind
    {
        base,
        derived,
    }

    @disable
    Dobject HomeObject;

    override abstract
    Derror Call(CallContext* cc, Dobject othis, out Value ret,
                 Value[] arglist);

    //
    override string getTypeof() const
    {     // ECMA 11.4.3
        return Text._function;
    }

    //
    override string toString()
    {
        import std.string : format;
        // Native overrides of this function replace Identifier with the actual name.
        // Don't need to do parameter list, though.
        immutable(char)[] s;

        s = format("function %s() { [native code] }", name);
        return s;
    }

    //
    override Derror HasInstance(ref Value v, out Value ret, CallContext* cc)
    {
        import std.conv : to;

        // ECMA v3 15.3.5.3
        Dobject V;
        Value* w;
        Dobject o;

        if(v.isPrimitive())
            goto Lfalse;
        if (auto err = v.to(V, cc))
            return err;
        if (auto err = Get(Key.prototype, w, cc))
            return err;
        assert (w !is null);
        if(w.isPrimitive())
        {
            string msg;
            try msg = w.type.to!string;
            catch(Throwable t){}
            return MustBeObjectError(cc, msg);
        }
        if (auto err = w.to(o, cc))
            return err;
        for(;; )
        {
            V = V.GetPrototypeOf;
            if(!V)
                goto Lfalse;
            if(o is V)
                goto Ltrue;
        }

    Ltrue:
        ret.put(true);
        return null;

    Lfalse:
        ret.put(false);
        return null;
    }

    // @disable
    // bool OrdinaryHasInstance(Dobject o, CallContext* cc)
    // {
    //     if (auto btf = cast(BoundFunctionExoticObject)this)
    //     {
    //         return o.InstanceofOperator(this, cc);
    //     }
    //     auto p = Get(Key.prototype, cc);
    //     assert(p && p.object);

    //     debug size_t loopCounter = 0;
    //     for(;;)
    //     {
    //         o = o.GetPrototypeOf;
    //         if (o is null)
    //             return false;
    //         if (p.object is o)
    //             return true;
    //         assert(++loopCounter < 100);
    //     }
    //     assert(0);
    // }


    @property @safe @nogc pure nothrow
    inout(PropertyKey) name() inout
    {
        return _name;
    }

protected:
    PropertyKey _name;

    //
    nothrow
    this(Dobject prototype, PropertyKey name, uint length)
    {
        import dmdscript.property : Property;

        super(prototype, Key.Function);
        _name = name;

        Value val;
        val.put(length);
        DefineOwnProperty(Key.length, val,
                          Property.Attribute.DontDelete |
                          Property.Attribute.DontEnum |
                          Property.Attribute.ReadOnly);
        val.put(name);
        DefineOwnProperty(Key.name, val,
                          Property.Attribute.DontDelete |
                          Property.Attribute.DontEnum |
                          Property.Attribute.ReadOnly);

        // Set(Key.arity, length,
        //     Property.Attribute.DontDelete |
        //     Property.Attribute.DontEnum |
        //     Property.Attribute.ReadOnly, cc);
    }


public static:
    //
    Dfunction isFunction(CallContext* cc, Value* v)
    {
        if (v.isPrimitive)
            return null;
        else
        {
            Dobject o;
            v.to(o, cc);
            return cast(Dfunction)o;
        }
    }
}

//------------------------------------------------------------------------------
abstract class Dconstructor : Dfunction
{
    //
    abstract override
    Derror Construct(CallContext* cc, out Value ret, Value[] arglist);


    //
    override
    Derror Call(CallContext* cc, Dobject, out Value ret, Value[] arglist)
    {
        // ECMA 15.3.1
        return Construct(cc, ret, arglist);
    }

    @property @safe @nogc pure nothrow
    inout(Dobject) classPrototype() inout
    {
        assert (_classPrototype !is null);
        return _classPrototype;
    }

protected:

    //
    nothrow
    this(Dobject classPrototype, Dobject functionPrototype,
         PropertyKey name, uint length)
    {
        import dmdscript.property: Property;

        super(functionPrototype, name, length);
        _classPrototype = classPrototype;

        Value val;
        val.put(this);
        _classPrototype.DefineOwnProperty (Key.constructor, val,
                                           Property.Attribute.DontEnum);
        val.put(_classPrototype);
        DefineOwnProperty (Key.prototype, val,
                           Property.Attribute.DontEnum |
                           Property.Attribute.DontDelete);
    }

    //
    template install()
    {
        void install(string M = __MODULE__)(Dobject functionPrototype)
        {
            import dmdscript.dnative: _i = install;
            assert (proptable !is null);
            assert (_classPrototype !is null);
            mixin("import " ~ M ~ ";");
            _i!(mixin(M))(this, functionPrototype);
            _i!(mixin(M))(_classPrototype, functionPrototype);
        }
    }
private:
    Dobject _classPrototype;
}

//------------------------------------------------------------------------------
class DfunctionConstructor : Dconstructor
{
    this(Dobject, Dobject functionPrototype)
    {
        super(functionPrototype, functionPrototype, Key.Function, 1);

        install(functionPrototype);
    }

    override Derror Construct(CallContext* cc, out Value ret,
                               Value[] arglist)
    {
        import dmdscript.functiondefinition : FunctionDefinition;
        import dmdscript.lexer : Mode;
        import dmdscript.parse : Parser;
        import dmdscript.scopex : Scope;
        import dmdscript.ddeclaredfunction : DdeclaredFunction;
        import dmdscript.protoerror;

        // ECMA 15.3.2.1
        string bdy;
        string P;
        FunctionDefinition fd;

        // Get parameter list (P) and body from arglist[]
        if(arglist.length)
        {
            arglist[arglist.length - 1].to(bdy, cc);
            if(arglist.length >= 2)
            {
                for(uint a = 0; a < arglist.length - 1; a++)
                {
                    if(a)
                        P ~= ',';
                    string s;
                    arglist[a].to(s, cc);
                    P ~= s;
                }
            }
        }

        try
        {
            fd = Parser!(Mode.None).parseFunctionDefinition(
                P, bdy, cc.realm.modulePool, cc.strictMode);

            // if((exception = Parser!(Mode.None).parseFunctionDefinition(
            //         fd, P, bdy)) !is null)
            //     goto Lsyntaxerror;

            if(fd !is null)
            {
                Scope sc;

                sc.ctor(fd);
                fd.semantic(&sc);
                // if (sc.exception !is null)
                //     throw sc.exception;
                fd.toIR(null);
                auto fobj = new DdeclaredFunction(cc.realm, fd, cc.save);
                // fobj.scopex = cc.scopex[0..cc.scoperoot].dup;
                // fobj.scopex = cc.scopes.dup;
                ret.put(fobj);
            }
            else
                ret.putVundefined();

            return null;
        }
        catch (Throwable t)
        {
            ret.putVundefined();
            auto msg = Value(cc.realm.dSyntaxError(t.msg));
            return new Derror(t, msg);
        }
    }
}


//==============================================================================
private:

//------------------------------------------------------------------------------
//
@DFD(0)
Derror toString(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // othis must be a Function
    if (auto f = cast(Dfunction)othis)
    {
        // Generate string that looks like a FunctionDeclaration
        // FunctionDeclaration:
        //	function Identifier (Identifier, ...) Block

        // If anonymous function, the name should be "anonymous"
        // per ECMA 15.3.2.1.19

        auto s = f.toString;
        ret.put(s);
    }
    else
    {
        ret.putVundefined();
        return TsNotTransferrableError(cc);
    }
    return null;
}

//------------------------------------------------------------------------------
//
@DFD(2)
Derror apply(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.3.4.3

    import core.sys.posix.stdlib: alloca;
    import dmdscript.primitive: Key, PropertyKey;
    import dmdscript.darray: Darray;
    import dmdscript.darguments: Darguments;
    import dmdscript.value: vundefined;
    import dmdscript.drealm: undefined;

    Value* thisArg;
    Value* argArray;
    Dobject o;
    Derror v;

    thisArg = &undefined;
    argArray = &undefined;
    switch(arglist.length)
    {
    case 0:
        break;
    default:
        argArray = &arglist[1];
        goto case;
    case 1:
        thisArg = &arglist[0];
        break;
    }

    if(thisArg.isUndefinedOrNull())
        o = cc.global;
    else if (auto err = thisArg.to(o, cc))
        return err;

    if(argArray.isUndefinedOrNull())
    {
        v = othis.Call(cc, o, ret, null);
    }
    else
    {
        if(argArray.isPrimitive())
        {
            Ltypeerror:
            ret.putVundefined();
            return ArrayArgsError(cc);
        }
        Dobject a;

        if (auto err = argArray.to(a, cc))
            return err;

        // Must be array or arguments object
        if(((cast(Darray)a) is null) && ((cast(Darguments)a) is null))
            goto Ltypeerror;

        uint len;
        uint i;
        Value[] alist;
        Value* x;

        if (auto err = a.Get(Key.length, x, cc))
            return err;
        assert (x !is null);
        len = 0;
        if (x !is null)
        {
            if (auto err = x.to(len, cc))
                return err;
        }

        Value[] p1;
        Value* v1;
        if(len < 128)
            v1 = cast(Value*)alloca(len * Value.sizeof);
        if(v1)
            alist = v1[0 .. len];
        else
        {
            p1 = new Value[len];
            alist = p1;
        }

        for(i = 0; i < len; i++)
        {
            if (auto err = a.Get(PropertyKey(i), x, cc))
                return err;
            assert (x !is null);
            alist[i] = *x;
        }

        v = othis.Call(cc, o, ret, alist);

        p1.destroy; p1 = null;
    }
    return v;
}

//------------------------------------------------------------------------------
@DFD(1)
Derror bind(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert(0);
}


//------------------------------------------------------------------------------
//
@DFD(1)
Derror call(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.3.4.4
    Value* thisArg;
    Dobject o;
    Derror v;

    if(arglist.length == 0)
    {
        o = cc.global;
        v = othis.Call(cc, o, ret, arglist);
    }
    else
    {
        thisArg = &arglist[0];
        if(thisArg.isUndefinedOrNull())
            o = cc.global;
        else
        {
            if (auto err = thisArg.to(o, cc))
                return err;
        }
        v = othis.Call(cc, o, ret, arglist[1 .. $]);
    }
    return v;
}


//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// for temp use

//
interface BoundFunctionExoticObject
{
    Dobject BoundTargetFunction();
    Value BoundThis();
    Value[] BoundArguments();
}
