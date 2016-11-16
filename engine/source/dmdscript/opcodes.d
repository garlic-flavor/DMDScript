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
import dmdscript.protoerror;

debug import std.stdio;

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
        o.Put(s, a, Property.Attribute.None);
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
            o.Put(s, a, Property.Attribute.None);
            break;
        }
        if(d == cc.globalroot)
        {
            o.Put(s, a, Property.Attribute.None);
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
    o.Put(id, a, Property.Attribute.None);
}


/*****************************************
 * Helper function for Values that cannot be converted to Objects.
 */

DError* cannotConvert(Value* b, int linnum)
{
    DError* sta;

    if(b.isUndefinedOrNull())
    {
        sta = CannotConvertToObject4Error(b.getType, linnum);
    }
    else
    {
        sta = CannotConvertToObject2Error(b.getType, b.toString, linnum);
    }
    return sta;
}

// enum size_t INDEX_FACTOR = Value.sizeof;//1;//or Value.sizeof;

struct IR
{
    union
    {
        Instruction opcode;

        IR*         code;
        Value*      value;
        idx_t       index;      // index into local variable table
        size_t      hash;       // cached hash value
        size_t      argc;
        sizediff_t  offset;
        Identifier* id;
        d_boolean   boolean;
        Statement   target;     // used for backpatch fixups
        Dobject     object;
        void*       ptr;
    }

    /****************************
     * This is the main interpreter loop.
     */

