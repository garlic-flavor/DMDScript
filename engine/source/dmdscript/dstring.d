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

import dmdscript.primitive : Key, string_t, char_t;
import dmdscript.callcontext : CallContext;
import dmdscript.dobject : Dobject;
import dmdscript.value : Value, DError;
import dmdscript.dfunction : Dconstructor;
import dmdscript.errmsgs;
import dmdscript.dnative : DnativeFunction, DFD = DnativeFunctionDescriptor;
import dmdscript.dglobal : undefined;

debug import std.stdio;

//==============================================================================
///
class Dstring : Dobject
{
    import dmdscript.dobject : Initializer;
    import dmdscript.property : Property;
    import dmdscript.primitive : PropertyKey;

    this(string_t s)
    {
        import std.utf : toUCSindex;

        super(getPrototype, Key.String);

        CallContext cc;

        version (TEST262)
        {
            auto val = Value(s.length16);
            Set(PropertyKey(Key.length), val,
                Property.Attribute.DontEnum |
                Property.Attribute.DontDelete |
                Property.Attribute.ReadOnly, cc);
        }
        else
        {
            auto val = Value(toUCSindex(s, s.length));
            Set(Key.length, val,
                Property.Attribute.DontEnum |
                Property.Attribute.DontDelete |
                Property.Attribute.ReadOnly, cc);
        }

        value.put(s);
    }

    this(Dobject prototype)
    {
        import dmdscript.primitive : Text;

        super(prototype, Key.String);

        CallContext cc;
        auto val = Value(0);
        Set(Key.length, val,
            Property.Attribute.DontEnum |
            Property.Attribute.DontDelete |
            Property.Attribute.ReadOnly, cc);
        value.put(Text.Empty);
    }

    mixin Initializer!DstringConstructor;

    override Value* Get(in PropertyKey key, ref CallContext cc)
    {
        size_t index;
        if (key.isArrayIndex(index) && index < value.text.length)
        {
            version(TEST262)
            {
                import std.exception : assumeUnique;
                char_t[] buf;
                badencode(buf, value.text.charCodeAt16(index));
                return new Value(buf.assumeUnique);
            }
            else static assert (0);
        }
        else
            return super.Get(key, cc);
    }
}

//==============================================================================
private:

version (TEST262)
{
//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// SO DIRTY IMPLEMENTATION!
    @safe pure
    size_t stride16(in char_t[] src, ref size_t needle)
    {
        import std.utf : stride;
        static if      (is(char_t == char))
        {
            auto len = stride(src, needle);
            needle += len;
            return len < 4 ? 1 : 2;
        }
        else static if (is(char_t == wchar))
        {
            auto len = stride(src, needle);
            needle += len;
            return len;
        }
        else static if (is(char_t == dchar))
        {
            import std.uni : isSurrogate;
            auto len = src[needle].isSurrogate ? 2 : 1;
            needle++;
            return len;
        }
        else static assert (0);
    }
    //
    @safe pure
    size_t length16(in char[] src)
    {
        size_t len = 0;
        for(size_t l = 0; l < src.length;)
        {
            len += stride16(src, l);
        }
        return len;
    }
    //
    @safe pure
    bool isSurrogate(in char_t[] src, size_t needle)
    {
        import std.utf : stride;
        return 4 <= stride(src, needle);
    }

    //
    @safe pure
    dchar charCodeAt16(in char_t[] buf, size_t pos)
    {
        import std.utf : stride, decode, encode;
        dchar result = 0;

        for (size_t i = 0, p = 0, l = 0; i < buf.length && p <= pos; i += l)
        {
            l = stride(buf, i);
            if      (l < 4)
            {
                if (p == pos)
                {
                    result = decode(buf, i);
                    break;
                }
                else
                    ++p;
            }
            else if (l == 4) // surrogate pair.
            {
                auto d = decode(buf, i);
                wchar[2] wbuf;
                encode(wbuf, d);
                if      (p == pos)
                    result = wbuf[0];
                else if (p + 1 == pos)
                    result = wbuf[1];
                else
                    p += 2;
            }
            else assert (0);
        }
        return result;
    }

    @safe pure
    void badencode(ref char_t[] buf, dchar d)
    {
        import std.utf : encode, isValidDchar;
        if (!isValidDchar(d))
            buf ~= ' ';
        else
            encode(buf, d);
    }
}

