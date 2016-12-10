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


module dmdscript.dstring;

import dmdscript.primitive;
import dmdscript.script : CallContext;
import dmdscript.dobject : Dobject;
import dmdscript.value : Value, DError, vundefined;
import dmdscript.dfunction : Dconstructor;
import dmdscript.key : Key;
import dmdscript.errmsgs;
import dmdscript.dnative : DnativeFunction, DnativeFunctionDescriptor;

debug import std.stdio;

/* ===================== Dstring_fromCharCode ==================== */
@DnativeFunctionDescriptor(Key.fromCharCode, 1,
                           DnativeFunctionDescriptor.Type.Static)
DError* Dstring_fromCharCode(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.exception : assumeUnique;
    import std.traits : Unqual, ForeachType;
    import std.utf : encode, isValidDchar;

    // ECMA 15.5.3.2
    Unqual!(ForeachType!tstring)[] s = null;

    for(size_t i = 0; i < arglist.length; i++)
    {
        Value* v;
        uint u;

        v = &arglist[i];
        u = v.toUint16(cc);
        //writef("string.fromCharCode(%x)", u);
        if(!isValidDchar(u))
        {
            ret.putVundefined();
            return NotValidUTFError("String", "fromCharCode()", u);
        }
        encode(s, u);
        //writefln("s[0] = %x, s = '%s'", s[0], s);
    }
    ret.put(s.assumeUnique);
    return null;
}

/* ===================== Dstring_constructor ==================== */

class DstringConstructor : Dconstructor
{
    this()
    {
        import dmdscript.dnative : NativeFunctionData;
        import dmdscript.property : Property;

        super(Key.String, 1, Dfunction.getPrototype);

        DnativeFunctionDescriptor.install!(mixin(__MODULE__))
            (this, Property.Attribute.None,
             DnativeFunctionDescriptor.Type.Static);
        // enum NativeFunctionData[] nfd =
        // [
        //     { Key.fromCharCode, &Dstring_fromCharCode, 1 },
        // ];

        // DnativeFunction.initialize(this, nfd, Property.Attribute.None);
        debug
        {
            CallContext cc;
            assert(proptable.get(Key.fromCharCode, cc, null));
        }
    }

    override DError* Construct(ref CallContext cc, out Value ret,
                               Value[] arglist)
    {
        // ECMA 15.5.2
        tstring s;
        Dobject o;

        s = (arglist.length) ? arglist[0].toString() : Text.Empty;
        o = new Dstring(s);
        ret.put(o);
        return null;
    }

    override DError* Call(ref CallContext cc, Dobject othis, out Value ret,
                          Value[] arglist)
    {
        // ECMA 15.5.1
        tstring s;

        s = (arglist.length) ? arglist[0].toString() : Text.Empty;
        ret.put(s);
        return null;
    }
}


/* ===================== Dstring_prototype_toString =============== */
@DnativeFunctionDescriptor(Key.toString, 0)
DError* Dstring_prototype_toString(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    //writef("Dstring.prototype.toString()\n");
    // othis must be a String
    if (auto ds = cast(Dstring)othis)
    {
        ret = ds.value;
    }
    else
    {
        ret.putVundefined();
        return FunctionWantsStringError(Key.toString, othis.classname);
    }
    return null;
}

/* ===================== Dstring_prototype_valueOf =============== */
@DnativeFunctionDescriptor(Key.valueOf, 0)
DError* Dstring_prototype_valueOf(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // Does same thing as String.prototype.toString()

    //writef("string.prototype.valueOf()\n");
    // othis must be a String
    if (auto ds = cast(Dstring)othis)
    {
        ret = ds.value;
    }
    else
    {
        ret.putVundefined();
        return FunctionWantsStringError(Key.valueOf, othis.classname);
    }
    return null;
}

