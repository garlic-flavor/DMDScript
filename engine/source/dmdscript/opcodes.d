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


module dmdscript.opcodes;

import core.stdc.string;
import std.string;
import std.conv;
import std.stdio;

import dmdscript.script;
import dmdscript.dobject;
import dmdscript.statement;
import dmdscript.functiondefinition;
import dmdscript.value;
import dmdscript.iterator;
import dmdscript.scopex;
import dmdscript.identifier;
import dmdscript.ir;
import dmdscript.errmsgs;
import dmdscript.property;
import dmdscript.ddeclaredfunction;
import dmdscript.dfunction;

//debug=VERIFY;	// verify integrity of code

version = SCOPECACHING;         // turn scope caching on
//version = SCOPECACHE_LOG;	// log statistics on it

// Catch & Finally are "fake" Dobjects that sit in the scope
// chain to implement our exception handling context.

class Catch : Dobject
{
    // This is so scope_get() will skip over these objects
    override Value* Get(d_string PropertyName) const
    {
        return null;
    }
    override Value* Get(d_string PropertyName, uint hash) const
    {
        return null;
    }

    // This is so we can distinguish between a real Dobject
    // and these fakers
    override d_string getTypeof()
    {
        return null;
    }

    uint offset;        // offset of CatchBlock
    d_string name;      // catch identifier

    this(uint offset, d_string name)
    {
        super(null);
        this.offset = offset;
        this.name = name;
    }

    override int isCatch() const
    {
        return true;
    }
}

class Finally : Dobject
{
    override Value* Get(d_string PropertyName) const
    {
        return null;
    }
    override Value* Get(d_string PropertyName, uint hash) const
    {
        return null;
    }
    override d_string getTypeof()
    {
        return null;
    }

    IR* finallyblock;    // code for FinallyBlock

    this(IR* finallyblock)
    {
        super(null);
        this.finallyblock = finallyblock;
    }

    override int isFinally() const
    {
        return true;
    }
}


/************************
 * Look for identifier in scope.
 */

Value* scope_get(Dobject[] scopex, Identifier* id, Dobject *pthis)
{
    uint d;
    Dobject o;
    Value* v;

    //writef("scope_get: scope = %p, scope.data = %p\n", scopex, scopex.data);
    //writefln("scope_get: scopex = %x, length = %d, id = %s", cast(uint)scopex.ptr, scopex.length, id.toString());
    d = scopex.length;
    for(;; )
    {
        if(!d)
        {
            v = null;
            *pthis = null;
            break;
        }
        d--;
        o = scopex[d];
        //writef("o = %x, hash = x%x, s = '%s'\n", o, hash, s);
        v = o.Get(id);
        if(v)
        {
            *pthis = o;
            break;
        }
    }
    return v;
}

Value* scope_get_lambda(Dobject[] scopex, Identifier* id, Dobject *pthis)
{
    uint d;
    Dobject o;
    Value* v;

    //writefln("scope_get_lambda: scope = %x, length = %d, id = %s", cast(uint)scopex.ptr, scopex.length, id.toString());
    d = scopex.length;
    for(;; )
    {
        if(!d)
        {
            v = null;
            *pthis = null;
            break;
        }
        d--;
        o = scopex[d];
        //printf("o = %p ", o);
        //writefln("o = %s", o);
        //printf("o = %x, hash = x%x, s = '%.*s'\n", o, hash, s);
        //v = o.GetLambda(s, hash);
        v = o.Get(id);
        if(v)
        {
            *pthis = o;
            break;
        }
    }
    //writefln("v = %x", cast(uint)cast(void*)v);
    return v;
}

Value* scope_get(Dobject[] scopex, Identifier* id)
{
    uint d;
    Dobject o;
    Value* v;

    //writefln("scope_get: scopex = %x, length = %d, id = %s", cast(uint)scopex.ptr, scopex.length, id.toString());
    d = scopex.length;
    // 1 is most common case for d
    if(d == 1)
    {
        return scopex[0].Get(id);
    }
    for(;; )
    {
        if(!d)
        {
            v = null;
            break;
        }
        d--;
        o = scopex[d];
        //writefln("\to = %s", o);
        v = o.Get(id);
        if(v)
            break;
        //writefln("\tnot found");
    }
    return v;
}

/************************************
 * Find last object in scopex, null if none.
 */

Dobject scope_tos(Dobject[] scopex)
{
    uint d;
    Dobject o;

    for(d = scopex.length; d; )
    {
        d--;
        o = scopex[d];
        if(o.getTypeof() != null)  // if not a Finally or a Catch
            return o;
    }
    return null;
}

/*****************************************
 */

void PutValue(CallContext* cc, d_string s, Value* a)
{
    // ECMA v3 8.7.2
    // Look for the object o in the scope chain.
    // If we find it, put its value.
    // If we don't find it, put it into the global object

    uint d;
    uint hash;
    Value* v;
    Dobject o;
    //a.checkReference();
    d = cc.scopex.length;
    if(d == cc.globalroot)
    {
        o = scope_tos(cc.scopex);
        o.Put(s, a, 0);
        return;
    }

    hash = Value.calcHash(s);

    for(;; d--)
    {
        assert(d > 0);
        o = cc.scopex[d - 1];

        v = o.Get(s, hash);
        if(v)
        {
            // Overwrite existing property with new one
            v.checkReference();
            o.Put(s, a, 0);
            break;
        }
        if(d == cc.globalroot)
        {
            o.Put(s, a, 0);
            return;
        }
    }
}


void PutValue(CallContext* cc, Identifier* id, Value* a)
{
    // ECMA v3 8.7.2
    // Look for the object o in the scope chain.
    // If we find it, put its value.
    // If we don't find it, put it into the global object

    uint d;
    Value* v;
    Dobject o;
    //a.checkReference();
    d = cc.scopex.length;
    if(d == cc.globalroot)
    {
        o = scope_tos(cc.scopex);
    }
    else
    {
        for(;; d--)
        {
            assert(d > 0);
            o = cc.scopex[d - 1];
            v = o.Get(id);
            if(v)
            {
                v.checkReference();
                break;// Overwrite existing property with new one
            }
            if(d == cc.globalroot)
                break;
        }
    }
    o.Put(id, a, 0);
}


/*****************************************
 * Helper function for Values that cannot be converted to Objects.
 */

Status* cannotConvert(Value* b, int linnum)
{
    ErrInfo errinfo;
    Status* sta;

    errinfo.linnum = linnum;
    if(b.isUndefinedOrNull())
    {
        sta = Dobject.RuntimeError(&errinfo, errmsgtbl[ERR_CANNOT_CONVERT_TO_OBJECT4],
                                 b.getType());
    }
    else
    {
        sta = Dobject.RuntimeError(&errinfo, errmsgtbl[ERR_CANNOT_CONVERT_TO_OBJECT2],
                                 b.getType(), b.toString());
    }
    return sta;
}

enum size_t INDEX_FACTOR = Value.sizeof;  // or 1

struct IR
{
    union
    {
        Instruction opcode;

        IR* code;
        Value*      value;
        uint        index;      // index into local variable table
        uint        hash;       // cached hash value
        int         offset;
        Identifier* id;
        d_boolean   boolean;
        Statement   target;     // used for backpatch fixups
        Dobject     object;
        void*       ptr;
    }