//------------------------------------------------------------------------------
@DFD(1, DFD.Type.Static)
DError* fromCharCode(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.exception : assumeUnique;
    import std.utf : encode, isValidDchar;

    // ECMA 15.5.3.2
    char_t[] s = null;

    for(size_t i = 0; i < arglist.length; i++)
    {
        Value* v;
        uint u;

        v = &arglist[i];
        u = v.toUint16(cc);
//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        // BAD IMPLEMENTATION!!!
        version (TEST262)
        {
            badencode(s, u);
        }
        else
        {
            if(!isValidDchar(u))
            {
                ret.putVundefined();
                return NotValidUTFError("String", "fromCharCode()", u);
            }
            encode(s, u);
        }
    }
    ret.put(s.assumeUnique);
    return null;
}

//
@DFD(1, DFD.Type.Static)
DError* fromCodePoint(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1, DFD.Type.Static)
DError* raw(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//------------------------------------------------------------------------------
class DstringConstructor : Dconstructor
{
    this()
    {
        import dmdscript.property : Property;

        super(Key.String, 1, Dfunction.getPrototype);

        // DFD.install!(mixin(__MODULE__))
        //     (this, Property.Attribute.None);
    }

    override DError* Construct(ref CallContext cc, out Value ret,
                               Value[] arglist)
    {
        import dmdscript.primitive : Text;

        // ECMA 15.5.2
        string_t s;
        Dobject o;

        s = (arglist.length) ? arglist[0].toString(cc) : Text.Empty;
        o = new Dstring(s);
        ret.put(o);
        return null;
    }

    override DError* Call(ref CallContext cc, Dobject othis, out Value ret,
                          Value[] arglist)
    {
        import dmdscript.primitive : Text;

        // ECMA 15.5.1
        string_t s;

        s = (arglist.length) ? arglist[0].toString(cc) : Text.Empty;
        ret.put(s);
        return null;
    }
}

//------------------------------------------------------------------------------
@DFD(0)
DError* toString(
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

//------------------------------------------------------------------------------
@DFD(0)
DError* valueOf(
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

//------------------------------------------------------------------------------
@DFD(1)
DError* charAt(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.utf : stride;
    import dmdscript.primitive : Text;
    // ECMA 15.5.4.4

    Value* v;
    int pos;            // ECMA says pos should be a d_number,
                        // but int should behave the same
    string_t s;
    string_t result;

    v = &othis.value;
    s = v.toString(cc);
    v = arglist.length ? &arglist[0] : &undefined;
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

//------------------------------------------------------------------------------
@DFD(1)
DError* charCodeAt(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.utf : decode, stride, encode;

    // ECMA 15.5.4.5

    Value* v;
    size_t pos;            // ECMA says pos should be a d_number,
                           // but int should behave the same
    string_t s;
    uint len;
    double result;

    v = &othis.value;
    s = v.toString(cc);
    v = arglist.length ? &arglist[0] : &undefined;
    pos = cast(int)v.toInteger(cc);

    result = double.nan;

    version (TEST262)
    {
        result = charCodeAt16(s, pos);
    }
    else
    {
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
    }

    ret.put(result);
    return null;
}

//------------------------------------------------------------------------------
@DFD(1)
DError* concat(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.5.4.6
    string_t s;

    //writefln("Dstring.prototype.concat()");

    s = othis.value.toString(cc);
    for(size_t a = 0; a < arglist.length; a++)
        s ~= arglist[a].toString(cc);

    ret.put(s);
    return null;
}

//------------------------------------------------------------------------------
@DFD(1)
DError* indexOf(
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
    string_t s;
    size_t sUCSdim;

    string_t searchString;
    ptrdiff_t k;

    Value xx;
    xx.put(othis);
    s = xx.toString(cc);
    sUCSdim = toUCSindex(s, s.length);

    v1 = arglist.length ? &arglist[0] : &undefined;
    v2 = (arglist.length >= 2) ? &arglist[1] : &undefined;

    searchString = v1.toString(cc);
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

//------------------------------------------------------------------------------
@DFD(1)
DError* lastIndexOf(
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
    string_t s;
    size_t sUCSdim;
    string_t searchString;
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
            s = ret.toString(cc);
        }
    }
    else
    {
        // the 'builtin' version
        s = othis.value.toString();
    }
    sUCSdim = toUCSindex(s, s.length);

    v1 = arglist.length ? &arglist[0] : &undefined;
    searchString = v1.toString(cc);
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

//------------------------------------------------------------------------------
@DFD(1)
DError* localeCompare(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.5.4.9
    string_t s1;
    string_t s2;
    double n;
    Value* v;

    v = &othis.value;
    s1 = v.toString(cc);
    s2 = arglist.length ? arglist[0].toString(cc) : undefined.toString(cc);
    n = localeCompare(cc, s1, s2);
    ret.put(n);
    return null;
}

@safe @nogc pure nothrow
int localeCompare(ref CallContext cc, string_t s1, string_t s2)
{   // no locale support here
    import std.string : cmp;
    return cmp(s1, s2);
}

//------------------------------------------------------------------------------
@DFD(1)
DError* match(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import dmdscript.dregexp : Dregexp, EXEC_STRING, EXEC_ARRAY;
    import dmdscript.darray : Darray;
    import dmdscript.property : Property;
    import dmdscript.primitive : PropertyKey;

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

            // a[n] = ret;
            a.Set(PropertyKey(n), ret, Property.Attribute.None, cc);

        }
        ret.put(a);
    }
    else
    {
        Dregexp.exec(r, ret, (&othis.value)[0 .. 1], EXEC_ARRAY);
    }
    return null;
}

//------------------------------------------------------------------------------
@DFD(2)
DError* replace(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import core.sys.posix.stdlib : alloca;
    import std.string : indexOf;
    import dmdscript.dfunction : Dfunction;
    import dmdscript.dregexp : Dregexp, RegExp, EXEC_STRING;

    // ECMA v3 15.5.4.11
    // String.prototype.replace(searchValue, replaceValue)

    string_t str;
    string_t searchString;
    string_t newstring;
    Value* searchValue;
    Value* replaceValue;
    Dregexp r;
    RegExp re;
    string_t replacement;
    string_t result;
    int m;
    int i;
    int lasti;
    string_t[1] pmatch;
    Dfunction f;
    Value* v;

    v = &othis.value;
    str = v.toString(cc);
    searchValue = (arglist.length >= 1) ? &arglist[0] : &undefined;
    replaceValue = (arglist.length >= 2) ? &arglist[1] : &undefined;
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
                replacement = ret.toString(cc);
            }
            else
            {
                newstring = replaceValue.toString(cc);
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
        searchString = searchValue.toString(cc);
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
                replacement = ret.toString(cc);
            }
            else
            {
                newstring = replaceValue.toString(cc);
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

//------------------------------------------------------------------------------
@DFD(2)
DError* slice(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.utf : toUTFindex, toUCSindex;
    // ECMA v3 15.5.4.13
    ptrdiff_t start;
    ptrdiff_t end;
    ptrdiff_t sUCSdim;
    string_t s;
    string_t r;
    Value* v;

    v = &othis.value;
    s = v.toString(cc);
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


//------------------------------------------------------------------------------
@DFD(2)
DError* split(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import core.stdc.string : memcmp;
    import dmdscript.primitive : char_t, PropertyKey;
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
    string_t rs;
    string_t T;
    string_t S;
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
    S = v.toString(cc);
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
        rs = separator.toString(cc);
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
                    if(q + rs.length <= S.length && !memcmp(S.ptr + q, rs.ptr, rs.length * char_t.sizeof))
                    {
                        e = q + rs.length;
                        if(e != p)
                        {
                            T = S[p .. q];
                            val.put(T);
                            A.Set(PropertyKey(cast(uint)A.length.number), val,
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
                            val.put(T);
                            A.Set(PropertyKey(cast(size_t)A.length.number), val,
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
                                val.put(T);
                                A.Set(PropertyKey(cast(size_t)A.length.number),
                                      val, Property.Attribute.None, cc);
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
                  Property.Attribute.None, cc);
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
    A.Set(PropertyKey(0u), val, Property.Attribute.None, cc);
    Lret:
    ret.put(A);
    return null;
}

//------------------------------------------------------------------------------
DError* dstring_substring(string_t s, size_t sUCSdim, double start,
                          double end, out Value ret)
{
    import std.math : isNaN;
    import std.utf : toUTFindex;

    string_t sb;
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
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.utf : toUCSindex;
    import std.math : isNaN;

    // Javascript: TDG pg. 689
    // String.prototype.substr(start, length)
    double start;
    double length;
    string_t s;

    s = othis.value.toString(cc);
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

//------------------------------------------------------------------------------
@DFD(2)
DError* substring(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.utf : toUCSindex;

    // ECMA 15.5.4.9
    // String.prototype.substring(start)
    // String.prototype.substring(start, end)
    double start;
    double end;
    string_t s;

    //writefln("String.prototype.substring()");
    s = othis.value.toString(cc);
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

//------------------------------------------------------------------------------
enum CASE
{
    Lower,
    Upper,
    LocaleLower,
    LocaleUpper
};

DError* tocase(ref CallContext cc, Dobject othis, out Value ret, CASE caseflag)
{
    import std.string : toLower, toUpper;

    string_t s;

    s = othis.value.toString(cc);
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
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.5.4.11
    // String.prototype.toLowerCase()

    //writef("Dstring_prototype_toLowerCase()\n");
    return tocase(cc, othis, ret, CASE.Lower);
}

//------------------------------------------------------------------------------
@DFD(0)
DError* toLocaleLowerCase(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.5.4.17

    //writef("Dstring_prototype_toLocaleLowerCase()\n");
    return tocase(cc, othis, ret, CASE.LocaleLower);
}

//------------------------------------------------------------------------------
@DFD(0)
DError* toUpperCase(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.5.4.12
    // String.prototype.toUpperCase()

    return tocase(cc, othis, ret, CASE.Upper);
}

//------------------------------------------------------------------------------
@DFD(0)
DError* toLocaleUpperCase(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.5.4.18

    return tocase(cc, othis, ret, CASE.LocaleUpper);
}

//------------------------------------------------------------------------------
DError* dstring_anchor(
    ref CallContext cc, Dobject othis, out Value ret, string_t tag,
    string_t name, Value[] arglist)
{
    // For example:
    //	"foo".anchor("bar")
    // produces:
    //	<tag name="bar">foo</tag>

    string_t foo = othis.value.toString(cc);
    Value* va = arglist.length ? &arglist[0] : &undefined;
    string_t bar = va.toString(cc);

    string_t s;

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
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // Non-standard extension
    // String.prototype.anchor(anchor)
    // For example:
    //	"foo".anchor("bar")
    // produces:
    //	<A NAME="bar">foo</A>

    return dstring_anchor(cc, othis, ret, "A", "NAME", arglist);
}

//------------------------------------------------------------------------------
@DFD(1)
DError* fontcolor(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    return dstring_anchor(cc, othis, ret, "FONT", "COLOR", arglist);
}

//------------------------------------------------------------------------------
@DFD(1)
DError* fontsize(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    return dstring_anchor(cc, othis, ret, "FONT", "SIZE", arglist);
}

//------------------------------------------------------------------------------
@DFD(1)
DError* link(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    return dstring_anchor(cc, othis, ret, "A", "HREF", arglist);
}


//------------------------------------------------------------------------------
/*
Produce <tag>othis</tag>
*/
DError* dstring_bracket(ref CallContext cc, Dobject othis, out Value ret,
                        string_t tag)
{
    string_t foo = othis.value.toString(cc);
    string_t s;

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
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // Non-standard extension
    // String.prototype.big()
    // For example:
    //	"foo".big()
    // produces:
    //	<BIG>foo</BIG>

    return dstring_bracket(cc, othis, ret, "BIG");
}

//------------------------------------------------------------------------------
@DFD(0)
DError* blink(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    return dstring_bracket(cc, othis, ret, "BLINK");
}

//------------------------------------------------------------------------------
@DFD(0)
DError* bold(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    return dstring_bracket(cc, othis, ret, "B");
}

//------------------------------------------------------------------------------
@DFD(0)
DError* fixed(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    return dstring_bracket(cc, othis, ret, "TT");
}

//------------------------------------------------------------------------------
@DFD(0)
DError* italics(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    return dstring_bracket(cc, othis, ret, "I");
}

//------------------------------------------------------------------------------
@DFD(0)
DError* small(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    return dstring_bracket(cc, othis, ret, "SMALL");
}

//------------------------------------------------------------------------------
@DFD(0)
DError* strike(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    return dstring_bracket(cc, othis, ret, "STRIKE");
}

//------------------------------------------------------------------------------
@DFD(0)
DError* sub(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    return dstring_bracket(cc, othis, ret, "SUB");
}

//------------------------------------------------------------------------------
@DFD(0)
DError* sup(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    return dstring_bracket(cc, othis, ret, "SUP");
}

//
@DFD(1)
DError* codePointAt(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1)
DError* endsWith(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1)
DError* includes(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1)
DError* normalize(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1)
DError* repeat(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1)
DError* startsWith(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1)
DError* trim(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}