/* ===================== Dstring_prototype_charAt =============== */
@DnativeFunctionDescriptor(Key.charAt, 1)
DError* Dstring_prototype_charAt(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.utf : stride;
    // ECMA 15.5.4.4

    Value* v;
    int pos;            // ECMA says pos should be a d_number,
                        // but int should behave the same
    tstring s;
    tstring result;

    v = &othis.value;
    s = v.toString();
    v = arglist.length ? &arglist[0] : &vundefined;
    pos = cast(int)v.toInteger(cc);

    result = Text.Empty;

    if(pos >= 0)
    {
        size_t idx;

        while(1)
        {
            if(idx == s.length)
                break;
            if(pos == 0)
            {
                result = s[idx .. idx + stride(s, idx)];
                break;
            }
            idx += stride(s, idx);
            pos--;
        }
    }

    ret.put(result);
    return null;
}

/* ===================== Dstring_prototype_charCodeAt ============= */
@DnativeFunctionDescriptor(Key.charCodeAt, 1)
DError* Dstring_prototype_charCodeAt(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.utf : decode, stride;

    // ECMA 15.5.4.5

    Value* v;
    int pos;            // ECMA says pos should be a d_number,
                        // but int should behave the same
    tstring s;
    uint len;
    double result;

    v = &othis.value;
    s = v.toString();
    v = arglist.length ? &arglist[0] : &vundefined;
    pos = cast(int)v.toInteger(cc);

    result = double.nan;

    if(pos >= 0)
    {
        size_t idx;

        while(1)
        {
            assert(idx <= s.length);
            if(idx == s.length)
                break;
            if(pos == 0)
            {
                result = decode(s, idx);
                break;
            }
            idx += stride(s, idx);
            pos--;
        }
    }

    ret.put(result);
    return null;
}

/* ===================== Dstring_prototype_concat ============= */
@DnativeFunctionDescriptor(Key.concat, 1)
DError* Dstring_prototype_concat(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.5.4.6
    tstring s;

    //writefln("Dstring.prototype.concat()");

    s = othis.value.toString();
    for(size_t a = 0; a < arglist.length; a++)
        s ~= arglist[a].toString();

    ret.put(s);
    return null;
}

/* ===================== Dstring_prototype_indexOf ============= */
@DnativeFunctionDescriptor(Key.indexOf, 1)
DError* Dstring_prototype_indexOf(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.utf : toUCSindex, toUTFindex;
    import std.string : indexOf;

    // ECMA 15.5.4.6
    // String.prototype.indexOf(searchString, position)

    Value* v1;
    Value* v2;
    ptrdiff_t pos;            // ECMA says pos should be a d_number,
                        // but I can't find a reason.
    tstring s;
    size_t sUCSdim;

    tstring searchString;
    ptrdiff_t k;

    Value xx;
    xx.put(othis);
    s = xx.toString();
    sUCSdim = toUCSindex(s, s.length);

    v1 = arglist.length ? &arglist[0] : &vundefined;
    v2 = (arglist.length >= 2) ? &arglist[1] : &vundefined;

    searchString = v1.toString();
    pos = cast(int)v2.toInteger(cc);

    if(pos < 0)
        pos = 0;
    else if(pos > sUCSdim)
        pos = sUCSdim;

    if(searchString.length == 0)
        k = pos;
    else
    {
        pos = toUTFindex(s, pos);
        k = indexOf(s[pos .. $], searchString);
        if(k != -1)
            k = toUCSindex(s, pos + k);
    }

    ret.put(k);
    return null;
}

