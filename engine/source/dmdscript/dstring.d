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

import dmdscript.primitive : Key;
import dmdscript.dobject : Dobject;
import dmdscript.value : Value, DError;
import dmdscript.dfunction : Dconstructor;
import dmdscript.errmsgs;
import dmdscript.dnative : DnativeFunction, DFD = DnativeFunctionDescriptor;
import dmdscript.drealm : undefined, Drealm;

debug import std.stdio;

//==============================================================================
///
class Dstring : Dobject
{
    import dmdscript.property : Property;
    import dmdscript.primitive : PropertyKey;

    override Value* Get(in PropertyKey key, Drealm realm)
    {
        size_t index;
        if (key.isArrayIndex(index) && index < value.text.length)
        {
            return new Value(_stringAt(value.text, index));
/*            version(TEST262)
            {
                size_t i = 0;
                return new Value(CESU8.toCcharAt(value.text, index, i));
            }
            else static*/ assert (0);
        }
        else
            return super.Get(key, realm);
    }

private:
    this(Dobject prototype, string s)
    {
        import std.utf : toUCSindex;
        super(prototype, Key.String);

        auto val = Value(toUCSindex(s, s.length));
        DefineOwnProperty(Key.length, val,
                          Property.Attribute.DontEnum |
                          Property.Attribute.DontDelete |
                          Property.Attribute.ReadOnly);

        value.put(s);
    }

    this(Dobject prototype)
    {
        import dmdscript.primitive : Text;

        super(prototype, Key.String);

        auto val = Value(0);
        DefineOwnProperty(Key.length, val,
                          Property.Attribute.DontEnum |
                          Property.Attribute.DontDelete |
                          Property.Attribute.ReadOnly);
        value.put(Text.Empty);
    }
}

//------------------------------------------------------------------------------
class DstringConstructor : Dconstructor
{
    this(Dobject superClassPrototype, Dobject functionPrototype)
    {
        import dmdscript.property : Property;

        super(new Dobject(superClassPrototype), functionPrototype,
              Key.String, 1);

        install(functionPrototype);
    }

    Dstring opCall(string s)
    {
        return new Dstring(classPrototype, s);
    }

    override DError* Construct(Drealm realm, out Value ret,
                               Value[] arglist)
    {
        import dmdscript.primitive : Text;

        // ECMA 15.5.2
        string s;
        Dobject o;

        s = (arglist.length) ? arglist[0].toString(realm) : Text.Empty;
        o = opCall(s);
        ret.put(o);
        return null;
    }

    override DError* Call(Drealm realm, Dobject othis, out Value ret,
                          Value[] arglist)
    {
        import dmdscript.primitive : Text;

        // ECMA 15.5.1
        string s;

        s = (arglist.length) ? arglist[0].toString(realm) : Text.Empty;
        ret.put(s);
        return null;
    }
}

//==============================================================================
private:


//------------------------------------------------------------------------------
@safe pure
double _charCodeAt(in char[] src, in size_t index)
{
    import std.utf : decode, stride;

    size_t i, cc;
    for (i = 0, cc = 0; i < src.length && cc <= index;)
    {
        if (cc == index)
        {
            return decode(src, i);
        }
        else
        {
            i += stride(src, i);
            ++cc;
        }
    }

    return double.nan;
}

//------------------------------------------------------------------------------
@safe pure
inout(char)[] _stringAt(inout char[] src, in size_t index)
{
    import std.utf : decode, stride;

    size_t i, cc, len;
    for (i = 0, cc = 0; i < src.length && cc <= index;)
    {
        if (cc == index)
        {
            len = stride(src, i);
            return src[i..i+len];
        }
        else
        {
            i += stride(src, i);
            ++cc;
        }
    }

    return null;
}

//------------------------------------------------------------------------------
@DFD(1, DFD.Type.Static)
DError* fromCharCode(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.array : Appender;
    import std.utf : encode, isValidDchar;

    // ECMA 15.5.3.2
    Appender!string s;
    char[4] buf;
    size_t l;

    for(size_t i = 0; i < arglist.length; i++)
    {
        Value* v;
        uint u;

        v = &arglist[i];
        u = v.toUint16(realm);

        if(!isValidDchar(u))
        {
            ret.putVundefined();
            return NotValidUTFError(realm, "String", "fromCharCode()", u);
        }

        l = encode(buf, u);
        s.put(buf[0..l]);
    }
    ret.put(s.data);
    return null;
}

//
@DFD(1, DFD.Type.Static)
DError* fromCodePoint(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1, DFD.Type.Static)
DError* raw(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}


