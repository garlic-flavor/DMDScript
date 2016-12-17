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


module dmdscript.dregexp;

import dmdscript.primitive : char_t, string_t, StringKey, Text, PKey = Key;
import dmdscript.callcontext;
import dmdscript.dobject;
import dmdscript.value;
import dmdscript.protoerror;
import dmdscript.darray;
import dmdscript.dfunction;
import dmdscript.property;
import dmdscript.errmsgs;
import dmdscript.dnative : DnativeFunction, DFD = DnativeFunctionDescriptor;
import dmdscript.dglobal : undefined;

//alias script.tchar tchar;

// Values for Dregexp.exec.rettype
enum { EXEC_STRING, EXEC_ARRAY, EXEC_BOOLEAN, EXEC_INDEX };

/* ===================== Dregexp_constructor ==================== */

class DregexpConstructor : Dconstructor
{
    Value* input;
    Value* multiline;
    Value* lastMatch;
    Value* lastParen;
    Value* leftContext;
    Value* rightContext;
    Value*[10] dollar;

    // Extensions
    Value* index;
    Value* lastIndex;

    this()
    {
        super(Key.RegExp, 2, Dfunction.getPrototype);

        Value v;
        v.put(Text.Empty);

        Value vb;
        vb.put(false);

        Value vnm1;
        vnm1.put(-1);

        // Static properties
        DefineOwnProperty(Key.input, v, Property.Attribute.DontDelete);
        DefineOwnProperty(Key.multiline, vb, Property.Attribute.DontDelete);
        DefineOwnProperty(Key.lastMatch, v,
               Property.Attribute.ReadOnly | Property.Attribute.DontDelete);
        DefineOwnProperty(Key.lastParen, v,
            Property.Attribute.ReadOnly | Property.Attribute.DontDelete);
        DefineOwnProperty(Key.leftContext, v,
            Property.Attribute.ReadOnly | Property.Attribute.DontDelete);
        DefineOwnProperty(Key.rightContext, v,
            Property.Attribute.ReadOnly | Property.Attribute.DontDelete);
        DefineOwnProperty(Key.dollar1, v,
            Property.Attribute.ReadOnly | Property.Attribute.DontDelete);
        DefineOwnProperty(Key.dollar2, v,
            Property.Attribute.ReadOnly | Property.Attribute.DontDelete);
        DefineOwnProperty(Key.dollar3, v,
            Property.Attribute.ReadOnly | Property.Attribute.DontDelete);
        DefineOwnProperty(Key.dollar4, v,
            Property.Attribute.ReadOnly | Property.Attribute.DontDelete);
        DefineOwnProperty(Key.dollar5, v,
            Property.Attribute.ReadOnly | Property.Attribute.DontDelete);
        DefineOwnProperty(Key.dollar6, v,
            Property.Attribute.ReadOnly | Property.Attribute.DontDelete);
        DefineOwnProperty(Key.dollar7, v,
            Property.Attribute.ReadOnly | Property.Attribute.DontDelete);
        DefineOwnProperty(Key.dollar8, v,
            Property.Attribute.ReadOnly | Property.Attribute.DontDelete);
        DefineOwnProperty(Key.dollar9, v,
            Property.Attribute.ReadOnly | Property.Attribute.DontDelete);

        DefineOwnProperty(Key.index, vnm1,
            Property.Attribute.ReadOnly | Property.Attribute.DontDelete);
        DefineOwnProperty(Key.lastIndex, vnm1,
            Property.Attribute.ReadOnly | Property.Attribute.DontDelete);

        CallContext cc;
        input = Get(Key.input, cc);
        multiline = Get(Key.multiline, cc);
        lastMatch = Get(Key.lastMatch, cc);
        lastParen = Get(Key.lastParen, cc);
        leftContext = Get(Key.leftContext, cc);
        rightContext = Get(Key.rightContext, cc);
        dollar[0] = lastMatch;
        dollar[1] = Get(Key.dollar1, cc);
        dollar[2] = Get(Key.dollar2, cc);
        dollar[3] = Get(Key.dollar3, cc);
        dollar[4] = Get(Key.dollar4, cc);
        dollar[5] = Get(Key.dollar5, cc);
        dollar[6] = Get(Key.dollar6, cc);
        dollar[7] = Get(Key.dollar7, cc);
        dollar[8] = Get(Key.dollar8, cc);
        dollar[9] = Get(Key.dollar9, cc);

        index = Get(Key.index, cc);
        lastIndex = Get(Key.lastIndex, cc);

        // Should lastMatch be an alias for dollar[nparens],
        // or should it be a separate property?
        // We implemented it the latter way.
        // Since both are ReadOnly, I can't see that it makes
        // any difference.
    }