/* ===================== Dstring_prototype_lastIndexOf ============= */
@DnativeFunctionDescriptor(Key.lastIndexOf, 1)
DError* Dstring_prototype_lastIndexOf(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.utf : toUCSindex, toUTFindex;
    import std.string : lastIndexOf;
    import std.math : isNaN;

    // ECMA v3 15.5.4.8
    // String.prototype.lastIndexOf(searchString, position)

    Value* v1;
    ptrdiff_t pos;            // ECMA says pos should be a d_number,
                        // but I can't find a reason.
    tstring s;
    size_t sUCSdim;
    tstring searchString;
    ptrdiff_t k;

    version(all)
    {
        {
            // This is the 'transferable' version
            Value* v;
            DError* a;
            v = othis.Get(Key.toString, cc);
            a = v.Call(cc, othis, ret, null);
            if(a)                       // if exception was thrown
                return a;
            s = ret.toString();
        }
    }
    else
    {
        // the 'builtin' version
        s = othis.value.toString();
    }
    sUCSdim = toUCSindex(s, s.length);

    v1 = arglist.length ? &arglist[0] : &vundefined;
    searchString = v1.toString();
    if(arglist.length >= 2)
    {
        double n;
        Value* v = &arglist[1];

        n = v.toNumber(cc);
        if(isNaN(n) || n > sUCSdim)
            pos = sUCSdim;
        else if(n < 0)
            pos = 0;
        else
            pos = cast(int)n;
    }
    else
        pos = sUCSdim;

    //writef("len = %d, p = '%ls'\n", len, p);
    //writef("pos = %d, sslen = %d, ssptr = '%ls'\n", pos, sslen, ssptr);
    //writefln("s = '%s', pos = %s, searchString = '%s'", s, pos, searchString);

    if(searchString.length == 0)
        k = pos;
    else
    {
        pos = toUTFindex(s, pos);
        pos += searchString.length;
        if(pos > s.length)
            pos = s.length;
        k = lastIndexOf(s[0 .. pos], searchString);
        //writefln("s = '%s', pos = %s, searchString = '%s', k = %d", s, pos, searchString, k);
        if(k != -1)
            k = toUCSindex(s, k);
    }
    ret.put(k);
    return null;
}

/* ===================== Dstring_prototype_localeCompare ============= */
@DnativeFunctionDescriptor(Key.localeCompare, 1)
DError* Dstring_prototype_localeCompare(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import dmdscript.script : localeCompare;

    // ECMA v3 15.5.4.9
    tstring s1;
    tstring s2;
    double n;
    Value* v;

    v = &othis.value;
    s1 = v.toString();
    s2 = arglist.length ? arglist[0].toString() : vundefined.toString();
    n = localeCompare(cc, s1, s2);
    ret.put(n);
    return null;
}

/* ===================== Dstring_prototype_match ============= */
@DnativeFunctionDescriptor(Key.match, 1)
DError* Dstring_prototype_match(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import dmdscript.dregexp : Dregexp, EXEC_STRING, EXEC_ARRAY;
    import dmdscript.darray : Darray;
    import dmdscript.property : Property;

    // ECMA v3 15.5.4.10
    Dregexp r;

    if (0 < arglist.length && !arglist[0].isPrimitive)
        r = cast(Dregexp)arglist[0].toObject;

    if (r is null)
    {
        Value regret;

        regret.put(cast(Dobject)null);
        Dregexp.getConstructor().Construct(cc, regret, arglist);
        r = cast(Dregexp)regret.object;
    }

    if(r.global.dbool)
    {
        Darray a = new Darray;
        int n;
        int i;
        int lasti;

        i = 0;
        lasti = 0;
        for(n = 0;; n++)
        {
            r.lastIndex.put(cast(double)i);
            Dregexp.exec(r, ret, (&othis.value)[0 .. 1], EXEC_STRING);
            if(!ret.text)             // if match failed
            {
                r.lastIndex.put(cast(double)i);
                break;
            }
            lasti = i;
            i = cast(int)r.lastIndex.toInt32(cc);
            if(i == lasti)              // if no source was consumed
                i++;                    // consume a character

            a.Set(n, ret, Property.Attribute.None, cc);           // a[n] = ret;
        }
        ret.put(a);
    }
    else
    {
        Dregexp.exec(r, ret, (&othis.value)[0 .. 1], EXEC_ARRAY);
    }
    return null;
}

