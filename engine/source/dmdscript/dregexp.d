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

import dmdscript.script;
import dmdscript.dobject;
import dmdscript.value;
import dmdscript.protoerror;
import dmdscript.text;
import dmdscript.darray;
import dmdscript.dfunction;
import dmdscript.property;
import dmdscript.errmsgs;
import dmdscript.dnative;

//alias script.tchar tchar;

// Values for Dregexp.exec.rettype
enum { EXEC_STRING, EXEC_ARRAY, EXEC_BOOLEAN, EXEC_INDEX };


/* ===================== Dregexp_constructor ==================== */

class DregexpConstructor : Dfunction
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
        super(2, Dfunction.getPrototype);

        Value v;
        v.putVstring(null);

        Value vb;
        vb.putVboolean(false);

        Value vnm1;
        vnm1.putVnumber(-1);

        name = "RegExp";

        // Static properties
        Put(Text.input, v, Property.Attribute.DontDelete);
        Put(Text.multiline, vb, Property.Attribute.DontDelete);
        Put(Text.lastMatch, v,
            Property.Attribute.ReadOnly | Property.Attribute.DontDelete);
        Put(Text.lastParen, v,
            Property.Attribute.ReadOnly | Property.Attribute.DontDelete);
        Put(Text.leftContext, v,
            Property.Attribute.ReadOnly | Property.Attribute.DontDelete);
        Put(Text.rightContext, v,
            Property.Attribute.ReadOnly | Property.Attribute.DontDelete);
        Put(Text.dollar1, v,
            Property.Attribute.ReadOnly | Property.Attribute.DontDelete);
        Put(Text.dollar2, v,
            Property.Attribute.ReadOnly | Property.Attribute.DontDelete);
        Put(Text.dollar3, v,
            Property.Attribute.ReadOnly | Property.Attribute.DontDelete);
        Put(Text.dollar4, v,
            Property.Attribute.ReadOnly | Property.Attribute.DontDelete);
        Put(Text.dollar5, v,
            Property.Attribute.ReadOnly | Property.Attribute.DontDelete);
        Put(Text.dollar6, v,
            Property.Attribute.ReadOnly | Property.Attribute.DontDelete);
        Put(Text.dollar7, v,
            Property.Attribute.ReadOnly | Property.Attribute.DontDelete);
        Put(Text.dollar8, v,
            Property.Attribute.ReadOnly | Property.Attribute.DontDelete);
        Put(Text.dollar9, v,
            Property.Attribute.ReadOnly | Property.Attribute.DontDelete);

        Put(Text.index, vnm1,
            Property.Attribute.ReadOnly | Property.Attribute.DontDelete);
        Put(Text.lastIndex, vnm1,
            Property.Attribute.ReadOnly | Property.Attribute.DontDelete);

        input = Get(Text.input);
        multiline = Get(Text.multiline);
        lastMatch = Get(Text.lastMatch);
        lastParen = Get(Text.lastParen);
        leftContext = Get(Text.leftContext);
        rightContext = Get(Text.rightContext);
        dollar[0] = lastMatch;
        dollar[1] = Get(Text.dollar1);
        dollar[2] = Get(Text.dollar2);
        dollar[3] = Get(Text.dollar3);
        dollar[4] = Get(Text.dollar4);
        dollar[5] = Get(Text.dollar5);
        dollar[6] = Get(Text.dollar6);
        dollar[7] = Get(Text.dollar7);
        dollar[8] = Get(Text.dollar8);
        dollar[9] = Get(Text.dollar9);

        index = Get(Text.index);
        lastIndex = Get(Text.lastIndex);

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
        d_string P;
        d_string F;
        Dregexp r;
        Dregexp R;

        //writef("Dregexp_constructor.Construct()\n");
        ret.putVundefined();
        pattern = &vundefined;
        flags = &vundefined;
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
            ret.putVobject(r);
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
            Dobject o;

            pattern = &arglist[0];
            if(!pattern.isPrimitive())
            {
                o = pattern.object;
                if(o.isDregexp() &&
                   (arglist.length == 1 || arglist[1].isUndefined())
                   )
                {
                    ret.putVobject(o);
                    return null;
                }
            }
        }
        return Construct(cc, ret, arglist);
    }


    override Value* Get(in d_string PropertyName)
    {
        return Dfunction.Get(perlAlias(PropertyName));
    }

    override DError* Put(in d_string PropertyName, ref Value value,
                         in Property.Attribute attributes)
    {
        return Dfunction.Put(perlAlias(PropertyName), value, attributes);
    }

    override DError* Put(in d_string PropertyName, Dobject o,
                         in Property.Attribute attributes)
    {
        return Dfunction.Put(perlAlias(PropertyName), o, attributes);
    }

    override DError* Put(in d_string PropertyName, in d_number n,
                         in Property.Attribute attributes)
    {
        return Dfunction.Put(perlAlias(PropertyName), n, attributes);
    }

    override int CanPut(in d_string PropertyName)
    {
        return Dfunction.CanPut(perlAlias(PropertyName));
    }

    override int HasProperty(in d_string PropertyName)
    {
        return Dfunction.HasProperty(perlAlias(PropertyName));
    }

    override int Delete(in d_string PropertyName)
    {
        return Dfunction.Delete(perlAlias(PropertyName));
    }

    // Translate Perl property names to script property names
    static d_string perlAlias(d_string s)
    {
        import std.algorithm : countUntil;
        d_string t;

        static immutable tchar[] from = "_*&+`'";
        static enum d_string[] to =
        [
            Text.input,
            Text.multiline,
            Text.lastMatch,
            Text.lastParen,
            Text.leftContext,
            Text.rightContext,
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

DError* Dregexp_prototype_toString(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // othis must be a RegExp
    Dregexp r;

    if(!othis.isDregexp())
    {
        ret.putVundefined();
        return NotTransferrableError("RegExp.prototype.toString()");
    }
    else
    {
        d_string s;

        r = cast(Dregexp)(othis);
        s = "/";
        s ~= r.re.pattern;
        s ~= "/";
        s ~= r.re.flags;
        ret.putVstring(s);
    }
    return null;
}

/* ===================== Dregexp_prototype_test =============== */

DError* Dregexp_prototype_test(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.10.6.3 says this is equivalent to:
    //	RegExp.prototype.exec(string) != null
    return Dregexp.exec(othis, ret, arglist, EXEC_BOOLEAN);
}

/* ===================== Dregexp_prototype_exec ============= */

DError* Dregexp_prototype_exec(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    return Dregexp.exec(othis, ret, arglist, EXEC_ARRAY);
}


/* ===================== Dregexp_prototype_compile ============= */

DError* Dregexp_prototype_compile(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // RegExp.prototype.compile(pattern, attributes)

    // othis must be a RegExp
    if(!othis.isClass(Text.RegExp))
    {
        ret.putVundefined();
        return NotTransferrableError("RegExp.prototype.compile()");
    }
    else
    {
        d_string pattern;
        d_string attributes;
        Dregexp dr;
        RegExp r;

        dr = cast(Dregexp)othis;
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
            dr.source.putVstring(r.pattern);
            dr.global.putVboolean(r.global);
            dr.ignoreCase.putVboolean(r.ignoreCase);
        }
        //writef("r.attributes = x%x\n", r.attributes);
    }
    // Documentation says nothing about a return value,
    // so let's use "undefined"
    ret.putVundefined();
    return null;
}

/* ===================== Dregexp_prototype ==================== */

class DregexpPrototype : Dregexp
{
    this()
    {
        super(Dobject.getPrototype);
        classname = Text.Object;
        auto attributes =
            Property.Attribute.ReadOnly |
            Property.Attribute.DontDelete |
            Property.Attribute.DontEnum;
        Dobject f = Dfunction.getPrototype;

        Put(Text.constructor, Dregexp.getConstructor, attributes);

        static enum NativeFunctionData[] nfd =
        [
            { Text.toString, &Dregexp_prototype_toString, 0 },
            { Text.compile, &Dregexp_prototype_compile, 2 },
            { Text.exec, &Dregexp_prototype_exec, 1 },
            { Text.test, &Dregexp_prototype_test, 1 },
        ];

        DnativeFunction.initialize(this, nfd, attributes);
    }
}


/* ===================== Dregexp ==================== */


class Dregexp : Dobject
{
    Value* global;
    Value* ignoreCase;
    Value* multiline;
    Value* lastIndex;
    Value* source;

    RegExp re;

    this(d_string pattern, d_string attributes)
    {
        super(getPrototype());

        Value v;
        v.putVstring(null);

        Value vb;
        vb.putVboolean(false);

        classname = Text.RegExp;

        //writef("Dregexp.Dregexp(pattern = '%ls', attributes = '%ls')\n", d_string_ptr(pattern), d_string_ptr(attributes));
        Put(Text.source, v,
            Property.Attribute.ReadOnly |
            Property.Attribute.DontDelete |
            Property.Attribute.DontEnum);
        Put(Text.global, vb,
            Property.Attribute.ReadOnly |
            Property.Attribute.DontDelete |
            Property.Attribute.DontEnum);
        Put(Text.ignoreCase, vb,
            Property.Attribute.ReadOnly |
            Property.Attribute.DontDelete |
            Property.Attribute.DontEnum);
        Put(Text.multiline, vb,
            Property.Attribute.ReadOnly |
            Property.Attribute.DontDelete |
            Property.Attribute.DontEnum);
        Put(Text.lastIndex, 0.0,
            Property.Attribute.DontDelete |
            Property.Attribute.DontEnum);

        source = Get(Text.source);
        global = Get(Text.global);
        ignoreCase = Get(Text.ignoreCase);
        multiline = Get(Text.multiline);
        lastIndex = Get(Text.lastIndex);

        re = new RegExp(pattern, attributes);
        if(re.errors == 0)
        {
            source.putVstring(pattern);
            //writef("source = '%s'\n", source.x.string.toDchars());
            global.putVboolean(re.global);
            ignoreCase.putVboolean(re.ignoreCase);
            multiline.putVboolean(re.multiline);
        }
        else
        {
            // have caller throw SyntaxError
        }
    }

    this(Dobject prototype)
    {
        super(prototype);

        Value v;
        v.putVstring(null);

        Value vb;
        vb.putVboolean(false);

        classname = Text.RegExp;

        Put(Text.source, v,
            Property.Attribute.ReadOnly |
            Property.Attribute.DontDelete |
            Property.Attribute.DontEnum);
        Put(Text.global, vb,
            Property.Attribute.ReadOnly |
            Property.Attribute.DontDelete |
            Property.Attribute.DontEnum);
        Put(Text.ignoreCase, vb,
            Property.Attribute.ReadOnly |
            Property.Attribute.DontDelete |
            Property.Attribute.DontEnum);
        Put(Text.multiline, vb,
            Property.Attribute.ReadOnly |
            Property.Attribute.DontDelete |
            Property.Attribute.DontEnum);
        Put(Text.lastIndex, 0.0,
            Property.Attribute.DontDelete |
            Property.Attribute.DontEnum);

        source = Get(Text.source);
        global = Get(Text.global);
        ignoreCase = Get(Text.ignoreCase);
        multiline = Get(Text.multiline);
        lastIndex = Get(Text.lastIndex);

        re = new RegExp(null, null);
    }

    override DError* Call(ref CallContext cc, Dobject othis, out Value ret,
                          Value[] arglist)
    {
        // This is the same as calling RegExp.prototype.exec(str)
        Value* v;

        v = Get(Text.exec);
        return v.toObject().Call(cc, this, ret, arglist);
    }

static:
    Dregexp isRegExp(Value* v)
    {
        Dregexp r;

        if(!v.isPrimitive() && v.toObject().isDregexp())
        {
            r = cast(Dregexp)(v.toObject());
        }
        return r;
    }

    DError* exec(Dobject othis, out Value ret, Value[] arglist, int rettype)
    {
        //writef("Dregexp.exec(arglist.length = %d, rettype = %d)\n", arglist.length, rettype);

        // othis must be a RegExp
        if(!othis.isClass(Text.RegExp))
        {
            ret.putVundefined();
            return NotTransferrableError("RegExp.prototype.exec()");
        }
        else
        {
            d_string s;
            Dregexp dr;
            RegExp r;
            DregexpConstructor dc;
            uint i;
            d_int32 lasti;

            if(arglist.length)
                s = arglist[0].toString();
            else
            {
                Dfunction df;

                df = Dregexp.getConstructor();
                s = (cast(DregexpConstructor)df).input.text;
            }

            dr = cast(Dregexp)othis;
            r = dr.re;
            dc = cast(DregexpConstructor)Dregexp.getConstructor();

            // Decide if we are multiline
            r.multiline = 0 != dr.multiline.dbool;

            if(r.global && rettype != EXEC_INDEX)
                lasti = cast(int)dr.lastIndex.toInteger();
            else
                lasti = 0;

            if(r.test(s, lasti))
            {   // Successful match
                Value* lastv;
                uint nmatches;

                if(r.global && rettype != EXEC_INDEX)
                {
                    dr.lastIndex.putVnumber(r.lastIndex);
                }

                dc.input.putVstring(r.input);

                dc.lastMatch.putVstring(r.lastMatch);

                dc.leftContext.putVstring(r.leftContext);

                dc.rightContext.putVstring(r.rightContext);

                dc.index.putVnumber(r.index);
                dc.lastIndex.putVnumber(r.lastIndex);

                // Fill in $1..$9
                lastv = &vundefined;
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
                            dc.dollar[i].putVstring(s);
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
                    dc.lastParen.putVstring(null);

                switch(rettype)
                {
                case EXEC_ARRAY:
                {
                    Darray a = new Darray();

                    a.Put(Text.input, r.input, Property.Attribute.None);
                    a.Put(Text.index, r.index, Property.Attribute.None);
                    a.Put(Text.lastIndex, r.lastIndex, Property.Attribute.None);

                    a.Put(cast(d_uint32)0, *dc.lastMatch,
                          Property.Attribute.None);

                    // [1]..[nparens]
                    if (nmatches < 9)
                        nmatches = 9;
                    for(i = 1; i <= nmatches; i++)
                    {
                        if(i > r.nmatches)
                            a.Put(i, Text.Empty, Property.Attribute.None);

                        // Reuse values already put into dc.dollar[]
                        else if(r.nmatches <= 9)
                            a.Put(i, *dc.dollar[i], Property.Attribute.None);
                        else if(i > r.nmatches - 9)
                            a.Put(i, *dc.dollar[i - (r.nmatches - 9)],
                                  Property.Attribute.None);
                        else if(r.captures(i) is null)
                        {
                            a.Put(i, vundefined, Property.Attribute.None);
                        }
                        else
                        {
                            a.Put(i, r.captures(i), Property.Attribute.None);
                        }
                    }
                    ret.putVobject(a);
                    break;
                }
                case EXEC_STRING:
                    ret = *dc.lastMatch;
                    break;

                case EXEC_BOOLEAN:
                    ret.putVboolean(true);      // success
                    break;

                case EXEC_INDEX:
                    ret.putVnumber(r.index);
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
                    dr.lastIndex.putVnumber(0);
                    break;

                case EXEC_STRING:
                    ret.putVstring(null);
                    dr.lastIndex.putVnumber(0);
                    break;

                case EXEC_BOOLEAN:
                    ret.putVboolean(false);
                    dr.lastIndex.putVnumber(0);
                    break;

                case EXEC_INDEX:
                    ret.putVnumber(-1.0);
                    // Do not set lastIndex
                    break;

                default:
                    assert(0);
                }
            }
        }
        return null;
    }

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

        _constructor.Put(Text.prototype, _prototype,
                         Property.Attribute.DontEnum |
                         Property.Attribute.DontDelete |
                         Property.Attribute.ReadOnly);
    }
private:
    Dfunction _constructor;
    Dobject _prototype;
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
        d_string src;
    }
}
