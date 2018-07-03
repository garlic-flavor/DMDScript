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

module dmdscript.derror;

// import dmdscript.primitive: Key;
import dmdscript.dobject: Dobject;
// import dmdscript.dfunction: Dconstructor;
// import dmdscript.dnative: DnativeFunction, DFD = DnativeFunctionDescriptor;
// import dmdscript.drealm: Drealm;
debug import std.stdio;

class Derror
{
    import dmdscript.opcodes: IR;
    import dmdscript.property: SpecialSymbols;
    import dmdscript.value: Value;
    import dmdscript.callcontext: CallContext;

    Value value;

    //--------------------------------------------------------------------
    ///
    @safe pure nothrow
    this(in ref Value v, string f = __FILE__, size_t l = __LINE__)
    {
        value.put(v);
        addTrace(f, l);
    }

    ///
    @safe pure nothrow
    this(Throwable t, in ref Value v, string f = __FILE__, size_t l = __LINE__)
    {
        _throwable = t;
        this(v, f, l);
    }

    ///
    @property @safe @nogc pure nothrow
    ref throwable() inout
    {
        return _throwable;
    }

    ///
    @property @safe @nogc pure nothrow
    auto trace() inout
    {
        return _trace;
    }

    ///
    @property @safe @nogc pure nothrow
    ref message() inout
    {
        return _msg;
    }

    @property @safe @nogc pure nothrow
    auto previous() inout
    {
        return _prev;
    }

    //--------------------------------------------------------------------
    @safe pure nothrow
    void addTrace(string f = __FILE__, size_t l = __LINE__)
    {
        addTrace(new Trace(f, l));
    }

    //--------------------------------------------------------------------
    @safe pure nothrow
    void addTrace(const(IR)* b, const(IR)* c,
                  string f = __FILE__, size_t l = __LINE__)
    {
        addTrace(new Trace(f, l, b, c));
    }

    //--------------------------------------------------------------------
    @safe @nogc pure nothrow
    void addInfo(string id, string fn, bool sm)
    {
        for (auto ite = &_trace; (*ite) !is null; ite = &(*ite).next)
        {
            if (0 == (*ite).bufferId.length)
            {
                (*ite).bufferId = id;
                (*ite).funcname = fn;
                (*ite).strictMode = sm;
            }
        }

        if (_prev !is null)
            _prev.addInfo(id, fn, sm);
    }

    @safe @nogc pure nothrow
    void addSource(string src)
    {
        for (auto ite = &_trace; (*ite) !is null; ite = &(*ite).next)
        {
            if (0 == (*ite).src.length)
                (*ite).src = src;
        }

        if (_prev !is null)
            _prev.addSource(src);
    }

    @safe @nogc pure nothrow
    void addPrev(Derror prev)
    {
        if (_prev !is null)
            _prev.addPrev(prev);
        else
            _prev = prev;
    }

    nothrow
    void updateMessage(CallContext* cc)
    {
        string m;
        value.to(m, cc);
        message = m;
    }


    struct Trace
    {
        string dFile;
        size_t dLine;
        const(IR)* base;
        const(IR)* code;

        string bufferId;
        string funcname;
        bool strictMode;
        string src;

        Trace* next;
    }

private:
    string _msg;
    Throwable _throwable;
    Trace* _trace;
    Derror _prev;

    @safe @nogc pure nothrow
    void addTrace(Trace* t)
    {
        assert (t !is null);
        for (auto ite = &_trace; ; ite = &(*ite).next)
        {
            if      ((*ite) is null)
            {
                (*ite) = t;
                break;
            }
            else if ((*ite).dFile == t.dFile && (*ite).dLine == t.dLine)
                break;
            else if ((*ite).code !is null && (*ite).code is t.code)
                break;
        }
    }
}

//------------------------------------------------------------------------------
// return true on error.
@safe /*pure*/ nothrow
bool onError(Derror err, out Derror sta,
             string f = __FILE__, size_t l = __LINE__)
{
    pragma (inline, true);

    if (err is null)
        return false;
    else
    {
        err.addTrace(f, l);
        sta = err;
        return true;
    }
}