    /****************************
     * This is the main interpreter loop.
     */

    static Status* call(CallContext* cc, Dobject othis,
                        IR* code, Value* ret, Value* locals)
    {
        Value* a;
        Value* b;
        Value* c;
        Value* v;
        Status* sta;
        Iterator* iter;
        Identifier* id;
        d_string s;
        d_string s2;
        d_number n;
        d_boolean bo;
        d_int32 i32;
        d_uint32 u32;
        d_boolean res;
        d_string tx;
        d_string ty;
        Dobject o;
        Dobject[] scopex;
        uint dimsave;
        uint offset;
        Catch ca;
        Finally f;
        IR* codestart = code;
        //Finally blocks are sort of called, sort of jumped to
        //So we are doing "push IP in some stack" + "jump"
        IR*[] finallyStack;      //it's a stack of backreferences for finally
        d_number inc;
        void callFinally(Finally f){
            //cc.scopex = scopex;
            finallyStack ~= code;
            code = f.finallyblock;
        }
        Status* unwindStack(Status* err)
        {
            assert(scopex.length && scopex[0] !is null,"Null in scopex, Line " ~ to!string(code.opcode.linnum));
            sta = err;
            a = &sta.entity;
            //v = scope_get(scopex,Identifier.build("mycars2"));
            //a.getErrInfo(null, GETlinnum(code));

            for(;; )
            {
                if(scopex.length <= dimsave)
                {
                    ret.putVundefined();
                    // 'a' may be pointing into the stack, which means
                    // it gets scrambled on return. Therefore, we copy
                    // its contents into a safe area in CallContext.
                    assert(cc.value.sizeof == Status.sizeof);
                    Status.copy(&cc.value, sta);
                    return &cc.value;
                }
                o = scopex[$ - 1];
                scopex = scopex[0 .. $ - 1];            // pop entry off scope chain

                if(o.isCatch())
                {
                    ca = cast(Catch)o;
                    //writef("catch('%s')\n", ca.name);
                    o = new Dobject(Dobject.getPrototype());
                    version(JSCRIPT_CATCH_BUG)
                    {
                        PutValue(cc, ca.name, a);
                    }
                    else
                    {
                        o.Put(ca.name, a, DontDelete);
                    }
                    scopex ~= o;
                    cc.scopex = scopex;
                    code = codestart + ca.offset;
                    break;
                }
                else
                {
                    if(o.isFinally())
                    {
                        f = cast(Finally)o;
                        callFinally(f);
                        break;
                    }
                }
            }
            return null;
        }
        /***************************************
         * Cache for getscope's
         */
        version(SCOPECACHING)
        {
            struct ScopeCache
            {
                d_string s;
                Value*   v;     // never null, and never from a Dcomobject
            }
            int si;
            ScopeCache zero;
            ScopeCache[16] scopecache;
            version(SCOPECACHE_LOG)
                int scopecache_cnt = 0;

            uint SCOPECACHE_SI(immutable(tchar)* s)
            {
                return (cast(uint)(s)) & 15;
            }
            void SCOPECACHE_CLEAR()
            {
                scopecache[] = zero;
            }
        }
        else
        {
            uint SCOPECACHE_SI(d_string s)
            {
                return 0;
            }
            void SCOPECACHE_CLEAR()
            {
            }
        }

        // Eliminate the scale factor of Value.sizeof by computing it at compile
        // time
        Value* GETa(IR* code)
        {
            return cast(Value*)(cast(void*)locals + (code + 1).index);
        }
        Value* GETb(IR* code)
        {
            return cast(Value*)(cast(void*)locals + (code + 2).index);
        }
        Value* GETc(IR* code)
        {
            return cast(Value*)(cast(void*)locals + (code + 3).index);
        }
        Value* GETd(IR* code)
        {
            return cast(Value*)(cast(void*)locals + (code + 4).index);
        }
        Value* GETe(IR* code)
        {
            return cast(Value*)(cast(void*)locals + (code + 5).index);
        }

        uint GETlinnum(IR* code)
        {
            return code.opcode.linnum;
        }

        debug(VERIFY) uint checksum = IR.verify(__LINE__, code);

        version(none)
        {
            writefln("+printfunc");
            printfunc(code);
            writefln("-printfunc");
        }
        scopex = cc.scopex;
        //printf("call: scope = %p, length = %d\n", scopex.ptr, scopex.length);
        dimsave = scopex.length;
        //if (logflag)
        //    writef("IR.call(othis = %p, code = %p, locals = %p)\n",othis,code,locals);

        //debug
        version(none) //no data field in scop struct
        {
            uint debug_scoperoot = cc.scoperoot;
            uint debug_globalroot = cc.globalroot;
            uint debug_scopedim = scopex.length;
            uint debug_scopeallocdim = scopex.allocdim;
            Dobject debug_global = cc.global;
            Dobject debug_variable = cc.variable;

            void** debug_pscoperootdata = cast(void**)mem.malloc((void*).sizeof * debug_scoperoot);
            void** debug_pglobalrootdata = cast(void**)mem.malloc((void*).sizeof * debug_globalroot);

            memcpy(debug_pscoperootdata, scopex.data, (void*).sizeof * debug_scoperoot);
            memcpy(debug_pglobalrootdata, scopex.data, (void*).sizeof * debug_globalroot);
        }

        assert(code);
        assert(othis);

        for(;; )
        {
            Lnext:
            //writef("cc = %x, interrupt = %d\n", cc, cc.Interrupt);
            if(cc.Interrupt)                    // see if script was interrupted
                goto Linterrupt;
            try{
                version(none)
                {
                    writef("Scopex len: %d ",scopex.length);
                    writef("%2d:", code - codestart);
                    print(code - codestart, code);
                    writeln();
                }

                //debug
                version(none) //no data field in scop struct
                {
                    assert(scopex == cc.scopex);
                    assert(debug_scoperoot == cc.scoperoot);
                    assert(debug_globalroot == cc.globalroot);
                    assert(debug_global == cc.global);
                    assert(debug_variable == cc.variable);
                    assert(scopex.length >= debug_scoperoot);
                    assert(scopex.length >= debug_globalroot);
                    assert(scopex.length >= debug_scopedim);
                    assert(scopex.allocdim >= debug_scopeallocdim);
                    assert(0 == memcmp(debug_pscoperootdata, scopex.data, (void*).sizeof * debug_scoperoot));
                    assert(0 == memcmp(debug_pglobalrootdata, scopex.data, (void*).sizeof * debug_globalroot));
                    assert(scopex);
                }

                //writef("\tIR%d:\n", code.opcode);

                assert(code.opcode < Opcode.max,
                       "Unrecognized IR instruction " ~ code.opcode.to!string);
                final switch(code.opcode)
                {
                case Opcode.Error:
                    assert(0);

                case Opcode.Nop:
                    code++;
                    break;

                case Opcode.Get:                 // a = b.c
                    a = GETa(code);
                    b = GETb(code);
                    o = b.toObject();
                    if(!o)
                    {
                        sta = cannotConvert(b, GETlinnum(code));
                        goto Lthrow;
                    }
                    c = GETc(code);
                    if(c.vtype == V_NUMBER &&
                       (i32 = cast(d_int32)c.number) == c.number &&
                       i32 >= 0)
                    {
                        //writef("IRget %d\n", i32);
                        v = o.Get(cast(d_uint32)i32, c);
                    }
                    else
                    {
                        s = c.toString();
                        v = o.Get(s);
                    }
                    if(!v)
                        v = &vundefined;
                    Value.copy(a, v);
                    code += 4;
                    break;

                case Opcode.Put:                 // b.c = a
                    a = GETa(code);
                    b = GETb(code);
                    c = GETc(code);
                    if(c.vtype == V_NUMBER &&
                       (i32 = cast(d_int32)c.number) == c.number &&
                       i32 >= 0)
                    {
                        //writef("IRput %d\n", i32);
                        if(b.vtype == V_OBJECT)
                            sta = b.object.Put(cast(d_uint32)i32, c, a, 0);
                        else
                            sta = b.Put(cast(d_uint32)i32, c, a);
                    }
                    else
                    {
                        s = c.toString();
                        sta = b.Put(s, a);
                    }
                    if(sta)
                        goto Lthrow;
                    code += 4;
                    break;

                case Opcode.GetS:                // a = b.s
                    a = GETa(code);
                    b = GETb(code);
                    s = (code + 3).id.value.text;
                    o = b.toObject();
                    if(!o)
                    {
                        //writef("%s %s.%s cannot convert to Object", b.getType(), b.toString(), s);
                        ErrInfo errinfo;
                        sta = Dobject.RuntimeError(&errinfo,
                                                   errmsgtbl[ERR_CANNOT_CONVERT_TO_OBJECT3],
                                                   b.getType(), b.toString(),
                                                   s);
                        goto Lthrow;
                    }
                    v = o.Get(s);
                    if(!v)
                    {
                        //writef("IRgets: %s.%s is undefined\n", b.getType(), d_string_ptr(s));
                        v = &vundefined;
                    }
                    Value.copy(a, v);
                    code += 4;
                    goto Lnext;
                case Opcode.CheckRef: // s
                    id = (code+1).id;
                    s = id.value.text;
                    if(!scope_get(scopex, id))
                        throw new ErrorValue(Dobject.ReferenceError(errmsgtbl[ERR_UNDEFINED_VAR],s));
                    code += 2;
                    break;
                case Opcode.GetScope:            // a = s
                    a = GETa(code);
                    id = (code + 2).id;
                    s = id.value.text;
                    version(SCOPECACHING)
                    {
                        si = SCOPECACHE_SI(s.ptr);
                        if(s is scopecache[si].s)
                        {
                            version(SCOPECACHE_LOG)
                                scopecache_cnt++;
                            Value.copy(a, scopecache[si].v);
                            code += 3;
                            break;
                        }
                        //writefln("miss %s, was %s, s.ptr = %x, cache.ptr = %x", s, scopecache[si].s, cast(uint)s.ptr, cast(uint)scopecache[si].s.ptr);
                    }
                    version(all)
                    {
                        v = scope_get(scopex,id);
                        if(!v){
                            v = signalingUndefined(s);
                            PutValue(cc,id,v);
                        }
                        else
                        {
                            version(SCOPECACHING)
                            {
                                if(1) //!o.isDcomobject())
                                {
                                    scopecache[si].s = s;
                                    scopecache[si].v = v;
                                }
                            }
                        }
                    }
                    //writef("v = %p\n", v);
                    //writef("v = %g\n", v.toNumber());
                    //writef("v = %s\n", d_string_ptr(v.toString()));
                    Value.copy(a, v);
                    code += 3;
                    break;

                case Opcode.AddAsS:              // a = (b.c += a)
                    c = GETc(code);
                    s = c.toString();
                    goto Laddass;

                case Opcode.AddAsSS:             // a = (b.s += a)
                    s = (code + 3).id.value.text;
                    Laddass:
                    b = GETb(code);
                    v = b.Get(s);
                    goto Laddass2;

                case Opcode.AddAsSScope:         // a = (s += a)
                    b = null;               // Needed for the b.Put() below to shutup a compiler use-without-init warning
                    id = (code + 2).id;
                    s = id.value.text;
                    version(SCOPECACHING)
                    {
                        si = SCOPECACHE_SI(s.ptr);
                        if(s is scopecache[si].s)
                            v = scopecache[si].v;
                        else
                            v = scope_get(scopex, id);
                    }
                    else
                    {
                        v = scope_get(scopex, id);
                    }
                    Laddass2:
                    a = GETa(code);
                    if(!v)
                    {
                        throw new ErrorValue(Dobject.ReferenceError(errmsgtbl[ERR_UNDEFINED_VAR],s));
                        //a.putVundefined();
                        /+
                                            if (b)
                                            {
                                                a = b.Put(s, v);
                                                //if (a) goto Lthrow;
                                            }
                                            else
                                            {
                                                PutValue(cc, s, v);
                                            }
                         +/
                    }
                    else if(a.vtype == V_NUMBER && v.vtype == V_NUMBER)
                    {
                        a.number += v.number;
                        v.number = a.number;
                    }
                    else
                    {
                        v.toPrimitive(v, null);
                        a.toPrimitive(a, null);
                        if(v.isString())
                        {
                            s2 = v.toString() ~a.toString();
                            a.putVstring(s2);
                            Value.copy(v, a);
                        }
                        else if(a.isString())
                        {
                            s2 = v.toString() ~a.toString();
                            a.putVstring(s2);
                            Value.copy(v, a);
                        }
                        else
                        {
                            a.putVnumber(a.toNumber() + v.toNumber());
                            *v = *a;//full copy
                        }
                    }
                    code += 4;
                    break;

                case Opcode.PutS:            // b.s = a
                    a = GETa(code);
                    b = GETb(code);
                    o = b.toObject();
                    if(!o)
                    {
                        sta = cannotConvert(b, GETlinnum(code));
                        goto Lthrow;
                    }
                    sta = o.Put((code + 3).id.value.text, a, 0);
                    if(sta)
                        goto Lthrow;
                    code += 4;
                    goto Lnext;

                case Opcode.PutScope:            // s = a
                    a = GETa(code);
                    a.checkReference();
                    PutValue(cc, (code + 2).id, a);
                    code += 3;
                    break;

                case Opcode.PutDefault:              // b = a
                    a = GETa(code);
                    b = GETb(code);
                    o = b.toObject();
                    if(!o)
                    {
                        ErrInfo errinfo;
                        sta = Dobject.RuntimeError(&errinfo,
                                                   errmsgtbl[ERR_CANNOT_ASSIGN], a.getType(),
                                                   b.getType());
                        goto Lthrow;
                    }
                    sta = o.PutDefault(a);
                    if(sta)
                        goto Lthrow;
                    code += 3;
                    break;

                case Opcode.PutThis:             // s = a
                    //a = cc.variable.Put((code + 2).id.value.string, GETa(code), DontDelete);
                    o = scope_tos(scopex);
                    assert(o);
                    if(o.HasProperty((code + 2).id.value.text))
                        sta = o.Put((code+2).id.value.text,GETa(code),DontDelete);
                    else
                        sta = cc.variable.Put((code + 2).id.value.text, GETa(code), DontDelete);
                    if (sta)
                        goto Lthrow;
                    code += 3;
                    break;

                case Opcode.Mov:                 // a = b
                    Value.copy(GETa(code), GETb(code));
                    code += 3;
                    break;

                case Opcode.String:              // a = "string"
                    GETa(code).putVstring((code + 2).id.value.text);
                    code += 3;
                    break;

                case Opcode.Object:              // a = object
                { FunctionDefinition fd;
                  fd = cast(FunctionDefinition)(code + 2).ptr;
                  Dfunction fobject = new DdeclaredFunction(fd);
                  fobject.scopex = scopex;
                  GETa(code).putVobject(fobject);
                  code += 3;
                  break; }

                case Opcode.This:                // a = this
                    GETa(code).putVobject(othis);
                    //writef("IRthis: %s, othis = %x\n", GETa(code).getType(), othis);
                    code += 2;
                    break;

                case Opcode.Number:              // a = number
                    GETa(code).putVnumber(*cast(d_number *)(code + 2));
                    code += 4;
                    break;

                case Opcode.Boolean:             // a = boolean
                    GETa(code).putVboolean((code + 2).boolean);
                    code += 3;
                    break;

                case Opcode.Null:                // a = null
                    GETa(code).putVnull();
                    code += 2;
                    break;

                case Opcode.Undefined:           // a = undefined
                    GETa(code).putVundefined();
                    code += 2;
                    break;

                case Opcode.ThisGet:             // a = othis.ident
                    a = GETa(code);
                    v = othis.Get((code + 2).id.value.text);
                    if(!v)
                        v = &vundefined;
                    Value.copy(a, v);
                    code += 3;
                    break;

                case Opcode.Neg:                 // a = -a
                    a = GETa(code);
                    n = a.toNumber();
                    a.putVnumber(-n);
                    code += 2;
                    break;

                case Opcode.Pos:                 // a = a
                    a = GETa(code);
                    n = a.toNumber();
                    a.putVnumber(n);
                    code += 2;
                    break;

                case Opcode.Com:                 // a = ~a
                    a = GETa(code);
                    i32 = a.toInt32();
                    a.putVnumber(~i32);
                    code += 2;
                    break;

                case Opcode.Not:                 // a = !a
                    a = GETa(code);
                    a.putVboolean(!a.toBoolean());
                    code += 2;
                    break;

                case Opcode.Typeof:      // a = typeof a
                    // ECMA 11.4.3 says that if the result of (a)
                    // is a Reference and GetBase(a) is null,
                    // then the result is "undefined". I don't know
                    // what kind of script syntax will generate this.
                    a = GETa(code);
                    a.putVstring(a.getTypeof());
                    code += 2;
                    break;

                case Opcode.Instance:        // a = b instanceof c
                {
                    Dobject co;

                    // ECMA v3 11.8.6

                    b = GETb(code);
                    o = b.toObject();
                    c = GETc(code);
                    if(c.isPrimitive())
                    {
                        ErrInfo errinfo;
                        sta = Dobject.RuntimeError(&errinfo,
                                                   errmsgtbl[ERR_RHS_MUST_BE_OBJECT],
                                                   "instanceof", c.getType());
                        goto Lthrow;
                    }
                    co = c.toObject();
                    a = GETa(code);
                    sta = co.HasInstance(a, b);
                    if(sta)
                        goto Lthrow;
                    code += 4;
                    break;
                }
                case Opcode.Add:                     // a = b + c
                    a = GETa(code);
                    b = GETb(code);
                    c = GETc(code);

                    if(b.vtype == V_NUMBER && c.vtype == V_NUMBER)
                    {
                        a.putVnumber(b.number + c.number);
                    }
                    else
                    {
                        char[Value.sizeof] vtmpb;
                        Value* vb = cast(Value*)vtmpb;
                        char[Value.sizeof] vtmpc;
                        Value* vc = cast(Value*)vtmpc;

                        b.toPrimitive(vb, null);
                        c.toPrimitive(vc, null);

                        if(vb.isString() || vc.isString())
                        {
                            s = vb.toString() ~vc.toString();
                            a.putVstring(s);
                        }
                        else
                        {
                            a.putVnumber(vb.toNumber() + vc.toNumber());
                        }
                    }

                    code += 4;
                    break;

                case Opcode.Sub:                 // a = b - c
                    a = GETa(code);
                    b = GETb(code);
                    c = GETc(code);
                    a.putVnumber(b.toNumber() - c.toNumber());
                    code += 4;
                    break;

                case Opcode.Mul:                 // a = b * c
                    a = GETa(code);
                    b = GETb(code);
                    c = GETc(code);
                    a.putVnumber(b.toNumber() * c.toNumber());
                    code += 4;
                    break;

                case Opcode.Div:                 // a = b / c
                    a = GETa(code);
                    b = GETb(code);
                    c = GETc(code);

                    //writef("%g / %g = %g\n", b.toNumber() , c.toNumber(), b.toNumber() / c.toNumber());
                    a.putVnumber(b.toNumber() / c.toNumber());
                    code += 4;
                    break;

                case Opcode.Mod:                 // a = b % c
                    a = GETa(code);
                    b = GETb(code);
                    c = GETc(code);
                    a.putVnumber(b.toNumber() % c.toNumber());
                    code += 4;
                    break;

                case Opcode.ShL:                 // a = b << c
                    a = GETa(code);
                    b = GETb(code);
                    c = GETc(code);
                    i32 = b.toInt32();
                    u32 = c.toUint32() & 0x1F;
                    i32 <<= u32;
                    a.putVnumber(i32);
                    code += 4;
                    break;

                case Opcode.ShR:                 // a = b >> c
                    a = GETa(code);
                    b = GETb(code);
                    c = GETc(code);
                    i32 = b.toInt32();
                    u32 = c.toUint32() & 0x1F;
                    i32 >>= cast(d_int32)u32;
                    a.putVnumber(i32);
                    code += 4;
                    break;

                case Opcode.UShR:                // a = b >>> c
                    a = GETa(code);
                    b = GETb(code);
                    c = GETc(code);
                    i32 = b.toUint32();
                    u32 = c.toUint32() & 0x1F;
                    u32 = (cast(d_uint32)i32) >> u32;
                    a.putVnumber(u32);
                    code += 4;
                    break;

                case Opcode.And:         // a = b & c
                    a = GETa(code);
                    b = GETb(code);
                    c = GETc(code);
                    a.putVnumber(b.toInt32() & c.toInt32());
                    code += 4;
                    break;

                case Opcode.Or:          // a = b | c
                    a = GETa(code);
                    b = GETb(code);
                    c = GETc(code);
                    a.putVnumber(b.toInt32() | c.toInt32());
                    code += 4;
                    break;

                case Opcode.Xor:         // a = b ^ c
                    a = GETa(code);
                    b = GETb(code);
                    c = GETc(code);
                    a.putVnumber(b.toInt32() ^ c.toInt32());
                    code += 4;
                    break;
                case Opcode.In:          // a = b in c
                    a = GETa(code);
                    b = GETb(code);
                    c = GETc(code);
                    s = b.toString();
                    o = c.toObject();
                    if(!o){
                        ErrInfo errinfo;
                        throw new ErrorValue(Dobject.RuntimeError(&errinfo,errmsgtbl[ERR_RHS_MUST_BE_OBJECT],"in",c.toString()));
                    }
                    a.putVboolean(o.HasProperty(s));
                    code += 4;
                    break;

                /********************/

                case Opcode.PreInc:     // a = ++b.c
                    c = GETc(code);
                    s = c.toString();
                    goto Lpreinc;
                case Opcode.PreIncS:    // a = ++b.s
                    s = (code + 3).id.value.text;
                    Lpreinc:
                    inc = 1;
                    Lpre:
                    a = GETa(code);
                    b = GETb(code);
                    v = b.Get(s);
                    if(!v)
                        v = &vundefined;
                    n = v.toNumber();
                    a.putVnumber(n + inc);
                    b.Put(s, a);
                    code += 4;
                    break;

                case Opcode.PreIncScope:        // a = ++s
                    inc = 1;
                    Lprescope:
                    a = GETa(code);
                    id = (code + 2).id;
                    s = id.value.text;
                    version(SCOPECACHING)
                    {
                        si = SCOPECACHE_SI(s.ptr);
                        if(s is scopecache[si].s)
                        {
                            v = scopecache[si].v;
                            n = v.toNumber() + inc;
                            v.putVnumber(n);
                            a.putVnumber(n);
                        }
                        else
                        {
                            v = scope_get(scopex, id, &o);
                            if(v)
                            {
                                n = v.toNumber() + inc;
                                v.putVnumber(n);
                                a.putVnumber(n);
                            }
                            else
                            {
                                //FIXED: as per ECMA v5 should throw ReferenceError
                                sta = Dobject.ReferenceError(errmsgtbl[ERR_UNDEFINED_VAR], s);
                                //a.putVundefined();
                                goto Lthrow;
                            }
                        }
                    }
                    else
                    {
                        v = scope_get(scopex, id, &o);
                        if(v)
                        {
                            n = v.toNumber();
                            v.putVnumber(n + inc);
                            Value.copy(a, v);
                        }
                        else
                            throw new ErrorValue(Dobject.ReferenceError(errmsgtbl[ERR_UNDEFINED_VAR], s));
                    }
                    code += 4;
                    break;

                case Opcode.PreDec:     // a = --b.c
                    c = GETc(code);
                    s = c.toString();
                    goto Lpredec;
                case Opcode.PreDecS:    // a = --b.s
                    s = (code + 3).id.value.text;
                    Lpredec:
                    inc = -1;
                    goto Lpre;

                case Opcode.PreDecScope:        // a = --s
                    inc = -1;
                    goto Lprescope;

                /********************/

                case Opcode.PostInc:     // a = b.c++
                    c = GETc(code);
                    s = c.toString();
                    goto Lpostinc;
                case Opcode.PostIncS:    // a = b.s++
                    s = (code + 3).id.value.text;
                    Lpostinc:
                    a = GETa(code);
                    b = GETb(code);
                    v = b.Get(s);
                    if(!v)
                        v = &vundefined;
                    n = v.toNumber();
                    a.putVnumber(n + 1);
                    b.Put(s, a);
                    a.putVnumber(n);
                    code += 4;
                    break;

                case Opcode.PostIncScope:        // a = s++
                    id = (code + 2).id;
                    v = scope_get(scopex, id, &o);
                    if(v && v != &vundefined)
                    {
                        a = GETa(code);
                        n = v.toNumber();
                        v.putVnumber(n + 1);
                        a.putVnumber(n);
                    }
                    else
                    {
                        //GETa(code).putVundefined();
                        //FIXED: as per ECMA v5 should throw ReferenceError
                        throw new ErrorValue(Dobject.ReferenceError(id.value.text));
                        //v = signalingUndefined(id.value.string);
                    }
                    code += 3;
                    break;

                case Opcode.PostDec:     // a = b.c--
                    c = GETc(code);
                    s = c.toString();
                    goto Lpostdec;
                case Opcode.PostDecS:    // a = b.s--
                    s = (code + 3).id.value.text;
                    Lpostdec:
                    a = GETa(code);
                    b = GETb(code);
                    v = b.Get(s);
                    if(!v)
                        v = &vundefined;
                    n = v.toNumber();
                    a.putVnumber(n - 1);
                    b.Put(s, a);
                    a.putVnumber(n);
                    code += 4;
                    break;

                case Opcode.PostDecScope:        // a = s--
                    id = (code + 2).id;
                    v = scope_get(scopex, id, &o);
                    if(v && v != &vundefined)
                    {
                        n = v.toNumber();
                        a = GETa(code);
                        v.putVnumber(n - 1);
                        a.putVnumber(n);
                    }
                    else
                    {
                        //GETa(code).putVundefined();
                        //FIXED: as per ECMA v5 should throw ReferenceError
                        throw new ErrorValue(Dobject.ReferenceError(id.value.text));
                        //v = signalingUndefined(id.value.string);
                    }
                    code += 3;
                    break;

                case Opcode.Del:     // a = delete b.c
                case Opcode.DelS:    // a = delete b.s
                    b = GETb(code);
                    if(b.isPrimitive())
                        bo = true;
                    else
                    {
                        o = b.toObject();
                        if(!o)
                        {
                            sta = cannotConvert(b, GETlinnum(code));
                            goto Lthrow;
                        }
                        s = (code.opcode == IRdel)
                            ? GETc(code).toString()
                            : (code + 3).id.value.text;
                        if(o.implementsDelete())
                            bo = o.Delete(s);
                        else
                            bo = !o.HasProperty(s);
                    }
                    GETa(code).putVboolean(bo);
                    code += 4;
                    break;

                case Opcode.DelScope:    // a = delete s
                    id = (code + 2).id;
                    s = id.value.text;
                    //o = scope_tos(scopex);		// broken way
                    if(!scope_get(scopex, id, &o))
                        bo = true;
                    else if(o.implementsDelete())
                        bo = o.Delete(s);
                    else
                        bo = !o.HasProperty(s);
                    GETa(code).putVboolean(bo);
                    code += 3;
                    break;

                /* ECMA requires that if one of the numeric operands is NAN,
                 * then the result of the comparison is false. D generates a
                 * correct test for NAN operands.
                 */

                case Opcode.CLT:         // a = (b <   c)
                    a = GETa(code);
                    b = GETb(code);
                    c = GETc(code);
                    if(b.vtype == V_NUMBER && c.vtype == V_NUMBER)
                        res = (b.number < c.number);
                    else
                    {
                        b.toPrimitive(b, TypeNumber);
                        c.toPrimitive(c, TypeNumber);
                        if(b.isString() && c.isString())
                        {
                            d_string x = b.toString();
                            d_string y = c.toString();

                            res = std.string.cmp(x, y) < 0;
                        }
                        else
                            res = b.toNumber() < c.toNumber();
                    }
                    a.putVboolean(res);
                    code += 4;
                    break;

                case Opcode.CLE:         // a = (b <=  c)
                    a = GETa(code);
                    b = GETb(code);
                    c = GETc(code);
                    if(b.vtype == V_NUMBER && c.vtype == V_NUMBER)
                        res = (b.number <= c.number);
                    else
                    {
                        b.toPrimitive(b, TypeNumber);
                        c.toPrimitive(c, TypeNumber);
                        if(b.isString() && c.isString())
                        {
                            d_string x = b.toString();
                            d_string y = c.toString();

                            res = std.string.cmp(x, y) <= 0;
                        }
                        else
                            res = b.toNumber() <= c.toNumber();
                    }
                    a.putVboolean(res);
                    code += 4;
                    break;

                case Opcode.CGT:         // a = (b >   c)
                    a = GETa(code);
                    b = GETb(code);
                    c = GETc(code);
                    if(b.vtype == V_NUMBER && c.vtype == V_NUMBER)
                        res = (b.number > c.number);
                    else
                    {
                        b.toPrimitive(b, TypeNumber);
                        c.toPrimitive(c, TypeNumber);
                        if(b.isString() && c.isString())
                        {
                            d_string x = b.toString();
                            d_string y = c.toString();

                            res = std.string.cmp(x, y) > 0;
                        }
                        else
                            res = b.toNumber() > c.toNumber();
                    }
                    a.putVboolean(res);
                    code += 4;
                    break;


                case Opcode.CGE:         // a = (b >=  c)
                    a = GETa(code);
                    b = GETb(code);
                    c = GETc(code);
                    if(b.vtype == V_NUMBER && c.vtype == V_NUMBER)
                        res = (b.number >= c.number);
                    else
                    {
                        b.toPrimitive(b, TypeNumber);
                        c.toPrimitive(c, TypeNumber);
                        if(b.isString() && c.isString())
                        {
                            d_string x = b.toString();
                            d_string y = c.toString();

                            res = std.string.cmp(x, y) >= 0;
                        }
                        else
                            res = b.toNumber() >= c.toNumber();
                    }
                    a.putVboolean(res);
                    code += 4;
                    break;

                case Opcode.CEq:         // a = (b ==  c)
                case Opcode.CNE:         // a = (b !=  c)
                    a = GETa(code);
                    b = GETb(code);
                    c = GETc(code);
                    Lagain:
                    tx = b.getType();
                    ty = c.getType();
                    if(logflag)
                        writef("tx('%s', '%s')\n", tx, ty);
                    if(tx == ty)
                    {
                        if(tx == TypeUndefined ||
                           tx == TypeNull)
                            res = true;
                        else if(tx == TypeNumber)
                        {
                            d_number x = b.number;
                            d_number y = c.number;

                            res = (x == y);
                            //writef("x = %g, y = %g, res = %d\n", x, y, res);
                        }
                        else if(tx == TypeString)
                        {
                            if(logflag)
                            {
                                writef("b = %x, c = %x\n", b, c);
                                writef("cmp('%s', '%s')\n", b.text, c.text);
                                writef("cmp(%d, %d)\n", b.text.length, c.text.length);
                            }
                            res = (b.text == c.text);
                        }
                        else if(tx == TypeBoolean)
                            res = (b.dbool == c.dbool);
                        else // TypeObject
                        {
                            res = b.object == c.object;
                        }
                    }
                    else if(tx == TypeNull && ty == TypeUndefined)
                        res = true;
                    else if(tx == TypeUndefined && ty == TypeNull)
                        res = true;
                    else if(tx == TypeNumber && ty == TypeString)
                    {
                        c.putVnumber(c.toNumber());
                        goto Lagain;
                    }
                    else if(tx == TypeString && ty == TypeNumber)
                    {
                        b.putVnumber(b.toNumber());
                        goto Lagain;
                    }
                    else if(tx == TypeBoolean)
                    {
                        b.putVnumber(b.toNumber());
                        goto Lagain;
                    }
                    else if(ty == TypeBoolean)
                    {
                        c.putVnumber(c.toNumber());
                        goto Lagain;
                    }
                    else if(ty == TypeObject)
                    {
                        c.toPrimitive(c, null);
                        // v = cast(Value*)c.toPrimitive(c, null);
                        // if(v)
                        // {
                        //     a = v;
                        //     goto Lthrow;
                        // }
                        goto Lagain;
                    }
                    else if(tx == TypeObject)
                    {
                        b.toPrimitive(b, null);
                        // v = cast(Value*)b.toPrimitive(b, null);
                        // if(v)
                        // {
                        //     a = v;
                        //     goto Lthrow;
                        // }
                        goto Lagain;
                    }
                    else
                    {
                        res = false;
                    }

                    res ^= (code.opcode == IRcne);
                    //Lceq:
                    a.putVboolean(res);
                    code += 4;
                    break;

                case Opcode.CID:         // a = (b === c)
                case Opcode.CNID:        // a = (b !== c)
                    a = GETa(code);
                    b = GETb(code);
                    c = GETc(code);
                    version(none)
                    {
                        writeln("***\n");
                        print(code-codestart,code);
                        writeln();
                    }
                    tx = b.getType();
                    ty = c.getType();
                    if(tx == ty)
                    {
                        if(tx == TypeUndefined ||
                           tx == TypeNull)
                            res = true;
                        else if(tx == TypeNumber)
                        {
                            d_number x = b.number;
                            d_number y = c.number;

                            // Ensure that a NAN operand produces false
                            if(code.opcode == IRcid)
                                res = (x == y);
                            else
                                res = (x != y);
                            goto Lcid;
                        }
                        else if(tx == TypeString)
                            res = (b.text == c.text);
                        else if(tx == TypeBoolean)
                            res = (b.dbool == c.dbool);
                        else // TypeObject
                        {
                            res = b.object == c.object;
                        }
                    }
                    else
                    {
                        res = false;
                    }

                    res ^= (code.opcode == IRcnid);
                    Lcid:
                    a.putVboolean(res);
                    code += 4;
                    break;

                case Opcode.JT:          // if (b) goto t
                    b = GETb(code);
                    if(b.toBoolean())
                        code += (code + 1).offset;
                    else
                        code += 3;
                    break;

                case Opcode.JF:          // if (!b) goto t
                    b = GETb(code);
                    if(!b.toBoolean())
                        code += (code + 1).offset;
                    else
                        code += 3;
                    break;

                case Opcode.JTB:         // if (b) goto t
                    b = GETb(code);
                    if(b.dbool)
                        code += (code + 1).offset;
                    else
                        code += 3;
                    break;

                case Opcode.JFB:         // if (!b) goto t
                    b = GETb(code);
                    if(!b.dbool)
                        code += (code + 1).offset;
                    else
                        code += 3;
                    break;

                case Opcode.Jmp:
                    code += (code + 1).offset;
                    break;

                case Opcode.JLT:         // if (b <   c) goto c
                    b = GETb(code);
                    c = GETc(code);
                    if(b.vtype == V_NUMBER && c.vtype == V_NUMBER)
                    {
                        if(b.number < c.number)
                            code += 4;
                        else
                            code += (code + 1).offset;
                        break;
                    }
                    else
                    {
                        b.toPrimitive(b, TypeNumber);
                        c.toPrimitive(c, TypeNumber);
                        if(b.isString() && c.isString())
                        {
                            d_string x = b.toString();
                            d_string y = c.toString();

                            res = std.string.cmp(x, y) < 0;
                        }
                        else
                            res = b.toNumber() < c.toNumber();
                    }
                    if(!res)
                        code += (code + 1).offset;
                    else
                        code += 4;
                    break;

                case Opcode.JLE:         // if (b <=  c) goto c
                    b = GETb(code);
                    c = GETc(code);
                    if(b.vtype == V_NUMBER && c.vtype == V_NUMBER)
                    {
                        if(b.number <= c.number)
                            code += 4;
                        else
                            code += (code + 1).offset;
                        break;
                    }
                    else
                    {
                        b.toPrimitive(b, TypeNumber);
                        c.toPrimitive(c, TypeNumber);
                        if(b.isString() && c.isString())
                        {
                            d_string x = b.toString();
                            d_string y = c.toString();

                            res = std.string.cmp(x, y) <= 0;
                        }
                        else
                            res = b.toNumber() <= c.toNumber();
                    }
                    if(!res)
                        code += (code + 1).offset;
                    else
                        code += 4;
                    break;

                case Opcode.JLTC:        // if (b < constant) goto c
                    b = GETb(code);
                    res = (b.toNumber() < *cast(d_number *)(code + 3));
                    if(!res)
                        code += (code + 1).offset;
                    else
                        code += 5;
                    break;

                case Opcode.JLEC:        // if (b <= constant) goto c
                    b = GETb(code);
                    res = (b.toNumber() <= *cast(d_number *)(code + 3));
                    if(!res)
                        code += (code + 1).offset;
                    else
                        code += 5;
                    break;

                case Opcode.Iter:                // a = iter(b)
                    a = GETa(code);
                    b = GETb(code);
                    o = b.toObject();
                    if(!o)
                    {
                        sta = cannotConvert(b, GETlinnum(code));
                        goto Lthrow;
                    }
                    sta = o.putIterator(a);
                    if(sta)
                        goto Lthrow;
                    code += 3;
                    break;

                case Opcode.Next:        // a, b.c, iter
                                    // if (!(b.c = iter)) goto a; iter = iter.next
                    s = GETc(code).toString();
                    goto case_next;

                case Opcode.NextS:       // a, b.s, iter
                    s = (code + 3).id.value.text;
                    case_next:
                    iter = GETd(code).iter;
                    v = iter.next();
                    if(!v)
                        code += (code + 1).offset;
                    else
                    {
                        b = GETb(code);
                        b.Put(s, v);
                        code += 5;
                    }
                    break;

                case Opcode.NextScope:   // a, s, iter
                    s = (code + 2).id.value.text;
                    iter = GETc(code).iter;
                    v = iter.next();
                    if(!v)
                        code += (code + 1).offset;
                    else
                    {
                        o = scope_tos(scopex);
                        o.Put(s, v, 0);
                        code += 4;
                    }
                    break;

                case Opcode.Call:        // a = b.c(argc, argv)
                    s = GETc(code).toString();
                    goto case_call;

                case Opcode.CallS:       // a = b.s(argc, argv)
                    s = (code + 3).id.value.text;
                    goto case_call;

                    case_call:
                    a = GETa(code);
                    b = GETb(code);
                    o = b.toObject();
                    if(!o)
                    {
                        goto Lcallerror;
                    }
                    {
                        //writef("v.call\n");
                        v = o.Get(s);
                        if(!v)
                            goto Lcallerror;
                        //writef("calling... '%s'\n", v.toString());
                        cc.callerothis = othis;
                        a.putVundefined();
                        sta = v.Call(cc, o, a, GETe(code)[0 .. (code + 4).index]);
                        //writef("regular call, a = %x\n", a);
                    }
                    debug(VERIFY)
                        assert(checksum == IR.verify(__LINE__, codestart));
                    if(sta)
                        goto Lthrow;
                    code += 6;
                    goto Lnext;

                    Lcallerror:
                    {
                        //writef("%s %s.%s is undefined and has no Call method\n", b.getType(), b.toString(), s);
                        ErrInfo errinfo;
                        sta = Dobject.RuntimeError(&errinfo,
                                                   errmsgtbl[ERR_UNDEFINED_NO_CALL3],
                                                   b.getType(), b.toString(),
                                                   s);
                        goto Lthrow;
                    }

                case Opcode.CallScope:   // a = s(argc, argv)
                    id = (code + 2).id;
                    s = id.value.text;
                    a = GETa(code);
                    v = scope_get_lambda(scopex, id, &o);
                    //writefln("v.toString() = '%s'", v.toString());
                    if(!v)
                    {
                        ErrInfo errinfo;
                        sta = Dobject.ReferenceError(errmsgtbl[ERR_UNDEFINED_VAR],s);
                        //a = Dobject.RuntimeError(&errinfo, errmsgtbl[ERR_UNDEFINED_NO_CALL2], "property", s);
                        goto Lthrow;
                    }
                    // Should we pass othis or o? I think othis.
                    cc.callerothis = othis;        // pass othis to eval()
                    a.putVundefined();
                    sta = v.Call(cc, o, a, GETd(code)[0 .. (code + 3).index]);
                    //writef("callscope result = %x\n", a);
                    debug(VERIFY)
                        assert(checksum == IR.verify(__LINE__, codestart));
                    if(sta)
                        goto Lthrow;
                    code += 5;
                    goto Lnext;

                case Opcode.CallV:   // v(argc, argv) = a
                    a = GETa(code);
                    b = GETb(code);
                    o = b.toObject();
                    if(!o)
                    {
                        //writef("%s %s is undefined and has no Call method\n", b.getType(), b.toString());
                        ErrInfo errinfo;
                        sta = Dobject.RuntimeError(&errinfo,
                                                 errmsgtbl[ERR_UNDEFINED_NO_CALL2],
                                                 b.getType(), b.toString());
                        goto Lthrow;
                    }
                    cc.callerothis = othis;        // pass othis to eval()
                    a.putVundefined();
                    sta = o.Call(cc, o, a, GETd(code)[0 .. (code + 3).index]);
                    if(sta)
                        goto Lthrow;
                    code += 5;
                    goto Lnext;

                case Opcode.PutCall:        // b.c(argc, argv) = a
                    s = GETc(code).toString();
                    goto case_putcall;

                case Opcode.PutCallS:       //  b.s(argc, argv) = a
                    s = (code + 3).id.value.text;
                    goto case_putcall;

                    case_putcall:
                    a = GETa(code);
                    b = GETb(code);
                    o = b.toObject();
                    if(!o)
                        goto Lcallerror;
                    //v = o.GetLambda(s, Value.calcHash(s));
                    v = o.Get(s, Value.calcHash(s));
                    if(!v)
                        goto Lcallerror;
                    //writef("calling... '%s'\n", v.toString());
                    o = v.toObject();
                    if(!o)
                    {
                        ErrInfo errinfo;
                        sta = Dobject.RuntimeError(&errinfo,
                                                 errmsgtbl[ERR_CANNOT_ASSIGN_TO2],
                                                 b.getType(), s);
                        goto Lthrow;
                    }
                    sta = o.put_Value(a, GETe(code)[0 .. (code + 4).index]);
                    if(sta)
                        goto Lthrow;
                    code += 6;
                    goto Lnext;

                case Opcode.PutCallScope:   // a = s(argc, argv)
                    id = (code + 2).id;
                    s = id.value.text;
                    v = scope_get_lambda(scopex, id, &o);
                    if(!v)
                    {
                        ErrInfo errinfo;
                        sta = Dobject.RuntimeError(&errinfo,
                                                   errmsgtbl[ERR_UNDEFINED_NO_CALL2],
                                                   "property", s);
                        goto Lthrow;
                    }
                    o = v.toObject();
                    if(!o)
                    {
                        ErrInfo errinfo;
                        sta = Dobject.RuntimeError(&errinfo,
                                                 errmsgtbl[ERR_CANNOT_ASSIGN_TO],
                                                 s);
                        goto Lthrow;
                    }
                    sta = o.put_Value(GETa(code), GETd(code)[0 .. (code + 3).index]);
                    if(sta)
                        goto Lthrow;
                    code += 5;
                    goto Lnext;

                case Opcode.PutCallV:        // v(argc, argv) = a
                    b = GETb(code);
                    o = b.toObject();
                    if(!o)
                    {
                        //writef("%s %s is undefined and has no Call method\n", b.getType(), b.toString());
                        ErrInfo errinfo;
                        sta = Dobject.RuntimeError(&errinfo,
                                                 errmsgtbl[ERR_UNDEFINED_NO_CALL2],
                                                 b.getType(), b.toString());
                        goto Lthrow;
                    }
                    sta = o.put_Value(GETa(code), GETd(code)[0 .. (code + 3).index]);
                    if(sta)
                        goto Lthrow;
                    code += 5;
                    goto Lnext;

                case Opcode.New: // a = new b(argc, argv)
                    a = GETa(code);
                    b = GETb(code);
                    a.putVundefined();
                    sta = b.Construct(cc, a, GETd(code)[0 .. (code + 3).index]);
                    debug(VERIFY)
                        assert(checksum == IR.verify(__LINE__, codestart));
                    if(sta)
                        goto Lthrow;
                    code += 5;
                    goto Lnext;

                case Opcode.Push:
                    SCOPECACHE_CLEAR();
                    a = GETa(code);
                    o = a.toObject();
                    if(!o)
                    {
                        sta = cannotConvert(a, GETlinnum(code));
                        goto Lthrow;
                    }
                    scopex ~= o;                // push entry onto scope chain
                    cc.scopex = scopex;
                    code += 2;
                    break;

                case Opcode.Pop:
                    SCOPECACHE_CLEAR();
                    o = scopex[$ - 1];
                    scopex = scopex[0 .. $ - 1];        // pop entry off scope chain
                    cc.scopex = scopex;
                    // If it's a Finally, we need to execute
                    // the finally block
                    code += 1;

                    if(o.isFinally())   // test could be eliminated with virtual func
                    {
                        f = cast(Finally)o;
                        callFinally(f);
                        debug(VERIFY)
                            assert(checksum == IR.verify(__LINE__, codestart));
                    }

                    goto Lnext;

                case Opcode.FinallyRet:
                    assert(finallyStack.length);
                    code = finallyStack[$-1];
                    finallyStack = finallyStack[0..$-1];
                    goto Lnext;
                case Opcode.Ret:
                    version(SCOPECACHE_LOG)
                        printf("scopecache_cnt = %d\n", scopecache_cnt);
                    return null;

                case Opcode.RetExp:
                    a = GETa(code);
                    a.checkReference();
                    Value.copy(ret, a);
                    //writef("returns: %s\n", ret.toString());
                    return null;

                case Opcode.ImpRet:
                    a = GETa(code);
                    a.checkReference();
                    Value.copy(ret, a);
                    //writef("implicit return: %s\n", ret.toString());
                    code += 2;
                    goto Lnext;

                case Opcode.Throw:
                    a = GETa(code);
                    sta = new Status(*a);
                    cc.linnum = GETlinnum(code);
                    Lthrow:
                    assert(scopex[0] !is null);
                    sta = unwindStack(sta);
                    if(sta)
                        return sta;
                    break;
                case Opcode.TryCatch:
                    SCOPECACHE_CLEAR();
                    offset = (code - codestart) + (code + 1).offset;
                    s = (code + 2).id.value.text;
                    ca = new Catch(offset, s);
                    scopex ~= ca;
                    cc.scopex = scopex;
                    code += 3;
                    break;

                case Opcode.TryFinally:
                    SCOPECACHE_CLEAR();
                    f = new Finally(code + (code + 1).offset);
                    scopex ~= f;
                    cc.scopex = scopex;
                    code += 2;
                    break;

                case Opcode.Assert:
                {
                    ErrInfo errinfo;
                    errinfo.linnum = (code + 1).index;
                    version(all)  // Not supported under some com servers
                    {
                        sta = Dobject.RuntimeError(&errinfo, errmsgtbl[ERR_ASSERT], (code + 1).index);
                        goto Lthrow;
                    }
                    else
                    {
                        RuntimeErrorx(ERR_ASSERT, (code + 1).index);
                        code += 2;
                        break;
                    }
                }
                case Opcode.End:
                    code += 1;
                    goto Linterrupt;
                }
             }
            catch(ErrorValue err)
            {
                sta = unwindStack(&err.value);
                if(sta)//sta is exception that was not caught
                    return sta;
            }
        }

        Linterrupt:
        ret.putVundefined();
        return null;
    }