    override DError* Construct(ref CallContext cc, out Value ret,
                               Value[] arglist)
    {
        // ECMA 262 v3 15.10.4.1

        Value* pattern;
        Value* flags;
        string_t P;
        string_t F;
        Dregexp r;
        Dregexp R;

        //writef("Dregexp_constructor.Construct()\n");
        ret.putVundefined();
        pattern = &undefined;
        flags = &undefined;
        switch(arglist.length)
        {
        case 0:
            break;

        default:
            flags = &arglist[1];
            goto case;
        case 1:
            pattern = &arglist[0];
            break;
        }
        R = Dregexp.isRegExp(pattern);
        if(R)
        {
            if(flags.isUndefined())
            {
                P = R.re.pattern;
                F = R.re.flags;
            }
            else
            {
                return TypeError("RegExp.prototype.constructor");
            }
        }
        else
        {
            P = pattern.isUndefined() ? "" : pattern.toString();
            F = flags.isUndefined() ? "" : flags.toString();
        }
        r = new Dregexp(P, F);
        if(r.re.errors)
        {
            return RegexpCompileError;
        }
        else
        {
            ret.put(r);
            return null;
        }
    }

    override DError* Call(ref CallContext cc, Dobject othis, out Value ret,
                          Value[] arglist)
    {
        // ECMA 262 v3 15.10.3.1
        if(arglist.length >= 1)
        {
            Value* pattern;

            pattern = &arglist[0];
            if(!pattern.isPrimitive())
            {
                if (auto reg = cast(Dregexp)pattern.object)
                {
                    if (arglist.length == 1 || arglist[1].isUndefined)
                    {
                        ret.put(reg);
                        return null;
                    }
                }
            }
        }
        return Construct(cc, ret, arglist);
    }


    alias GetImpl = Dobject.GetImpl;

    override Value* GetImpl(in ref StringKey PropertyName, ref CallContext cc)
    {
        auto sk = StringKey(perlAlias(PropertyName));
        return super.GetImpl(sk, cc);
    }

    alias SetImpl = super.SetImpl;
    override
    DError* SetImpl(in ref StringKey PropertyName, ref Value value,
                in Property.Attribute attributes, ref CallContext cc)
    {
        auto sk = StringKey(perlAlias(PropertyName));
        return Dfunction.SetImpl(sk, value, attributes, cc);
    }

    override int CanPut(in string_t PropertyName)
    {
        return Dfunction.CanPut(perlAlias(PropertyName));
    }

    override bool HasProperty(in string_t PropertyName)
    {
        return Dfunction.HasProperty(perlAlias(PropertyName));
    }

    override bool Delete(in StringKey PropertyName)
    {
        return Dfunction.Delete(StringKey(perlAlias(PropertyName)));
    }

    // Translate Perl property names to script property names
    static string_t perlAlias(string_t s)
    {
        import std.algorithm : countUntil;
        string_t t;

        static immutable char_t[] from = "_*&+`'";
        static enum string_t[] to =
        [
            Key.input,
            Key.multiline,
            Key.lastMatch,
            Key.lastParen,
            Key.leftContext,
            Key.rightContext,
        ];

        t = s;
        if(s.length == 2 && s[0] == '$')
        {
            ptrdiff_t i;

            i = countUntil(from, s[1]);
            if(i >= 0)
                t = to[i];
        }
        return t;
    }
}


/* ===================== Dregexp_prototype_toString =============== */
@DFD(0)
DError* toString(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // othis must be a RegExp
    if (auto r = cast(Dregexp)othis)
    {
        string_t s;

        s = "/";
        s ~= r.re.pattern;
        s ~= "/";
        s ~= r.re.flags;
        ret.put(s);
    }
    else
    {
        ret.putVundefined();
        return NotTransferrableError("RegExp.prototype.toString()");
    }
    return null;
}

