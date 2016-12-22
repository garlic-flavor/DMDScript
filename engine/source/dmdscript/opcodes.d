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

import dmdscript.primitive;
import dmdscript.callcontext;
import dmdscript.dobject;
import dmdscript.statement;
import dmdscript.functiondefinition;
import dmdscript.value;
import dmdscript.iterator;
import dmdscript.scopex;
import dmdscript.ir;
import dmdscript.errmsgs;
import dmdscript.property;
import dmdscript.ddeclaredfunction;
import dmdscript.dfunction;
import dmdscript.protoerror;
import dmdscript.dglobal : undefined;

debug import std.stdio;

//debug=VERIFY;	// verify integrity of code

version = SCOPECACHING;         // turn scope caching on
//version = SCOPECACHE_LOG;	// log statistics on it

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
        StringKey*  id;
        bool        boolean;
        Statement   target;     // used for backpatch fixups
        Dobject     object;
        void*       ptr;
    }

    /****************************
     * This is the main interpreter loop.
     */
    static DError* call(ref CallContext cc, Dobject othis,
                        IR* code, out Value ret, Value* locals)
    {
        import std.array : join;
        import std.conv : to;
        import std.string : cmp;

        Value* a;
        Value* b;
        Value* c;
        Value* v;
        PropertyKey* ppk;
        DError* sta;
        Iterator* iter;
        StringKey* id;
        string_t s;
        string_t s2;
        double n;
        bool bo;
        int i32;
        uint u32;
        bool res;
        Value.Type tx;
        Value.Type ty;
        Dobject o;
        uint offset;
        const IR* codestart = code;

        //Finally blocks are sort of called, sort of jumped to
        //So we are doing "push IP in some stack" + "jump"
        IR*[] finallyStack;      //it's a stack of backreferences for finally
        double inc;

        @safe pure nothrow
        void callFinally(Finally f)
        {
            //cc.scopex = scopex;
            finallyStack ~= code;
            code = f.finallyblock;
        }

        DError* unwindStack(DError* err)
        {
            // assert(scopex.length && scopex[0] !is null,
            //        "Null in scopex, Line " ~ code.opcode.linnum.to!string);
            assert (err !is null);

            for(auto counter = 0;; ++counter)
            {
                // pop entry off scope chain
                if      ((o = cc.popScope) is null)
                {
                    ret.putVundefined;
                    return err;
                }
                else if (auto ca = cast(Catch)o)
                {
                    o = new Dobject(Dobject.getPrototype);
                    version(JSCRIPT_CATCH_BUG)
                    {
                        PutValue(cc, ca.name, &err.entity);
                    }
                    else
                    {
                        o.Set(ca.name, err.entity,
                              Property.Attribute.DontDelete, cc);
                    }
                    cc.pushScope(o);
                    code = cast(IR*)codestart + ca.offset;
                    break;
                }
                else if (auto fin = cast(Finally)o)
                {
                    callFinally(fin);
                    break;
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
                string_t s;
                Value*   v;     // never null, and never from a Dcomobject
            }
            int si;
            ScopeCache zero;
            ScopeCache[16] scopecache;
            version(SCOPECACHE_LOG)
                int scopecache_cnt = 0;

            uint SCOPECACHE_SI(immutable(char_t)* s)
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
            uint SCOPECACHE_SI(string_t s)
            {
                return 0;
            }
            void SCOPECACHE_CLEAR()
            {
            }
        }

        debug(VERIFY) uint checksum = IR.verify(code);

        // scopex = cc.scopex;

        // dimsave = scopex.length;

        assert(code);
        assert(othis);

        loop: for(;; )
        {
            // Lnext:
            if(cc.isInterrupting) // see if script was interrupted
                break loop;

            try
            {
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
                        sta = cannotConvert(b);
                        goto Lthrow;
                    }
                    c = locals + (code + 3).index;
                    if(c.type == Value.Type.Number &&
                       (i32 = cast(int)c.number) == c.number &&
                       i32 >= 0)
                    {
                        v = o.Get(cast(uint)i32/*, *c*/, cc);
                    }
                    else
                    {
                        v = o.Get(c.toString, cc);
                    }
                    if(!v)
                        v = &undefined;
                    *a = *v;
                    code += IRTypes[Opcode.Get].size;
                    break;

                case Opcode.Put:                 // b.c = a
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
                    if(c.type == Value.Type.Number &&
                       (i32 = cast(int)c.number) == c.number &&
                       i32 >= 0)
                    {
                        if(b.type == Value.Type.Object)
                            sta = b.object.Set(cast(uint)i32/*, *c*/, *a,
                                               Property.Attribute.None, cc);
                        else
                            sta = b.Set(cast(uint)i32/*, *c*/, *a, cc);
                    }
                    else
                    {
                        s = c.toString();
                        sta = b.Set(s, *a, cc);
                    }
                    if(sta)
                        goto Lthrow;
                    code += IRTypes[Opcode.Put].size;
                    break;

                case Opcode.GetS:                // a = b.s
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    s = *(code + 3).id;
                    o = b.toObject();
                    if(!o)
                    {
                        sta = CannotConvertToObject3Error(
                            b.type.to!string_t, b.toString, s);
                        goto Lthrow;
                    }
                    v = o.Get(s, cc);
                    if(!v)
                    {
                        v = &undefined;
                    }
                    *a = *v;
                    code += IRTypes[Opcode.GetS].size;
                    // goto Lnext;
                    break;
                case Opcode.CheckRef: // s
                    id = (code+1).id;
                    s = *id;
                    // if(!scope_get(cc, scopex, id))
                    if (!cc.get(*id))
                        throw UndefinedVarError.toThrow(s);
                    code += IRTypes[Opcode.CheckRef].size;
                    break;
                case Opcode.GetScope:            // a = s
                    a = locals + (code + 1).index;
                    id = (code + 2).id;
                    s = *id;
                    version(SCOPECACHING)
                    {
                        si = SCOPECACHE_SI(s.ptr);
                        if(s is scopecache[si].s)
                        {
                            version(SCOPECACHE_LOG)
                                scopecache_cnt++;
                            *a = *scopecache[si].v;
                            code += 3;
                            break;
                        }
                    }
                    version(all)
                    {
                        // v = scope_get(cc, scopex, id);
                        v = cc.get(*id);
                        if(v is null)
                        {
                            v = signalingUndefined(s);
                            cc.set(*id, *v);
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

                    *a = *v;
                    code += IRTypes[Opcode.GetScope].size;
                    break;

                case Opcode.AddAsS:              // a = (b.c += a)
                    c = locals + (code + 3).index;
                    s = c.toString();
                    goto Laddass;

                case Opcode.AddAsSS:             // a = (b.s += a)
                    s = *(code + 3).id;
                    Laddass:
                    b = locals + (code + 2).index;
                    v = b.Get(s, cc);
                    goto Laddass2;

                case Opcode.AddAsSScope:         // a = (s += a)
                    b = null;               // Needed for the b.Put() below to shutup a compiler use-without-init warning
                    id = (code + 2).id;
                    s = *id;
                    version(SCOPECACHING)
                    {
                        si = SCOPECACHE_SI(s.ptr);
                        if(s is scopecache[si].s)
                            v = scopecache[si].v;
                        else
                            // v = scope_get(cc, scopex, id);
                            v = cc.get(*id);
                    }
                    else
                    {
                        v = scope_get(cc, scopex, id);
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
                    else if(a.type == Value.Type.Number &&
                            v.type == Value.Type.Number)
                    {
                        a.number += v.number;
                        v.number = a.number;
                    }
                    else
                    {
                        v.toPrimitive(cc, *v);
                        a.toPrimitive(cc, *a);
                        if(v.isString)
                        {
                            if (a.isUndefined)
                                s2 = v.toString;
                            else
                                s2 = v.toString ~ a.toString;
                            a.put(s2);
                        }
                        else if(a.isString)
                        {
                            if (v.isUndefined)
                                s2 = a.toString;
                            else
                                s2 = v.toString ~ a.toString;
                            a.put(s2);
                        }
                        else
                        {
                            a.put(a.toNumber(cc) + v.toNumber(cc));
                        }
                        *v = *a;//full copy // needed ?
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
                        sta = cannotConvert(b);
                        goto Lthrow;
                    }
                    sta = o.Set(*(code + 3).id, *a,
                                Property.Attribute.None, cc);
                    if(sta)
                        goto Lthrow;
                    code += IRTypes[Opcode.PutS].size;
                    // goto Lnext;
                    break;

                case Opcode.PutScope:            // s = a
                    a = locals + (code + 1).index;
                    a.checkReference();
                    cc.set(*(code + 2).id, *a);
                    code += IRTypes[Opcode.PutScope].size;
                    break;

                case Opcode.PutDefault:              // b = a
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    o = b.toObject();
                    if(!o)
                    {
                        sta = CannotAssignError(a.type.to!string_t,
                                                b.type.to!string_t);
                        goto Lthrow;
                    }
                    sta = o.PutDefault(*a);
                    if(sta)
                        goto Lthrow;
                    code += IRTypes[Opcode.PutDefault].size;
                    break;

                case Opcode.PutThis:             // s = a
                    //a = cc.variable.Put((code + 2).id.value.string, GETa(code), DontDelete);
                    o = cc.scopex.getNonFakeObject;
                    assert(o);
                    if(o.HasProperty(*(code + 2).id))
                        sta = o.Set(*(code+2).id,
                                    *(locals + (code + 1).index),
                                    Property.Attribute.DontDelete, cc);
                    else
                        sta = cc.setThis(*(code + 2).id,
                                         *(locals + (code + 1).index),
                                         Property.Attribute.DontDelete);
                    if (sta)
                        goto Lthrow;
                    code += IRTypes[Opcode.PutThis].size;
                    break;

                case Opcode.Mov:                 // a = b
                    *(locals + (code + 1).index) = *(locals + (code + 2).index);
                    code += IRTypes[Opcode.Mov].size;
                    break;

                case Opcode.String:              // a = "string"
                    (locals + (code + 1).index).put(*(code + 2).id);
                    code += IRTypes[Opcode.String].size;
                    break;

                case Opcode.Object:              // a = object
                {
                    FunctionDefinition fd;
                    fd = cast(FunctionDefinition)(code + 2).ptr;
                    Dfunction fobject = new DdeclaredFunction(fd);
                    fobject.scopex = cc.scopex.stack;
                    (locals + (code + 1).index).put(fobject);
                    code += IRTypes[Opcode.Object].size;
                    break;
                }
                case Opcode.This:                // a = this
                    (locals + (code + 1).index).put(othis);

                    code += IRTypes[Opcode.This].size;
                    break;

                case Opcode.Number:              // a = number
                    (locals + (code + 1).index).put(
                        *cast(double*)(code + 2));
                    code += IRTypes[Opcode.Number].size;
                    break;

                case Opcode.Boolean:             // a = boolean
                    (locals + (code + 1).index).put((code + 2).boolean);
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
                    v = othis.Get(*(code + 2).id, cc);
                    if(!v)
                        v = &undefined;
                    *a = *v;
                    code += IRTypes[Opcode.ThisGet].size;
                    break;

                case Opcode.Neg:                 // a = -a
                    a = locals + (code + 1).index;
                    n = a.toNumber(cc);
                    a.put(-n);
                    code += IRTypes[Opcode.Neg].size;
                    break;

                case Opcode.Pos:                 // a = a
                    a = locals + (code + 1).index;
                    n = a.toNumber(cc);
                    a.put(n);
                    code += IRTypes[Opcode.Pos].size;
                    break;

                case Opcode.Com:                 // a = ~a
                    a = locals + (code + 1).index;
                    i32 = a.toInt32(cc);
                    a.put(~i32);
                    code += IRTypes[Opcode.Com].size;
                    break;

                case Opcode.Not:                 // a = !a
                    a = locals + (code + 1).index;
                    a.put(!a.toBoolean());
                    code += IRTypes[Opcode.Not].size;
                    break;

                case Opcode.Typeof:      // a = typeof a
                    // ECMA 11.4.3 says that if the result of (a)
                    // is a Reference and GetBase(a) is null,
                    // then the result is "undefined". I don't know
                    // what kind of script syntax will generate this.
                    a = locals + (code + 1).index;
                    a.put(a.getTypeof());
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
                        sta = RhsMustBeObjectError("instanceof",
                                                   c.type.to!string_t);
                        goto Lthrow;
                    }
                    co = c.toObject();
                    a = locals + (code + 1).index;
                    sta = co.HasInstance(cc, *a, *b);
                    if(sta)
                        goto Lthrow;
                    code += IRTypes[Opcode.Instance].size;
                    break;
                }
                case Opcode.Add:                     // a = b + c
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;

                    if(b.type == Value.Type.Number &&
                       c.type == Value.Type.Number)
                    {
                        a.put(b.number + c.number);
                    }
                    else
                    {
                        char[Value.sizeof] vtmpb;
                        Value* vb = cast(Value*)vtmpb;
                        char[Value.sizeof] vtmpc;
                        Value* vc = cast(Value*)vtmpc;

                        b.toPrimitive(cc, *vb);
                        c.toPrimitive(cc, *vc);

                        if(vb.isString() || vc.isString())
                        {
                            s = vb.toString() ~vc.toString();
                            a.put(s);
                        }
                        else
                        {
                            a.put(vb.toNumber(cc) + vc.toNumber(cc));
                        }
                    }

                    code += IRTypes[Opcode.Add].size;
                    break;

                case Opcode.Sub:                 // a = b - c
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
                    a.put(b.toNumber(cc) - c.toNumber(cc));
                    code += 4;
                    break;

                case Opcode.Mul:                 // a = b * c
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
                    a.put(b.toNumber(cc) * c.toNumber(cc));
                    code += IRTypes[Opcode.Mul].size;
                    break;

                case Opcode.Div:                 // a = b / c
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;

                    a.put(b.toNumber(cc) / c.toNumber(cc));
                    code += IRTypes[Opcode.Div].size;
                    break;

                case Opcode.Mod:                 // a = b % c
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
                    a.put(b.toNumber(cc) % c.toNumber(cc));
                    code += IRTypes[Opcode.Mod].size;
                    break;

                case Opcode.ShL:                 // a = b << c
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
                    i32 = b.toInt32(cc);
                    u32 = c.toUint32(cc) & 0x1F;
                    i32 <<= u32;
                    a.put(i32);
                    code += IRTypes[Opcode.ShL].size;
                    break;

                case Opcode.ShR:                 // a = b >> c
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
                    i32 = b.toInt32(cc);
                    u32 = c.toUint32(cc) & 0x1F;
                    i32 >>= cast(int)u32;
                    a.put(i32);
                    code += IRTypes[Opcode.ShR].size;
                    break;

                case Opcode.UShR:                // a = b >>> c
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
                    i32 = b.toUint32(cc);
                    u32 = c.toUint32(cc) & 0x1F;
                    u32 = (cast(uint)i32) >> u32;
                    a.put(u32);
                    code += IRTypes[Opcode.UShR].size;
                    break;

                case Opcode.And:         // a = b & c
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
                    a.put(b.toInt32(cc) & c.toInt32(cc));
                    code += IRTypes[Opcode.And].size;
                    break;

                case Opcode.Or:          // a = b | c
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
                    a.put(b.toInt32(cc) | c.toInt32(cc));
                    code += IRTypes[Opcode.Or].size;
                    break;

                case Opcode.Xor:         // a = b ^ c
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
                    a.put(b.toInt32(cc) ^ c.toInt32(cc));
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

                    a.put(o.HasProperty(s));
                    code += IRTypes[Opcode.In].size;
                    break;

                /********************/

                case Opcode.PreInc:     // a = ++b.c
                    c = locals + (code + 3).index;
                    s = c.toString();
                    goto Lpreinc;
                case Opcode.PreIncS:    // a = ++b.s
                    s = *(code + 3).id;
                    Lpreinc:
                    inc = 1;
                    Lpre:
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    v = b.Get(s, cc);
                    if(!v)
                        v = &undefined;
                    n = v.toNumber(cc);
                    a.put(n + inc);
                    b.Set(s, *a, cc);

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
                    s = *id;
                    version(SCOPECACHING)
                    {
                        si = SCOPECACHE_SI(s.ptr);
                        if(s is scopecache[si].s)
                        {
                            v = scopecache[si].v;
                            n = v.toNumber(cc) + inc;
                            v.put(n);
                            a.put(n);
                        }
                        else
                        {
                            // v = scope_get(cc, scopex, id, o);
                            v = cc.get(*id, o);
                            if(v)
                            {
                                n = v.toNumber(cc) + inc;
                                v.put(n);
                                a.put(n);
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
                        v = scope_get(scopex, id, o);
                        if(v)
                        {
                            n = v.toNumber(cc);
                            v.put(n + inc);
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
                    s = *(code + 3).id;
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
                    s = *(code + 3).id;
                    Lpostinc:
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    v = b.Get(s, cc);
                    if(!v)
                        v = &undefined;
                    n = v.toNumber(cc);
                    a.put(n + 1);
                    b.Set(s, *a, cc);
                    a.put(n);

                    static assert(IRTypes[Opcode.PostInc].size
                                  == IRTypes[Opcode.PostIncS].size);
                    code += IRTypes[Opcode.PostIncS].size;
                    break;

                case Opcode.PostIncScope:        // a = s++
                    id = (code + 2).id;
                    // v = scope_get(cc, scopex, id, o);
                    v = cc.get(*id, o);
                    if(v && v != &undefined)
                    {
                        a = locals + (code + 1).index;
                        n = v.toNumber(cc);
                        v.put(n + 1);
                        a.put(n);
                    }
                    else
                    {
                        //GETa(code).putVundefined();
                        //FIXED: as per ECMA v5 should throw ReferenceError
                        throw ReferenceError.toThrow(*id);
                        //v = signalingUndefined(id.value.string);
                    }
                    code += IRTypes[Opcode.PostIncScope].size;
                    break;

                case Opcode.PostDec:     // a = b.c--
                    c = locals + (code + 3).index;
                    s = c.toString();
                    goto Lpostdec;
                case Opcode.PostDecS:    // a = b.s--
                    s = *(code + 3).id;
                    Lpostdec:
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    v = b.Get(s, cc);
                    if(!v)
                        v = &undefined;
                    n = v.toNumber(cc);
                    a.put(n - 1);
                    b.Set(s, *a, cc);
                    a.put(n);

                    static assert(IRTypes[Opcode.PostDecS].size
                                  == IRTypes[Opcode.PostDec].size);
                    code += IRTypes[Opcode.PostDecS].size;
                    break;

                case Opcode.PostDecScope:        // a = s--
                    id = (code + 2).id;
                    // v = scope_get(cc, scopex, id, o);
                    v = cc.get(*id, o);
                    if(v && v != &undefined)
                    {
                        n = v.toNumber(cc);
                        a = locals + (code + 1).index;
                        v.put(n - 1);
                        a.put(n);
                    }
                    else
                    {
                        //GETa(code).putVundefined();
                        //FIXED: as per ECMA v5 should throw ReferenceError
                        throw ReferenceError.toThrow(*id);
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
                            sta = cannotConvert(b);
                            goto Lthrow;
                        }
                        s = (code.opcode == Opcode.Del)
                            ? (locals + (code + 3).index).toString()
                            : *(code + 3).id;
                        if(o.implementsDelete())
                            bo = !!o.Delete(StringKey(s));
                        else
                            bo = !o.HasProperty(s);
                    }
                    (locals + (code + 1).index).put(bo);

                    static assert (IRTypes[Opcode.Del].size
                                   == IRTypes[Opcode.DelS].size);
                    code += IRTypes[Opcode.DelS].size;
                    break;

                case Opcode.DelScope:    // a = delete s
                    id = (code + 2).id;
                    s = *id;
                    //o = scope_tos(scopex);		// broken way
                    // if(!scope_get(cc, scopex, id, o))
                    if (!cc.get(*id, o))
                        bo = true;
                    else if(o.implementsDelete())
                        bo = !!o.Delete(StringKey(s));
                    else
                        bo = !o.HasProperty(s);
                    (locals + (code + 1).index).put(bo);
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
                    if(b.type == Value.Type.Number &&
                       c.type == Value.Type.Number)
                        res = (b.number < c.number);
                    else
                    {
                        b.toPrimitive(cc, *b, Value.Type.Number);
                        c.toPrimitive(cc, *c, Value.Type.Number);
                        if(b.isString() && c.isString())
                        {
                            string_t x = b.toString();
                            string_t y = c.toString();

                            res = cmp(x, y) < 0;
                        }
                        else
                            res = b.toNumber(cc) < c.toNumber(cc);
                    }
                    a.put(res);
                    code += IRTypes[Opcode.CLT].size;
                    break;

                case Opcode.CLE:         // a = (b <=  c)
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
                    if(b.type == Value.Type.Number &&
                       c.type == Value.Type.Number)
                        res = (b.number <= c.number);
                    else
                    {
                        b.toPrimitive(cc, *b, Value.Type.Number);
                        c.toPrimitive(cc, *c, Value.Type.Number);
                        if(b.isString() && c.isString())
                        {
                            string_t x = b.toString();
                            string_t y = c.toString();

                            res = cmp(x, y) <= 0;
                        }
                        else
                            res = b.toNumber(cc) <= c.toNumber(cc);
                    }
                    a.put(res);
                    code += IRTypes[Opcode.CLE].size;
                    break;

                case Opcode.CGT:         // a = (b >   c)
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
                    if(b.type == Value.Type.Number &&
                       c.type == Value.Type.Number)
                        res = (b.number > c.number);
                    else
                    {
                        b.toPrimitive(cc, *b, Value.Type.Number);
                        c.toPrimitive(cc, *c, Value.Type.Number);
                        if(b.isString() && c.isString())
                        {
                            string_t x = b.toString();
                            string_t y = c.toString();

                            res = cmp(x, y) > 0;
                        }
                        else
                            res = b.toNumber(cc) > c.toNumber(cc);
                    }
                    a.put(res);
                    code += IRTypes[Opcode.CGT].size;
                    break;


                case Opcode.CGE:         // a = (b >=  c)
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
                    if(b.type == Value.Type.Number &&
                       c.type == Value.Type.Number)
                        res = (b.number >= c.number);
                    else
                    {
                        b.toPrimitive(cc, *b, Value.Type.Number);
                        c.toPrimitive(cc, *c, Value.Type.Number);
                        if(b.isString() && c.isString())
                        {
                            string_t x = b.toString();
                            string_t y = c.toString();

                            res = cmp(x, y) >= 0;
                        }
                        else
                            res = b.toNumber(cc) >= c.toNumber(cc);
                    }
                    a.put(res);
                    code += IRTypes[Opcode.CGE].size;
                    break;

                case Opcode.CEq:         // a = (b ==  c)
                case Opcode.CNE:         // a = (b !=  c)
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
                    Lagain:
                    tx = b.type;
                    ty = c.type;
                    if      (tx == ty)
                    {
                        if      (tx == Value.Type.Undefined ||
                                 tx == Value.Type.Null)
                            res = true;
                        else if (tx == Value.Type.Number)
                        {
                            double x = b.number;
                            double y = c.number;

                            res = (x == y);
                        }
                        else if (tx == Value.Type.String)
                        {
                            res = (b.text == c.text);
                        }
                        else if (tx == Value.Type.Boolean)
                            res = (b.dbool == c.dbool);
                        else // TypeObject
                        {
                            res = b.object == c.object;
                        }
                    }
                    else if (tx == Value.Type.Null &&
                             ty == Value.Type.Undefined)
                        res = true;
                    else if (tx == Value.Type.Undefined &&
                             ty == Value.Type.Null)
                        res = true;
                    else if (tx == Value.Type.Number &&
                             ty == Value.Type.String)
                    {
                        c.put(c.toNumber(cc));
                        goto Lagain;
                    }
                    else if (tx == Value.Type.String &&
                             ty == Value.Type.Number)
                    {
                        b.put(b.toNumber(cc));
                        goto Lagain;
                    }
                    else if (tx == Value.Type.Boolean)
                    {
                        b.put(b.toNumber(cc));
                        goto Lagain;
                    }
                    else if (ty == Value.Type.Boolean)
                    {
                        c.put(c.toNumber(cc));
                        goto Lagain;
                    }
                    else if (ty == Value.Type.Object)
                    {
                        c.toPrimitive(cc, *c);
                        // v = cast(Value*)c.toPrimitive(c, null);
                        // if(v)
                        // {
                        //     a = v;
                        //     goto Lthrow;
                        // }
                        goto Lagain;
                    }
                    else if (tx == Value.Type.Object)
                    {
                        b.toPrimitive(cc, *b);
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
                    a.put(res);

                    static assert (IRTypes[Opcode.CEq].size
                                   == IRTypes[Opcode.CNE].size);
                    code += IRTypes[Opcode.CNE].size;
                    break;

                case Opcode.CID:         // a = (b === c)
                case Opcode.CNID:        // a = (b !== c)
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;

                    tx = b.type;
                    ty = c.type;
                    if      (tx == ty)
                    {
                        if      (tx == Value.Type.Undefined ||
                                 tx == Value.Type.Null)
                            res = true;
                        else if (tx == Value.Type.Number)
                        {
                            double x = b.number;
                            double y = c.number;

                            // Ensure that a NAN operand produces false
                            if(code.opcode == Opcode.CID)
                                res = (x == y);
                            else
                                res = (x != y);
                            goto Lcid;
                        }
                        else if (tx == Value.Type.String)
                            res = (b.text == c.text);
                        else if (tx == Value.Type.Boolean)
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
                    a.put(res);

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
                    if(b.type == Value.Type.Number &&
                       c.type == Value.Type.Number)
                    {
                        if(b.number < c.number)
                            code += 4;
                        else
                            code += (code + 1).offset;
                        break;
                    }
                    else
                    {
                        b.toPrimitive(cc, *b, Value.Type.Number);
                        c.toPrimitive(cc, *c, Value.Type.Number);
                        if(b.isString() && c.isString())
                        {
                            string_t x = b.toString();
                            string_t y = c.toString();

                            res = cmp(x, y) < 0;
                        }
                        else
                            res = b.toNumber(cc) < c.toNumber(cc);
                    }
                    if(!res)
                        code += (code + 1).offset;
                    else
                        code += IRTypes[Opcode.JLT].size;
                    break;

                case Opcode.JLE:         // if (b <=  c) goto c
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
                    if(b.type == Value.Type.Number &&
                       c.type == Value.Type.Number)
                    {
                        if(b.number <= c.number)
                            code += IRTypes[Opcode.JLE].size;
                        else
                            code += (code + 1).offset;
                        break;
                    }
                    else
                    {
                        b.toPrimitive(cc, *b, Value.Type.Number);
                        c.toPrimitive(cc, *c, Value.Type.Number);
                        if(b.isString() && c.isString())
                        {
                            string_t x = b.toString();
                            string_t y = c.toString();

                            res = cmp(x, y) <= 0;
                        }
                        else
                            res = b.toNumber(cc) <= c.toNumber(cc);
                    }
                    if(!res)
                        code += (code + 1).offset;
                    else
                        code += IRTypes[Opcode.JLE].size;
                    break;

                case Opcode.JLTC:        // if (b < constant) goto c
                    b = locals + (code + 2).index;
                    res = (b.toNumber(cc) < *cast(double*)(code + 3));
                    if(!res)
                        code += (code + 1).offset;
                    else
                        code += IRTypes[Opcode.JLTC].size;
                    break;

                case Opcode.JLEC:        // if (b <= constant) goto c
                    b = locals + (code + 2).index;
                    res = (b.toNumber(cc) <= *cast(double*)(code + 3));
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
                        sta = cannotConvert(b);
                        goto Lthrow;
                    }
                    sta = o.putIterator(*a);
                    if(sta)
                        goto Lthrow;
                    code += IRTypes[Opcode.Iter].size;
                    break;

                case Opcode.Next:        // a, b.c, iter
                    // if (!(b.c = iter)) goto a; iter = iter.next
                    s = (locals + (code + 3).index).toString();
                    goto case_next;

                case Opcode.NextS:       // a, b.s, iter
                    s = *(code + 3).id;
                    case_next:
                    iter = (locals + (code + 4).index).iter;
                    ppk = iter.next();
                    if(!ppk)
                        code += (code + 1).offset;
                    else
                    {
                        b = locals + (code + 2).index;
                        b.Set(s, ppk.value, cc);

                        static assert (IRTypes[Opcode.Next].size
                                       == IRTypes[Opcode.NextS].size);
                        code += IRTypes[Opcode.Next].size;
                    }
                    break;

                case Opcode.NextScope:   // a, s, iter
                    s = *(code + 2).id;
                    iter = (locals + (code + 3).index).iter;
                    ppk = iter.next();
                    if(!ppk)
                        code += (code + 1).offset;
                    else
                    {
                        o = cc.scopex.getNonFakeObject;
                        o.Set(s, ppk.value, Property.Attribute.None, cc);
                        code += IRTypes[Opcode.NextScope].size;
                    }
                    break;

                case Opcode.Call:        // a = b.c(argc, argv)
                    s = (locals + (code + 3).index).toString();
                    goto case_call;

                case Opcode.CallS:       // a = b.s(argc, argv)
                    s = *(code + 3).id;
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
                        v = o.Get(s, cc);
                        if(!v)
                            goto Lcallerror;

                        // cc.callerothis = othis;
                        a.putVundefined();
                        sta = v.Call(cc, o, *a, (locals + (code + 5).index)
                                                   [0 .. (code + 4).index]);
                    }
                    debug(VERIFY)
                        assert(checksum == IR.verify(codestart));
                    if(sta)
                        goto Lthrow;

                    static assert (IRTypes[Opcode.Call].size
                                   == IRTypes[Opcode.CallS].size);
                    code += IRTypes[Opcode.CallS].size;
                    // goto Lnext;
                    break;

                    Lcallerror:
                    {
                        sta = UndefinedNoCall3Error(b.type.to!string_t,
                                                    b.toString, s);
                        if (auto didyoumean = cc.searchSimilarWord(o, s))
                        {
                            sta.addMessage(", did you mean \"" ~
                                           didyoumean.join("\" or \"") ~
                                           "\"?");
                        }
                        goto Lthrow;
                    }

                case Opcode.CallScope:   // a = s(argc, argv)
                    id = (code + 2).id;
                    s = *id;
                    a = locals + (code + 1).index;
                    // v = scope_get_lambda(cc, scopex, id, o);
                    v = cc.get(*id, o);

                    if(v is null)
                    {
                        //a = Dobject.RuntimeError(&errinfo, errmsgtbl[ERR_UNDEFINED_NO_CALL2], "property", s);
                        sta = UndefinedVarError(s);
                        if (auto didyoumean = cc.searchSimilarWord(s))
                        {
                            sta.addMessage(", did you mean \"" ~
                                           didyoumean.join("\" or \"") ~
                                           "\"?");
                        }
                        goto Lthrow;
                    }
                    // Should we pass othis or o? I think othis.
                    // cc.callerothis = othis;        // pass othis to eval()
                    a.putVundefined();
                    sta = v.Call(cc, o, *a, (locals + (code + 4).index)
                                               [0 .. (code + 3).index]);

                    debug(VERIFY)
                        assert(checksum == IR.verify(codestart));
                    if(sta)
                    {
                        sta.addTrace(codestart, code);
                        cc.addTraceInfoTo(sta);
                        goto Lthrow;
                    }
                    code += IRTypes[Opcode.CallScope].size;
                    // goto Lnext;
                    break;

                case Opcode.CallV:   // v(argc, argv) = a
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    o = b.toObject();
                    if(!o)
                    {
                        sta = UndefinedNoCall2Error(b.type.to!string_t,
                                                    b.toString);
                        goto Lthrow;
                    }
                    // cc.callerothis = othis;        // pass othis to eval()
                    a.putVundefined();
                    sta = o.Call(cc, o, *a, (locals + (code + 4).index)[0 .. (code + 3).index]);
                    if(sta)
                        goto Lthrow;
                    code += IRTypes[Opcode.CallV].size;
                    // goto Lnext;
                    break;

                case Opcode.PutCall:        // b.c(argc, argv) = a
                    s = (locals + (code + 3).index).toString();
                    goto case_putcall;

                case Opcode.PutCallS:       //  b.s(argc, argv) = a
                    s = *(code + 3).id;
                    goto case_putcall;

                    case_putcall:
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    o = b.toObject();
                    if(!o)
                        goto Lcallerror;
                    //v = o.GetLambda(s, Value.calcHash(s));
                    v = o.Get(s, cc);
                    if(!v)
                        goto Lcallerror;
                    //writef("calling... '%s'\n", v.toString());
                    o = v.toObject();
                    if(!o)
                    {
                        sta = CannotAssignTo2Error(b.type.to!string_t, s);
                        goto Lthrow;
                    }
                    sta = o.put_Value(*a, (locals + (code + 5).index)[0 .. (code + 4).argc]);
                    if(sta)
                        goto Lthrow;

                    static assert (IRTypes[Opcode.PutCall].size
                                   == IRTypes[Opcode.PutCallS].size);
                    code += IRTypes[Opcode.PutCallS].size;
                    // goto Lnext;
                    break;

                case Opcode.PutCallScope:   // a = s(argc, argv)
                    id = (code + 2).id;
                    s = *id;
                    // v = scope_get_lambda(cc, scopex, id, o);
                    v = cc.get(*id, o);
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
                    sta = o.put_Value(*(locals + (code + 1).index), (locals + (code + 4).index)[0 .. (code + 3).index]);
                    if(sta)
                        goto Lthrow;
                    code += IRTypes[Opcode.PutCallScope].size;
                    // goto Lnext;
                    break;

                case Opcode.PutCallV:        // v(argc, argv) = a
                    b = locals + (code + 2).index;
                    o = b.toObject();
                    if(!o)
                    {
                        //writef("%s %s is undefined and has no Call method\n", b.getType(), b.toString());
                        sta = UndefinedNoCall2Error(b.type.to!string_t,
                                                    b.toString);
                        goto Lthrow;
                    }
                    sta = o.put_Value(*(locals + (code + 1).index), (locals + (code + 4).index)[0 .. (code + 3).index]);
                    if(sta)
                        goto Lthrow;
                    code += IRTypes[Opcode.PutCallV].size;
                    // goto Lnext;
                    break;

                case Opcode.New: // a = new b(argc, argv)
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    a.putVundefined();
                    sta = b.Construct(cc, *a, (locals + (code + 4).index)[0 .. (code + 3).index]);
                    debug(VERIFY)
                        assert(checksum == IR.verify(codestart));
                    if(sta)
                        goto Lthrow;
                    code += IRTypes[Opcode.New].size;
                    // goto Lnext;
                    break;

                case Opcode.Push:
                    SCOPECACHE_CLEAR();
                    a = locals + (code + 1).index;
                    o = a.toObject();
                    if(!o)
                    {
                        sta = cannotConvert(a);
                        goto Lthrow;
                    }
                    // scopex ~= o;                // push entry onto scope chain
                    // cc.scopex = scopex;
                    cc.pushScope(o);
                    code += IRTypes[Opcode.Push].size;
                    break;

                case Opcode.Pop:
                    SCOPECACHE_CLEAR();
                    // o = scopex[$ - 1];
                    // scopex = scopex[0 .. $ - 1];        // pop entry off scope chain
                    // cc.scopex = scopex;
                    o = cc.popScope;
                    // If it's a Finally, we need to execute
                    // the finally block
                    code += IRTypes[Opcode.Pop].size;

                    if(auto fin = cast(Finally)o) // test could be eliminated with virtual func
                    {
                        callFinally(fin);
                        debug(VERIFY)
                            assert(checksum == IR.verify(codestart));
                    }

                    // goto Lnext;
                    break;

                case Opcode.FinallyRet:
                    assert(finallyStack.length);
                    code = finallyStack[$-1];
                    finallyStack = finallyStack[0..$-1];
                    // goto Lnext;
                    break;

                case Opcode.Ret:
                    // version(SCOPECACHE_LOG)
                    //     printf("scopecache_cnt = %d\n", scopecache_cnt);
                    return null;

                case Opcode.RetExp:
                    a = locals + (code + 1).index;
                    a.checkReference();
                    ret = *a;

                    return null;

                case Opcode.ImpRet:
                    a = locals + (code + 1).index;
                    assert (a !is null);
                    a.checkReference;
                    ret = *a;

                    code += IRTypes[Opcode.ImpRet].size;
                    // goto Lnext;
                    break;

                case Opcode.Throw:
                    a = locals + (code + 1).index;
                    sta = new DError(cc, *a);
                    Lthrow:
                    // assert(scopex[0] !is null);
                    sta = unwindStack(sta);
                    if(sta)
                    {
                        sta.addTrace(codestart, code);
                        return sta;
                    }
                    break;
                case Opcode.TryCatch:
                    SCOPECACHE_CLEAR();
                    offset = (code - codestart) + (code + 1).offset;
                    s = *(code + 2).id;
                    // scopex ~= ca;
                    // cc.scopex = scopex;
                    cc.pushScope(new Catch(offset, s));
                    code += IRTypes[Opcode.TryCatch].size;
                    break;

                case Opcode.TryFinally:
                    SCOPECACHE_CLEAR();
                    // scopex ~= f;
                    // cc.scopex = scopex;
                    cc.pushScope(new Finally(code + (code + 1).offset));
                    code += IRTypes[Opcode.TryFinally].size;
                    break;

                case Opcode.Assert:
                {
                    version(all)  // Not supported under some com servers
                    {
                        auto linnum = (code + 1).index;
                        sta = AssertError(linnum);
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
                    // goto Linterrupt;
                    break loop;
                } // the end of the final switch.
            }
            catch(Throwable t)
            {
                sta = unwindStack(t.toDError!typeerror);
                if (sta !is null)
                {
                    sta.addTrace(codestart, code);
                    return sta;
                }
            }
        } // the end of the for(;;) loop.

        // Linterrupt:
        ret.putVundefined();
        return null;
    }

    /*********************************
     * Give size of opcode.
     */

    static size_t size(Opcode opcode)
    {
        static size_t sizeOf(T)(){ return T.size; }
        return IRTypeDispatcher!sizeOf(opcode);
    }

    /*******************************************
     * This is a 'disassembler' for our interpreted code.
     * Useful for debugging.
     */

    debug static void toBuffer(size_t address, const(IR)* code,
                               scope void delegate(in char_t[]) sink)
    {
        static string proc(T)(size_t address, const(IR)* c)
        {
            import std.traits : Parameters;

            alias Ps = Parameters!(T.toString);
            static if      (0 == Ps.length)
                return (cast(T*)c).toString;
            else static if (1 == Ps.length && is(Ps[0] : size_t))
                return (cast(T*)c).toString(address);
            else static assert(0);
        }
        sink(IRTypeDispatcher!proc(code.opcode, address, code,));
    }

    debug static string_t toString(const(IR)* code)
    {
        import std.format : format;
        import std.array : Appender;

        Appender!string_t buf;
        auto codestart = code;

        for(;; )
        {
            buf.put(format("%04d", cast(size_t)(code - codestart)));
            buf.put(":");
            toBuffer(code - codestart, code, b=>buf.put(b));
            buf.put("\n");
            if(code.opcode == Opcode.End)
                break;
            code += size(code.opcode);
        }
        return buf.data;
    }

    /***************************************
     * Verify that it is a correct sequence of code.
     * Useful for isolating memory corruption bugs.
     */
    debug static uint verify(IR* codestart, size_t linnum = __LINE__)
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
                        writef("undefined opcode %d in code %p\n",
                               code.opcode, codestart);
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

//==============================================================================
private:

//------------------------------------------------------------------------------
// Catch & Finally are "fake" Dobjects that sit in the scope
// chain to implement our exception handling context.

class Catch : Dobject
{
    import dmdscript.primitive : StringKey, string_t;
    import dmdscript.callcontext : CallContext;
    import dmdscript.value : Value;

    alias GetImpl = Dobject.GetImpl;
    // This is so scope_get() will skip over these objects
    override Value* GetImpl(in ref StringKey, ref CallContext) const
    {
        return null;
    }

    // This is so we can distinguish between a real Dobject
    // and these fakers
    override string_t getTypeof() const
    {
        return null;
    }

    uint offset;        // offset of CatchBlock
    string_t name;      // catch identifier

    this(uint offset, string_t name)
    {
        super(null);
        this.offset = offset;
        this.name = name;
    }
}

//------------------------------------------------------------------------------
class Finally : Dobject
{
    import dmdscript.primitive : StringKey, string_t;
    import dmdscript.callcontext : CallContext;
    import dmdscript.value : Value;
    import dmdscript.opcodes : IR;

    alias GetImpl = Dobject.GetImpl;
    override Value* GetImpl(in ref StringKey, ref CallContext) const
    {
        return null;
    }

    override string_t getTypeof() const
    {
        return null;
    }

    IR* finallyblock;    // code for FinallyBlock

    this(IR* finallyblock)
    {
        super(null);
        this.finallyblock = finallyblock;
    }
}


//------------------------------------------------------------------------------
/*
Helper function for Values that cannot be converted to Objects.
 */
DError* cannotConvert(Value* b)
{
    import std.conv : to;
    DError* sta;

    if(b.isUndefinedOrNull)
    {
        sta = CannotConvertToObject4Error(b.type.to!string_t);
    }
    else
    {
        sta = CannotConvertToObject2Error(b.type.to!string_t, b.toString);
    }
    return sta;
}