    /*******************************************
     * This is a 'disassembler' for our interpreted code.
     * Useful for debugging.
     */

    debug static void print(uint address, IR* code)
    {
        static string proc(T)(size_t address, IR* c)
        {
            import std.traits : Parameters;

            alias Ps = Parameters!(T.toString);
            static if      (0 == Ps.length)
                return (cast(T*)c).toString;
            else static if (1 == Ps.length && is(Ps[0] : size_t))
                return (cast(T*)c).toString(address);
            else static assert(0);
        }
        IRTypeDispatcher!proc(code.opcode, address, code,).writeln;
    }

    /*********************************
     * Give size of opcode.
     */

    static size_t size(Opcode opcode)
    {
        size_t sz = 9999;

        @safe @nogc nothrow static pure size_t sizeOf(T)(){ return T.sizeof; }
        sz = IRTypeDispatcher!sizeOf(opcode) / IR.sizeof;

        assert(sz <= 6);
        return sz;
    }

    debug static void printfunc(IR* code)
    {
        IR* codestart = code;

        for(;; )
        {
            //writef("%2d(%d):", code - codestart, code.linnum);
            writef("%2d:", code - codestart);
            print(code - codestart, code);
            if(code.opcode == IRend)
                return;
            code += size(code.opcode);
        }
    }

    /***************************************
     * Verify that it is a correct sequence of code.
     * Useful for isolating memory corruption bugs.
     */

    static uint verify(uint linnum, IR* codestart)
    {
        debug(VERIFY)
        {
            uint checksum = 0;
            uint sz;
            uint i;
            IR* code;

            // Verify code
            for(code = codestart;; )
            {
                switch(code.opcode)
                {
                case Opcode.End:
                    return checksum;

                case Opcode.Error:
                    writef("verify failure line %u\n", linnum);
                    assert(0);
                    break;

                default:
                    if(code.opcode >= Opcode.max)
                    {
                        writef("undefined opcode %d in code %p\n", code.opcode, codestart);
                        assert(0);
                    }
                    sz = IR.size(code.opcode);
                    for(i = 0; i < sz; i++)
                    {
                        checksum += code.opcode;
                        code++;
                    }
                    break;
                }
            }
        }
        else
            return 0;
    }
}
static assert(IR.sizeof == size_t.sizeof);