/* ===================== Dregexp_prototype_test =============== */
@DFD(1)
DError* test(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.10.6.3 says this is equivalent to:
    //	RegExp.prototype.exec(string) != null
    return Dregexp.exec(othis, ret, arglist, EXEC_BOOLEAN);
}

/* ===================== Dregexp_prototype_exec ============= */
@DFD(1)
DError* exec(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    return Dregexp.exec(othis, ret, arglist, EXEC_ARRAY);
}


/* ===================== Dregexp_prototype_compile ============= */
@DFD(2)
DError* compile(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // RegExp.prototype.compile(pattern, attributes)

    // othis must be a RegExp
    if (auto dr = cast(Dregexp)othis)
    {
        string_t pattern;
        string_t attributes;
        RegExp r;

        switch(arglist.length)
        {
        case 0:
            break;

        default:
            attributes = arglist[1].toString();
            goto case;
        case 1:
            pattern = arglist[0].toString();
            break;
        }

        r = dr.re;
        try
        {
            r.compile(pattern, attributes);
        }
        catch(RegexException e)
        {
            // Affect source, global and ignoreCase properties
            dr.source.put(r.pattern);
            dr.global.put(r.global);
            dr.ignoreCase.put(r.ignoreCase);
        }
        //writef("r.attributes = x%x\n", r.attributes);
    }
    else
    {
        ret.putVundefined();
        return NotTransferrableError("RegExp.prototype.compile()");
    }

    // Documentation says nothing about a return value,
    // so let's use "undefined"
    ret.putVundefined();
    return null;
}

/* ===================== Dregexp_prototype ==================== */
/*
class DregexpPrototype : Dregexp
{
    this()
    {
        super(Dobject.getPrototype, Key.Object);
        auto attributes =
            Property.Attribute.ReadOnly |
            Property.Attribute.DontDelete |
            Property.Attribute.DontEnum;
        Dobject f = Dfunction.getPrototype;

        DefineOwnProperty(Key.constructor, Dregexp.getConstructor, attributes);

        static enum NativeFunctionData[] nfd =
        [
            { Key.toString, &Dregexp_prototype_toString, 0 },
            { Key.compile, &Dregexp_prototype_compile, 2 },
            { Key.exec, &Dregexp_prototype_exec, 1 },
            { Key.test, &Dregexp_prototype_test, 1 },
        ];

        DnativeFunction.initialize(this, nfd, attributes);
    }
}
//*/

/* ===================== Dregexp ==================== */


class Dregexp : Dobject
{
    import dmdscript.dobject : Initializer;

    Value* global;
    Value* ignoreCase;
    Value* multiline;
    Value* lastIndex;
    Value* source;

    RegExp re;

    this(string_t pattern, string_t attributes)
    {
        super(getPrototype, Key.RegExp);

        Value v;
        v.put(Text.Empty);

        Value vb;
        vb.put(false);

        CallContext cc;
        Set(Key.source, v,
            Property.Attribute.ReadOnly |
            Property.Attribute.DontDelete |
            Property.Attribute.DontEnum, cc);
        Set(Key.global, vb,
            Property.Attribute.ReadOnly |
            Property.Attribute.DontDelete |
            Property.Attribute.DontEnum, cc);
        Set(Key.ignoreCase, vb,
            Property.Attribute.ReadOnly |
            Property.Attribute.DontDelete |
            Property.Attribute.DontEnum, cc);
        Set(Key.multiline, vb,
            Property.Attribute.ReadOnly |
            Property.Attribute.DontDelete |
            Property.Attribute.DontEnum, cc);
        Set(Key.lastIndex, 0.0,
            Property.Attribute.DontDelete |
            Property.Attribute.DontEnum, cc);

        source = Get(Key.source, cc);
        global = Get(Key.global, cc);
        ignoreCase = Get(Key.ignoreCase, cc);
        multiline = Get(Key.multiline, cc);
        lastIndex = Get(Key.lastIndex, cc);

        re = new RegExp(pattern, attributes);
        if(re.errors == 0)
        {
            source.put(pattern);
            //writef("source = '%s'\n", source.x.string.toDchars());
            global.put(re.global);
            ignoreCase.put(re.ignoreCase);
            multiline.put(re.multiline);
        }
        else
        {
            // have caller throw SyntaxError
        }
    }

