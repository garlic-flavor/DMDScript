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

import dmdscript.script;
import dmdscript.dobject;
import dmdscript.dregexp;
import dmdscript.darray;
import dmdscript.value;
import dmdscript.dfunction;
import dmdscript.text;
import dmdscript.property;
import dmdscript.errmsgs;
import dmdscript.dnative;

debug import std.stdio;
//alias script.tchar tchar;

/* ===================== Dstring_fromCharCode ==================== */

DError* Dstring_fromCharCode(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.exception : assumeUnique;
    import std.traits : Unqual, ForeachType;
    import std.utf : encode, isValidDchar;

    // ECMA 15.5.3.2
    Unqual!(ForeachType!d_string)[] s = null;

    for(size_t i = 0; i < arglist.length; i++)
    {
        Value* v;
        uint u;

        v = &arglist[i];
        u = v.toUint16();
        //writef("string.fromCharCode(%x)", u);
        if(!isValidDchar(u))
        {
            ret.putVundefined();
            return NotValidUTFError("String", "fromCharCode()", u);
        }
        encode(s, u);
        //writefln("s[0] = %x, s = '%s'", s[0], s);
    }
    ret.putVstring(s.assumeUnique);
    return null;
}

/* ===================== Dstring_constructor ==================== */

class DstringConstructor : Dfunction
{
    this()
    {
        super(1, Dfunction.getPrototype);
        name = "String";

        static enum NativeFunctionData[] nfd =
        [
            { Text.fromCharCode, &Dstring_fromCharCode, 1 },
        ];

        DnativeFunction.initialize(this, nfd, Property.Attribute.None);
    }

    override DError* Construct(ref CallContext cc, out Value ret,
                               Value[] arglist)
    {
        // ECMA 15.5.2
        d_string s;
        Dobject o;

        s = (arglist.length) ? arglist[0].toString() : Text.Empty;
        o = new Dstring(s);
        ret.putVobject(o);
        return null;
    }

    override DError* Call(ref CallContext cc, Dobject othis, out Value ret,
                          Value[] arglist)
    {
        // ECMA 15.5.1
        d_string s;

        s = (arglist.length) ? arglist[0].toString() : Text.Empty;
        ret.putVstring(s);
        return null;
    }
}


/* ===================== Dstring_prototype_toString =============== */

DError* Dstring_prototype_toString(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    //writef("Dstring.prototype.toString()\n");
    // othis must be a String
    if(!othis.isClass(Text.String))
    {
        ret.putVundefined();
        return FunctionWantsStringError(Text.toString, othis.classname);
    }
    else
    {
        Value* v;

        v = &(cast(Dstring)othis).value;
        ret = *v;
    }
    return null;
}

/* ===================== Dstring_prototype_valueOf =============== */

DError* Dstring_prototype_valueOf(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // Does same thing as String.prototype.toString()

    //writef("string.prototype.valueOf()\n");
    // othis must be a String
    if(!othis.isClass(Text.String))
    {
        ret.putVundefined();
        return FunctionWantsStringError(Text.valueOf, othis.classname);
    }
    else
    {
        Value* v;

        v = &(cast(Dstring)othis).value;
        ret = *v;
    }
    return null;
}

/* ===================== Dstring_prototype_charAt =============== */

DError* Dstring_prototype_charAt(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.utf : stride;
    // ECMA 15.5.4.4

    Value* v;
    int pos;            // ECMA says pos should be a d_number,
                        // but int should behave the same
    d_string s;
    d_string result;

    v = &othis.value;
    s = v.toString();
    v = arglist.length ? &arglist[0] : &vundefined;
    pos = cast(int)v.toInteger();

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

    ret.putVstring(result);
    return null;
}

/* ===================== Dstring_prototype_charCodeAt ============= */

DError* Dstring_prototype_charCodeAt(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.utf : decode, stride;

    // ECMA 15.5.4.5

    Value* v;
    int pos;            // ECMA says pos should be a d_number,
                        // but int should behave the same
    d_string s;
    uint len;
    d_number result;

    v = &othis.value;
    s = v.toString();
    v = arglist.length ? &arglist[0] : &vundefined;
    pos = cast(int)v.toInteger();

    result = d_number.nan;

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

    ret.putVnumber(result);
    return null;
}

/* ===================== Dstring_prototype_concat ============= */

DError* Dstring_prototype_concat(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.5.4.6
    d_string s;

    //writefln("Dstring.prototype.concat()");

    s = othis.value.toString();
    for(size_t a = 0; a < arglist.length; a++)
        s ~= arglist[a].toString();

    ret.putVstring(s);
    return null;
}