/* ===================== Dstring_prototype_replace ============= */
@DnativeFunctionDescriptor(Key.replace, 2)
DError* Dstring_prototype_replace(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import core.sys.posix.stdlib : alloca;
    import std.string : indexOf;
    import dmdscript.dfunction : Dfunction;
    import dmdscript.dregexp : Dregexp, RegExp, EXEC_STRING;

    // ECMA v3 15.5.4.11
    // String.prototype.replace(searchValue, replaceValue)

    tstring str;
    tstring searchString;
    tstring newstring;
    Value* searchValue;
    Value* replaceValue;
    Dregexp r;
    RegExp re;
    tstring replacement;
    tstring result;
    int m;
    int i;
    int lasti;
    tstring[1] pmatch;
    Dfunction f;
    Value* v;

    v = &othis.value;
    str = v.toString();
    searchValue = (arglist.length >= 1) ? &arglist[0] : &vundefined;
    replaceValue = (arglist.length >= 2) ? &arglist[1] : &vundefined;
    r = Dregexp.isRegExp(searchValue);
    f = Dfunction.isFunction(replaceValue);
    if(r)
    {
        int offset = 0;

        re = r.re;
        i = 0;
        result = str;

        r.lastIndex.put(cast(double)0);
        for(;; )
        {
            Dregexp.exec(r, ret, (&othis.value)[0 .. 1], EXEC_STRING);
            if(!ret.text)             // if match failed
                break;

            m = re.nmatches;
            if(f)
            {
                Value* alist;

                alist = cast(Value* )alloca((m + 3) * Value.sizeof);
                assert(alist);
                alist[0].put(ret.text);
                for(i = 0; i < m; i++)
                {
                    alist[1 + i].put(re.captures(1 + i));
                }
                alist[m + 1].put(re.index);
                alist[m + 2].put(str);
                f.Call(cc, f, ret, alist[0 .. m + 3]);
                replacement = ret.toString();
            }
            else
            {
                newstring = replaceValue.toString();
                replacement = re.replace(newstring);
            }
            ptrdiff_t starti = re.index;
            ptrdiff_t endi = re.lastIndex;
            result = str[0 .. starti] ~
                     replacement ~
                     str[endi .. $];

            if(re.global)
            {
                offset += replacement.length - (endi - starti);

                // If no source was consumed, consume a character
                lasti = i;
                i = cast(int)r.lastIndex.toInt32(cc);
                if(i == lasti)
                {
                    i++;
                    r.lastIndex.put(i);
                }
            }
            else
                break;
        }
    }
    else
    {
        searchString = searchValue.toString();
        ptrdiff_t match = indexOf(str, searchString);
        if(match >= 0)
        {
            pmatch[0] = str[match .. match + searchString.length];
            if(f)
            {
                Value[3] alist;

                alist[0].put(searchString);
                alist[1].put(match);
                alist[2].put(str);
                f.Call(cc, f, ret, alist);
                replacement = ret.toString();
            }
            else
            {
                newstring = replaceValue.toString();
                replacement = RegExp.replace3(newstring, str, pmatch[]);
            }
            result = str[0 .. match] ~
                     replacement ~
                     str[match + searchString.length .. $];
        }
        else
        {
            result = str;
        }
    }

    ret.put(result);
    return null;
}

/* ===================== Dstring_prototype_search ============= */
@DnativeFunctionDescriptor(Key.search, 1)
DError* Dstring_prototype_search(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import dmdscript.dregexp : Dregexp, EXEC_INDEX;

    // ECMA v3 15.5.4.12
    Dregexp r;

    //writef("String.prototype.search()\n");
    if (0 < arglist.length && !arglist[0].isPrimitive)
        r = cast(Dregexp)arglist[0].toObject;

    if (r is null)
    {
        Value regret;

        regret.put(cast(Dobject)null);
        Dregexp.getConstructor().Construct(cc, regret, arglist);
        r = cast(Dregexp)regret.object;
    }

    Dregexp.exec(r, ret, (&othis.value)[0 .. 1], EXEC_INDEX);
    return null;
}

/* ===================== Dstring_prototype_slice ============= */
@DnativeFunctionDescriptor(Key.slice, 2)
DError* Dstring_prototype_slice(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.utf : toUTFindex, toUCSindex;
    // ECMA v3 15.5.4.13
    ptrdiff_t start;
    ptrdiff_t end;
    ptrdiff_t sUCSdim;
    tstring s;
    tstring r;
    Value* v;

    v = &othis.value;
    s = v.toString();
    sUCSdim = toUCSindex(s, s.length);
    switch(arglist.length)
    {
    case 0:
        start = 0;
        end = sUCSdim;
        break;

    case 1:
        start = arglist[0].toInt32(cc);
        end = sUCSdim;
        break;

    default:
        start = arglist[0].toInt32(cc);
        end = arglist[1].toInt32(cc);
        break;
    }

    if(start < 0)
    {
        start += sUCSdim;
        if(start < 0)
            start = 0;
    }
    else if(start >= sUCSdim)
        start = sUCSdim;

    if(end < 0)
    {
        end += sUCSdim;
        if(end < 0)
            end = 0;
    }
    else if(end >= sUCSdim)
        end = sUCSdim;

    if(start > end)
        end = start;

    start = toUTFindex(s, start);
    end = toUTFindex(s, end);
    r = s[start .. end];

    ret.put(r);
    return null;
}


