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
    static DError* call(Drealm realm, Dobject othis, const(IR)* code,
                        out Value ret, Value* locals)
    {
        import std.array : join;
        import std.conv : to;
        import std.string : cmp;

        const(IR*) codestart = code;
        Value* a;
        Value* b;
        Value* c;
        Value* v;
        Dobject o;
        DError* sta;
        PropertyKey pk;
        Identifier id;
        double inc;

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

        DError* unwindStack(DError* err)
        {
            // assert(scopex.length && scopex[0] !is null,
            //        "Null in scopex, Line " ~ code.opcode.linnum.to!string);
            assert (err !is null);

            for(auto counter = 0;; ++counter)
            {
                // pop entry off scope chain
                if      ((o = realm.popScope) is null)
                {
                    ret.putVundefined;
                    return err;
                }
                else if (auto ca = cast(Catch)o)
                {
                    o = realm.dObject();
                    version(JSCRIPT_CATCH_BUG)
                    {
                        PutValue(realm, ca.name, &err.entity);
                    }
                    else
                    {
                        o.Set(*ca.name, err.entity,
                              Property.Attribute.DontDelete, realm);
                    }
                    realm.push(o);
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
            int si;
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

        loop: for(;; )
        {
            // Lnext:
            if(realm.isInterrupting) // see if script was interrupted
                break loop;

            try
            {
                assert(code.opcode <= Opcode.max,
                       "Unrecognized IR instruction " ~ code.opcode.to!string);

                final switch(code.opcode)
                {
                case Opcode.Error:
                    assert(0);

                case Opcode.Nop:
                    code += IRTypes[Opcode.Nop].size;
                    break;

                case Opcode.Get:                 // a = b.c
                {
                    int i32;
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    o = b.toObject(realm);
                    if(!o)
                    {
                        sta = cannotConvert(realm, b);
                        goto Lthrow;
                    }
                    c = locals + (code + 3).index;
                    v = o.Get(c.toPropertyKey, realm);

                    if(!v)
                        v = &undefined;
                    *a = *v;
                    code += IRTypes[Opcode.Get].size;
                    break;
                }
                case Opcode.Put:                 // b.c = a
                {
                    int i32;
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
                    sta = b.Set(c.toPropertyKey, *a, realm);
                    if(sta)
                        goto Lthrow;
                    code += IRTypes[Opcode.Put].size;
                    break;
                }
                case Opcode.GetS:                // a = b.s
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    id = (code + 3).id;
                    o = b.toObject(realm);
                    if(!o)
                    {
                        sta = CannotConvertToObject3Error(realm,
                            b.type.to!string, b.toString(realm),
                            id.toString);
                        goto Lthrow;
                    }
                    v = o.Get(*id, realm);
                    if(!v)
                    {
                        v = &undefined;
                    }
                    *a = *v;
                    code += IRTypes[Opcode.GetS].size;
                    break;
                case Opcode.CheckRef: // s
                    id = (code+1).id;
                    if (realm.get(*id) is null)
                    {
                        sta = UndefinedVarError(realm, id.toString);
                        goto Lthrow;
                    }
                    code += IRTypes[Opcode.CheckRef].size;
                    break;
                case Opcode.GetScope:            // a = s
                    a = locals + (code + 1).index;
                    id = (code + 2).id;
                    version(SCOPECACHING)
                    {
                        si = SCOPECACHE_SI(id);
                        if(id is scopecache[si].id)
                        {
                            version(SCOPECACHE_LOG)
                                scopecache_cnt++;
                            *a = *scopecache[si].v;
                            code += IRTypes[Opcode.GetScope].size;
                            break;
                        }
                    }

                    // v = scope_get(cc, scopex, id);
                    v = realm.get(*id);
                    if(v is null)
                    {
                        // if (realm.strictMode)
                        // {
                        //     sta = CannotAssignToError(realm, id.toString);
                        //     goto Lthrow;
                        // }

                        realm.set(*id, undefined);
                        v = signalingUndefined(id.toString);
                        // realm.set(*id, *v);
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
                    code += IRTypes[Opcode.GetScope].size;
                    break;

                case Opcode.PutGetter:
                    assert (0, "not implemented yet");
                    // code += IRTypes[Opcode.PutGetter].size;
                    // break;
                case Opcode.PutGetterS:
                {
                    a = locals + (code + 1).index;
                    auto f = cast(Dfunction)a.toObject(realm);
                    if (f is null)
                    {
                        sta = cannotConvert(realm, a);
                        goto Lthrow;
                    }
                    b = locals + (code + 2).index;
                    o = b.toObject(realm);
                    if(o is null)
                    {
                        sta = cannotConvert(realm, b);
                        goto Lthrow;
                    }
                    if (!o.SetGetter(*(code+3).id, f, Property.Attribute.None))
                    {
                        sta = CannotPutError(realm); // !!!!!!!!!!!!!!!!!!!!!!!!!!
                        goto Lthrow;
                    }
                    code += IRTypes[Opcode.PutGetterS].size;
                    break;
                }
                case Opcode.PutSetter:
                    assert (0, "not implemented yet");
                    // code += IRTypes[Opcode.PutSetter].size;
                    // break;
                case Opcode.PutSetterS:
                {
                    a = locals + (code + 1).index;
                    auto f = cast(Dfunction)a.toObject(realm);
                    if (f is null)
                    {
                        sta = cannotConvert(realm, a);
                        goto Lthrow;
                    }
                    b = locals + (code + 2).index;
                    o = b.toObject(realm);
                    if(!o)
                    {
                        sta = cannotConvert(realm, b);
                        goto Lthrow;
                    }
                    if (!o.SetSetter(*(code+3).id, f, Property.Attribute.None))
                    {
                        sta = CannotPutError(realm); // !!!!!!!!!!!!!!!!!!!!!!!!!!!
                        goto Lthrow;
                    }
                    code += IRTypes[Opcode.PutSetterS].size;
                    break;
                }
                case Opcode.AddAsS:              // a = (b.c += a)
                    c = locals + (code + 3).index;
                    pk = c.toPropertyKey;
                    id = &pk;
                    goto Laddass;

                case Opcode.AddAsSS:             // a = (b.s += a)
                    id = (code + 3).id;

                    Laddass:
                    assert (id !is null);

                    b = locals + (code + 2).index;
                    v = b.Get(*id, realm);
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
                            v = realm.get(*id);
                    }
                    else
                    {
                        v = realm.get(*id);
                    }
                    Laddass2:
                    a = locals + (code + 1).index;
                    if(!v)
                    {
                        sta = UndefinedVarError(realm, id.toString);
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
                        v.toPrimitive(realm, *v);
                        a.toPrimitive(realm, *a);
                        if(v.isString)
                        {
                            if (a.isUndefined)
                                a.put(v.text);
                            else
                                a.put(v.text ~ a.toString(realm));
                        }
                        else if(a.isString)
                        {
                            if (!v.isUndefined)
                                a.put(v.toString(realm) ~ a.text);
                        }
                        else
                        {
                            a.put(a.toNumber(realm) + v.toNumber(realm));
                        }
                        *v = *a; //full copy
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
                    o = b.toObject(realm);
                    if(!o)
                    {
                        sta = cannotConvert(realm, b);
                        goto Lthrow;
                    }
                    sta = o.Set(*(code + 3).id, *a,
                                Property.Attribute.None, realm);
                    if(sta !is null)
                        goto Lthrow;
                    code += IRTypes[Opcode.PutS].size;
                    break;

                case Opcode.PutScope:            // s = a
                    a = locals + (code + 1).index;
                    sta = a.checkReference(realm);
                    if (sta !is null)
                        goto Lthrow;
                    sta = realm.set(*(code + 2).id, *a);
                    if (sta !is null)
                        goto Lthrow;
                    code += IRTypes[Opcode.PutScope].size;
                    break;

                case Opcode.PutDefault:              // b = a
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    o = b.toObject(realm);
                    if(!o)
                    {
                        sta = CannotAssignError(realm, a.type.to!string,
                                                b.type.to!string);
                        goto Lthrow;
                    }
                    sta = o.PutDefault(realm, *a);
                    if(sta)
                        goto Lthrow;
                    code += IRTypes[Opcode.PutDefault].size;
                    break;

                case Opcode.PutThis:             // id = a
                    o = realm.getNonFakeObject;
                    id = (code + 2).id;
                    a = locals + (code + 1).index;
                    assert(o);
                    if(o.HasProperty(*id))
                        sta = o.Set(*id, *a,
                                    Property.Attribute.DontDelete, realm);
                    else
                        sta = realm.setThis(*id, *a,
                                         Property.Attribute.DontDelete);
                    if (sta !is null)
                        goto Lthrow;
                    code += IRTypes[Opcode.PutThis].size;
                    break;

                case Opcode.PutThisLocal:
                    assert (0, "not implemented yet.");
                case Opcode.PutThisLocalConst:
                    assert (0, "not implemented yet.");

                case Opcode.Mov:                 // a = b
                    *(locals + (code + 1).index) = *(locals + (code + 2).index);
                    code += IRTypes[Opcode.Mov].size;
                    break;

                case Opcode.String:              // a = "string"
                    assert ((code + 2).value.isString);
                    (locals + (code + 1).index).put((code + 2).value.text);
                    code += IRTypes[Opcode.String].size;
                    break;

                case Opcode.Object:              // a = object
                {
                    auto fd = cast(FunctionDefinition)(code+2).fd;
                    auto fobject = new DdeclaredFunction(
                        realm, fd, realm.scopes.dup);
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
                    v = othis.Get(*(code + 2).id, realm);
                    if(!v)
                        v = &undefined;
                    *a = *v;
                    code += IRTypes[Opcode.ThisGet].size;
                    break;

                case Opcode.Neg:                 // a = -a
                    a = locals + (code + 1).index;
                    a.put(-a.toNumber(realm));
                    code += IRTypes[Opcode.Neg].size;
                    break;

                case Opcode.Pos:                 // a = a
                    a = locals + (code + 1).index;
                    a.put(a.toNumber(realm));
                    code += IRTypes[Opcode.Pos].size;
                    break;

                case Opcode.Com:                 // a = ~a
                    a = locals + (code + 1).index;
                    a.put(~a.toInt32(realm));
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
                    a.put(a.getTypeof);
                    code += IRTypes[Opcode.Typeof].size;
                    break;

                case Opcode.Instance:        // a = b instanceof c
                    // ECMA v3 11.8.6
                    c = locals + (code + 3).index;
                    if(c.isPrimitive)
                    {
                        sta = RhsMustBeObjectError(realm, "instanceof",
                                                   c.type.to!string);
                        goto Lthrow;
                    }
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    sta = c.toObject(realm).HasInstance(realm, *a, *b);
                    if(sta)
                        goto Lthrow;
                    code += IRTypes[Opcode.Instance].size;
                    break;
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

                        b.toPrimitive(realm, *vb);
                        c.toPrimitive(realm, *vc);

                        if(vb.isString || vc.isString)
                            a.put(vb.toString(realm) ~ vc.toString(realm));
                        else
                            a.put(vb.toNumber(realm) + vc.toNumber(realm));
                    }

                    code += IRTypes[Opcode.Add].size;
                    break;

                case Opcode.Sub:                 // a = b - c
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
                    a.put(b.toNumber(realm) - c.toNumber(realm));
                    code += 4;
                    break;

                case Opcode.Mul:                 // a = b * c
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
                    a.put(b.toNumber(realm) * c.toNumber(realm));
                    code += IRTypes[Opcode.Mul].size;
                    break;

                case Opcode.Div:                 // a = b / c
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;

                    a.put(b.toNumber(realm) / c.toNumber(realm));
                    code += IRTypes[Opcode.Div].size;
                    break;

                case Opcode.Mod:                 // a = b % c
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
                    a.put(b.toNumber(realm) % c.toNumber(realm));
                    code += IRTypes[Opcode.Mod].size;
                    break;

                case Opcode.ShL:                 // a = b << c
                {
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
                    auto i32 = b.toInt32(realm);
                    auto u32 = c.toUint32(realm) & 0x1F;
                    i32 <<= u32;
                    a.put(i32);
                    code += IRTypes[Opcode.ShL].size;
                    break;
                }
                case Opcode.ShR:                 // a = b >> c
                {
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
                    auto i32 = b.toInt32(realm);
                    auto u32 = c.toUint32(realm) & 0x1F;
                    i32 >>= cast(int)u32;
                    a.put(i32);
                    code += IRTypes[Opcode.ShR].size;
                    break;
                }
                case Opcode.UShR:                // a = b >>> c
                {
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
                    auto i32 = b.toUint32(realm);
                    auto u32 = c.toUint32(realm) & 0x1F;
                    u32 = (cast(uint)i32) >> u32;
                    a.put(u32);
                    code += IRTypes[Opcode.UShR].size;
                    break;
                }
                case Opcode.And:         // a = b & c
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
                    a.put(b.toInt32(realm) & c.toInt32(realm));
                    code += IRTypes[Opcode.And].size;
                    break;

                case Opcode.Or:          // a = b | c
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
                    a.put(b.toInt32(realm) | c.toInt32(realm));
                    code += IRTypes[Opcode.Or].size;
                    break;

                case Opcode.Xor:         // a = b ^ c
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
                    a.put(b.toInt32(realm) ^ c.toInt32(realm));
                    code += IRTypes[Opcode.Xor].size;
                    break;
                case Opcode.In:          // a = b in c
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
                    pk = b.toPropertyKey;
                    o = c.toObject(realm);
                    if(!o)
                        throw RhsMustBeObjectError.toThrow(
                            "in", c.toString(realm));

                    a.put(o.HasProperty(pk));
                    code += IRTypes[Opcode.In].size;
                    break;

                /********************/

                case Opcode.PreInc:     // a = ++b.c
                    c = locals + (code + 3).index;
                    pk = c.toPropertyKey;
                    id = &pk;
                    goto Lpreinc;
                case Opcode.PreIncS:    // a = ++b.s
                    id = (code + 3).id;
                    Lpreinc:
                    inc = 1;
                    Lpre:
                    assert (id !is null);

                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    v = b.Get(*id, realm);
                    if(!v)
                        v = &undefined;
                    a.put(v.toNumber(realm) + inc);
                    b.Set(*id, *a, realm);

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
                    version(SCOPECACHING)
                    {
                        si = SCOPECACHE_SI(id);
                        if(id is scopecache[si].id)
                        {
                            v = scopecache[si].v;
                            auto n = v.toNumber(realm) + inc;
                            v.put(n);
                            a.put(n);
                        }
                        else
                        {
                            // v = scope_get(cc, scopex, id, o);
                            v = realm.get(*id, o);
                            if(v)
                            {
                                auto n = v.toNumber(realm) + inc;
                                v.put(n);
                                a.put(n);
                            }
                            else
                            {
                                sta = UndefinedVarError(realm, id.toString);
                                goto Lthrow;
                            }
                        }
                    }
                    else
                    {
                        v = realm.get(id, o);
                        if(v)
                        {
                            auto n = v.toNumber(realm) + inc;
                            a.put(n);
                            v.put(n);
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
                    break;

                case Opcode.PreDec:     // a = --b.c
                    c = locals + (code + 3).index;
                    pk = c.toPropertyKey;
                    id = &pk;
                    goto Lpredec;
                case Opcode.PreDecS:    // a = --b.s
                    id = (code + 3).id;
                    Lpredec:
                    inc = -1;
                    goto Lpre;

                case Opcode.PreDecScope:        // a = --s
                    inc = -1;
                    goto Lprescope;

                /********************/

                case Opcode.PostInc:     // a = b.c++
                    c = locals + (code + 3).index;
                    pk = c.toPropertyKey;
                    id = &pk;
                    goto Lpostinc;
                case Opcode.PostIncS:    // a = b.s++
                {
                    id = (code + 3).id;
                    Lpostinc:
                    assert (id !is null);
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    v = b.Get(*id, realm);
                    if(!v)
                        v = &undefined;
                    auto n = v.toNumber(realm);
                    a.put(n + 1);
                    b.Set(*id, *a, realm);
                    a.put(n);

                    static assert(IRTypes[Opcode.PostInc].size
                                  == IRTypes[Opcode.PostIncS].size);
                    code += IRTypes[Opcode.PostIncS].size;
                    break;
                }
                case Opcode.PostIncScope:        // a = s++
                    id = (code + 2).id;
                    // v = scope_get(cc, scopex, id, o);
                    v = realm.get(*id, o);
                    if(v && v != &undefined)
                    {
                        a = locals + (code + 1).index;
                        auto n = v.toNumber(realm);
                        v.put(n + 1);
                        a.put(n);
                    }
                    else
                    {
                        sta = ReferenceError(realm, id.toString);
                        goto Lthrow;
                    }
                    code += IRTypes[Opcode.PostIncScope].size;
                    break;

                case Opcode.PostDec:     // a = b.c--
                    c = locals + (code + 3).index;
                    pk = c.toPropertyKey;
                    id = &pk;
                    goto Lpostdec;
                case Opcode.PostDecS:    // a = b.s--
                {
                    id = (code + 3).id;
                    Lpostdec:
                    assert (id !is null);
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    v = b.Get(*id, realm);
                    if(!v)
                        v = &undefined;
                    auto n = v.toNumber(realm);
                    a.put(n - 1);
                    b.Set(*id, *a, realm);
                    a.put(n);

                    static assert(IRTypes[Opcode.PostDecS].size
                                  == IRTypes[Opcode.PostDec].size);
                    code += IRTypes[Opcode.PostDecS].size;
                    break;
                }
                case Opcode.PostDecScope:        // a = s--
                    id = (code + 2).id;
                    v = realm.get(*id, o);
                    if(v && v != &undefined)
                    {
                        auto n = v.toNumber(realm);
                        a = locals + (code + 1).index;
                        v.put(n - 1);
                        a.put(n);
                    }
                    else
                    {
                        sta = ReferenceError(realm, id.toString);
                        goto Lthrow;
                    }
                    code += IRTypes[Opcode.PostDecScope].size;
                    break;

                case Opcode.Del:     // a = delete b.c
                case Opcode.DelS:    // a = delete b.s
                {
                    bool bo;
                    b = locals + (code + 2).index;
                    if(b.isPrimitive)
                        bo = true;
                    else
                    {
                        o = b.toObject(realm);
                        if(!o)
                        {
                            sta = cannotConvert(realm, b);
                            goto Lthrow;
                        }
                        if (code.opcode == Opcode.Del)
                        {
                            pk = (locals + (code + 3).index).toPropertyKey;
                            id = &pk;
                        }
                        else
                            id = (code + 3).id;
                        if(o.implementsDelete)
                            bo = !!o.Delete(*id);
                        else
                            bo = !o.HasProperty(*id);
                    }
                    (locals + (code + 1).index).put(bo);

                    static assert (IRTypes[Opcode.Del].size
                                   == IRTypes[Opcode.DelS].size);
                    code += IRTypes[Opcode.DelS].size;
                    break;
                }
                case Opcode.DelScope:    // a = delete s
                {
                    bool bo;
                    id = (code + 2).id;
                    //o = scope_tos(scopex);		// broken way
                    // if(!scope_get(cc, scopex, id, o))
                    if (!realm.get(*id, o))
                        bo = true;
                    else if(o.implementsDelete())
                        bo = !!o.Delete(*id);
                    else
                        bo = !o.HasProperty(*id);
                    (locals + (code + 1).index).put(bo);
                    code += IRTypes[Opcode.DelScope].size;
                    break;
                }
                /* ECMA requires that if one of the numeric operands is NAN,
                 * then the result of the comparison is false. D generates a
                 * correct test for NAN operands.
                 */

                case Opcode.CLT:         // a = (b <   c)
                {
                    bool res;
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
                    if(b.type == Value.Type.Number &&
                       c.type == Value.Type.Number)
                        res = (b.number < c.number);
                    else
                    {
                        b.toPrimitive(realm, *b, Value.Type.Number);
                        c.toPrimitive(realm, *c, Value.Type.Number);
                        if(b.isString() && c.isString())
                        {
                            string x = b.toString(realm);
                            string y = c.toString(realm);

                            res = cmp(x, y) < 0;
                        }
                        else
                            res = b.toNumber(realm) < c.toNumber(realm);
                    }
                    a.put(res);
                    code += IRTypes[Opcode.CLT].size;
                    break;
                }
                case Opcode.CLE:         // a = (b <=  c)
                {
                    bool res;
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
                    if(b.type == Value.Type.Number &&
                       c.type == Value.Type.Number)
                        res = (b.number <= c.number);
                    else
                    {
                        b.toPrimitive(realm, *b, Value.Type.Number);
                        c.toPrimitive(realm, *c, Value.Type.Number);
                        if(b.isString() && c.isString())
                        {
                            string x = b.toString(realm);
                            string y = c.toString(realm);

                            res = cmp(x, y) <= 0;
                        }
                        else
                            res = b.toNumber(realm) <= c.toNumber(realm);
                    }
                    a.put(res);
                    code += IRTypes[Opcode.CLE].size;
                    break;
                }
                case Opcode.CGT:         // a = (b >   c)
                {
                    bool res;
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
                    if(b.type == Value.Type.Number &&
                       c.type == Value.Type.Number)
                        res = (b.number > c.number);
                    else
                    {
                        b.toPrimitive(realm, *b, Value.Type.Number);
                        c.toPrimitive(realm, *c, Value.Type.Number);
                        if(b.isString() && c.isString())
                        {
                            string x = b.toString(realm);
                            string y = c.toString(realm);

                            res = cmp(x, y) > 0;
                        }
                        else
                            res = b.toNumber(realm) > c.toNumber(realm);
                    }
                    a.put(res);
                    code += IRTypes[Opcode.CGT].size;
                    break;
                }
                case Opcode.CGE:         // a = (b >=  c)
                {
                    bool res;
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    c = locals + (code + 3).index;
                    if(b.type == Value.Type.Number &&
                       c.type == Value.Type.Number)
                        res = (b.number >= c.number);
                    else
                    {
                        b.toPrimitive(realm, *b, Value.Type.Number);
                        c.toPrimitive(realm, *c, Value.Type.Number);
                        if(b.isString() && c.isString())
                        {
                            string x = b.toString(realm);
                            string y = c.toString(realm);

                            res = cmp(x, y) >= 0;
                        }
                        else
                            res = b.toNumber(realm) >= c.toNumber(realm);
                    }
                    a.put(res);
                    code += IRTypes[Opcode.CGE].size;
                    break;
                }
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
                        c.put(c.toNumber(realm));
                        goto Lagain;
                    }
                    else if (tx == Value.Type.String &&
                             ty == Value.Type.Number)
                    {
                        b.put(b.toNumber(realm));
                        goto Lagain;
                    }
                    else if (tx == Value.Type.Boolean)
                    {
                        b.put(b.toNumber(realm));
                        goto Lagain;
                    }
                    else if (ty == Value.Type.Boolean)
                    {
                        c.put(c.toNumber(realm));
                        goto Lagain;
                    }
                    else if (ty == Value.Type.Object)
                    {
                        c.toPrimitive(realm, *c);
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
                        b.toPrimitive(realm, *b);
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
                }
                case Opcode.JT:          // if (b) goto t
                    b = locals + (code + 2).index;
                    if(b.toBoolean)
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
                {
                    bool res;
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
                        b.toPrimitive(realm, *b, Value.Type.Number);
                        c.toPrimitive(realm, *c, Value.Type.Number);
                        if(b.isString() && c.isString())
                        {
                            string x = b.toString(realm);
                            string y = c.toString(realm);

                            res = cmp(x, y) < 0;
                        }
                        else
                            res = b.toNumber(realm) < c.toNumber(realm);
                    }
                    if(!res)
                        code += (code + 1).offset;
                    else
                        code += IRTypes[Opcode.JLT].size;
                    break;
                }
                case Opcode.JLE:         // if (b <=  c) goto c
                {
                    bool res;
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
                        b.toPrimitive(realm, *b, Value.Type.Number);
                        c.toPrimitive(realm, *c, Value.Type.Number);
                        if(b.isString() && c.isString())
                        {
                            string x = b.toString(realm);
                            string y = c.toString(realm);

                            res = cmp(x, y) <= 0;
                        }
                        else
                            res = b.toNumber(realm) <= c.toNumber(realm);
                    }
                    if(!res)
                        code += (code + 1).offset;
                    else
                        code += IRTypes[Opcode.JLE].size;
                    break;
                }
                case Opcode.JLTC:        // if (b < constant) goto c
                    b = locals + (code + 2).index;
                    if(!(b.toNumber(realm) < *cast(double*)(code + 3)))
                        code += (code + 1).offset;
                    else
                        code += IRTypes[Opcode.JLTC].size;
                    break;
                case Opcode.JLEC:        // if (b <= constant) goto c
                    b = locals + (code + 2).index;
                    if(!(b.toNumber(realm) <= *cast(double*)(code + 3)))
                        code += (code + 1).offset;
                    else
                        code += IRTypes[Opcode.JLEC].size;
                    break;

                case Opcode.Iter:                // a = iter(b)
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    o = b.toObject(realm);
                    if(!o)
                    {
                        sta = cannotConvert(realm, b);
                        goto Lthrow;
                    }
                    sta = o.putIterator(*a);
                    if(sta)
                        goto Lthrow;
                    code += IRTypes[Opcode.Iter].size;
                    break;

                case Opcode.Next:        // a, b.c, iter
                    // if (!(b.c = iter)) goto a; iter = iter.next
                    pk = (locals + (code + 3).index).toPropertyKey;
                    id = &pk;
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
                        b.Set(*id, Value(*ppk), realm);

                        static assert (IRTypes[Opcode.Next].size
                                       == IRTypes[Opcode.NextS].size);
                        code += IRTypes[Opcode.Next].size;
                    }
                    break;
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
                        o = realm.getNonFakeObject;
                        auto val = Value(*ppk);
                        o.Set(*id, val, Property.Attribute.None, realm);
                        code += IRTypes[Opcode.NextScope].size;
                    }
                    break;
                }
                case Opcode.Call:        // a = b.c(argc, argv)
                    pk = (locals + (code + 3).index).toPropertyKey;
                    id = &pk;
                    goto case_call;

                case Opcode.CallS:       // a = b.s(argc, argv)
                    id = (code + 3).id;

                    case_call:
                    assert (id !is null);
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    o = b.toObject(realm);
                    if(!o)
                    {
                        goto Lcallerror;
                    }
                    v = o.Get(*id, realm);
                    if(!v)
                       goto Lcallerror;

                    a.putVundefined();
                    sta = v.Call(realm, o, *a, (locals + (code + 5).index)
                                 [0 .. (code + 4).index]);

                    debug(VERIFY)
                        assert(checksum == IR.verify(codestart));
                    if(sta !is null)
                        goto Lthrow;

                    static assert (IRTypes[Opcode.Call].size
                                   == IRTypes[Opcode.CallS].size);
                    code += IRTypes[Opcode.CallS].size;
                    break;

                    Lcallerror:
                    {
                        auto s = id.toString;
                        sta = UndefinedNoCall3Error(realm,
                            b.type.to!string, b.toString(realm), s);
                        if (auto didyoumean = realm.searchSimilarWord(o, s))
                        {
                            sta.addMessage(", did you mean \"" ~
                                           didyoumean.join("\" or \"") ~
                                           "\"?");
                        }
                        goto Lthrow;
                    }
                case Opcode.CallScope:   // a = s(argc, argv)
                    id = (code + 2).id;
                    a = locals + (code + 1).index;
                    v = realm.get(*id, o);

                    if(v is null)
                    {
                        //a = Dobject.RuntimeError(&errinfo, errmsgtbl[ERR_UNDEFINED_NO_CALL2], "property", s);
                        auto n = id.toString;
                        sta = UndefinedVarError(realm, n);
                        if (auto didyoumean = realm.searchSimilarWord(n))
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
                    sta = v.Call(realm, o, *a, (locals + (code + 4).index)
                                               [0 .. (code + 3).index]);

                    debug(VERIFY)
                        assert(checksum == IR.verify(codestart));
                    if(sta !is null)
                    {
                        sta.addTrace(codestart, code);
                        realm.addTraceInfoTo(sta);
                        goto Lthrow;
                    }
                    code += IRTypes[Opcode.CallScope].size;
                    break;

                case Opcode.CallV:   // v(argc, argv) = a
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    o = b.toObject(realm);
                    if(!o)
                    {
                        sta = UndefinedNoCall2Error(realm, b.type.to!string,
                                                    b.toString(realm));
                        goto Lthrow;
                    }
                    a.putVundefined();
                    sta = o.Call(realm, o, *a,
                                 (locals + (code + 4).index)
                                 [0 .. (code + 3).index]);
                    if(sta !is null)
                        goto Lthrow;
                    code += IRTypes[Opcode.CallV].size;
                    break;

                case Opcode.PutCall:        // b.c(argc, argv) = a
                    pk = (locals + (code + 3).index).toPropertyKey;
                    id = &pk;
                    goto case_putcall;

                case Opcode.PutCallS:       //  b.s(argc, argv) = a
                    id = (code + 3).id;

                    case_putcall:
                    assert (id !is null);

                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    o = b.toObject(realm);
                    if(!o)
                        goto Lcallerror;
                    //v = o.GetLambda(s, Value.calcHash(s));
                    v = o.Get(*id, realm);
                    if(v is null)
                        goto Lcallerror;
                    //writef("calling... '%s'\n", v.toString());
                    o = v.toObject(realm);
                    if(o is null)
                    {
                        sta = CannotAssignTo2Error(realm, b.type.to!string,
                                                   id.toString);
                        goto Lthrow;
                    }
                    sta = o.put_Value(realm, *a, (locals + (code + 5).index)
                                      [0 .. (code + 4).argc]);
                    if(sta !is null)
                        goto Lthrow;

                    static assert (IRTypes[Opcode.PutCall].size
                                   == IRTypes[Opcode.PutCallS].size);
                    code += IRTypes[Opcode.PutCallS].size;
                    break;

                case Opcode.PutCallScope:   // a = s(argc, argv)
                    id = (code + 2).id;
                    v = realm.get(*id, o);
                    if(v is null)
                    {
                        sta = UndefinedNoCall2Error(realm, "property",
                                                    id.toString);
                        goto Lthrow;
                    }
                    o = v.toObject(realm);
                    if(o is null)
                    {
                        sta = CannotAssignToError(realm, id.toString);
                        goto Lthrow;
                    }
                    a = locals + (code + 1).index;
                    c = locals + (code + 4).index;
                    sta = o.put_Value(realm, *a, c[0 .. (code + 3).argc]);
                    if(sta)
                        goto Lthrow;
                    code += IRTypes[Opcode.PutCallScope].size;
                    break;

                case Opcode.PutCallV:        // v(argc, argv) = a
                    b = locals + (code + 2).index;
                    o = b.toObject(realm);
                    if(o is null)
                    {
                        sta = UndefinedNoCall2Error(realm, b.type.to!string,
                                                    b.toString(realm));
                        goto Lthrow;
                    }
                    a = locals + (code + 1).index;
                    c = locals + (code + 4).index;
                    sta = o.put_Value(realm, *a, c[0 .. (code + 3).argc]);
                    if(sta !is null)
                        goto Lthrow;
                    code += IRTypes[Opcode.PutCallV].size;
                    break;

                case Opcode.New: // a = new b(argc, argv)
                    a = locals + (code + 1).index;
                    b = locals + (code + 2).index;
                    a.putVundefined();
                    c = locals + (code + 4).index;
                    sta = b.Construct(realm, *a, c[0 .. (code + 3).argc]);
                    debug(VERIFY)
                        assert(checksum == IR.verify(codestart));
                    if(sta !is null)
                        goto Lthrow;
                    code += IRTypes[Opcode.New].size;
                    break;

                case Opcode.Push:
                    SCOPECACHE_CLEAR();
                    a = locals + (code + 1).index;
                    o = a.toObject(realm);
                    if(!o)
                    {
                        sta = cannotConvert(realm, a);
                        goto Lthrow;
                    }
                    realm.push(o);
                    code += IRTypes[Opcode.Push].size;
                    break;

                case Opcode.Pop:
                    SCOPECACHE_CLEAR();
                    o = realm.popScope;
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
                    break;

                case Opcode.FinallyRet:
                    assert(finallyStack.length);
                    code = finallyStack[$-1];
                    finallyStack = finallyStack[0..$-1];
                    break;

                case Opcode.Ret:
                    // version(SCOPECACHE_LOG)
                    //     printf("scopecache_cnt = %d\n", scopecache_cnt);
                    return null;

                case Opcode.RetExp:
                    a = locals + (code + 1).index;
                    sta = a.checkReference(realm);
                    if (sta !is null)
                        goto Lthrow;
                    ret = *a;

                    return null;

                case Opcode.ImpRet:
                    a = locals + (code + 1).index;
                    sta = a.checkReference(realm);
                    if (sta !is null)
                        goto Lthrow;
                    ret = *a;

                    code += IRTypes[Opcode.ImpRet].size;
                    break;

                case Opcode.Throw:
                    a = locals + (code + 1).index;
                    sta = new DError(realm, *a);

                    Lthrow:
                    sta = unwindStack(sta);
                    if(sta !is null)
                    {
                        sta.addTrace(codestart, code);
                        return sta;
                    }
                    break;
                case Opcode.TryCatch:
                {
                    SCOPECACHE_CLEAR();
                    auto offset = (code - codestart) + (code + 1).offset;
                    id = (code + 2).id;
                    realm.push(new Catch(offset, id));
                    code += IRTypes[Opcode.TryCatch].size;
                    break;
                }
                case Opcode.TryFinally:
                    SCOPECACHE_CLEAR();
                    realm.push(new Finally(code + (code + 1).offset));
                    code += IRTypes[Opcode.TryFinally].size;
                    break;

                case Opcode.Assert:
                {
                    version(all)  // Not supported under some com servers
                    {
                        auto linnum = (code + 1).index;
                        sta = AssertError(realm, linnum);
                        goto Lthrow;
                    }
                    else
                    {
                        RuntimeErrorx(ERR_ASSERT, (code + 1).index);
                        code += IRTypes[Opcode.Assert].size;
                        break;
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
                        name, realm.modulePool, fd);
                    (locals + (code + 1).index).put(newrealm);

                    code += IRTypes[Opcode.Import].size;
                    break;
//##############################################################################
//##############################################################################
//##############################################################################
                }
                case Opcode.End:
                    code += IRTypes[Opcode.End].size;
                    break loop;
                } // the end of the final switch.
            }
            catch (Throwable t)
            {
                sta = unwindStack(t.toDError(realm));
                if (sta !is null)
                {
                    sta.addTrace(codestart, code);
                    return sta;
                }
            }
        } // the end of the loop:for(;;).

        ret.putVundefined();
        return null;
    }

    /*********************************
     * Give size of opcode.
     */

    static size_t size(in Opcode opcode)
    {
        static size_t sizeOf(T)(){ return T.size; }
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
        sink(IRTypeDispatcher!proc(code.opcode, address, code,));
    }

    debug static string toString(const(IR)* code)
    {
        import std.format : format;
        import std.array : Appender;

        Appender!string buf;
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
    import dmdscript.drealm: Drealm;

    // This is so scope_get() will skip over these objects
    override Value* Get(in PropertyKey, Drealm) const
    {
        return null;
    }

    // This is so we can distinguish between a real Dobject
    // and these fakers
    override string getTypeof() const
    {
        return null;
    }

    uint offset;        // offset of CatchBlock
    Identifier name;      // catch identifier

    this(uint offset, Identifier name)
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

    override Value* Get(in PropertyKey, Drealm) const
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
DError* cannotConvert(Drealm realm, Value* b)
{
    import std.conv : to;
    DError* sta;

    if(b.isUndefinedOrNull)
    {
        sta = CannotConvertToObject4Error(realm, b.type.to!string);
    }
    else
    {
        sta = CannotConvertToObject2Error(
            realm, b.type.to!string, b.toString(realm));
    }
    return sta;
}