    static DError* call(CallContext* cc, Dobject othis,
                        IR* code, Value* ret, Value* locals)
    {
        import std.conv : to;
        import std.stdio : writef;
        import std.string : cmp;

        Value* a;
        Value* b;
        Value* c;
        Value* v;
        DError* sta;
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
        DError* unwindStack(DError* err)
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
                    assert(cc.value.sizeof == DError.sizeof);
                    DError.copy(&cc.value, sta);
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
                        o.Put(ca.name, a, Property.Attribute.DontDelete);
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
                    code += IRTypes[Opcode.Nop].size;
                    break;

                case Opcode.Get:                 // a = b.c
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    o = b.toObject();
                    if(!o)
                    {
                        sta = cannotConvert(b, code.opcode.linnum);
                        goto Lthrow;
                    }
                    c = locals + (code + 3).index;
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
                    code += IRTypes[Opcode.Get].size;
                    break;

                case Opcode.Put:                 // b.c = a
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
                    if(c.vtype == V_NUMBER &&
                       (i32 = cast(d_int32)c.number) == c.number &&
                       i32 >= 0)
                    {
                        //writef("IRput %d\n", i32);
                        if(b.vtype == V_OBJECT)
                            sta = b.object.Put(cast(d_uint32)i32, c, a,
                                               Property.Attribute.None);
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
                    code += IRTypes[Opcode.Put].size;
                    break;

                case Opcode.GetS:                // a = b.s
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    s = (code + 3).id.value.text;
                    o = b.toObject();
                    if(!o)
                    {
                        sta = CannotConvertToObject3Error(
                            b.getType, b.toString, s);
                        goto Lthrow;
                    }
                    v = o.Get(s);
                    if(!v)
                    {
                        //writef("IRgets: %s.%s is undefined\n", b.getType(), d_string_ptr(s));
                        v = &vundefined;
                    }
                    Value.copy(a, v);
                    code += IRTypes[Opcode.GetS].size;
                    goto Lnext;
                case Opcode.CheckRef: // s
                    id = (code+1).id;
                    s = id.value.text;
                    if(!scope_get(scopex, id))
                        throw UndefinedVarError.toThrow(s);
                    code += IRTypes[Opcode.CheckRef].size;
                    break;
                case Opcode.GetScope:            // a = s
                    a = locals + (code + 1).index;
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
                    code += IRTypes[Opcode.GetScope].size;
                    break;

                case Opcode.AddAsS:              // a = (b.c += a)
                    c = locals + (code + 3).index;
                    s = c.toString();
                    goto Laddass;

                case Opcode.AddAsSS:             // a = (b.s += a)
                    s = (code + 3).id.value.text;
                    Laddass:
                    b = locals + (code + 2).index;
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
                    a = locals + (code + 1).index;
                    if(!v)
                    {
                        throw UndefinedVarError.toThrow(s);
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

                    static assert(IRTypes[Opcode.AddAsS].size
                                  == IRTypes[Opcode.AddAsSS].size &&
                                  IRTypes[Opcode.AddAsS].size
                                  == IRTypes[Opcode.AddAsSScope].size);
                    code += IRTypes[Opcode.AddAsSScope].size;
                    break;

                case Opcode.PutS:            // b.s = a
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    o = b.toObject();
                    if(!o)
                    {
                        sta = cannotConvert(b, code.opcode.linnum);
                        goto Lthrow;
                    }
                    sta = o.Put((code + 3).id.value.text, a,
                                Property.Attribute.None);
                    if(sta)
                        goto Lthrow;
                    code += IRTypes[Opcode.PutS].size;
                    goto Lnext;

                case Opcode.PutScope:            // s = a
                    a = locals + (code + 1).index;
                    a.checkReference();
                    PutValue(cc, (code + 2).id, a);
                    code += IRTypes[Opcode.PutScope].size;
                    break;

                case Opcode.PutDefault:              // b = a
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    o = b.toObject();
                    if(!o)
                    {
                        sta = CannotAssignError(a.getType, b.getType);
                        goto Lthrow;
                    }
                    sta = o.PutDefault(a);
                    if(sta)
                        goto Lthrow;
                    code += IRTypes[Opcode.PutDefault].size;
                    break;

                case Opcode.PutThis:             // s = a
                    //a = cc.variable.Put((code + 2).id.value.string, GETa(code), DontDelete);
                    o = scope_tos(scopex);
                    assert(o);
                    if(o.HasProperty((code + 2).id.value.text))
                        sta = o.Put((code+2).id.value.text,
                                    locals + (code + 1).index,
                                    Property.Attribute.DontDelete);
                    else
                        sta = cc.variable.Put((code + 2).id.value.text,
                                              locals + (code + 1).index,
                                              Property.Attribute.DontDelete);
                    if (sta)
                        goto Lthrow;
                    code += IRTypes[Opcode.PutThis].size;
                    break;

                case Opcode.Mov:                 // a = b
                    Value.copy(locals + (code + 1).index, locals + (code + 2).index);
                    code += IRTypes[Opcode.Mov].size;
                    break;

                case Opcode.String:              // a = "string"
                    (locals + (code + 1).index).putVstring(
                        (code + 2).id.value.text);
                    code += IRTypes[Opcode.String].size;
                    break;

                case Opcode.Object:              // a = object
                {
                    FunctionDefinition fd;
                    fd = cast(FunctionDefinition)(code + 2).ptr;
                    Dfunction fobject = new DdeclaredFunction(fd);
                    fobject.scopex = scopex;
                    (locals + (code + 1).index).putVobject(fobject);
                    code += IRTypes[Opcode.Object].size;
                    break;
                }
                case Opcode.This:                // a = this
                    (locals + (code + 1).index).putVobject(othis);
                    //writef("IRthis: %s, othis = %x\n", GETa(code).getType(), othis);
                    code += IRTypes[Opcode.This].size;
                    break;

                case Opcode.Number:              // a = number
                    (locals + (code + 1).index).putVnumber(
                        *cast(d_number*)(code + 2));
                    code += IRTypes[Opcode.Number].size;
                    break;

                case Opcode.Boolean:             // a = boolean
                    (locals + (code + 1).index).putVboolean((code + 2).boolean);
                    code += IRTypes[Opcode.Boolean].size;
                    break;

                case Opcode.Null:                // a = null
                    (locals + (code + 1).index).putVnull();
                    code += IRTypes[Opcode.Null].size;
                    break;

                case Opcode.Undefined:           // a = undefined
                    (locals + (code + 1).index).putVundefined();
                    code += IRTypes[Opcode.Undefined].size;
                    break;

                case Opcode.ThisGet:             // a = othis.ident
                    a = locals + (code + 1).index;
                    v = othis.Get((code + 2).id.value.text);
                    if(!v)
                        v = &vundefined;
                    Value.copy(a, v);
                    code += IRTypes[Opcode.ThisGet].size;
                    break;

                case Opcode.Neg:                 // a = -a
                    a = locals + (code + 1).index;
                    n = a.toNumber();
                    a.putVnumber(-n);
                    code += IRTypes[Opcode.Neg].size;
                    break;

                case Opcode.Pos:                 // a = a
                    a = locals + (code + 1).index;
                    n = a.toNumber();
                    a.putVnumber(n);
                    code += IRTypes[Opcode.Pos].size;
                    break;

                case Opcode.Com:                 // a = ~a
                    a = locals + (code + 1).index;
                    i32 = a.toInt32();
                    a.putVnumber(~i32);
                    code += IRTypes[Opcode.Com].size;
                    break;

                case Opcode.Not:                 // a = !a
                    a = locals + (code + 1).index;
                    a.putVboolean(!a.toBoolean());
                    code += IRTypes[Opcode.Not].size;
                    break;

                case Opcode.Typeof:      // a = typeof a
                    // ECMA 11.4.3 says that if the result of (a)
                    // is a Reference and GetBase(a) is null,
                    // then the result is "undefined". I don't know
                    // what kind of script syntax will generate this.
                    a = locals + (code + 1).index;
                    a.putVstring(a.getTypeof());
                    code += IRTypes[Opcode.Typeof].size;
                    break;

                case Opcode.Instance:        // a = b instanceof c
                {
                    Dobject co;

                    // ECMA v3 11.8.6

                    b = locals + (code + 2).index;
                    o = b.toObject();
                    c = locals + (code + 3).index;
                    if(c.isPrimitive())
                    {
                        sta = RhsMustBeObjectError("instanceof", c.getType);
                        goto Lthrow;
                    }
                    co = c.toObject();
                    a = locals + (code + 1).index;
                    sta = co.HasInstance(a, b);
                    if(sta)
                        goto Lthrow;
                    code += IRTypes[Opcode.Instance].size;
                    break;
                }
                case Opcode.Add:                     // a = b + c
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;

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

                    code += IRTypes[Opcode.Add].size;
                    break;

                case Opcode.Sub:                 // a = b - c
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
                    a.putVnumber(b.toNumber() - c.toNumber());
                    code += 4;
                    break;

                case Opcode.Mul:                 // a = b * c
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
                    a.putVnumber(b.toNumber() * c.toNumber());
                    code += IRTypes[Opcode.Mul].size;
                    break;

                case Opcode.Div:                 // a = b / c
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;

                    //writef("%g / %g = %g\n", b.toNumber() , c.toNumber(), b.toNumber() / c.toNumber());
                    a.putVnumber(b.toNumber() / c.toNumber());
                    code += IRTypes[Opcode.Div].size;
                    break;

                case Opcode.Mod:                 // a = b % c
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
                    a.putVnumber(b.toNumber() % c.toNumber());
                    code += IRTypes[Opcode.Mod].size;
                    break;

                case Opcode.ShL:                 // a = b << c
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
                    i32 = b.toInt32();
                    u32 = c.toUint32() & 0x1F;
                    i32 <<= u32;
                    a.putVnumber(i32);
                    code += IRTypes[Opcode.ShL].size;
                    break;

                case Opcode.ShR:                 // a = b >> c
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
                    i32 = b.toInt32();
                    u32 = c.toUint32() & 0x1F;
                    i32 >>= cast(d_int32)u32;
                    a.putVnumber(i32);
                    code += IRTypes[Opcode.ShR].size;
                    break;

                case Opcode.UShR:                // a = b >>> c
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
                    i32 = b.toUint32();
                    u32 = c.toUint32() & 0x1F;
                    u32 = (cast(d_uint32)i32) >> u32;
                    a.putVnumber(u32);
                    code += IRTypes[Opcode.UShR].size;
                    break;

                case Opcode.And:         // a = b & c
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
                    a.putVnumber(b.toInt32() & c.toInt32());
                    code += IRTypes[Opcode.And].size;
                    break;

                case Opcode.Or:          // a = b | c
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
                    a.putVnumber(b.toInt32() | c.toInt32());
                    code += IRTypes[Opcode.Or].size;
                    break;

                case Opcode.Xor:         // a = b ^ c
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
                    a.putVnumber(b.toInt32() ^ c.toInt32());
                    code += IRTypes[Opcode.Xor].size;
                    break;
                case Opcode.In:          // a = b in c
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
                    s = b.toString();
                    o = c.toObject();
                    if(!o)
                        throw RhsMustBeObjectError.toThrow("in", c.toString);

                    a.putVboolean(o.HasProperty(s));
                    code += IRTypes[Opcode.In].size;
                    break;

                /********************/

                case Opcode.PreInc:     // a = ++b.c
                    c = locals + (code + 3).index;
                    s = c.toString();
                    goto Lpreinc;
                case Opcode.PreIncS:    // a = ++b.s
                    s = (code + 3).id.value.text;
                    Lpreinc:
                    inc = 1;
                    Lpre:
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    v = b.Get(s);
                    if(!v)
                        v = &vundefined;
                    n = v.toNumber();
                    a.putVnumber(n + inc);
                    b.Put(s, a);

                    static assert(IRTypes[Opcode.PreInc].size
                                  == IRTypes[Opcode.PreIncS].size &&
                                  IRTypes[Opcode.PreDec].size
                                  == IRTypes[Opcode.PreIncS].size &&
                                  IRTypes[Opcode.PreDecS].size);
                    code += IRTypes[Opcode.PreIncS].size;
                    break;

                case Opcode.PreIncScope:        // a = ++s
                    inc = 1;
                    Lprescope:
                    a = locals + (code + 1).index;
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
                                sta = UndefinedVarError(s);
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
                        {
                            throw UndefinedVarError.toThrow(s);
                        }
                    }
                    static assert(IRTypes[Opcode.PreIncScope].size
                                  == IRTypes[Opcode.PreDecScope].size);
                    code += IRTypes[Opcode.PreIncScope].size;
                    break;

                case Opcode.PreDec:     // a = --b.c
                    c = locals + (code + 3).index;
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
                    c = locals + (code + 3).index;
                    s = c.toString();
                    goto Lpostinc;
                case Opcode.PostIncS:    // a = b.s++
                    s = (code + 3).id.value.text;
                    Lpostinc:
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    v = b.Get(s);
                    if(!v)
                        v = &vundefined;
                    n = v.toNumber();
                    a.putVnumber(n + 1);
                    b.Put(s, a);
                    a.putVnumber(n);

                    static assert(IRTypes[Opcode.PostInc].size
                                  == IRTypes[Opcode.PostIncS].size);
                    code += IRTypes[Opcode.PostIncS].size;
                    break;

                case Opcode.PostIncScope:        // a = s++
                    id = (code + 2).id;
                    v = scope_get(scopex, id, &o);
                    if(v && v != &vundefined)
                    {
                        a = locals + (code + 1).index;
                        n = v.toNumber();
                        v.putVnumber(n + 1);
                        a.putVnumber(n);
                    }
                    else
                    {
                        //GETa(code).putVundefined();
                        //FIXED: as per ECMA v5 should throw ReferenceError
                        throw ReferenceError.toThrow(id.value.text);
                        //v = signalingUndefined(id.value.string);
                    }
                    code += IRTypes[Opcode.PostIncScope].size;
                    break;

                case Opcode.PostDec:     // a = b.c--
                    c = locals + (code + 3).index;
                    s = c.toString();
                    goto Lpostdec;
                case Opcode.PostDecS:    // a = b.s--
                    s = (code + 3).id.value.text;
                    Lpostdec:
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    v = b.Get(s);
                    if(!v)
                        v = &vundefined;
                    n = v.toNumber();
                    a.putVnumber(n - 1);
                    b.Put(s, a);
                    a.putVnumber(n);

                    static assert(IRTypes[Opcode.PostDecS].size
                                  == IRTypes[Opcode.PostDec].size);
                    code += IRTypes[Opcode.PostDecS].size;
                    break;

                case Opcode.PostDecScope:        // a = s--
                    id = (code + 2).id;
                    v = scope_get(scopex, id, &o);
                    if(v && v != &vundefined)
                    {
                        n = v.toNumber();
                        a = locals + (code + 1).index;
                        v.putVnumber(n - 1);
                        a.putVnumber(n);
                    }
                    else
                    {
                        //GETa(code).putVundefined();
                        //FIXED: as per ECMA v5 should throw ReferenceError
                        throw ReferenceError.toThrow(id.value.text);
                        //v = signalingUndefined(id.value.string);
                    }
                    code += IRTypes[Opcode.PostDecScope].size;
                    break;

                case Opcode.Del:     // a = delete b.c
                case Opcode.DelS:    // a = delete b.s
                    b = locals + (code + 2).index;
                    if(b.isPrimitive())
                        bo = true;
                    else
                    {
                        o = b.toObject();
                        if(!o)
                        {
                            sta = cannotConvert(b, code.opcode.linnum);
                            goto Lthrow;
                        }
                        s = (code.opcode == Opcode.Del)
                            ? (locals + (code + 3).index).toString()
                            : (code + 3).id.value.text;
                        if(o.implementsDelete())
                            bo = o.Delete(s);
                        else
                            bo = !o.HasProperty(s);
                    }
                    (locals + (code + 1).index).putVboolean(bo);

                    static assert (IRTypes[Opcode.Del].size
                                   == IRTypes[Opcode.DelS].size);
                    code += IRTypes[Opcode.DelS].size;
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
                    (locals + (code + 1).index).putVboolean(bo);
                    code += IRTypes[Opcode.DelScope].size;
                    break;

                /* ECMA requires that if one of the numeric operands is NAN,
                 * then the result of the comparison is false. D generates a
                 * correct test for NAN operands.
                 */

                case Opcode.CLT:         // a = (b <   c)
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
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

                            res = cmp(x, y) < 0;
                        }
                        else
                            res = b.toNumber() < c.toNumber();
                    }
                    a.putVboolean(res);
                    code += IRTypes[Opcode.CLT].size;
                    break;