/* ===================== Dstring_prototype_split ============= */
@DnativeFunctionDescriptor(Key.split, 2)
DError* Dstring_prototype_split(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import core.stdc.string : memcmp;
    import dmdscript.dregexp : Dregexp, RegExp;
    import dmdscript.darray : Darray;
    import dmdscript.property : Property;

    // ECMA v3 15.5.4.14
    // String.prototype.split(separator, limit)
    size_t lim;
    size_t p;
    size_t q;
    size_t e;
    Value* separator = &vundefined;
    Value* limit = &vundefined;
    Dregexp R;
    RegExp re;
    tstring rs;
    tstring T;
    tstring S;
    Darray A;
    int str;

    //writefln("Dstring_prototype_split()");
    switch(arglist.length)
    {
    default:
        limit = &arglist[1];
        goto case;
    case 1:
        separator = &arglist[0];
        goto case;
    case 0:
        break;
    }

    Value* v;
    v = &othis.value;
    S = v.toString();
    A = new Darray;
    if(limit.isUndefined())
        lim = ~0u;
    else
        lim = limit.toUint32(cc);
    p = 0;
    R = Dregexp.isRegExp(separator);
    if(R)       // regular expression
    {
        re = R.re;
        assert(re);
        rs = null;
        str = 0;
    }
    else        // string
    {
        re = null;
        rs = separator.toString();
        str = 1;
    }
    if(lim == 0)
        goto Lret;

    // ECMA v3 15.5.4.14 is specific: "If separator is undefined, then the
    // result array contains just one string, which is the this value
    // (converted to a string)." However, neither Javascript nor Jscript
    // do that, they regard an undefined as being the string "undefined".
    // We match Javascript/Jscript behavior here, not ECMA.

    // Uncomment for ECMA compatibility
    //if (!separator.isUndefined())
    {
        //writefln("test1 S = '%s', rs = '%s'", S, rs);
        if(S.length)
        {
            L10:
            for(q = p; q != S.length; q++)
            {
                if(str)                 // string
                {
                    if(q + rs.length <= S.length && !memcmp(S.ptr + q, rs.ptr, rs.length * tchar.sizeof))
                    {
                        e = q + rs.length;
                        if(e != p)
                        {
                            T = S[p .. q];
                            A.Set(cast(uint)A.length.number, T,
                                  Property.Attribute.None, cc);
                            if(A.length.number == lim)
                                goto Lret;
                            p = e;
                            goto L10;
                        }
                    }
                }
                else            // regular expression
                {
                    if(re.test(S, q))
                    {
                        q = re.index;
                        e = re.lastIndex;
                        if(e != p)
                        {
                            T = S[p .. q];
                            //writefln("S = '%s', T = '%s', p = %d, q = %d, e = %d\n", S, T, p, q, e);
                            A.Set(cast(uint)A.length.number, T,
                                  Property.Attribute.None, cc);
                            if(A.length.number == lim)
                                goto Lret;
                            p = e;
                            for(uint i = 0; i < re.nmatches; i++)
                            {
                                ptrdiff_t so = re.capturesIndex(1 + i);
                                ptrdiff_t eo = re.capturesLastIndex(1 + i);

                                //writefln("i = %d, nsub = %s, so = %s, eo = %s, S.length = %s", i, re.re_nsub, so, eo, S.length);
                                if(so != -1 && eo != -1)
                                    T = S[so .. eo];
                                else
                                    T = null;
                                A.Set(cast(uint)A.length.number, T,
                                      Property.Attribute.None, cc);
                                if(A.length.number == lim)
                                    goto Lret;
                            }
                            goto L10;
                        }
                    }
                }
            }
            T = S[p .. S.length];
            A.Set(cast(uint)A.length.number, T, Property.Attribute.None, cc);
            goto Lret;
        }
        if(str)                 // string
        {
            if(rs.length <= S.length && S[0 .. rs.length] == rs[])
                goto Lret;
        }
        else            // regular expression
        {
            if(re.test(S, 0))
                goto Lret;
        }
    }

    A.Set(0u, S, Property.Attribute.None, cc);
    Lret:
    ret.put(A);
    return null;
}