// //==============================================================================
// ///
// class Derror : Dobject
// {
//     import dmdscript.property : Property;

// private:
//     this(Dobject prototype, CallContext* cc, Value* m, Value* v2)
//     {
//         super(prototype, Key.Error);

//         string msg;
//         msg = m.toString(cc);
//         auto val = Value(msg);
//         Set(Key.message, val, Property.Attribute.None, cc);
//         Set(Key.description, val, Property.Attribute.None, cc);
//         if(m.isString())
//         {
//         }
//         else if(m.isNumber)
//         {
//             double n = m.toNumber(cc);
//             n = cast(double)(/*FACILITY |*/ cast(int)n);
//             val.put(n);
//             Set(Key.number, val, Property.Attribute.None, cc);
//         }
//         if(v2.isString)
//         {
//             Set(Key.description, *v2, Property.Attribute.None, cc);
//             Set(Key.message, *v2, Property.Attribute.None, cc);
//         }
//         else if(v2.isNumber)
//         {
//             double n = v2.toNumber(cc);
//             n = cast(double)(/*FACILITY |*/ cast(int)n);
//             val.put(n);
//             Set(Key.number, val, Property.Attribute.None, cc);
//         }
//     }

//     this(Dobject prototype)
//     {
//         super(prototype, Key.Error);
//     }
// }

// // Comes from MAKE_HRESULT(SEVERITY_ERROR, FACILITY_CONTROL, 0)
// const uint FACILITY = 0x800A0000;

// //------------------------------------------------------------------------------
// class DerrorConstructor : Dconstructor
// {
//     this(Dobject superClassPrototype, Dobject functionPrototype)
//     {
//         import dmdscript.primitive: Text;
//         import dmdscript.property: Property;

//         super(new Dobject(superClassPrototype), functionPrototype,
//               Key.Error, 1);

//         install(functionPrototype);

//         auto cp = classPrototype;

//         Value val;
//         val.put(Key.Error);
//         cp.DefineOwnProperty(Key.name, val, Property.Attribute.None);
//         val.put(Text.Empty);
//         cp.DefineOwnProperty(Key.message, val, Property.Attribute.None);
//         cp.DefineOwnProperty(Key.description, val, Property.Attribute.None);
//         // val.put(0);
//         // cp.DefineOwnProperty(Key.number, val, Property.Attribute.None);
//     }

//     Derror opCall(ARGS...)(ARGS args)
//     {
//         return new Derror(classPrototype, args);
//     }

//     override DError Construct(CallContext* cc, out Value ret,
//                                Value[] arglist)
//     {
//         import dmdscript.drealm: undefined;
//         import dmdscript.primitive : Text;

//         // ECMA 15.7.2
//         Dobject o;
//         Value* m;
//         Value* n;
//         Value vemptystring;

//         vemptystring.put(Text.Empty);
//         switch(arglist.length)
//         {
//         case 0:         // ECMA doesn't say what we do if m is undefined
//             m = &vemptystring;
//             n = &undefined;
//             break;
//         case 1:
//             m = &arglist[0];
//             if(m.isNumber())
//             {
//                 n = m;
//                 m = &vemptystring;
//             }
//             else
//                 n = &undefined;
//             break;
//         default:
//             m = &arglist[0];
//             n = &arglist[1];
//             break;
//         }
//         o = opCall(cc, m, n);
//         ret.put(o);
//         return null;
//     }
// }

// //==============================================================================
// private:


// //------------------------------------------------------------------------------
// @DFD(0)
// DError toString(
//     DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
//     Value[] arglist)
// {
//     import dmdscript.drealm: undefined;

//     // ECMA v3 15.11.4.3
//     // Return implementation defined string
//     Value* v, v2;

//     //writef("Error.prototype.toString()\n");
//     if (auto err = othis.Get(Key.message, cc, v))
//         return err;
//     if (v is null)
//         v = &undefined;
//     if (auto err = othis.Get(Key.name, cc, v2))
//         return err;
//     if (v2 is null)
//         v2 = &undefined;

//     ret.put(v2.toString(cc) ~ ": " ~ v.toString(cc));
//     return null;
// }