    this(Dobject prototype, string_t cname = Key.RegExp)
    {
        super(prototype, cname);

        Value v;
        v.put(Text.Empty);

        Value vb;
        vb.put(false);

        CallContext cc;
        Set(Key.source, v,
            Property.Attribute.ReadOnly |
            Property.Attribute.DontDelete |
            Property.Attribute.DontEnum, cc);
        Set(Key.global, vb,
            Property.Attribute.ReadOnly |
            Property.Attribute.DontDelete |
            Property.Attribute.DontEnum, cc);
        Set(Key.ignoreCase, vb,
            Property.Attribute.ReadOnly |
            Property.Attribute.DontDelete |
            Property.Attribute.DontEnum, cc);
        Set(Key.multiline, vb,
            Property.Attribute.ReadOnly |
            Property.Attribute.DontDelete |
            Property.Attribute.DontEnum, cc);
        Set(Key.lastIndex, 0.0,
            Property.Attribute.DontDelete |
            Property.Attribute.DontEnum, cc);

        source = Get(Key.source, cc);
        global = Get(Key.global, cc);
        ignoreCase = Get(Key.ignoreCase, cc);
        multiline = Get(Key.multiline, cc);
        lastIndex = Get(Key.lastIndex, cc);

        re = new RegExp(null, null);
    }

    override DError* Call(ref CallContext cc, Dobject othis, out Value ret,
                          Value[] arglist)
    {
        // This is the same as calling RegExp.prototype.exec(str)
        Value* v;

        v = Get(Key.exec, cc);
        return v.toObject().Call(cc, this, ret, arglist);
    }

static:
    Dregexp isRegExp(Value* v)
    {
        if      (v.isPrimitive)
            return null;
        else
            return cast(Dregexp)v.toObject;
    }

    DError* exec(Dobject othis, out Value ret, Value[] arglist, int rettype)
    {
        //writef("Dregexp.exec(arglist.length = %d, rettype = %d)\n", arglist.length, rettype);

        // othis must be a RegExp
        if (auto dr = cast(Dregexp)othis)
        {
            string_t s;
            RegExp r;
            DregexpConstructor dc;
            uint i;
            int lasti;
            CallContext cc;

            if(arglist.length)
                s = arglist[0].toString();
            else
            {
                Dfunction df;

                df = Dregexp.getConstructor();
                s = (cast(DregexpConstructor)df).input.text;
            }

            r = dr.re;
            dc = cast(DregexpConstructor)Dregexp.getConstructor();

            // Decide if we are multiline
            r.multiline = 0 != dr.multiline.dbool;

            if(r.global && rettype != EXEC_INDEX)
                lasti = cast(int)dr.lastIndex.toInteger(cc);
            else
                lasti = 0;

            if(r.test(s, lasti))
            {   // Successful match
                Value* lastv;
                uint nmatches;

                if(r.global && rettype != EXEC_INDEX)
                {
                    dr.lastIndex.put(r.lastIndex);
                }

                dc.input.put(r.input);

                dc.lastMatch.put(r.lastMatch);

                dc.leftContext.put(r.leftContext);

                dc.rightContext.put(r.rightContext);

                dc.index.put(r.index);
                dc.lastIndex.put(r.lastIndex);

                // Fill in $1..$9
                lastv = &undefined;
                nmatches = r.nmatches;
                for(i = 1; i <= 9; i++)
                {
                    auto n = i;
                    // Use last 9 entries for $1 .. $9
                    if (9 < nmatches)
                        n += nmatches - 9;

                    if (n <= nmatches)
                    {
                        s = r.captures(n);
                        if (s !is null)
                            dc.dollar[i].put(s);
                        else
                            dc.dollar[i].putVundefined;
                        lastv = dc.dollar[i];
                    }
                    else
                        dc.dollar[i].putVundefined;
                }

                // Last substring in $1..$9, or "" if none
                if(0 < nmatches)
                    *dc.lastParen = *lastv;
                else
                    dc.lastParen.put(Text.Empty);

                switch(rettype)
                {
                case EXEC_ARRAY:
                {
                    Darray a = new Darray();

                    a.Set(Key.input, r.input, Property.Attribute.None, cc);
                    a.Set(Key.index, r.index, Property.Attribute.None, cc);
                    a.Set(Key.lastIndex, r.lastIndex,
                          Property.Attribute.None, cc);

                    a.Set(cast(uint)0, *dc.lastMatch,
                          Property.Attribute.None, cc);

                    // [1]..[nparens]
                    if (nmatches < 9)
                        nmatches = 9;
                    for(i = 1; i <= nmatches; i++)
                    {
                        if(i > r.nmatches)
                            a.Set(i, Text.Empty, Property.Attribute.None, cc);

                        // Reuse values already put into dc.dollar[]
                        else if(r.nmatches <= 9)
                            a.Set(i, *dc.dollar[i],
                                  Property.Attribute.None, cc);
                        else if(i > r.nmatches - 9)
                            a.Set(i, *dc.dollar[i - (r.nmatches - 9)],
                                  Property.Attribute.None, cc);
                        else if(r.captures(i) is null)
                        {
                            a.Set(i, vundefined, Property.Attribute.None, cc);
                        }
                        else
                        {
                            a.Set(i, r.captures(i),
                                  Property.Attribute.None, cc);
                        }
                    }
                    ret.put(a);
                    break;
                }
                case EXEC_STRING:
                    ret = *dc.lastMatch;
                    break;

                case EXEC_BOOLEAN:
                    ret.put(true);      // success
                    break;

                case EXEC_INDEX:
                    ret.put(r.index);
                    break;

                default:
                    assert(0);
                }
            }
            else        // failed to match
            {
                //writef("failed\n");
                switch(rettype)
                {
                case EXEC_ARRAY:
                    //writef("memcpy\n");
                    ret.putVnull();         // Return null
                    dr.lastIndex.put(0);
                    break;

                case EXEC_STRING:
                    ret.put(Text.Empty);
                    dr.lastIndex.put(0);
                    break;

                case EXEC_BOOLEAN:
                    ret.put(false);
                    dr.lastIndex.put(0);
                    break;

                case EXEC_INDEX:
                    ret.put(-1.0);
                    // Do not set lastIndex
                    break;

                default:
                    assert(0);
                }
            }
        }
        else
        {
            ret.putVundefined();
            return NotTransferrableError("RegExp.prototype.exec()");
        }

        return null;
    }