/* ===================== Dstring_prototype_substr ============= */
DError* dstring_substring(tstring s, size_t sUCSdim, double start,
                          double end, out Value ret)
{
    import std.math : isNaN;
    import std.utf : toUTFindex;

    tstring sb;
    int sb_len;

    if(isNaN(start))
        start = 0;
    else if(start > sUCSdim)
        start = sUCSdim;
    else if(start < 0)
        start = 0;

    if(isNaN(end))
        end = 0;
    else if(end > sUCSdim)
        end = sUCSdim;
    else if(end < 0)
        end = 0;

    if(end < start)             // swap
    {
        double t;

        t = start;
        start = end;
        end = t;
    }

    size_t st = toUTFindex(s, cast(size_t)start);
    size_t en = toUTFindex(s, cast(size_t)end);
    sb = s[st .. en];

    ret.put(sb);
    return null;
}

@DnativeFunctionDescriptor(Key.substr, 2)
DError* Dstring_prototype_substr(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.utf : toUCSindex;
    import std.math : isNaN;

    // Javascript: TDG pg. 689
    // String.prototype.substr(start, length)
    double start;
    double length;
    tstring s;

    s = othis.value.toString();
    size_t sUCSdim = toUCSindex(s, s.length);
    start = 0;
    length = 0;
    if(arglist.length >= 1)
    {
        start = arglist[0].toInteger(cc);
        if(start < 0)
            start = sUCSdim + start;
        if(arglist.length >= 2)
        {
            length = arglist[1].toInteger(cc);
            if(isNaN(length) || length < 0)
                length = 0;
        }
        else
            length = sUCSdim - start;
    }

    return dstring_substring(s, sUCSdim, start, start + length, ret);
}

/* ===================== Dstring_prototype_substring ============= */
@DnativeFunctionDescriptor(Key.substring, 2)
DError* Dstring_prototype_substring(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.utf : toUCSindex;

    // ECMA 15.5.4.9
    // String.prototype.substring(start)
    // String.prototype.substring(start, end)
    double start;
    double end;
    tstring s;

    //writefln("String.prototype.substring()");
    s = othis.value.toString();
    size_t sUCSdim = toUCSindex(s, s.length);
    start = 0;
    end = sUCSdim;
    if(arglist.length >= 1)
    {
        start = arglist[0].toInteger(cc);
        if(arglist.length >= 2)
            end = arglist[1].toInteger(cc);
        //writef("s = '%ls', start = %d, end = %d\n", s, start, end);
    }

    return dstring_substring(s, sUCSdim, start, end, ret);
}

/* ===================== Dstring_prototype_toLowerCase ============= */

enum CASE
{
    Lower,
    Upper,
    LocaleLower,
    LocaleUpper
};

DError* tocase(Dobject othis, out Value ret, CASE caseflag)
{
    import std.string : toLower, toUpper;

    tstring s;

    s = othis.value.toString();
    switch(caseflag)
    {
    case CASE.Lower:
        s = toLower(s);
        break;
    case CASE.Upper:
        s = toUpper(s);
        break;
    case CASE.LocaleLower:
        s = toLower(s);
        break;
    case CASE.LocaleUpper:
        s = toUpper(s);
        break;
    default:
        assert(0);
    }

    ret.put(s);
    return null;
}
@DnativeFunctionDescriptor(Key.toLowerCase, 0)
DError* Dstring_prototype_toLowerCase(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.5.4.11
    // String.prototype.toLowerCase()

    //writef("Dstring_prototype_toLowerCase()\n");
    return tocase(othis, ret, CASE.Lower);
}

/* ===================== Dstring_prototype_toLocaleLowerCase ============= */
@DnativeFunctionDescriptor(Key.toLocaleLowerCase, 0)
DError* Dstring_prototype_toLocaleLowerCase(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.5.4.17

    //writef("Dstring_prototype_toLocaleLowerCase()\n");
    return tocase(othis, ret, CASE.LocaleLower);
}

