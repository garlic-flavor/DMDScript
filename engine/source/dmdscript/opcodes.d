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
// import dmdscript.protoerror;
import dmdscript.drealm : undefined, Drealm, DmoduleRealm;
import dmdscript.callcontext: CallContext;
import dmdscript.derror: Derror, onError;

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
        Identifier  id;
        bool        boolean;
        Statement   target;     // used for backpatch fixups
        FunctionDefinition fd;
    }

    /****************************
     * This is the main interpreter loop.
     */
    static nothrow
    Derror call(CallContext* cc, Dobject othis, const(IR)* code,
                 out Value ret, Value* locals)
    {
        import std.array : join;
        import std.conv : to;
        import std.string : cmp;
        import std.bigint: BigInt;
        alias PA = Property.Attribute;
        alias VT = Value.Type;

        const(IR*) codestart = code;
        Value* a;
        Value* b;
        Value* c;
        Value* v;
        Dobject o;
        Derror sta, prevError;
        Identifier id;
        union AX
        {
            PropertyKey pk;
            double inc;
            bool b;
            string s;
            double d;
            int i;
            PA attr;
            struct { double d1, d2; }
            struct { string s1, s2; }
            struct { int i1, i2; }
            struct { uint u1, u2; }
        }
        AX ax = void;

        //Finally blocks are sort of called, sort of jumped to
        //So we are doing "push IP in some stack" + "jump"
        const(IR)*[] finallyStack;// it's a stack of backreferences for finally

        @safe pure nothrow
        void callFinally(Finally f)
        {
            //cc.scopex = scopex;
            finallyStack ~= code;
            code = f.finallyblock;
        }

        nothrow
        Derror unwindStack(Derror err)
        {
            // assert(scopex.length && scopex[0] !is null,
            //        "Null in scopex, Line " ~ code.opcode.linnum.to!string);
            assert (err !is null);

            // chain the object caught and an object to be thrown.
            if (prevError !is null)
            {
                prevError.updateMessage(cc);
                err.addPrev(prevError);
                prevError = null;
            }

            for (;;)
            {
                // pop entry off scope chain
                if      ((o = cc.pop) is null)
                {
                    ret.putVundefined;
                    return err;
                }
                else if (auto ca = cast(Catch)o)
                {
                    prevError = err;
                    o = cc.realm.dObject();
                    version(JSCRIPT_CATCH_BUG)
                    {
                        PutValue(realm, ca.name, &err.entity);
                    }
                    else
                    {
                        o.Set(*ca.name, err.value,
                              Property.Attribute.DontDelete, cc);
                    }
                    cc.push(o);
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
                Identifier id;
                Value*   v;     // never null, and never from a Dcomobject
            }
            size_t si;
            ScopeCache[16] scopecache;
            version(SCOPECACHE_LOG)
                int scopecache_cnt = 0;

            size_t SCOPECACHE_SI(Identifier s)
            {
                return (cast(size_t)cast(void*)s) & 15;
            }
            void SCOPECACHE_CLEAR()
            {
                scopecache[] = ScopeCache();
            }
        }

        debug(VERIFY) uint checksum = IR.verify(code);

        // scopex = cc.scopex;

        // dimsave = scopex.length;

        assert(code);
        assert(othis);

    retry:
        try
        {
        Lnext:
            if (cc.realm.isInterrupting) // see if script was interrupted
                return sta;

            assert(code.opcode <= Opcode.max,
                   "Unrecognized IR instruction " ~ code.opcode.to!string);

            final switch(code.opcode)
            {
            case Opcode.Error:
                assert(0);

            case Opcode.Nop:
                code += IRTypes[Opcode.Nop].size;
                goto Lnext;

            case Opcode.Get:                 // a = b.c
            {
                int i32;
                a = locals + (code + 1).index;
                b = locals + (code + 2).index;
                b.to(o, cc);
                if(!o)
                {
                    sta = cannotConvert(cc, b);
                    goto Lthrow;
                }
                c = locals + (code + 3).index;
                c.to(ax.pk, cc);
                sta = o.Get(ax.pk, v, cc);
                if (sta !is null)
                    goto Lthrow;

                if(!v)
                    v = &undefined;
                *a = *v;
                code += IRTypes[Opcode.Get].size;
                goto Lnext;
            }
            case Opcode.Put:                 // b.c = a
            {
                int i32;
                a = locals + (code + 1).index;
                b = locals + (code + 2).index;
                c = locals + (code + 3).index;
                c.to(ax.pk, cc);
                sta = b.Set(ax.pk, *a, cc);
                if(sta)
                    goto Lthrow;
                code += IRTypes[Opcode.Put].size;
                goto Lnext;
            }
            case Opcode.GetS:                // a = b.s
                a = locals + (code + 1).index;
                b = locals + (code + 2).index;
                id = (code + 3).id;
                b.to(o, cc);
                if(o is null)
                {
                    b.to(ax.s, cc);
                    sta = CannotConvertToObject3Error(
                        cc, b.type.to!string, ax.s, id.toString);
                    goto Lthrow;
                }
                if (o.Get(*id, v, cc).onError(sta))
                    goto Lthrow;
                if(v is null)
                {
                    v = &undefined;
                }
                *a = *v;
                code += IRTypes[Opcode.GetS].size;
                goto Lnext;
            case Opcode.CheckRef: // s
                id = (code+1).id;
                sta = cc.get(*id, v);
                if (sta !is null)
                    goto Lthrow;
                if (v is null)
                {
                    sta = UndefinedVarError(cc, id.toString);
                    goto Lthrow;
                }
                code += IRTypes[Opcode.CheckRef].size;
                goto Lnext;
            mixin("GetScope".op(q{            // a = s
                mixin(fill!a);
                id = (code + 2).id;
                version(SCOPECACHING)
                {
                    si = SCOPECACHE_SI(id);
                    if(id is scopecache[si].id)
                    {
                        version(SCOPECACHE_LOG)
                            scopecache_cnt++;
                        *a = *scopecache[si].v;
                        mixin("GetScope".goNext);
                    }
                }

                // v = scope_get(cc, scopex, id);
                if (cc.get(*id, v).onError(sta))
                    goto Lthrow;
                if(v is null)
                {
                    // if (realm.strictMode)
                    // {
                    //     sta = CannotAssignToError(realm, id.toString);
                    //     goto Lthrow;
                    // }

                    cc.set(*id, undefined);
                    v = signalingUndefined(id.toString);
                }
                else
                {
                    version(SCOPECACHING)
                    {
                        scopecache[si].id = id;
                        scopecache[si].v = v;
                    }
                }
                *a = *v;
            }));
            case Opcode.PutGetter:
                assert (0, "not implemented yet");
                // code += IRTypes[Opcode.PutGetter].size;
                // break;
            case Opcode.PutGetterS:
            {
                a = locals + (code + 1).index;
                a.to(o, cc);
                auto f = cast(Dfunction)o;
                if (f is null)
                {
                    sta = cannotConvert(cc, a);
                    goto Lthrow;
                }
                b = locals + (code + 2).index;
                b.to(o, cc);
                if(o is null)
                {
                    sta = cannotConvert(cc, b);
                    goto Lthrow;
                }
                if (!o.SetGetter(*(code+3).id, f, Property.Attribute.None))
                {
                    sta = CannotPutError(cc); // !!!!!!!!!!!!!!!!!!!!!!!!!!
                    goto Lthrow;
                }
                code += IRTypes[Opcode.PutGetterS].size;
                goto Lnext;
            }
            case Opcode.PutSetter:
                assert (0, "not implemented yet");
                // code += IRTypes[Opcode.PutSetter].size;
                // break;
            case Opcode.PutSetterS:
            {
                a = locals + (code + 1).index;
                a.to(o, cc);
                auto f = cast(Dfunction)o;
                if (f is null)
                {
                    sta = cannotConvert(cc, a);
                    goto Lthrow;
                }
                b = locals + (code + 2).index;
                b.to(o, cc);
                if(!o)
                {
                    sta = cannotConvert(cc, b);
                    goto Lthrow;
                }
                if (!o.SetSetter(*(code+3).id, f, Property.Attribute.None))
                {
                    sta = CannotPutError(cc); // !!!!!!!!!!!!!!!!!!!!!!!!!!!
                    goto Lthrow;
                }
                code += IRTypes[Opcode.PutSetterS].size;
                goto Lnext;
            }
            case Opcode.AddAsS:              // a = (b.c += a)
                c = locals + (code + 3).index;
                c.to(ax.pk, cc);
                id = &ax.pk;
                goto Laddass;

            case Opcode.AddAsSS:             // a = (b.s += a)
                id = (code + 3).id;

            Laddass:
                assert (id !is null);

                b = locals + (code + 2).index;
                sta = b.Get(*id, v, cc);
                if (sta !is null)
                    goto Lthrow;
                goto Laddass2;

            case Opcode.AddAsSScope:         // a = (s += a)
                b = null;
                id = (code + 2).id;
                version(SCOPECACHING)
                {
                    si = SCOPECACHE_SI(id);
                    if(id is scopecache[si].id)
                        v = scopecache[si].v;
                    else
                    {
                        sta = cc.get(*id, v);
                        if (sta !is null)
                            goto Lthrow;
                    }
                }
                else
                {
                    sta = cc.get(*id, v);
                    if (sta !is null)
                        goto Lthrow;
                }
            Laddass2:
                a = locals + (code + 1).index;
                if(!v)
                {
                    sta = UndefinedVarError(cc, id.toString);
                    //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                    // To_Do: add b's information
                    goto Lthrow;
                }
                else if(a.type == Value.Type.Number &&
                        v.type == Value.Type.Number)
                {
                    a.number += v.number;
                    v.number = a.number;
                }
                else
                {
                    v.toPrimitive(*v, cc);
                    a.toPrimitive(*a, cc);
                    if(v.isString)
                    {
                        if (a.isUndefined)
                            a.put(v.text);
                        else
                        {
                            a.to(ax.s, cc);
                            a.put(v.text ~ ax.s);
                        }
                    }
                    else if(a.isString)
                    {
                        if (!v.isUndefined)
                        {
                            v.to(ax.s, cc);
                            a.put(ax.s ~ a.text);
                        }
                    }
                    else
                    {
                        a.to(ax.d1, cc);
                        v.to(ax.d2, cc);
                        a.put(ax.d1 + ax.d2);
                    }
                    *v = *a; //full copy
                }

                static assert(IRTypes[Opcode.AddAsS].size
                              == IRTypes[Opcode.AddAsSS].size &&
                              IRTypes[Opcode.AddAsS].size
                              == IRTypes[Opcode.AddAsSScope].size);
                code += IRTypes[Opcode.AddAsSScope].size;
                goto Lnext;

            mixin("PutS".op(q{            // b.s = a
                mixin (fill!(a, b));
                if (b.to(o, cc).onError(sta))
                    goto Lthrow;
                if(o is null)
                {
                    sta = cannotConvert(cc, b);
                    goto Lthrow;
                }
                if (cc.strictMode)
                    ax.attr = PA.None;
                else
                    ax.attr = PA.Silent;
                if (o.Set(*(code + 3).id, *a, ax.attr, cc).onError(sta))
                    goto Lthrow;
            }));

            mixin("PutScope".op(q{            // s = a
                mixin (fill!a);
                if (a.checkReference(cc).onError(sta))
                    goto Lthrow;

                if (cc.strictMode)
                    ax.attr = PA.None;
                else
                    ax.attr = PA.Silent;

                if (cc.set(*(code + 2).id, *a, ax.attr).onError(sta))
                    goto Lthrow;
            }));

            case Opcode.PutDefault:              // b = a
                a = locals + (code + 1).index;
                b = locals + (code + 2).index;
                b.to(o, cc);
                if(!o)
                {
                    sta = CannotAssignError(cc, a.type.to!string,
                                            b.type.to!string);
                    goto Lthrow;
                }
                sta = o.PutDefault(*a, cc);
                if(sta)
                    goto Lthrow;
                code += IRTypes[Opcode.PutDefault].size;
                goto Lnext;

            mixin("PutThis".op(q{             // id = a
                mixin(fill!a);
                id = (code + 2).id;
                o = cc.getNonFakeObject;
                assert(o !is null);
                if (cc.strictMode)
                    ax.attr = PA.DontDelete;
                else
                    ax.attr = PA.DontDelete | PA.Silent;
                if(o.HasProperty(*id))
                {
                    if (o.Set(*id, *a, ax.attr, cc).onError(sta))
                        goto Lthrow;
                }
                else
                {
                    if (cc.setThis(*id, *a, ax.attr).onError(sta))
                        goto Lthrow;
                }
            }));
            case Opcode.PutThisLocal:
                assert (0, "not implemented yet.");
            case Opcode.PutThisLocalConst:
                assert (0, "not implemented yet.");

            case Opcode.Mov:                 // a = b
                *(locals + (code + 1).index) = *(locals + (code + 2).index);
                code += IRTypes[Opcode.Mov].size;
                goto Lnext;

            case Opcode.String:              // a = "string"
                assert ((code + 2).value.isString);
                (locals + (code + 1).index).put((code + 2).value.text);
                code += IRTypes[Opcode.String].size;
                goto Lnext;

            case Opcode.Object:              // a = object
            {
                auto fd = cast(FunctionDefinition)(code+2).fd;
                auto fobject = new DdeclaredFunction(cc.realm, fd, cc.save);
                (locals + (code + 1).index).put(fobject);
                code += IRTypes[Opcode.Object].size;
                goto Lnext;
            }
            case Opcode.This:                // a = this
                (locals + (code + 1).index).put(othis);

                code += IRTypes[Opcode.This].size;
                goto Lnext;

            mixin("Number".op(q{              // a = number
                (locals + (code + 1).index).put(
                    *cast(double*)(code + 2));
            }));
            case Opcode.BigInt:              // a = BigInt
                (locals + (code + 1).index).put(
                    *cast(BigInt**)(code + 2));
                code += IRTypes[Opcode.BigInt].size;
                goto Lnext;
            case Opcode.Boolean:             // a = boolean
                (locals + (code + 1).index).put((code + 2).boolean);
                code += IRTypes[Opcode.Boolean].size;
                goto Lnext;

            case Opcode.Null:                // a = null
                (locals + (code + 1).index).putVnull();
                code += IRTypes[Opcode.Null].size;
                goto Lnext;

            case Opcode.Undefined:           // a = undefined
                (locals + (code + 1).index).putVundefined();
                code += IRTypes[Opcode.Undefined].size;
                goto Lnext;

            case Opcode.ThisGet:             // a = othis.ident
                a = locals + (code + 1).index;
                sta = othis.Get(*(code + 2).id, v, cc);
                if (sta !is null)
                    goto Lthrow;
                if(!v)
                    v = &undefined;
                *a = *v;
                code += IRTypes[Opcode.ThisGet].size;
                goto Lnext;

            case Opcode.Neg:                 // a = -a
                a = locals + (code + 1).index;
                if (a.type == Value.Type.BigInt)
                    a.put(new BigInt( (*a.bigInt) * -1 ));
                else
                {
                    a.to(ax.d, cc);
                    a.put(-ax.d);
                }
                code += IRTypes[Opcode.Neg].size;
                goto Lnext;

            case Opcode.Pos:                 // a = a
                a = locals + (code + 1).index;
                a.to(ax.d, cc);
                a.put(ax.d);
                code += IRTypes[Opcode.Pos].size;
                goto Lnext;

            case Opcode.Com:                 // a = ~a
                a = locals + (code + 1).index;
                a.to(ax.i, cc);
                a.put(~ax.i);
                code += IRTypes[Opcode.Com].size;
                goto Lnext;

            case Opcode.Not:                 // a = !a
                a = locals + (code + 1).index;
                sta = a.to(ax.b, cc);
                if (sta !is null)
                {
                    sta.addTrace;
                    goto Lthrow;
                }
                a.put(!ax.b);
                code += IRTypes[Opcode.Not].size;
                goto Lnext;

            case Opcode.Typeof:      // a = typeof a
                // ECMA 11.4.3 says that if the result of (a)
                // is a Reference and GetBase(a) is null,
                // then the result is "undefined". I don't know
                // what kind of script syntax will generate this.
                a = locals + (code + 1).index;
                a.put(a.getTypeof);
                code += IRTypes[Opcode.Typeof].size;
                goto Lnext;

            case Opcode.Instance:        // a = b instanceof c
                // ECMA v3 11.8.6
                c = locals + (code + 3).index;
                if(c.isPrimitive)
                {
                    sta = RhsMustBeObjectError(cc, "instanceof",
                                               c.type.to!string);
                    goto Lthrow;
                }
                a = locals + (code + 1).index;
                b = locals + (code + 2).index;
                c.to(o, cc);
                sta = o.HasInstance(*b, *a, cc);
                if(sta)
                    goto Lthrow;
                code += IRTypes[Opcode.Instance].size;
                goto Lnext;
            mixin("Add".op(q{                     // a = b + c
                mixin (fill!(a, b, c));

                if(b.type == VT.Number && c.type == VT.Number)
                {
                    a.put(b.number + c.number);
                }
                else
                {
                    Value vb, vc;

                    if (b.toPrimitive(vb, cc).onError(sta))
                        goto Lthrow;
                    if (c.toPrimitive(vc, cc).onError(sta))
                        goto Lthrow;

                    if      (vb.isSymbol || vc.isSymbol)
                    {
                        sta = TypeError(cc, "Symbol cannot add.");
                        goto Lthrow;
                    }
                    else if (vb.isString || vc.isString)
                    {
                        mixin ("ax.s1".from!vb);
                        mixin ("ax.s2".from!vc);
                        a.put(ax.s1 ~ ax.s2);
                    }
                    else if (vb.isBigInt || vc.isBigInt)
                    {
                        if (!vb.isBigInt || !vc.isBigInt)
                        {
                            sta = TypeError(cc, "converting to BigInt");
                            goto Lthrow;
                        }
                        a.put(new BigInt(*vb.bigInt + *vc.bigInt));
                    }
                    else
                    {
                        mixin ("ax.d1".from!vb);
                        mixin ("ax.d2".from!vc);
                        a.put(ax.d1 + ax.d2);
                    }
                }
            }));

            case Opcode.Sub:                 // a = b - c
                a = locals + (code + 1).index;
                b = locals + (code + 2).index;
                c = locals + (code + 3).index;
                if (b.to(ax.d1, cc).onError(sta))
                    goto Lthrow;
                if (c.to(ax.d2, cc).onError(sta))
                    goto Lthrow;
                a.put(ax.d1 - ax.d2);
                code += 4;
                goto Lnext;

            case Opcode.Mul:                 // a = b * c
                a = locals + (code + 1).index;
                b = locals + (code + 2).index;
                c = locals + (code + 3).index;
                if (b.to(ax.d1, cc).onError(sta))
                    goto Lthrow;
                if (c.to(ax.d2, cc).onError(sta))
                    goto Lthrow;
                a.put(ax.d1 * ax.d2);
                code += IRTypes[Opcode.Mul].size;
                goto Lnext;

            case Opcode.Div:                 // a = b / c
                a = locals + (code + 1).index;
                b = locals + (code + 2).index;
                c = locals + (code + 3).index;

                if (b.to(ax.d1, cc).onError(sta))
                    goto Lthrow;
                if (c.to(ax.d2, cc).onError(sta))
                    goto Lthrow;
                a.put(ax.d1 / ax.d2);
                code += IRTypes[Opcode.Div].size;
                goto Lnext;

            case Opcode.Mod:                 // a = b % c
                a = locals + (code + 1).index;
                b = locals + (code + 2).index;
                c = locals + (code + 3).index;
                if (b.to(ax.d1, cc).onError(sta))
                    goto Lthrow;
                if (c.to(ax.d2, cc).onError(sta))
                    goto Lthrow;
                a.put(ax.d1 % ax.d2);
                code += IRTypes[Opcode.Mod].size;
                goto Lnext;

            case Opcode.ShL:                 // a = b << c
                a = locals + (code + 1).index;
                b = locals + (code + 2).index;
                c = locals + (code + 3).index;
                if (b.to(ax.i1, cc).onError(sta))
                    goto Lthrow;
                if (c.to(ax.u2, cc).onError(sta))
                    goto Lthrow;
                ax.i1 <<= (ax.u2 & 0x1F);
                a.put(ax.i1);
                code += IRTypes[Opcode.ShL].size;
                goto Lnext;
            case Opcode.ShR:                 // a = b >> c
                a = locals + (code + 1).index;
                b = locals + (code + 2).index;
                c = locals + (code + 3).index;
                if (b.to(ax.i1, cc).onError(sta))
                    goto Lthrow;
                if (c.to(ax.u2, cc).onError(sta))
                    goto Lthrow;
                ax.i1 >>= cast(int)(ax.u2 & 0x1F);
                a.put(ax.i1);
                code += IRTypes[Opcode.ShR].size;
                goto Lnext;
            case Opcode.UShR:                // a = b >>> c
                a = locals + (code + 1).index;
                b = locals + (code + 2).index;
                c = locals + (code + 3).index;
                if (b.to(ax.u1, cc).onError(sta))
                    goto Lthrow;
                if (c.to(ax.u2, cc).onError(sta))
                    goto Lthrow;
                ax.u2 = (cast(uint)ax.u1) >> (ax.u2 & 0x1F);
                a.put(ax.u2);
                code += IRTypes[Opcode.UShR].size;
                goto Lnext;
            case Opcode.And:         // a = b & c
                a = locals + (code + 1).index;
                b = locals + (code + 2).index;
                c = locals + (code + 3).index;
                if (b.to(ax.i1, cc).onError(sta))
                    goto Lthrow;
                if (c.to(ax.i2, cc).onError(sta))
                    goto Lthrow;
                a.put(ax.i1 & ax.i2);
                code += IRTypes[Opcode.And].size;
                goto Lnext;

            case Opcode.Or:          // a = b | c
                a = locals + (code + 1).index;
                b = locals + (code + 2).index;
                c = locals + (code + 3).index;
                if (b.to(ax.i1, cc).onError(sta))
                    goto Lthrow;
                if (c.to(ax.i2, cc).onError(sta))
                    goto Lthrow;
                a.put(ax.i1 | ax.i2);
                code += IRTypes[Opcode.Or].size;
                goto Lnext;

            case Opcode.Xor:         // a = b ^ c
                a = locals + (code + 1).index;
                b = locals + (code + 2).index;
                c = locals + (code + 3).index;
                if (b.to(ax.i1, cc).onError(sta))
                    goto Lthrow;
                if (c.to(ax.i2, cc).onError(sta))
                    goto Lthrow;
                a.put(ax.i1 ^ ax.i2);
                code += IRTypes[Opcode.Xor].size;
                goto Lnext;
            case Opcode.In:          // a = b in c
                a = locals + (code + 1).index;
                b = locals + (code + 2).index;
                c = locals + (code + 3).index;
                if (b.to(ax.pk, cc).onError(sta))
                    goto Lthrow;
                if (c.to(o, cc).onError(sta))
                    goto Lthrow;
                if(o is null)
                {
                    c.to(ax.s, cc);
                    sta = RhsMustBeObjectError(cc, "in", ax.s);
                    goto Lthrow;
                }

                a.put(o.HasProperty(ax.pk));
                code += IRTypes[Opcode.In].size;
                goto Lnext;

                /********************/

            case Opcode.PreInc:     // a = ++b.c
                c = locals + (code + 3).index;
                if (c.to(ax.pk, cc).onError(sta))
                    goto Lthrow;
                id = &ax.pk;
                goto Lpreinc;
            case Opcode.PreIncS:    // a = ++b.s
                id = (code + 3).id;
            Lpreinc:
                ax.inc = 1;
            Lpre:
                assert (id !is null);

                a = locals + (code + 1).index;
                b = locals + (code + 2).index;
                if (b.Get(*id, v, cc).onError(sta))
                    goto Lthrow;
                if(!v)
                    v = &undefined;
                if (v.to(ax.d2, cc).onError(sta))
                    goto Lthrow;
                a.put(ax.d2 + ax.inc);
                b.Set(*id, *a, cc);

                static assert(IRTypes[Opcode.PreInc].size
                              == IRTypes[Opcode.PreIncS].size &&
                              IRTypes[Opcode.PreDec].size
                              == IRTypes[Opcode.PreIncS].size &&
                              IRTypes[Opcode.PreDecS].size);
                code += IRTypes[Opcode.PreIncS].size;
                goto Lnext;

            case Opcode.PreIncScope:        // a = ++s
                ax.inc = 1;
            Lprescope:
                a = locals + (code + 1).index;
                id = (code + 2).id;
                version(SCOPECACHING)
                {
                    si = SCOPECACHE_SI(id);
                    if(id is scopecache[si].id)
                    {
                        v = scopecache[si].v;
                        v.to(ax.d2, cc);
                        auto n = ax.d2 + ax.inc;
                        v.put(n);
                        a.put(n);
                    }
                    else
                    {
                        // v = scope_get(cc, scopex, id, o);
                        sta = cc.get(*id, o, v);
                        if (sta !is null)
                            goto Lthrow;
                        if(v)
                        {
                            v.to(ax.d2, cc);
                            auto n = ax.d2 + ax.inc;
                            v.put(n);
                            a.put(n);
                        }
                        else
                        {
                            sta = UndefinedVarError(cc, id.toString);
                            goto Lthrow;
                        }
                    }
                }
                else
                {
                    v = cc.get(id, o);
                    if(v)
                    {
                        v.toNumber(ax.d2, cc);
                        ax.d = ax.d2 + ax.inc;
                        a.put(ax.d);
                        v.put(ax.d);
                    }
                    else
                    {
                        sta = UndefinedVarError(s);
                        goto Lthrow;
                    }
                }
                static assert(IRTypes[Opcode.PreIncScope].size
                              == IRTypes[Opcode.PreDecScope].size);
                code += IRTypes[Opcode.PreIncScope].size;
                goto Lnext;

            case Opcode.PreDec:     // a = --b.c
                c = locals + (code + 3).index;
                c.to(ax.pk, cc);
                id = &ax.pk;
                goto Lpredec;
            case Opcode.PreDecS:    // a = --b.s
                id = (code + 3).id;
            Lpredec:
                ax.inc = -1;
                goto Lpre;

            case Opcode.PreDecScope:        // a = --s
                ax.inc = -1;
                goto Lprescope;

                /********************/

            case Opcode.PostInc:     // a = b.c++
                c = locals + (code + 3).index;
                c.to(ax.pk, cc);
                id = &ax.pk;
                goto Lpostinc;
            case Opcode.PostIncS:    // a = b.s++
                id = (code + 3).id;
            Lpostinc:
                assert (id !is null);
                a = locals + (code + 1).index;
                b = locals + (code + 2).index;
                sta = b.Get(*id, v, cc);
                if (sta !is null)
                    goto Lthrow;
                if(!v)
                    v = &undefined;
                v.to(ax.d, cc);
                a.put(ax.d + 1);
                b.Set(*id, *a, cc);
                a.put(ax.d);

                static assert(IRTypes[Opcode.PostInc].size
                              == IRTypes[Opcode.PostIncS].size);
                code += IRTypes[Opcode.PostIncS].size;
                goto Lnext;
            case Opcode.PostIncScope:        // a = s++
                id = (code + 2).id;
                // v = scope_get(cc, scopex, id, o);
                sta = cc.get(*id, o, v);
                if (sta !is null)
                    goto Lthrow;
                if(v && v != &undefined)
                {
                    a = locals + (code + 1).index;
                    v.to(ax.d, cc);
                    v.put(ax.d + 1);
                    a.put(ax.d);
                }
                else
                {
                    sta = ReferenceError(cc, id.toString);
                    goto Lthrow;
                }
                code += IRTypes[Opcode.PostIncScope].size;
                goto Lnext;

            case Opcode.PostDec:     // a = b.c--
                c = locals + (code + 3).index;
                c.to(ax.pk, cc);
                id = &ax.pk;
                goto Lpostdec;
            case Opcode.PostDecS:    // a = b.s--
                id = (code + 3).id;
            Lpostdec:
                assert (id !is null);
                a = locals + (code + 1).index;
                b = locals + (code + 2).index;
                sta = b.Get(*id, v, cc);
                if (sta !is null)
                    goto Lthrow;
                if(!v)
                    v = &undefined;
                v.to(ax.d, cc);
                a.put(ax.d - 1);
                b.Set(*id, *a, cc);
                a.put(ax.d);

                static assert(IRTypes[Opcode.PostDecS].size
                              == IRTypes[Opcode.PostDec].size);
                code += IRTypes[Opcode.PostDecS].size;
                goto Lnext;
            case Opcode.PostDecScope:        // a = s--
                id = (code + 2).id;
                sta = cc.get(*id, o, v);
                if (sta !is null)
                    goto Lthrow;
                if(v && v != &undefined)
                {
                    v.to(ax.d, cc);
                    a = locals + (code + 1).index;
                    v.put(ax.d - 1);
                    a.put(ax.d);
                }
                else
                {
                    sta = ReferenceError(cc, id.toString);
                    goto Lthrow;
                }
                code += IRTypes[Opcode.PostDecScope].size;
                goto Lnext;

            case Opcode.Del:     // a = delete b.c
            case Opcode.DelS:    // a = delete b.s
            {
                bool bo;
                b = locals + (code + 2).index;
                if(b.isPrimitive)
                    bo = true;
                else
                {
                    b.to(o, cc);
                    if(!o)
                    {
                        sta = cannotConvert(cc, b);
                        goto Lthrow;
                    }
                    if (code.opcode == Opcode.Del)
                    {
                        (locals + (code + 3).index).to(ax.pk, cc);
                        id = &ax.pk;
                    }
                    else
                        id = (code + 3).id;
                    if(o.implementsDelete)
                        bo = o.Delete(*id);
                    else
                        bo = !o.HasProperty(*id);
                }
                (locals + (code + 1).index).put(bo);

                static assert (IRTypes[Opcode.Del].size
                               == IRTypes[Opcode.DelS].size);
                code += IRTypes[Opcode.DelS].size;
                goto Lnext;
            }
            mixin("DelScope".op(q{    // a = delete s
                id = (code + 2).id;
                //o = scope_tos(scopex);		// broken way
                if (cc.get(*id, o, v).onError(sta))
                    goto Lthrow;
                else if (v is null || o is null)
                    ax.b = true;
                else if (o.implementsDelete())
                    ax.b = o.Delete(*id);
                else
                    ax.b = !o.HasProperty(*id);
                (locals + (code + 1).index).put(ax.b);

                /* ECMA requires that if one of the numeric operands is NAN,
                 * then the result of the comparison is false. D generates a
                 * correct test for NAN operands.
                 */
            }));

            case Opcode.CLT:         // a = (b <   c)
                a = locals + (code + 1).index;
                b = locals + (code + 2).index;
                c = locals + (code + 3).index;
                if(b.type == Value.Type.Number &&
                   c.type == Value.Type.Number)
                    ax.b = (b.number < c.number);
                else
                {
                    b.toPrimitive(*b, cc, Value.Type.Number);
                    c.toPrimitive(*c, cc, Value.Type.Number);
                    if(b.isString() && c.isString())
                    {
                        b.to(ax.s1, cc);
                        c.to(ax.s2, cc);

                        ax.b = cmp(ax.s1, ax.s2) < 0;
                    }
                    else
                    {
                        b.to(ax.d1, cc);
                        b.to(ax.d2, cc);
                        ax.b = ax.d1 < ax.d2;
                    }
                }
                a.put(ax.b);
                code += IRTypes[Opcode.CLT].size;
                goto Lnext;
            case Opcode.CLE:         // a = (b <=  c)
                a = locals + (code + 1).index;
                b = locals + (code + 2).index;
                c = locals + (code + 3).index;
                if(b.type == Value.Type.Number &&
                   c.type == Value.Type.Number)
                    ax.b = (b.number <= c.number);
                else
                {
                    b.toPrimitive(*b, cc, Value.Type.Number);
                    c.toPrimitive(*c, cc, Value.Type.Number);
                    if(b.isString() && c.isString())
                    {
                        b.to(ax.s1, cc);
                        c.to(ax.s2, cc);

                        ax.b = cmp(ax.s1, ax.s2) <= 0;
                    }
                    else
                    {
                        b.to(ax.d1, cc);
                        c.to(ax.d2, cc);

                        ax.b = ax.d1 <= ax.d2;
                    }
                }
                a.put(ax.b);
                code += IRTypes[Opcode.CLE].size;
                goto Lnext;
            case Opcode.CGT:         // a = (b >   c)
                a = locals + (code + 1).index;
                b = locals + (code + 2).index;
                c = locals + (code + 3).index;
                if(b.type == Value.Type.Number &&
                   c.type == Value.Type.Number)
                    ax.b = (b.number > c.number);
                else
                {
                    b.toPrimitive(*b, cc, Value.Type.Number);
                    c.toPrimitive(*c, cc, Value.Type.Number);
                    if(b.isString() && c.isString())
                    {
                        b.to(ax.s1, cc);
                        c.to(ax.s2, cc);

                        ax.b = cmp(ax.s1, ax.s2) > 0;
                    }
                    else
                    {
                        b.to(ax.d1, cc);
                        c.to(ax.d2, cc);

                        ax.b = ax.d1 > ax.d2;
                    }
                }
                a.put(ax.b);
                code += IRTypes[Opcode.CGT].size;
                goto Lnext;
            case Opcode.CGE:         // a = (b >=  c)
                a = locals + (code + 1).index;
                b = locals + (code + 2).index;
                c = locals + (code + 3).index;
                if(b.type == Value.Type.Number &&
                   c.type == Value.Type.Number)
                    ax.b = (b.number >= c.number);
                else
                {
                    b.toPrimitive(*b, cc, Value.Type.Number);
                    c.toPrimitive(*c, cc, Value.Type.Number);
                    if(b.isString() && c.isString())
                    {
                        b.to(ax.s1, cc);
                        c.to(ax.s2, cc);

                        ax.b = cmp(ax.s1, ax.s2) >= 0;
                    }
                    else
                    {
                        b.to(ax.d1, cc);
                        c.to(ax.d2, cc);
                        ax.b = ax.d1 >= ax.d2;
                    }
                }
                a.put(ax.b);
                code += IRTypes[Opcode.CGE].size;
                goto Lnext;
            case Opcode.CEq:         // a = (b ==  c)
            case Opcode.CNE:         // a = (b !=  c)
            {
                a = locals + (code + 1).index;
                b = locals + (code + 2).index;
                c = locals + (code + 3).index;
            Lagain:
                auto tx = b.type;
                auto ty = c.type;
                bool res;
                if      (tx == ty)
                {
                    if      (tx == Value.Type.Undefined ||
                             tx == Value.Type.Null)
                        res = true;
                    else if (tx == Value.Type.Number)
                    {
                        res = (b.number == c.number);
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
                    c.to(ax.d, cc);
                    c.put(ax.d);
                    goto Lagain;
                }
                else if (tx == Value.Type.String &&
                         ty == Value.Type.Number)
                {
                    b.to(ax.d, cc);
                    b.put(ax.d);
                    goto Lagain;
                }
                else if (tx == Value.Type.Boolean)
                {
                    b.to(ax.d, cc);
                    b.put(ax.d);
                    goto Lagain;
                }
                else if (ty == Value.Type.Boolean)
                {
                    c.to(ax.d, cc);
                    c.put(ax.d);
                    goto Lagain;
                }
                else if (ty == Value.Type.Object)
                {
                    c.toPrimitive(*c, cc);
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
                    b.toPrimitive(*b, cc);
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
                goto Lnext;
            }
            case Opcode.CID:         // a = (b === c)
            case Opcode.CNID:        // a = (b !== c)
            {
                a = locals + (code + 1).index;
                b = locals + (code + 2).index;
                c = locals + (code + 3).index;

                bool res;
                auto tx = b.type;
                auto ty = c.type;
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
                    else if (tx == Value.Type.BigInt)
                        res = ((*b.bigInt) == (*c.bigInt));
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
                goto Lnext;
            }
            case Opcode.JT:          // if (b) goto t
                b = locals + (code + 2).index;
                if (b.to(ax.b, cc).onError(sta))
                    goto Lthrow;

                if(ax.b)
                    code += (code + 1).offset;
                else
                    code += IRTypes[Opcode.JT].size;
                goto Lnext;

            case Opcode.JF:          // if (!b) goto t
                b = locals + (code + 2).index;
                if (b.to(ax.b, cc).onError(sta))
                    goto Lthrow;
                if(!ax.b)
                    code += (code + 1).offset;
                else
                    code += IRTypes[Opcode.JF].size;
                goto Lnext;

            case Opcode.JTB:         // if (b) goto t
                b = locals + (code + 2).index;
                if(b.dbool)
                    code += (code + 1).offset;
                else
                    code += IRTypes[Opcode.JTB].size;
                goto Lnext;

            case Opcode.JFB:         // if (!b) goto t
                b = locals + (code + 2).index;
                if(!b.dbool)
                    code += (code + 1).offset;
                else
                    code += IRTypes[Opcode.JFB].size;
                goto Lnext;

            case Opcode.Jmp:
                code += (code + 1).offset;
                goto Lnext;

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
                    goto Lnext;
                }
                else
                {
                    b.toPrimitive(*b, cc, Value.Type.Number);
                    c.toPrimitive(*c, cc, Value.Type.Number);
                    if(b.isString() && c.isString())
                    {
                        b.to(ax.s1, cc);
                        c.to(ax.s2, cc);

                        ax.b = cmp(ax.s1, ax.s2) < 0;
                    }
                    else
                    {
                        b.to(ax.d1, cc);
                        c.to(ax.d2, cc);
                        ax.b = ax.d1 < ax.d2;
                    }
                }
                if(!ax.b)
                    code += (code + 1).offset;
                else
                    code += IRTypes[Opcode.JLT].size;
                goto Lnext;
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
                    goto Lnext;
                }
                else
                {
                    b.toPrimitive(*b, cc, Value.Type.Number);
                    c.toPrimitive(*c, cc, Value.Type.Number);
                    if(b.isString() && c.isString())
                    {
                        b.to(ax.s1, cc);
                        c.to(ax.s2, cc);

                        ax.b = cmp(ax.s1, ax.s2) <= 0;
                    }
                    else
                    {
                        b.to(ax.d1, cc);
                        c.to(ax.d2, cc);
                        ax.b = ax.d1 <= ax.d2;
                    }
                }
                if(!ax.b)
                    code += (code + 1).offset;
                else
                    code += IRTypes[Opcode.JLE].size;
                goto Lnext;
            case Opcode.JLTC:        // if (b < constant) goto c
                b = locals + (code + 2).index;
                b.to(ax.d, cc);
                if(!(ax.d < *cast(double*)(code + 3)))
                    code += (code + 1).offset;
                else
                    code += IRTypes[Opcode.JLTC].size;
                goto Lnext;
            case Opcode.JLEC:        // if (b <= constant) goto c
                b = locals + (code + 2).index;
                b.to(ax.d, cc);
                if(!(ax.d <= *cast(double*)(code + 3)))
                    code += (code + 1).offset;
                else
                    code += IRTypes[Opcode.JLEC].size;
                goto Lnext;

            case Opcode.Iter:                // a = iter(b)
                a = locals + (code + 1).index;
                b = locals + (code + 2).index;
                b.to(o, cc);
                if(!o)
                {
                    sta = cannotConvert(cc, b);
                    goto Lthrow;
                }
                sta = o.putIterator(*a);
                if(sta)
                    goto Lthrow;
                code += IRTypes[Opcode.Iter].size;
                goto Lnext;

            case Opcode.Next:        // a, b.c, iter
                // if (!(b.c = iter)) goto a; iter = iter.next
                (locals + (code + 3).index).to(ax.pk, cc);
                id = &ax.pk;
                goto case_next;

            case Opcode.NextS:       // a, b.s, iter
                id = (code + 3).id;
            case_next:
                {
                    assert (id !is null);
                    auto iter = (locals + (code + 4).index).iter;
                    auto ppk = iter.next();
                    if(!ppk)
                        code += (code + 1).offset;
                    else
                    {
                        b = locals + (code + 2).index;
                        b.Set(*id, Value(*ppk), cc);

                        static assert (IRTypes[Opcode.Next].size
                                       == IRTypes[Opcode.NextS].size);
                        code += IRTypes[Opcode.Next].size;
                    }
                    goto Lnext;
                }
            case Opcode.NextScope:   // a, s, iter
            {
                id = (code + 2).id;
                auto iter = (locals + (code + 3).index).iter;
                auto ppk = iter.next();
                if(!ppk)
                    code += (code + 1).offset;
                else
                {
                    o = cc.getNonFakeObject;
                    auto val = Value(*ppk);
                    o.Set(*id, val, Property.Attribute.None, cc);
                    code += IRTypes[Opcode.NextScope].size;
                }
                goto Lnext;
            }
            case Opcode.Call:        // a = b.c(argc, argv)
                (locals + (code + 3).index).to(ax.pk, cc);
                id = &ax.pk;
                goto case_call;

            case Opcode.CallS:       // a = b.s(argc, argv)
                id = (code + 3).id;

            case_call:
                assert (id !is null);
                a = locals + (code + 1).index;
                b = locals + (code + 2).index;
                b.to(o, cc);
                if(!o)
                {
                    goto Lcallerror;
                }
                sta = o.Get(*id, v, cc);
                if (sta !is null)
                    goto Lthrow;
                if(!v)
                    goto Lcallerror;

                a.putVundefined();
                sta = v.Call(cc, o, *a, (locals + (code + 5).index)
                             [0 .. (code + 4).index]);

                debug(VERIFY)
                    assert(checksum == IR.verify(codestart));
                if(sta !is null)
                    goto Lthrow;

                static assert (IRTypes[Opcode.Call].size
                               == IRTypes[Opcode.CallS].size);
                code += IRTypes[Opcode.CallS].size;
                goto Lnext;

            Lcallerror:
                ax.s1 = id.toString;
                b.to(ax.s2, cc);
                sta = UndefinedNoCall3Error(
                    cc, b.type.to!string, ax.s2, ax.s1);
                if      (o is null){}
                else if (auto didyoumean = cc.searchSimilarWord(o, ax.s1))
                {
                    sta.message ~= ", did you mean \"" ~
                        didyoumean.join("\" or \"") ~ "\"?";
                }
                goto Lthrow;
            mixin("CallScope".op(q{   // a = s(argc, argv)
                id = (code + 2).id;
                mixin (fill!a);
                if (cc.get(*id, o, v).onError(sta))
                    goto Lthrow;

                if(v is null)
                {
                    //a = Dobject.RuntimeError(&errinfo, errmsgtbl[ERR_UNDEFINED_NO_CALL2], "property", s);
                    auto n = id.toString;
                    sta = UndefinedVarError(cc, n);
                    if (auto didyoumean = cc.searchSimilarWord(n))
                    {
                        sta.message ~= ", did you mean \"" ~
                            didyoumean.join("\" or \"") ~ "\"?";
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
                if(sta !is null)
                {
                    sta.addTrace(codestart, code);
                    cc.addTraceInfoTo(sta);
                    goto Lthrow;
                }
            }));

            case Opcode.CallV:   // v(argc, argv) = a
                a = locals + (code + 1).index;
                b = locals + (code + 2).index;
                b.to(o, cc);
                if(!o)
                {
                    b.to(ax.s, cc);
                    sta = UndefinedNoCall2Error(cc, b.type.to!string, ax.s);
                    goto Lthrow;
                }
                a.putVundefined();
                sta = o.Call(cc, o, *a,
                             (locals + (code + 4).index)
                             [0 .. (code + 3).index]);
                if(sta !is null)
                    goto Lthrow;
                code += IRTypes[Opcode.CallV].size;
                goto Lnext;

            case Opcode.PutCall:        // b.c(argc, argv) = a
                (locals + (code + 3).index).to(ax.pk, cc);
                id = &ax.pk;
                goto case_putcall;

            case Opcode.PutCallS:       //  b.s(argc, argv) = a
                id = (code + 3).id;

            case_putcall:
                assert (id !is null);

                a = locals + (code + 1).index;
                b = locals + (code + 2).index;
                b.to(o, cc);
                if(!o)
                    goto Lcallerror;
                //v = o.GetLambda(s, Value.calcHash(s));
                sta = o.Get(*id, v, cc);
                if (sta !is null)
                    goto Lthrow;
                if(v is null)
                    goto Lcallerror;
                //writef("calling... '%s'\n", v.toString());
                v.to(o, cc);
                if(o is null)
                {
                    sta = CannotAssignTo2Error(cc, b.type.to!string,
                                               id.toString);
                    goto Lthrow;
                }
                sta = o.put_Value(cc, *a, (locals + (code + 5).index)
                                  [0 .. (code + 4).argc]);
                if(sta !is null)
                    goto Lthrow;

                static assert (IRTypes[Opcode.PutCall].size
                               == IRTypes[Opcode.PutCallS].size);
                code += IRTypes[Opcode.PutCallS].size;
                goto Lnext;

            case Opcode.PutCallScope:   // a = s(argc, argv)
                id = (code + 2).id;
                sta = cc.get(*id, o, v);
                if (sta !is null)
                    goto Lthrow;
                if(v is null)
                {
                    sta = UndefinedNoCall2Error(cc, "property",
                                                id.toString);
                    goto Lthrow;
                }
                v.to(o, cc);
                if(o is null)
                {
                    sta = CannotAssignToError(cc, id.toString);
                    goto Lthrow;
                }
                a = locals + (code + 1).index;
                c = locals + (code + 4).index;
                sta = o.put_Value(cc, *a, c[0 .. (code + 3).argc]);
                if(sta)
                    goto Lthrow;
                code += IRTypes[Opcode.PutCallScope].size;
                goto Lnext;

            case Opcode.PutCallV:        // v(argc, argv) = a
                b = locals + (code + 2).index;
                b.to(o, cc);
                if(o is null)
                {
                    b.to(ax.s, cc);
                    sta = UndefinedNoCall2Error(cc, b.type.to!string, ax.s);
                    goto Lthrow;
                }
                a = locals + (code + 1).index;
                c = locals + (code + 4).index;
                sta = o.put_Value(cc, *a, c[0 .. (code + 3).argc]);
                if(sta !is null)
                    goto Lthrow;
                code += IRTypes[Opcode.PutCallV].size;
                goto Lnext;

            case Opcode.New: // a = new b(argc, argv)
                a = locals + (code + 1).index;
                b = locals + (code + 2).index;
                a.putVundefined();
                c = locals + (code + 4).index;
                sta = b.Construct(cc, *a, c[0 .. (code + 3).argc]);
                debug(VERIFY)
                    assert(checksum == IR.verify(codestart));
                if(sta !is null)
                    goto Lthrow;
                code += IRTypes[Opcode.New].size;
                goto Lnext;

            case Opcode.Push:
                SCOPECACHE_CLEAR();
                a = locals + (code + 1).index;
                a.to(o, cc);
                if(!o)
                {
                    sta = cannotConvert(cc, a);
                    goto Lthrow;
                }
                cc.push(o);
                code += IRTypes[Opcode.Push].size;
                goto Lnext;

            case Opcode.Pop:
                SCOPECACHE_CLEAR();
                o = cc.pop;
                // If it's a Finally, we need to execute
                // the finally block
                code += IRTypes[Opcode.Pop].size;

                // test could be eliminated with virtual func
                if(auto fin = cast(Finally)o)
                {
                    callFinally(fin);
                    debug(VERIFY)
                        assert(checksum == IR.verify(codestart));
                }
                goto Lnext;

            case Opcode.FinallyRet:
                assert(finallyStack.length);
                code = finallyStack[$-1];
                finallyStack = finallyStack[0..$-1];
                goto Lnext;

            case Opcode.Ret:
                // version(SCOPECACHE_LOG)
                //     printf("scopecache_cnt = %d\n", scopecache_cnt);
                return null;

            case Opcode.RetExp:
                a = locals + (code + 1).index;
                sta = a.checkReference(cc);
                if (sta !is null)
                    goto Lthrow;
                ret = *a;

                return null;

            mixin("ImpRet".op(q{
                mixin (fill!a);
                if (a.checkReference(cc).onError(sta))
                    goto Lthrow;
                ret = *a;
            }));

            case Opcode.Throw:
                mixin (fill!a);
                sta = new Derror(*a);

            Lthrow:
                assert(sta !is null);
                sta.addTrace(codestart, code);
                if (unwindStack(sta).onError(sta))
                {
                    sta.addTrace(codestart, code);
                    return sta;
                }
                goto Lnext;
            case Opcode.TryCatch:
            {
                SCOPECACHE_CLEAR();
                auto offset = (code - codestart) + (code + 1).offset;
                id = (code + 2).id;
                cc.push(new Catch(offset, id));
                code += IRTypes[Opcode.TryCatch].size;
                goto Lnext;
            }
            case Opcode.TryFinally:
                SCOPECACHE_CLEAR();
                cc.push(new Finally(code + (code + 1).offset));
                code += IRTypes[Opcode.TryFinally].size;
                goto Lnext;

            case Opcode.Assert:
            {
                version(all)  // Not supported under some com servers
                {
                    auto linnum = code.opcode.linnum;
                    sta = AssertError(cc, linnum);
                    goto Lthrow;
                }
                else
                {
                    RuntimeErrorx(ERR_ASSERT, (code + 1).index);
                    code += IRTypes[Opcode.Assert].size;
                    goto Lnext;
                }
            }

            case Opcode.Import:
            {
//##############################################################################
//######                      CONSTRUCTION FIELD                          ######
//##############################################################################
                // import 'hoge.ds'
                assert ((code + 2).value.isString);
                auto name = (code + 2).value.text;
                auto fd = cast(FunctionDefinition)(code + 3).fd;
                auto newrealm = new DmoduleRealm(
                    name, cc.realm.modulePool, fd, cc.strictMode);
                if (newrealm.Call(cc, null, *(locals + (code + 1).index), null)
                    .onError(sta))
                    goto Lthrow;
                // (locals + (code + 1).index).put(newrealm);

                code += IRTypes[Opcode.Import].size;
                goto Lnext;
//##############################################################################
//##############################################################################
//##############################################################################
            }
            case Opcode.End:
                code += IRTypes[Opcode.End].size;
                break;
            } // the end of the final switch.
        }
        catch (Throwable t)
        {
            auto msg = Value("UnknownError : " ~ typeid(t).name);
            sta = new Derror(t, msg);

            if (unwindStack(sta).onError(sta))
                return sta;
            else goto retry;
        }

        ret.putVundefined();
        return null;
    }

    /*********************************
     * Give size of opcode.
     */
    static @safe pure
    size_t size(in Opcode opcode)
    {
        static @safe @nogc pure nothrow
            size_t sizeOf(T)(){ return T.size; }
        return IRTypeDispatcher!sizeOf(opcode);
    }

    /*******************************************
     * This is a 'disassembler' for our interpreted code.
     * Useful for debugging.
     */

    debug static void toBuffer(size_t address, const(IR)* code,
                               scope void delegate(in char[]) sink)
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
        sink(IRTypeDispatcher!proc(code.opcode, address, code));
    }

    debug static
    void dump(const(IR)* code, scope void delegate(in char[]) sink)
    {
        import std.format: format;
        import std.range: take, repeat;
        import std.conv: to;

        auto codestart = code;

        for(;; )
        {
            sink(format("% 4d[%04d]:", code.opcode.linnum,
                        cast(size_t)(code - codestart)));
            toBuffer(code - codestart, code, sink);
            sink("\n");
            if(code.opcode == Opcode.End)
                break;
            code += size(code.opcode);
        }
    }

    /***************************************
     * Verify that it is a correct sequence of code.
     * Useful for isolating memory corruption bugs.
     */
    debug static uint verify(const(IR)* codestart, size_t linnum = __LINE__)
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
    import dmdscript.value: Value;
    import dmdscript.callcontext: CallContext;

    // This is so scope_get() will skip over these objects
    override Derror Get(in PropertyKey, out Value*, CallContext*) const
    {
        return null;
    }

    // This is so we can distinguish between a real Dobject
    // and these fakers
    override string getTypeof() const
    {
        return null;
    }

    size_t offset;        // offset of CatchBlock
    Identifier name;      // catch identifier

    this(size_t offset, Identifier name)
    {
        super(null);
        this.offset = offset;
        this.name = name;
    }
}

//------------------------------------------------------------------------------
class Finally : Dobject
{
    import dmdscript.value: Value;
    import dmdscript.opcodes: IR;
    import dmdscript.drealm: Drealm;

    override Derror Get(in PropertyKey, out Value*, CallContext*) const
    {
        return null;
    }

    override string getTypeof() const
    {
        return null;
    }

    const(IR*) finallyblock;    // code for FinallyBlock

    this(const(IR*) finallyblock)
    {
        super(null);
        this.finallyblock = finallyblock;
    }
}


//------------------------------------------------------------------------------
/*
Helper function for Values that cannot be converted to Objects.
 */
Derror cannotConvert(CallContext* cc, Value* b)
{
    import std.conv : to;
    Derror sta;

    if      (b.isEmpty)
    {
        sta = UndefinedVarError(cc, b.text);
    }
    else if (b.isUndefinedOrNull)
    {
        sta = CannotConvertToObject4Error(cc, b.type.to!string);
    }
    else
    {
        string s;
        b.to(s, cc);
        sta = CannotConvertToObject2Error(cc, b.type.to!string, s);
    }
    return sta;
}

//------------------------------------------------------------------------------
// mixin sugar
// a = locals + (code + 1).index;
// b = locals + (code + 2).index;
// c = locals + (code + 3).index;
template fill(V...)
{
    import std.conv: to;

    static if (0 == V.length)
        enum fill = "";
    else
        enum fill = V[0].stringof ~ " = locals + (code + " ~
            (V[0].stringof[$-1] - 'a' + 1).to!string ~ ").index;" ~
            fill!(V[1..$]);
}

// vb.to(ax.s1, cc);
// vc.to(ax.s2, cc);
string from(alias V)(string To)
{
    return "if(" ~ V.stringof ~ ".to(" ~ To ~
        ", cc).onError(sta)) goto Lthrow;";
}


// code += IRTypes[Opcode.ImpRet].size;
// goto Lnext;
string goNext(string C)
{
    return " code += IRTypes[Opcode." ~ C ~ "].size; goto Lnext;";
}

string op(string OP, string bdy)
{
    return "case Opcode." ~ OP ~ ":" ~ bdy ~ goNext(OP);
}