/* ===================== Dstring_prototype_indexOf ============= */

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
    d_string s;
    size_t sUCSdim;

    d_string searchString;
    ptrdiff_t k;

    Value xx;
    xx.putVobject(othis);
    s = xx.toString();
    sUCSdim = toUCSindex(s, s.length);

    v1 = arglist.length ? &arglist[0] : &vundefined;
    v2 = (arglist.length >= 2) ? &arglist[1] : &vundefined;

    searchString = v1.toString();
    pos = cast(int)v2.toInteger();

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

    ret.putVnumber(k);
    return null;
}

/* ===================== Dstring_prototype_lastIndexOf ============= */

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
    d_string s;
    size_t sUCSdim;
    d_string searchString;
    ptrdiff_t k;

    version(all)
    {
        {
            // This is the 'transferable' version
            Value* v;
            DError* a;
            v = othis.Get(Text.toString, cc);
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
        d_number n;
        Value* v = &arglist[1];

        n = v.toNumber();
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
    ret.putVnumber(k);
    return null;
}

/* ===================== Dstring_prototype_localeCompare ============= */

DError* Dstring_prototype_localeCompare(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.5.4.9
    d_string s1;
    d_string s2;
    d_number n;
    Value* v;

    v = &othis.value;
    s1 = v.toString();
    s2 = arglist.length ? arglist[0].toString() : vundefined.toString();
    n = localeCompare(cc, s1, s2);
    ret.putVnumber(n);
    return null;
}

/* ===================== Dstring_prototype_match ============= */

DError* Dstring_prototype_match(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.5.4.10
    Dregexp r;
    Dobject o;

    if(arglist.length && !arglist[0].isPrimitive() &&
       (o = arglist[0].toObject()).isDregexp())
    {
    }
    else
    {
        Value regret;

        regret.putVobject(null);
        Dregexp.getConstructor().Construct(cc, regret, arglist);
        o = regret.object;
    }

    r = cast(Dregexp)o;
    if(r.global.dbool)
    {
        Darray a = new Darray;
        d_int32 n;
        d_int32 i;
        d_int32 lasti;

        i = 0;
        lasti = 0;
        for(n = 0;; n++)
        {
            r.lastIndex.putVnumber(i);
            Dregexp.exec(r, ret, (&othis.value)[0 .. 1], EXEC_STRING);
            if(!ret.text)             // if match failed
            {
                r.lastIndex.putVnumber(i);
                break;
            }
            lasti = i;
            i = cast(d_int32)r.lastIndex.toInt32();
            if(i == lasti)              // if no source was consumed
                i++;                    // consume a character

            a.Put(n, ret, Property.Attribute.None, cc);           // a[n] = ret;
        }
        ret.putVobject(a);
    }
    else
    {
        Dregexp.exec(r, ret, (&othis.value)[0 .. 1], EXEC_ARRAY);
    }
    return null;
}

/* ===================== Dstring_prototype_replace ============= */

DError* Dstring_prototype_replace(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import core.sys.posix.stdlib : alloca;
    import std.string : indexOf;

    // ECMA v3 15.5.4.11
    // String.prototype.replace(searchValue, replaceValue)

    d_string str;
    d_string searchString;
    d_string newstring;
    Value* searchValue;
    Value* replaceValue;
    Dregexp r;
    RegExp re;
    d_string replacement;
    d_string result;
    int m;
    int i;
    int lasti;
    d_string[1] pmatch;
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

        r.lastIndex.putVnumber(0);
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
                alist[0].putVstring(ret.text);
                for(i = 0; i < m; i++)
                {
                    alist[1 + i].putVstring(re.captures(1 + i));
                }
                alist[m + 1].putVnumber(re.index);
                alist[m + 2].putVstring(str);
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
                i = cast(d_int32)r.lastIndex.toInt32();
                if(i == lasti)
                {
                    i++;
                    r.lastIndex.putVnumber(i);
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

                alist[0].putVstring(searchString);
                alist[1].putVnumber(match);
                alist[2].putVstring(str);
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

    ret.putVstring(result);
    return null;
}

/* ===================== Dstring_prototype_search ============= */

DError* Dstring_prototype_search(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.5.4.12
    Dregexp r;
    Dobject o;

    //writef("String.prototype.search()\n");
    if(arglist.length && !arglist[0].isPrimitive() &&
       (o = arglist[0].toObject()).isDregexp())
    {
    }
    else
    {
        Value regret;

        regret.putVobject(null);
        Dregexp.getConstructor().Construct(cc, regret, arglist);
        o = regret.object;
    }

    r = cast(Dregexp)o;
    Dregexp.exec(r, ret, (&othis.value)[0 .. 1], EXEC_INDEX);
    return null;
}

/* ===================== Dstring_prototype_slice ============= */

DError* Dstring_prototype_slice(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.utf : toUTFindex, toUCSindex;
    // ECMA v3 15.5.4.13
    ptrdiff_t start;
    ptrdiff_t end;
    ptrdiff_t sUCSdim;
    d_string s;
    d_string r;
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
        start = arglist[0].toInt32();
        end = sUCSdim;
        break;

    default:
        start = arglist[0].toInt32();
        end = arglist[1].toInt32();
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

    ret.putVstring(r);
    return null;
}


/* ===================== Dstring_prototype_split ============= */

DError* Dstring_prototype_split(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import core.stdc.string : memcmp;

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
    d_string rs;
    d_string T;
    d_string S;
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
        lim = limit.toUint32();
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
                            A.Put(cast(uint)A.length.number, T,
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
                            A.Put(cast(uint)A.length.number, T,
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
                                A.Put(cast(uint)A.length.number, T,
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
            A.Put(cast(uint)A.length.number, T, Property.Attribute.None, cc);
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

    A.Put(0u, S, Property.Attribute.None, cc);
    Lret:
    ret.putVobject(A);
    return null;
}


/* ===================== Dstring_prototype_substr ============= */

DError* dstring_substring(d_string s, size_t sUCSdim, d_number start,
                          d_number end, out Value ret)
{
    import std.math : isNaN;
    import std.utf : toUTFindex;

    d_string sb;
    d_int32 sb_len;

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
        d_number t;

        t = start;
        start = end;
        end = t;
    }

    size_t st = toUTFindex(s, cast(size_t)start);
    size_t en = toUTFindex(s, cast(size_t)end);
    sb = s[st .. en];

    ret.putVstring(sb);
    return null;
}

DError* Dstring_prototype_substr(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.utf : toUCSindex;
    import std.math : isNaN;

    // Javascript: TDG pg. 689
    // String.prototype.substr(start, length)
    d_number start;
    d_number length;
    d_string s;

    s = othis.value.toString();
    size_t sUCSdim = toUCSindex(s, s.length);
    start = 0;
    length = 0;
    if(arglist.length >= 1)
    {
        start = arglist[0].toInteger();
        if(start < 0)
            start = sUCSdim + start;
        if(arglist.length >= 2)
        {
            length = arglist[1].toInteger();
            if(isNaN(length) || length < 0)
                length = 0;
        }
        else
            length = sUCSdim - start;
    }

    return dstring_substring(s, sUCSdim, start, start + length, ret);
}

/* ===================== Dstring_prototype_substring ============= */

DError* Dstring_prototype_substring(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.utf : toUCSindex;

    // ECMA 15.5.4.9
    // String.prototype.substring(start)
    // String.prototype.substring(start, end)
    d_number start;
    d_number end;
    d_string s;

    //writefln("String.prototype.substring()");
    s = othis.value.toString();
    size_t sUCSdim = toUCSindex(s, s.length);
    start = 0;
    end = sUCSdim;
    if(arglist.length >= 1)
    {
        start = arglist[0].toInteger();
        if(arglist.length >= 2)
            end = arglist[1].toInteger();
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

    d_string s;

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

    ret.putVstring(s);
    return null;
}

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

DError* Dstring_prototype_toLocaleLowerCase(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.5.4.17

    //writef("Dstring_prototype_toLocaleLowerCase()\n");
    return tocase(othis, ret, CASE.LocaleLower);
}

/* ===================== Dstring_prototype_toUpperCase ============= */

DError* Dstring_prototype_toUpperCase(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.5.4.12
    // String.prototype.toUpperCase()

    return tocase(othis, ret, CASE.Upper);
}

/* ===================== Dstring_prototype_toLocaleUpperCase ============= */

DError* Dstring_prototype_toLocaleUpperCase(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.5.4.18

    return tocase(othis, ret, CASE.LocaleUpper);
}

/* ===================== Dstring_prototype_anchor ============= */

DError* dstring_anchor(
    Dobject othis, out Value ret, d_string tag, d_string name, Value[] arglist)
{
    // For example:
    //	"foo".anchor("bar")
    // produces:
    //	<tag name="bar">foo</tag>

    d_string foo = othis.value.toString();
    Value* va = arglist.length ? &arglist[0] : &vundefined;
    d_string bar = va.toString();

    d_string s;

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

    ret.putVstring(s);
    return null;
}


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

DError* Dstring_prototype_fontcolor(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    return dstring_anchor(othis, ret, "FONT", "COLOR", arglist);
}

DError* Dstring_prototype_fontsize(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    return dstring_anchor(othis, ret, "FONT", "SIZE", arglist);
}

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

DError* dstring_bracket(Dobject othis, out Value ret, d_string tag)
{
    d_string foo = othis.value.toString();
    d_string s;

    s = "<"     ~
        tag     ~
        ">"     ~
        foo     ~
        "</"    ~
        tag     ~
        ">";

    ret.putVstring(s);
    return null;
}

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

DError* Dstring_prototype_blink(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    return dstring_bracket(othis, ret, "BLINK");
}

DError* Dstring_prototype_bold(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    return dstring_bracket(othis, ret, "B");
}

DError* Dstring_prototype_fixed(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    return dstring_bracket(othis, ret, "TT");
}

DError* Dstring_prototype_italics(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    return dstring_bracket(othis, ret, "I");
}

DError* Dstring_prototype_small(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    return dstring_bracket(othis, ret, "SMALL");
}

DError* Dstring_prototype_strike(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    return dstring_bracket(othis, ret, "STRIKE");
}

DError* Dstring_prototype_sub(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    return dstring_bracket(othis, ret, "SUB");
}

DError* Dstring_prototype_sup(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    return dstring_bracket(othis, ret, "SUP");
}



/* ===================== Dstring_prototype ==================== */

class DstringPrototype : Dstring
{
    this()
    {
        super(Dobject.getPrototype);

        CallContext cc;
        Put(Text.constructor, Dstring.getConstructor,
            Property.Attribute.DontEnum, cc);

        static enum NativeFunctionData[] nfd =
        [
            { Text.toString, &Dstring_prototype_toString, 0 },
            { Text.valueOf, &Dstring_prototype_valueOf, 0 },
            { Text.charAt, &Dstring_prototype_charAt, 1 },
            { Text.charCodeAt, &Dstring_prototype_charCodeAt, 1 },
            { Text.concat, &Dstring_prototype_concat, 1 },
            { Text.indexOf, &Dstring_prototype_indexOf, 1 },
            { Text.lastIndexOf, &Dstring_prototype_lastIndexOf, 1 },
            { Text.localeCompare, &Dstring_prototype_localeCompare, 1 },
            { Text.match, &Dstring_prototype_match, 1 },
            { Text.replace, &Dstring_prototype_replace, 2 },
            { Text.search, &Dstring_prototype_search, 1 },
            { Text.slice, &Dstring_prototype_slice, 2 },
            { Text.split, &Dstring_prototype_split, 2 },
            { Text.substr, &Dstring_prototype_substr, 2 },
            { Text.substring, &Dstring_prototype_substring, 2 },
            { Text.toLowerCase, &Dstring_prototype_toLowerCase, 0 },
            { Text.toLocaleLowerCase, &Dstring_prototype_toLocaleLowerCase, 0 },
            { Text.toUpperCase, &Dstring_prototype_toUpperCase, 0 },
            { Text.toLocaleUpperCase, &Dstring_prototype_toLocaleUpperCase, 0 },
            { Text.anchor, &Dstring_prototype_anchor, 1 },
            { Text.fontcolor, &Dstring_prototype_fontcolor, 1 },
            { Text.fontsize, &Dstring_prototype_fontsize, 1 },
            { Text.link, &Dstring_prototype_link, 1 },
            { Text.big, &Dstring_prototype_big, 0 },
            { Text.blink, &Dstring_prototype_blink, 0 },
            { Text.bold, &Dstring_prototype_bold, 0 },
            { Text.fixed, &Dstring_prototype_fixed, 0 },
            { Text.italics, &Dstring_prototype_italics, 0 },
            { Text.small, &Dstring_prototype_small, 0 },
            { Text.strike, &Dstring_prototype_strike, 0 },
            { Text.sub, &Dstring_prototype_sub, 0 },
            { Text.sup, &Dstring_prototype_sup, 0 },
        ];

        DnativeFunction.initialize(this, nfd, Property.Attribute.DontEnum);
    }
}

/* ===================== Dstring ==================== */

class Dstring : Dobject
{
    this(d_string s)
    {
        import std.utf : toUCSindex;

        super(getPrototype());
        classname = Text.String;

        CallContext cc;
        Put(Text.length, toUCSindex(s, s.length),
            Property.Attribute.DontEnum |
            Property.Attribute.DontDelete |
            Property.Attribute.ReadOnly, cc);
        value.putVstring(s);
    }

    this(Dobject prototype)
    {
        super(prototype);

        classname = Text.String;
        CallContext cc;
        Put(Text.length, 0,
            Property.Attribute.DontEnum |
            Property.Attribute.DontDelete |
            Property.Attribute.ReadOnly, cc);
        value.putVstring(null);
    }

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

        CallContext cc;
        _constructor.Put(Text.prototype, _prototype,
                         Property.Attribute.DontEnum |
                         Property.Attribute.DontDelete |
                         Property.Attribute.ReadOnly, cc);
    }

private:
    Dfunction _constructor;
    Dobject _prototype;
}