/* ===================== Dstring_prototype_toUpperCase ============= */
@DnativeFunctionDescriptor(Key.toUpperCase, 0)
DError* Dstring_prototype_toUpperCase(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.5.4.12
    // String.prototype.toUpperCase()

    return tocase(othis, ret, CASE.Upper);
}

/* ===================== Dstring_prototype_toLocaleUpperCase ============= */
@DnativeFunctionDescriptor(Key.toLocaleUpperCase, 0)
DError* Dstring_prototype_toLocaleUpperCase(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.5.4.18

    return tocase(othis, ret, CASE.LocaleUpper);
}

/* ===================== Dstring_prototype_anchor ============= */

DError* dstring_anchor(
    Dobject othis, out Value ret, tstring tag, tstring name, Value[] arglist)
{
    // For example:
    //	"foo".anchor("bar")
    // produces:
    //	<tag name="bar">foo</tag>

    tstring foo = othis.value.toString();
    Value* va = arglist.length ? &arglist[0] : &vundefined;
    tstring bar = va.toString();

    tstring s;

    s = "<"     ~
        tag     ~
        " "     ~
        name    ~
        "=\""   ~
        bar     ~
        "\">"   ~
        foo     ~
        "</"    ~
        tag     ~
        ">";

    ret.put(s);
    return null;
}

@DnativeFunctionDescriptor(Key.anchor, 1)
DError* Dstring_prototype_anchor(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // Non-standard extension
    // String.prototype.anchor(anchor)
    // For example:
    //	"foo".anchor("bar")
    // produces:
    //	<A NAME="bar">foo</A>

    return dstring_anchor(othis, ret, "A", "NAME", arglist);
}
@DnativeFunctionDescriptor(Key.fontcolor, 1)
DError* Dstring_prototype_fontcolor(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    return dstring_anchor(othis, ret, "FONT", "COLOR", arglist);
}
@DnativeFunctionDescriptor(Key.fontsize, 1)
DError* Dstring_prototype_fontsize(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    return dstring_anchor(othis, ret, "FONT", "SIZE", arglist);
}
@DnativeFunctionDescriptor(Key.link, 1)
DError* Dstring_prototype_link(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    return dstring_anchor(othis, ret, "A", "HREF", arglist);
}


/* ===================== Dstring_prototype bracketing ============= */

/***************************
 * Produce <tag>othis</tag>
 */

DError* dstring_bracket(Dobject othis, out Value ret, tstring tag)
{
    tstring foo = othis.value.toString();
    tstring s;

    s = "<"     ~
        tag     ~
        ">"     ~
        foo     ~
        "</"    ~
        tag     ~
        ">";

    ret.put(s);
    return null;
}
@DnativeFunctionDescriptor(Key.big, 0)
DError* Dstring_prototype_big(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // Non-standard extension
    // String.prototype.big()
    // For example:
    //	"foo".big()
    // produces:
    //	<BIG>foo</BIG>

    return dstring_bracket(othis, ret, "BIG");
}
@DnativeFunctionDescriptor(Key.blink, 0)
DError* Dstring_prototype_blink(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    return dstring_bracket(othis, ret, "BLINK");
}
@DnativeFunctionDescriptor(Key.bold, 0)
DError* Dstring_prototype_bold(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    return dstring_bracket(othis, ret, "B");
}
@DnativeFunctionDescriptor(Key.fixed, 0)
DError* Dstring_prototype_fixed(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    return dstring_bracket(othis, ret, "TT");
}
@DnativeFunctionDescriptor(Key.italics, 0)
DError* Dstring_prototype_italics(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    return dstring_bracket(othis, ret, "I");
}
@DnativeFunctionDescriptor(Key.small, 0)
DError* Dstring_prototype_small(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    return dstring_bracket(othis, ret, "SMALL");
}
@DnativeFunctionDescriptor(Key.strike, 0)
DError* Dstring_prototype_strike(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    return dstring_bracket(othis, ret, "STRIKE");
}
@DnativeFunctionDescriptor(Key.sub, 0)
DError* Dstring_prototype_sub(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    return dstring_bracket(othis, ret, "SUB");
}
@DnativeFunctionDescriptor(Key.sup, 0)
DError* Dstring_prototype_sup(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    return dstring_bracket(othis, ret, "SUP");
}