    mixin Initializer!DregexpConstructor;
/*
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
        _constructor = new DregexpConstructor();
        _prototype = new DregexpPrototype();

        version(none)
        {
            writef("Dregexp_constructor = %x\n", _constructor);
            uint *p;
            p = cast(uint *)_constructor;
            writef("p = %x\n", p);
            if(p)
                writef("*p = %x, %x, %x, %x\n", p[0], p[1], p[2], p[3]);
        }

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



package
{
    import std.regex;

    class RegExp
    {
        string pattern, flags;
        bool global, ignoreCase, multiline;
        int errors;

        this(string pattern, string attributes)
        {
            compile(pattern, attributes);
        }

        void compile(string pattern, string attributes)
        {
            import std.string : replace;

            this.pattern = pattern;
            flags = attributes;
            foreach(c; attributes)
            {
                switch(c)
                {
                case 'g':
                    global = true;
                    break;
                case 'i':
                    ignoreCase = true;
                    break;
                case 'm':
                    multiline = true;
                    break;
                default:
                }
            }

            if (global)
                attributes = attributes.replace("g", "");

            try
            {
                r = regex(pattern, attributes);
            }
            catch(Throwable)
            {
                errors = 1;
            }
            m.destroy;
            src = null;
        }

        bool test(string str, size_t startIndex)
        {
            src = str;

            assert(r !is typeof(r).init);
            m = str[startIndex..$].match(r);
            assert(m !is typeof(m).init);

            return !m.empty;
        }

        @property
        size_t index()
        {
            assert(m !is typeof(m).init && !m.empty && src !is null);
            return cast(size_t)(m.hit.ptr - src.ptr);
        }

        @property
        size_t lastIndex()
        {
            assert(m !is typeof(m).init && !m.empty && src !is null);
            return cast(size_t)(m.post.ptr - src.ptr);
        }

        @property
        string input()
        {
            return src;
        }

        @property
        string lastMatch()
        {
            assert(m !is typeof(m).init && !m.empty);
            return m.hit;
        }

        @property
        string leftContext()
        {
            assert(m !is typeof(m).init && !m.empty && src !is null);
            return src[0..(m.hit.ptr - src.ptr)];
        }

        @property
        string rightContext()
        {
            assert(m !is typeof(m).init && !m.empty);
            return m.post;
        }

        string captures(size_t i)
        {
            assert(m !is typeof(m).init && !m.empty);
            assert(i < m.front.length);

            return m.front[i];
        }

        sizediff_t capturesIndex(size_t i)
        {
            assert(m !is typeof(m).init && !m.empty && src !is null);
            if (i < m.front.length)
                return m.front[i].ptr - src.ptr;
            else
                return -1;
        }

        sizediff_t capturesLastIndex(size_t i)
        {
            assert(m !is typeof(m).init && !m.empty && src !is null);
            if (i < m.front.length)
                return m.front[i].ptr - src.ptr + m.front[i].length;
            else
                return -1;
        }

        @property
        size_t nmatches()
        {
            assert(m !is typeof(m).init && !m.empty);

            return m.front.length - 1;
        }

        string replace(string fmt)
        {
            auto m2 = new string[m.front.length];

            for (size_t i = 0; i < m.front.length; ++i)
                m2[i] = m.front[i];

            return replace3(fmt, src, m2);
        }

        // from undead.regexp.RegExp.replace3
        static string replace3(string fmt, string src, string[] m)
        {
            import std.array : Appender;
            assert(src !is null && 0 < m.length);
            assert(src.ptr <= m[0].ptr &&
                   m[0].ptr + m[0].length <= src.ptr + src.length);

            Appender!string result;
            int i;
            char c, c2;

            result.reserve = fmt.length;
            for (size_t f = 0; f < fmt.length; ++f)
            {
                c = fmt[f];
            L1:
                if (c != '$')
                {
                    result.put(c);
                    continue;
                }
                ++f;
                if (f == fmt.length)
                {
                    result.put(c);
                    break;
                }

                c = fmt[f];
                switch (c)
                {
                case '&':
                    result.put(m[0]);
                    break;
                case '`':
                    result.put(src[0..(m[0].ptr - src.ptr)]);
                    break;
                case '\'':
                    result.put(src[m[0].ptr - src.ptr + m[0].length .. $]);
                    break;

                case '0': .. case '9':
                    i = c - '0';
                    if (f+1 == fmt.length)
                    {
                        if (i == 0)
                        {
                            result.put('$');
                            result.put(c);
                        }
                    }
                    else
                    {
                        c2 = fmt[f+1];
                        if (c2 >= '0' && c2 <= '9')
                        {
                            i = (c - '0') * 10 + (c2 - '0');
                            ++f;
                        }
                        if (i == 0)
                        {
                            result.put('$');
                            result.put(c);
                            c = c2;
                            goto L1;
                        }
                    }

                    if (i < m.length)
                        result.put(m[i]);
                    break;

                default:
                    result.put('$');
                    result.put(c);
                    break;
                }
            }
            return result.data;
        }


    private:
        Regex!char r;
        RegexMatch!string m;
        string_t src;
    }
}

private:
enum Key : StringKey
{
    RegExp = PKey.RegExp,
    prototype = PKey.prototype,
    constructor = PKey.constructor,
    global = PKey.global,

    input = StringKey("input"),
    multiline = StringKey("multiline"),
    lastIndex = StringKey("lastIndex"),
    lastMatch = StringKey("lastMatch"),
    lastParen = StringKey("lastParen"),
    leftContext = StringKey("leftContext"),
    rightContext = StringKey("rightContext"),

    dollar1 = StringKey("$1"),
    dollar2 = StringKey("$2"),
    dollar3 = StringKey("$3"),
    dollar4 = StringKey("$4"),
    dollar5 = StringKey("$5"),
    dollar6 = StringKey("$6"),
    dollar7 = StringKey("$7"),
    dollar8 = StringKey("$8"),
    dollar9 = StringKey("$9"),
    index = StringKey("index"),

    source = StringKey("source"),
    ignoreCase = StringKey("ignoreCase"),
    exec = StringKey("exec"),
}