//------------------------------------------------------------------------------
@DFD(0)
DError* toString(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
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
        return FunctionWantsStringError(realm, Key.toString, othis.classname);
    }
    return null;
}

//------------------------------------------------------------------------------
@DFD(0)
DError* valueOf(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
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
        return FunctionWantsStringError(realm, Key.valueOf, othis.classname);
    }
    return null;
}

//------------------------------------------------------------------------------
@DFD(1)
DError* charAt(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    import dmdscript.primitive : Text;
    import std.utf : stride;
    // ECMA 15.5.4.4

    Value* v;
    int pos;            // ECMA says pos should be a d_number,
                        // but int should behave the same
    string s;
    string result;

    v = &othis.value;
    s = v.toString(realm);
    v = arglist.length ? &arglist[0] : &undefined;
    pos = cast(int)v.toInteger(realm);

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

//------------------------------------------------------------------------------
@DFD(1)
DError* charCodeAt(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.utf : decode, stride, encode;

    // ECMA 15.5.4.5

    Value* v;
    size_t pos;            // ECMA says pos should be a d_number,
                           // but int should behave the same
    string s;
    uint len;
    double result;

    v = &othis.value;
    s = v.toString(realm);
    v = arglist.length ? &arglist[0] : &undefined;
    pos = cast(int)v.toInteger(realm);

    result = _charCodeAt(s, pos);

    ret.put(result);
    return null;
}

//------------------------------------------------------------------------------
@DFD(1)
DError* concat(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.5.4.6
    string s;

    //writefln("Dstring.prototype.concat()");

    s = othis.value.toString(realm);
    for(size_t a = 0; a < arglist.length; a++)
        s ~= arglist[a].toString(realm);

    ret.put(s);
    return null;
}

//------------------------------------------------------------------------------
@DFD(1)
DError* indexOf(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.utf : stride, toUTFindex;
    import std.algorithm : countUntil;

    // ECMA 15.5.4.6
    // String.prototype.indexOf(searchString, position)

    Value* v1;
    Value* v2;
    ptrdiff_t pos;            // ECMA says pos should be a d_number,
                        // but I can't find a reason.
    string s;
    size_t sUCSdim;

    string searchString;
    ptrdiff_t k;

    Value xx;
    xx.put(othis);
    s = xx.toString(realm);
    sUCSdim = s.stride;

    v1 = arglist.length ? &arglist[0] : &undefined;
    v2 = (arglist.length >= 2) ? &arglist[1] : &undefined;

    searchString = v1.toString(realm);
    pos = cast(int)v2.toInteger(realm);

    if(pos < 0)
        pos = 0;
    else if(pos > sUCSdim)
        pos = sUCSdim;

    if(searchString.length == 0)
        k = pos;
    else
    {
        pos = toUTFindex(s, pos);
        k = countUntil(s[pos .. $], searchString);
        if(k != -1)
            k = stride(s[0 ..pos + k]);
    }

    ret.put(k);
    return null;
}

//------------------------------------------------------------------------------
@DFD(1)
DError* lastIndexOf(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.string : lastIndexOf;
    import std.math : isNaN;
    import std.algorithm : countUntil;
    import std.range : retro;
    import std.utf : stride, toUTFindex;

    // ECMA v3 15.5.4.8
    // String.prototype.lastIndexOf(searchString, position)

    Value* v1;
    ptrdiff_t pos;            // ECMA says pos should be a d_number,
                        // but I can't find a reason.
    string s;
    size_t sUCSdim;
    string searchString;
    ptrdiff_t k;

    version(all)
    {
        {
            // This is the 'transferable' version
            Value* v;
            DError* a;
            v = othis.Get(Key.toString, realm);
            a = v.Call(realm, othis, ret, null);
            if(a)                       // if exception was thrown
                return a;
            s = ret.toString(realm);
        }
    }
    else
    {
        // the 'builtin' version
        s = othis.value.toString();
    }
    sUCSdim = stride(s);

    v1 = arglist.length ? &arglist[0] : &undefined;
    searchString = v1.toString(realm);
    if(arglist.length >= 2)
    {
        double n;
        Value* v = &arglist[1];

        n = v.toNumber(realm);
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
        // k = lastIndexOf(s[0 .. pos], searchString);
        k = s[0 .. pos].retro.countUntil(searchString.retro);
        if (k != -1)
            k = pos - searchString.length;
        //writefln("s = '%s', pos = %s, searchString = '%s', k = %d", s, pos, searchString, k);
        if(k != -1)
            k = stride(s[0 .. k]);
    }
    ret.put(k);
    return null;
}

//------------------------------------------------------------------------------
@DFD(1)
DError* localeCompare(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.5.4.9
    string s1;
    string s2;
    double n;
    Value* v;

    v = &othis.value;
    s1 = v.toString(realm);
    s2 = arglist.length ? arglist[0].toString(realm) :
        undefined.toString(realm);
    n = localeCompare(realm, s1, s2);
    ret.put(n);
    return null;
}

@safe @nogc pure nothrow
int localeCompare(Drealm realm, string s1, string s2)
{   // no locale support here
    import std.string : cmp;
    return cmp(s1, s2);
}

//------------------------------------------------------------------------------
@DFD(1)
DError* match(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    import dmdscript.dregexp : Dregexp, EXEC_STRING, EXEC_ARRAY;
    import dmdscript.darray : Darray;
    import dmdscript.property : Property;
    import dmdscript.primitive : PropertyKey;

    // ECMA v3 15.5.4.10
    Dregexp r;

    if (0 < arglist.length && !arglist[0].isPrimitive)
        r = cast(Dregexp)arglist[0].toObject(realm);

    if (r is null)
    {
        Value regret;

        regret.put(cast(Dobject)null);
        realm.dRegexp.Construct(realm, regret, arglist);
        r = cast(Dregexp)regret.object;
    }

    if(r.global.dbool)
    {
        Darray a = realm.dArray();
        int n;
        int i;
        int lasti;

        i = 0;
        lasti = 0;
        for(n = 0;; n++)
        {
            r.lastIndex.put(cast(double)i);
            Dregexp.exec(r, realm, ret, (&othis.value)[0 .. 1], EXEC_STRING);
            if(!ret.text)             // if match failed
            {
                r.lastIndex.put(cast(double)i);
                break;
            }
            lasti = i;
            i = cast(int)r.lastIndex.toInt32(realm);
            if(i == lasti)              // if no source was consumed
                i++;                    // consume a character

            // a[n] = ret;
            a.Set(PropertyKey(n), ret, Property.Attribute.None, realm);

        }
        ret.put(a);
    }
    else
    {
        Dregexp.exec(r, realm, ret, (&othis.value)[0 .. 1], EXEC_ARRAY);
    }
    return null;
}

//------------------------------------------------------------------------------
@DFD(2)
DError* replace(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    import core.sys.posix.stdlib : alloca;
    import std.algorithm : countUntil;
    import std.utf : toUTF16;
    import dmdscript.dfunction : Dfunction;
    import dmdscript.dregexp : Dregexp, RegExp, EXEC_STRING;

    // ECMA v3 15.5.4.11
    // String.prototype.replace(searchValue, replaceValue)

    string str;
    string searchString;
    string newstring;
    Value* searchValue;
    Value* replaceValue;
    Dregexp r;
    RegExp re;
    string replacement;
    string result;
    sizediff_t m;
    int i;
    int lasti;
    string[1] pmatch;
    Dfunction f;
    Value* v;

    v = &othis.value;
    str = v.toString(realm);
    searchValue = (arglist.length >= 1) ? &arglist[0] : &undefined;
    replaceValue = (arglist.length >= 2) ? &arglist[1] : &undefined;
    r = Dregexp.isRegExp(realm, searchValue);
    f = Dfunction.isFunction(realm, replaceValue);
    if(r)
    {
        int offset = 0;

        re = r.re;
        i = 0;
        result = str;

        r.lastIndex.put(cast(double)0);
        for(;; )
        {
            Dregexp.exec(r, realm, ret, (&othis.value)[0 .. 1], EXEC_STRING);
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
                f.Call(realm, f, ret, alist[0 .. m + 3]);
                replacement = ret.toString(realm);
            }
            else
            {
                newstring = replaceValue.toString(realm);
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
                i = cast(int)r.lastIndex.toInt32(realm);
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
        searchString = searchValue.toString(realm);
        ptrdiff_t match = countUntil(str, searchString);
        if(match >= 0)
        {
            pmatch[0] = str[match .. match + searchString.length];
            if(f)
            {
                Value[3] alist;

                alist[0].put(searchString);
                alist[1].put(match);
                alist[2].put(str);
                f.Call(realm, f, ret, alist);
                replacement = ret.toString(realm);
            }
            else
            {
                newstring = replaceValue.toString(realm);
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

//------------------------------------------------------------------------------
@DFD(1)
DError* search(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    import dmdscript.dregexp : Dregexp, EXEC_INDEX;

    // ECMA v3 15.5.4.12
    Dregexp r;

    //writef("String.prototype.search()\n");
    if (0 < arglist.length && !arglist[0].isPrimitive)
        r = cast(Dregexp)arglist[0].toObject(realm);

    if (r is null)
    {
        Value regret;

        regret.put(cast(Dobject)null);
        realm.dRegexp.Construct(realm, regret, arglist);
        r = cast(Dregexp)regret.object;
    }

    Dregexp.exec(r, realm, ret, (&othis.value)[0 .. 1], EXEC_INDEX);
    return null;
}

//------------------------------------------------------------------------------
@DFD(2)
DError* slice(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.utf : stride, toUTFindex;

    // ECMA v3 15.5.4.13
    ptrdiff_t start;
    ptrdiff_t end;
    ptrdiff_t sUCSdim;
    string s;
    string r;
    Value* v;

    v = &othis.value;
    s = v.toString(realm);
    sUCSdim = stride(s);
    switch(arglist.length)
    {
    case 0:
        start = 0;
        end = sUCSdim;
        break;

    case 1:
        start = arglist[0].toInt32(realm);
        end = sUCSdim;
        break;

    default:
        start = arglist[0].toInt32(realm);
        end = arglist[1].toInt32(realm);
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


//------------------------------------------------------------------------------
@DFD(2)
DError* split(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    import core.stdc.string : memcmp;
    import dmdscript.primitive : PropertyKey;
    import dmdscript.dregexp : Dregexp, RegExp;
    import dmdscript.darray : Darray;
    import dmdscript.property : Property;

    // ECMA v3 15.5.4.14
    // String.prototype.split(separator, limit)
    size_t lim;
    size_t p;
    size_t q;
    size_t e;
    Value* separator = &undefined;
    Value* limit = &undefined;
    Dregexp R;
    RegExp re;
    string rs;
    string T;
    string S;
    Darray A;
    int str;
    Value val;

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
    S = v.toString(realm);
    A = realm.dArray();
    if(limit.isUndefined())
        lim = ~0u;
    else
        lim = limit.toUint32(realm);
    p = 0;
    R = Dregexp.isRegExp(realm, separator);
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
        rs = separator.toString(realm);
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
                    if(q + rs.length <= S.length && !memcmp(S.ptr + q, rs.ptr, rs.length * char.sizeof))
                    {
                        e = q + rs.length;
                        if(e != p)
                        {
                            T = S[p .. q];
                            val.put(T);
                            A.Set(PropertyKey(cast(uint)A.length.number), val,
                                  Property.Attribute.None, realm);
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
                            val.put(T);
                            A.Set(PropertyKey(cast(size_t)A.length.number), val,
                                  Property.Attribute.None, realm);
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
                                val.put(T);
                                A.Set(PropertyKey(cast(size_t)A.length.number),
                                      val, Property.Attribute.None, realm);
                                if(A.length.number == lim)
                                    goto Lret;
                            }
                            goto L10;
                        }
                    }
                }
            }
            T = S[p .. S.length];
            val.put(T);
            A.Set(PropertyKey(cast(uint)A.length.number), val,
                  Property.Attribute.None, realm);
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

    val.put(S);
    A.Set(PropertyKey(0u), val, Property.Attribute.None, realm);
    Lret:
    ret.put(A);
    return null;
}

//------------------------------------------------------------------------------
DError* dstring_substring(string s, size_t sUCSdim, double start,
                          double end, out Value ret)
{
    import std.math : isNaN;
    import std.utf : toUTFindex;

    string sb;
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

//------------------------------------------------------------------------------
@DFD(2)
DError* substr(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.math : isNaN;
    import std.utf : stride;

    // Javascript: TDG pg. 689
    // String.prototype.substr(start, length)
    double start;
    double length;
    string s;

    s = othis.value.toString(realm);
    size_t sUCSdim = stride(s);
    start = 0;
    length = 0;
    if(arglist.length >= 1)
    {
        start = arglist[0].toInteger(realm);
        if(start < 0)
            start = sUCSdim + start;
        if(arglist.length >= 2)
        {
            length = arglist[1].toInteger(realm);
            if(isNaN(length) || length < 0)
                length = 0;
        }
        else
            length = sUCSdim - start;
    }

    return dstring_substring(s, sUCSdim, start, start + length, ret);
}

//------------------------------------------------------------------------------
@DFD(2)
DError* substring(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.utf : stride;

    // ECMA 15.5.4.9
    // String.prototype.substring(start)
    // String.prototype.substring(start, end)
    double start;
    double end;
    string s;

    //writefln("String.prototype.substring()");
    s = othis.value.toString(realm);
    size_t sUCSdim = stride(s);
    start = 0;
    end = sUCSdim;
    if(arglist.length >= 1)
    {
        start = arglist[0].toInteger(realm);
        if(arglist.length >= 2)
            end = arglist[1].toInteger(realm);
        //writef("s = '%ls', start = %d, end = %d\n", s, start, end);
    }

    return dstring_substring(s, sUCSdim, start, end, ret);
}

//------------------------------------------------------------------------------
enum CASE
{
    Lower,
    Upper,
    LocaleLower,
    LocaleUpper
};

DError* tocase(Drealm realm, Dobject othis, out Value ret, CASE caseflag)
{
    import std.string : toLower, toUpper;

    string s;

    s = othis.value.toString(realm);
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

//------------------------------------------------------------------------------
@DFD(0)
DError* toLowerCase(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.5.4.11
    // String.prototype.toLowerCase()

    //writef("Dstring_prototype_toLowerCase()\n");
    return tocase(realm, othis, ret, CASE.Lower);
}

//------------------------------------------------------------------------------
@DFD(0)
DError* toLocaleLowerCase(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.5.4.17

    //writef("Dstring_prototype_toLocaleLowerCase()\n");
    return tocase(realm, othis, ret, CASE.LocaleLower);
}

//------------------------------------------------------------------------------
@DFD(0)
DError* toUpperCase(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.5.4.12
    // String.prototype.toUpperCase()

    return tocase(realm, othis, ret, CASE.Upper);
}

//------------------------------------------------------------------------------
@DFD(0)
DError* toLocaleUpperCase(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.5.4.18

    return tocase(realm, othis, ret, CASE.LocaleUpper);
}

//------------------------------------------------------------------------------
DError* dstring_anchor(
    Drealm realm, Dobject othis, out Value ret, string tag,
    string name, Value[] arglist)
{
    // For example:
    //	"foo".anchor("bar")
    // produces:
    //	<tag name="bar">foo</tag>

    string foo = othis.value.toString(realm);
    Value* va = arglist.length ? &arglist[0] : &undefined;
    string bar = va.toString(realm);

    string s;

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

//------------------------------------------------------------------------------
@DFD(1)
DError* anchor(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    // Non-standard extension
    // String.prototype.anchor(anchor)
    // For example:
    //	"foo".anchor("bar")
    // produces:
    //	<A NAME="bar">foo</A>

    return dstring_anchor(realm, othis, ret, "A", "NAME", arglist);
}

//------------------------------------------------------------------------------
@DFD(1)
DError* fontcolor(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    return dstring_anchor(realm, othis, ret, "FONT", "COLOR", arglist);
}

//------------------------------------------------------------------------------
@DFD(1)
DError* fontsize(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    return dstring_anchor(realm, othis, ret, "FONT", "SIZE", arglist);
}

//------------------------------------------------------------------------------
@DFD(1)
DError* link(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    return dstring_anchor(realm, othis, ret, "A", "HREF", arglist);
}


//------------------------------------------------------------------------------
/*
Produce <tag>othis</tag>
*/
DError* dstring_bracket(Drealm realm, Dobject othis, out Value ret,
                        string tag)
{
    string foo = othis.value.toString(realm);
    string s;

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

//------------------------------------------------------------------------------
@DFD(0)
DError* big(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    // Non-standard extension
    // String.prototype.big()
    // For example:
    //	"foo".big()
    // produces:
    //	<BIG>foo</BIG>

    return dstring_bracket(realm, othis, ret, "BIG");
}

//------------------------------------------------------------------------------
@DFD(0)
DError* blink(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    return dstring_bracket(realm, othis, ret, "BLINK");
}

//------------------------------------------------------------------------------
@DFD(0)
DError* bold(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    return dstring_bracket(realm, othis, ret, "B");
}

//------------------------------------------------------------------------------
@DFD(0)
DError* fixed(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    return dstring_bracket(realm, othis, ret, "TT");
}

//------------------------------------------------------------------------------
@DFD(0)
DError* italics(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    return dstring_bracket(realm, othis, ret, "I");
}

//------------------------------------------------------------------------------
@DFD(0)
DError* small(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    return dstring_bracket(realm, othis, ret, "SMALL");
}

//------------------------------------------------------------------------------
@DFD(0)
DError* strike(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    return dstring_bracket(realm, othis, ret, "STRIKE");
}

//------------------------------------------------------------------------------
@DFD(0)
DError* sub(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    return dstring_bracket(realm, othis, ret, "SUB");
}

//------------------------------------------------------------------------------
@DFD(0)
DError* sup(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    return dstring_bracket(realm, othis, ret, "SUP");
}

//
@DFD(1)
DError* codePointAt(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1)
DError* endsWith(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1)
DError* includes(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1)
DError* normalize(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1)
DError* repeat(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1)
DError* startsWith(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1)
DError* trim(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}