                case Opcode.CLE:         // a = (b <=  c)
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
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

                            res = cmp(x, y) <= 0;
                        }
                        else
                            res = b.toNumber() <= c.toNumber();
                    }
                    a.putVboolean(res);
                    code += IRTypes[Opcode.CLE].size;
                    break;

                case Opcode.CGT:         // a = (b >   c)
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
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

                            res = cmp(x, y) > 0;
                        }
                        else
                            res = b.toNumber() > c.toNumber();
                    }
                    a.putVboolean(res);
                    code += IRTypes[Opcode.CGT].size;
                    break;


                case Opcode.CGE:         // a = (b >=  c)
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
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

                            res = cmp(x, y) >= 0;
                        }
                        else
                            res = b.toNumber() >= c.toNumber();
                    }
                    a.putVboolean(res);
                    code += IRTypes[Opcode.CGE].size;
                    break;

                case Opcode.CEq:         // a = (b ==  c)
                case Opcode.CNE:         // a = (b !=  c)
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
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

                    res ^= (code.opcode == Opcode.CNE);
                    //Lceq:
                    a.putVboolean(res);

                    static assert (IRTypes[Opcode.CEq].size
                                   == IRTypes[Opcode.CNE].size);
                    code += IRTypes[Opcode.CNE].size;
                    break;

                case Opcode.CID:         // a = (b === c)
                case Opcode.CNID:        // a = (b !== c)
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
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
                            if(code.opcode == Opcode.CID)
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

                    res ^= (code.opcode == Opcode.CNID);
                    Lcid:
                    a.putVboolean(res);

                    static assert (IRTypes[Opcode.CID].size
                                   == IRTypes[Opcode.CNID].size);
                    code += IRTypes[Opcode.CID].size;
                    break;

                case Opcode.JT:          // if (b) goto t
                    b = locals + (code + 2).index;
                    if(b.toBoolean())
                        code += (code + 1).offset;
                    else
                        code += IRTypes[Opcode.JT].size;
                    break;

                case Opcode.JF:          // if (!b) goto t
                    b = locals + (code + 2).index;
                    if(!b.toBoolean())
                        code += (code + 1).offset;
                    else
                        code += IRTypes[Opcode.JF].size;
                    break;

                case Opcode.JTB:         // if (b) goto t
                    b = locals + (code + 2).index;
                    if(b.dbool)
                        code += (code + 1).offset;
                    else
                        code += IRTypes[Opcode.JTB].size;
                    break;

                case Opcode.JFB:         // if (!b) goto t
                    b = locals + (code + 2).index;
                    if(!b.dbool)
                        code += (code + 1).offset;
                    else
                        code += IRTypes[Opcode.JFB].size;
                    break;

                case Opcode.Jmp:
                    code += (code + 1).offset;
                    break;

                case Opcode.JLT:         // if (b <   c) goto c
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
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

                            res = cmp(x, y) < 0;
                        }
                        else
                            res = b.toNumber() < c.toNumber();
                    }
                    if(!res)
                        code += (code + 1).offset;
                    else
                        code += IRTypes[Opcode.JLT].size;
                    break;

                case Opcode.JLE:         // if (b <=  c) goto c
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
                    if(b.vtype == V_NUMBER && c.vtype == V_NUMBER)
                    {
                        if(b.number <= c.number)
                            code += IRTypes[Opcode.JLE].size;
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

                            res = cmp(x, y) <= 0;
                        }
                        else
                            res = b.toNumber() <= c.toNumber();
                    }
                    if(!res)
                        code += (code + 1).offset;
                    else
                        code += IRTypes[Opcode.JLE].size;
                    break;

                case Opcode.JLTC:        // if (b < constant) goto c
                    b = locals + (code + 2).index;
                    res = (b.toNumber() < *cast(d_number *)(code + 3));
                    if(!res)
                        code += (code + 1).offset;
                    else
                        code += IRTypes[Opcode.JLTC].size;
                    break;

                case Opcode.JLEC:        // if (b <= constant) goto c
                    b = locals + (code + 2).index;
                    res = (b.toNumber() <= *cast(d_number *)(code + 3));
                    if(!res)
                        code += (code + 1).offset;
                    else
                        code += IRTypes[Opcode.JLEC].size;
                    break;

                case Opcode.Iter:                // a = iter(b)
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    o = b.toObject();
                    if(!o)
                    {
                        sta = cannotConvert(b, code.opcode.linnum);
                        goto Lthrow;
                    }
                    sta = o.putIterator(a);
                    if(sta)
                        goto Lthrow;
                    code += IRTypes[Opcode.Iter].size;
                    break;

                case Opcode.Next:        // a, b.c, iter
                                    // if (!(b.c = iter)) goto a; iter = iter.next
                    s = (locals + (code + 3).index).toString();
                    goto case_next;

                case Opcode.NextS:       // a, b.s, iter
                    s = (code + 3).id.value.text;
                    case_next:
                    iter = (locals + (code + 4).index).iter;
                    v = iter.next();
                    if(!v)
                        code += (code + 1).offset;
                    else
                    {
                        b = locals + (code + 2).index;
                        b.Put(s, v);

                        static assert (IRTypes[Opcode.Next].size
                                       == IRTypes[Opcode.NextS].size);
                        code += IRTypes[Opcode.Next].size;
                    }
                    break;

                case Opcode.NextScope:   // a, s, iter
                    s = (code + 2).id.value.text;
                    iter = (locals + (code + 3).index).iter;
                    v = iter.next();
                    if(!v)
                        code += (code + 1).offset;
                    else
                    {
                        o = scope_tos(scopex);
                        o.Put(s, v, Property.Attribute.None);
                        code += IRTypes[Opcode.NextScope].size;
                    }
                    break;

                case Opcode.Call:        // a = b.c(argc, argv)
                    s = (locals + (code + 3).index).toString();
                    goto case_call;

                case Opcode.CallS:       // a = b.s(argc, argv)
                    s = (code + 3).id.value.text;
                    goto case_call;

                    case_call:
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
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
                        sta = v.Call(cc, o, a, (locals + (code + 5).index)[0 .. (code + 4).index]);
                        //writef("regular call, a = %x\n", a);
                    }
                    debug(VERIFY)
                        assert(checksum == IR.verify(__LINE__, codestart));
                    if(sta)
                        goto Lthrow;

                    static assert (IRTypes[Opcode.Call].size
                                   == IRTypes[Opcode.CallS].size);
                    code += IRTypes[Opcode.CallS].size;
                    goto Lnext;

                    Lcallerror:
                    {
                        //writef("%s %s.%s is undefined and has no Call method\n", b.getType(), b.toString(), s);
                        sta = UndefinedNoCall3Error(b.getType, b.toString, s);
                        goto Lthrow;
                    }

                case Opcode.CallScope:   // a = s(argc, argv)
                    id = (code + 2).id;
                    s = id.value.text;
                    a = locals + (code + 1).index;
                    v = scope_get_lambda(scopex, id, &o);
                    //writefln("v.toString() = '%s'", v.toString());
                    if(!v)
                    {
                        //a = Dobject.RuntimeError(&errinfo, errmsgtbl[ERR_UNDEFINED_NO_CALL2], "property", s);
                        sta = UndefinedVarError(s, code.opcode.linnum);
                        goto Lthrow;
                    }
                    // Should we pass othis or o? I think othis.
                    cc.callerothis = othis;        // pass othis to eval()
                    a.putVundefined();
                    sta = v.Call(cc, o, a, (locals + (code + 4).index)[0 .. (code + 3).index]);
                    //writef("callscope result = %x\n", a);
                    debug(VERIFY)
                        assert(checksum == IR.verify(__LINE__, codestart));
                    if(sta)
                        goto Lthrow;
                    code += IRTypes[Opcode.CallScope].size;
                    goto Lnext;

                case Opcode.CallV:   // v(argc, argv) = a
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    o = b.toObject();
                    if(!o)
                    {
                        //writef("%s %s is undefined and has no Call method\n", b.getType(), b.toString());
                        sta = UndefinedNoCall2Error(b.getType, b.toString);
                        goto Lthrow;
                    }
                    cc.callerothis = othis;        // pass othis to eval()
                    a.putVundefined();
                    sta = o.Call(cc, o, a, (locals + (code + 4).index)[0 .. (code + 3).index]);
                    if(sta)
                        goto Lthrow;
                    code += IRTypes[Opcode.CallV].size;
                    goto Lnext;

                case Opcode.PutCall:        // b.c(argc, argv) = a
                    s = (locals + (code + 3).index).toString();
                    goto case_putcall;

                case Opcode.PutCallS:       //  b.s(argc, argv) = a
                    s = (code + 3).id.value.text;
                    goto case_putcall;

                    case_putcall:
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
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
                        sta = CannotAssignTo2Error(b.getType, s);
                        goto Lthrow;
                    }
                    sta = o.put_Value(a, (locals + (code + 5).index)[0 .. (code + 4).argc]);
                    if(sta)
                        goto Lthrow;

                    static assert (IRTypes[Opcode.PutCall].size
                                   == IRTypes[Opcode.PutCallS].size);
                    code += IRTypes[Opcode.PutCallS].size;
                    goto Lnext;

                case Opcode.PutCallScope:   // a = s(argc, argv)
                    id = (code + 2).id;
                    s = id.value.text;
                    v = scope_get_lambda(scopex, id, &o);
                    if(!v)
                    {
                        sta = UndefinedNoCall2Error("property", s);
                        goto Lthrow;
                    }
                    o = v.toObject();
                    if(!o)
                    {
                        sta = CannotAssignToError(s);
                        goto Lthrow;
                    }
                    sta = o.put_Value(locals + (code + 1).index, (locals + (code + 4).index)[0 .. (code + 3).index]);
                    if(sta)
                        goto Lthrow;
                    code += IRTypes[Opcode.PutCallScope].size;
                    goto Lnext;

                case Opcode.PutCallV:        // v(argc, argv) = a
                    b = locals + (code + 2).index;
                    o = b.toObject();
                    if(!o)
                    {
                        //writef("%s %s is undefined and has no Call method\n", b.getType(), b.toString());
                        sta = UndefinedNoCall2Error(b.getType, b.toString);
                        goto Lthrow;
                    }
                    sta = o.put_Value(locals + (code + 1).index, (locals + (code + 4).index)[0 .. (code + 3).index]);
                    if(sta)
                        goto Lthrow;
                    code += IRTypes[Opcode.PutCallV].size;
                    goto Lnext;

                case Opcode.New: // a = new b(argc, argv)
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    a.putVundefined();
                    sta = b.Construct(cc, a, (locals + (code + 4).index)[0 .. (code + 3).index]);
                    debug(VERIFY)
                        assert(checksum == IR.verify(__LINE__, codestart));
                    if(sta)
                        goto Lthrow;
                    code += IRTypes[Opcode.New].size;
                    goto Lnext;

                case Opcode.Push:
                    SCOPECACHE_CLEAR();
                    a = locals + (code + 1).index;
                    o = a.toObject();
                    if(!o)
                    {
                        sta = cannotConvert(a, code.opcode.linnum);
                        goto Lthrow;
                    }
                    scopex ~= o;                // push entry onto scope chain
                    cc.scopex = scopex;
                    code += IRTypes[Opcode.Push].size;
                    break;

                case Opcode.Pop:
                    SCOPECACHE_CLEAR();
                    o = scopex[$ - 1];
                    scopex = scopex[0 .. $ - 1];        // pop entry off scope chain
                    cc.scopex = scopex;
                    // If it's a Finally, we need to execute
                    // the finally block
                    code += IRTypes[Opcode.Pop].size;

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
                    a = locals + (code + 1).index;
                    a.checkReference();
                    Value.copy(ret, a);
                    //writef("returns: %s\n", ret.toString());
                    return null;

                case Opcode.ImpRet:
                    a = locals + (code + 1).index;
                    a.checkReference();
                    Value.copy(ret, a);
                    //writef("implicit return: %s\n", ret.toString());
                    code += IRTypes[Opcode.ImpRet].size;
                    goto Lnext;

                case Opcode.Throw:
                    a = locals + (code + 1).index;
                    sta = new DError(*a);
                    cc.linnum = code.opcode.linnum;
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
                    code += IRTypes[Opcode.TryCatch].size;
                    break;

                case Opcode.TryFinally:
                    SCOPECACHE_CLEAR();
                    f = new Finally(code + (code + 1).offset);
                    scopex ~= f;
                    cc.scopex = scopex;
                    code += IRTypes[Opcode.TryFinally].size;
                    break;

                case Opcode.Assert:
                {
                    version(all)  // Not supported under some com servers
                    {
                        auto linnum = (code + 1).index;
                        sta = AssertError(linnum, linnum);
                        goto Lthrow;
                    }
                    else
                    {
                        RuntimeErrorx(ERR_ASSERT, (code + 1).index);
                        code += IRTypes[Opcode.Assert].size;
                        break;
                    }
                }
                case Opcode.End:
                    code += IRTypes[Opcode.End].size;
                    goto Linterrupt;
                }
            }
            catch(Throwable t)
            {
                sta = unwindStack(t.toDError!typeerror);
                if (sta)
                    return sta;

            }
            // catch(ErrorValue err)
            // {
            //     sta = unwindStack(&err.value);
            //     if(sta)//sta is exception that was not caught
            //         return sta;
            // }
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
        import std.stdio : writeln;

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
        static size_t sizeOf(T)(){ return T.size; }
        return IRTypeDispatcher!sizeOf(opcode);
    }

    debug static void printfunc(IR* code)
    {
        import std.stdio : writef;

        IR* codestart = code;

        for(;; )
        {
            //writef("%2d(%d):", code - codestart, code.linnum);
            writef("%2d:", code - codestart);
            print(code - codestart, code);
            if(code.opcode == Opcode.End)
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