/* ===================== Dstring_prototype ==================== */
/*
class DstringPrototype : Dstring
{
    this()
    {
        super(Dobject.getPrototype);

        DefineOwnProperty(Key.constructor, Dstring.getConstructor,
               Property.Attribute.DontEnum);

        static enum NativeFunctionData[] nfd =
        [
            { Key.toString, &Dstring_prototype_toString, 0 },
            { Key.valueOf, &Dstring_prototype_valueOf, 0 },
            { Key.charAt, &Dstring_prototype_charAt, 1 },
            { Key.charCodeAt, &Dstring_prototype_charCodeAt, 1 },
            { Key.concat, &Dstring_prototype_concat, 1 },
            { Key.indexOf, &Dstring_prototype_indexOf, 1 },
            { Key.lastIndexOf, &Dstring_prototype_lastIndexOf, 1 },
            { Key.localeCompare, &Dstring_prototype_localeCompare, 1 },
            { Key.match, &Dstring_prototype_match, 1 },
            { Key.replace, &Dstring_prototype_replace, 2 },
            { Key.search, &Dstring_prototype_search, 1 },
            { Key.slice, &Dstring_prototype_slice, 2 },
            { Key.split, &Dstring_prototype_split, 2 },
            { Key.substr, &Dstring_prototype_substr, 2 },
            { Key.substring, &Dstring_prototype_substring, 2 },
            { Key.toLowerCase, &Dstring_prototype_toLowerCase, 0 },
            { Key.toLocaleLowerCase, &Dstring_prototype_toLocaleLowerCase, 0 },
            { Key.toUpperCase, &Dstring_prototype_toUpperCase, 0 },
            { Key.toLocaleUpperCase, &Dstring_prototype_toLocaleUpperCase, 0 },
            { Key.anchor, &Dstring_prototype_anchor, 1 },
            { Key.fontcolor, &Dstring_prototype_fontcolor, 1 },
            { Key.fontsize, &Dstring_prototype_fontsize, 1 },
            { Key.link, &Dstring_prototype_link, 1 },
            { Key.big, &Dstring_prototype_big, 0 },
            { Key.blink, &Dstring_prototype_blink, 0 },
            { Key.bold, &Dstring_prototype_bold, 0 },
            { Key.fixed, &Dstring_prototype_fixed, 0 },
            { Key.italics, &Dstring_prototype_italics, 0 },
            { Key.small, &Dstring_prototype_small, 0 },
            { Key.strike, &Dstring_prototype_strike, 0 },
            { Key.sub, &Dstring_prototype_sub, 0 },
            { Key.sup, &Dstring_prototype_sup, 0 },
        ];

        DnativeFunction.initialize(this, nfd, Property.Attribute.DontEnum);
    }
}
//*/
/* ===================== Dstring ==================== */

class Dstring : Dobject
{
    import dmdscript.dobject : Initializer;
    import dmdscript.property : Property;

    this(tstring s)
    {
        import std.utf : toUCSindex;

        super(getPrototype, Key.String);

        CallContext cc;
        Set(Key.length, toUCSindex(s, s.length),
            Property.Attribute.DontEnum |
            Property.Attribute.DontDelete |
            Property.Attribute.ReadOnly, cc);
        value.put(s);
    }

    this(Dobject prototype)
    {
        super(prototype, Key.String);

        CallContext cc;
        Set(Key.length, 0,
            Property.Attribute.DontEnum |
            Property.Attribute.DontDelete |
            Property.Attribute.ReadOnly, cc);
        value.put(Text.Empty);
    }

    mixin Initializer!DstringConstructor;
/*
static:
    Dfunction getConstructor()
    {
        return _constructor;
    }

    Dobject getPrototype()
    {
        return _prototype;
    }
    void initialize()
    {
        _constructor = new DstringConstructor();
        _prototype = new DstringPrototype();

        _constructor.DefineOwnProperty(Key.prototype, _prototype,
                            Property.Attribute.DontEnum |
                            Property.Attribute.DontDelete |
                            Property.Attribute.ReadOnly);
    }

private:
    Dfunction _constructor;
    Dobject _prototype;
//*/
}


