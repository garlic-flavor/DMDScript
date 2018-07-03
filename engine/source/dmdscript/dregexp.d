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

import dmdscript.primitive : PropertyKey, Text, PKey = Key;
import dmdscript.dobject;
import dmdscript.value;
// import dmdscript.protoerror;
import dmdscript.darray;
import dmdscript.dfunction;
import dmdscript.property;
import dmdscript.errmsgs;
import dmdscript.dnative : DnativeFunction, DFD = DnativeFunctionDescriptor;
import dmdscript.drealm: undefined, Drealm;
import dmdscript.callcontext: CallContext;
import dmdscript.derror: Derror;

debug import std.stdio;


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

    this(Dobject superClassPrototype, Dobject functionPrototype)
    {
        alias PA = Property.Attribute;
        super(new Dobject(superClassPrototype), functionPrototype,
              Key.RegExp, 2);
        install(functionPrototype);

        Value v;
        v.put(Text.Empty);

        Value vb;
        vb.put(false);

        Value vnm1;
        vnm1.put(-1);

        // Static properties
        DefineOwnProperty(Key.input, v, PA.DontDelete);
        DefineOwnProperty(Key.multiline, vb, PA.DontDelete);
        DefineOwnProperty(Key.lastMatch, v, PA.ReadOnly | PA.DontDelete);
        DefineOwnProperty(Key.lastParen, v, PA.ReadOnly | PA.DontDelete);
        DefineOwnProperty(Key.leftContext, v, PA.ReadOnly | PA.DontDelete);
        DefineOwnProperty(Key.rightContext, v, PA.ReadOnly | PA.DontDelete);
        DefineOwnProperty(Key.dollar1, v, PA.ReadOnly | PA.DontDelete);
        DefineOwnProperty(Key.dollar2, v, PA.ReadOnly | PA.DontDelete);
        DefineOwnProperty(Key.dollar3, v, PA.ReadOnly | PA.DontDelete);
        DefineOwnProperty(Key.dollar4, v, PA.ReadOnly | PA.DontDelete);
        DefineOwnProperty(Key.dollar5, v, PA.ReadOnly | PA.DontDelete);
        DefineOwnProperty(Key.dollar6, v, PA.ReadOnly | PA.DontDelete);
        DefineOwnProperty(Key.dollar7, v, PA.ReadOnly | PA.DontDelete);
        DefineOwnProperty(Key.dollar8, v, PA.ReadOnly | PA.DontDelete);
        DefineOwnProperty(Key.dollar9, v, PA.ReadOnly | PA.DontDelete);

        DefineOwnProperty(Key.index, vnm1, PA.ReadOnly | PA.DontDelete);
        DefineOwnProperty(Key.lastIndex, vnm1,
                          PA.ReadOnly | PA.DontDelete | PA.DontConfig);

        input = proptable.getOwnData(Key.input);
        multiline = proptable.getOwnData(Key.multiline);
        lastMatch = proptable.getOwnData(Key.lastMatch);
        lastParen = proptable.getOwnData(Key.lastParen);
        leftContext = proptable.getOwnData(Key.leftContext);
        rightContext = proptable.getOwnData(Key.rightContext);
        dollar[0] = lastMatch;
        dollar[1] = proptable.getOwnData(Key.dollar1);
        dollar[2] = proptable.getOwnData(Key.dollar2);
        dollar[3] = proptable.getOwnData(Key.dollar3);
        dollar[4] = proptable.getOwnData(Key.dollar4);
        dollar[5] = proptable.getOwnData(Key.dollar5);
        dollar[6] = proptable.getOwnData(Key.dollar6);
        dollar[7] = proptable.getOwnData(Key.dollar7);
        dollar[8] = proptable.getOwnData(Key.dollar8);
        dollar[9] = proptable.getOwnData(Key.dollar9);

        index = proptable.getOwnData(Key.index);
        lastIndex = proptable.getOwnData(Key.lastIndex);

        // Should lastMatch be an alias for dollar[nparens],
        // or should it be a separate property?
        // We implemented it the latter way.
        // Since both are ReadOnly, I can't see that it makes
        // any difference.
    }

    nothrow
    Dregexp opCall(ARGS...)(ARGS args)
    {
        return new Dregexp(classPrototype, args);
    }

    override Derror Construct(CallContext* cc, out Value ret, Value[] arglist)
    {
        import dmdscript.primitive : Text;
        // ECMA 262 v3 15.10.4.1

        Value* pattern;
        Value* flags;
        string P;
        string F;
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
        R = Dregexp.isRegExp(cc, pattern);
        if(R)
        {
            if(flags.isUndefined)
            {
                P = R.re.pattern;
                F = R.re.flags;
            }
            else
            {
                return TypeError(cc, "RegExp.prototype.constructor");
            }
        }
        else
        {
            if (pattern.isUndefined)
                P = Text.Empty;
            else
                pattern.to(P, cc);
            if (flags.isUndefined)
                F = Text.Empty;
            else
                flags.to(F, cc);
        }
        r = opCall(P, F);
        if(r.re.errors !is null)
        {
            try return RegexpCompileError(cc, r.re.errors.toString);
            catch(Throwable) return null;
        }
        else
        {
            ret.put(r);
            return null;
        }
    }

    override Derror Call(CallContext* cc, Dobject othis, out Value ret,
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

    override
    Derror Get(in PropertyKey PropertyName,  out Value* ret, CallContext* cc)
    {
        auto sk = PropertyKey(perlAlias(PropertyName.toString));
        return super.Get(sk, ret, cc);
    }

    override
    Derror Set(in PropertyKey PropertyName, ref Value value,
                in Property.Attribute attributes, CallContext* cc)
    {
        auto sk = PropertyKey(perlAlias(PropertyName.toString));
        return Dfunction.Set(sk, value, attributes, cc);
    }

    override int CanPut(in string PropertyName)
    {
        return Dfunction.CanPut(perlAlias(PropertyName));
    }

    override bool HasProperty(in PropertyKey PropertyName)
    {
        auto key = PropertyKey(perlAlias(PropertyName));
        return Dfunction.HasProperty(key);
    }

    override bool Delete(in PropertyKey PropertyName)
    {
        auto pk = PropertyKey(perlAlias(PropertyName.toString));
        return Dfunction.Delete(pk);
    }

    // Translate Perl property names to script property names
    nothrow
    static string perlAlias(string s)
    {
        import std.algorithm : countUntil;
        string t;

        static immutable char[] from = "_*&+`'";
        static enum string[] to =
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

            try i = countUntil(from, s[1]);
            catch(Throwable){}
            if(i >= 0)
                t = to[i];
        }
        return t;
    }
}


/* ===================== Dregexp_prototype_toString =============== */
@DFD(0)
Derror toString(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // othis must be a RegExp
    if (auto r = cast(Dregexp)othis)
    {
        string s;

        s = "/";
        s ~= r.re.pattern;
        s ~= "/";
        s ~= r.re.flags;
        ret.put(s);
    }
    else
    {
        ret.putVundefined();
        return NotTransferrableError(cc, "RegExp.prototype.toString()");
    }
    return null;
}

/* ===================== Dregexp_prototype_test =============== */
@DFD(1)
Derror test(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.10.6.3 says this is equivalent to:
    //	RegExp.prototype.exec(string) != null
    return Dregexp.exec(othis, cc, ret, arglist, EXEC_BOOLEAN);
}

/* ===================== Dregexp_prototype_exec ============= */
@DFD(1)
Derror exec(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    return Dregexp.exec(othis, cc, ret, arglist, EXEC_ARRAY);
}


/* ===================== Dregexp_prototype_compile ============= */
@DFD(2)
Derror compile(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.regex : RegexException;

    // RegExp.prototype.compile(pattern, attributes)

    // othis must be a RegExp
    if (auto dr = cast(Dregexp)othis)
    {
        string pattern;
        string attributes;
        RegExp r;

        switch(arglist.length)
        {
        case 0:
            break;

        default:
            arglist[1].to(attributes, cc);
            goto case;
        case 1:
            arglist[0].to(pattern, cc);
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
            dr.source.put(cast(string)r.pattern);
            dr.global.put(r.global);
            dr.ignoreCase.put(r.ignoreCase);
        }
        //writef("r.attributes = x%x\n", r.attributes);
    }
    else
    {
        ret.putVundefined();
        return NotTransferrableError(cc, "RegExp.prototype.compile()");
    }

    // Documentation says nothing about a return value,
    // so let's use "undefined"
    ret.putVundefined();
    return null;
}


//------------------------------------------------------------------------------
///
class Dregexp : Dobject
{
    import dmdscript.primitive: PropertyKey;
    // import dmdscript.dobject : Initializer;

    Value* global;
    Value* ignoreCase;
    Value* multiline;
    Value* lastIndex;
    Value* source;

    RegExp re;

    nothrow
    this(Dobject prototype, string pattern, string attributes)
    {
        alias PA = Property.Attribute;
        super(prototype, Key.RegExp);

        Value v;
        v.put(Text.Empty);

        Value vb;
        vb.put(false);

        DefineOwnProperty(Key.source, v,
                          PA.ReadOnly | PA.DontDelete | PA.DontEnum);
        DefineOwnProperty(Key.global, vb,
                          PA.ReadOnly | PA.DontDelete | PA.DontEnum);
        DefineOwnProperty(Key.ignoreCase, vb,
                          PA.ReadOnly | PA.DontDelete | PA.DontEnum);
        DefineOwnProperty(Key.multiline, vb,
                          PA.ReadOnly | PA.DontDelete | PA.DontEnum);
        vb.put(0.0);
        DefineOwnProperty(Key.lastIndex, vb,
                          PA.DontDelete | PA.DontEnum | PA.DontConfig);

        source = proptable.getOwnData(Key.source);
        global = proptable.getOwnData(Key.global);
        ignoreCase = proptable.getOwnData(Key.ignoreCase);
        multiline = proptable.getOwnData(Key.multiline);
        lastIndex = proptable.getOwnData(Key.lastIndex);

        re = new RegExp(pattern, attributes);
        if(re.errors is null)
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

    this(Dobject prototype, PropertyKey cname = Key.RegExp)
    {
        super(prototype, cname);

        Value v;
        v.put(Text.Empty);

        Value vb;
        vb.put(false);

        DefineOwnProperty(Key.source, v,
                          PA.ReadOnly |
                          PA.DontDelete |
                          PA.DontEnum);
        DefineOwnProperty(Key.global, vb,
                          PA.ReadOnly |
                          PA.DontDelete |
                          PA.DontEnum);
        DefineOwnProperty(Key.ignoreCase, vb,
                          PA.ReadOnly |
                          PA.DontDelete |
                          PA.DontEnum);
        DefineOwnProperty(Key.multiline, vb,
                          PA.ReadOnly |
                          PA.DontDelete |
                          PA.DontEnum);
        vb.put(0.0);
        DefineOwnProperty(Key.lastIndex, vb,
                          PA.DontDelete |
                          PA.DontEnum |
                          PA.DontConfig);

        source = proptable.getOwnData(Key.source);
        global = proptable.getOwnData(Key.global);
        ignoreCase = proptable.getOwnData(Key.ignoreCase);
        multiline = proptable.getOwnData(Key.multiline);
        lastIndex = proptable.getOwnData(Key.lastIndex);

        re = new RegExp(null, null);
    }

    override Derror Call(CallContext* cc, Dobject othis, out Value ret,
                          Value[] arglist)
    {
        // This is the same as calling RegExp.prototype.exec(str)
        Value* v;

        if (auto err = Get(Key.exec, v, cc))
            return err;
        if (v !is null)
        {
            Dobject o;
            v.to(o, cc);
            return o.Call(cc, this, ret, arglist);
        }
        return null;
    }

static:
    nothrow
    Dregexp isRegExp(CallContext* cc, Value* v)
    {
        if      (v.isPrimitive)
            return null;
        else
        {
            Dobject o;
            v.to(o, cc);
            return cast(Dregexp)o;
        }
    }

    Derror exec(Dobject othis, CallContext* cc, out Value ret,
                 Value[] arglist, int rettype)
    {
        // othis must be a RegExp
        if (auto dr = cast(Dregexp)othis)
        {
            string s;
            RegExp r;
            DregexpConstructor dc;
            uint i;
            int lasti;
//            CallContext cc;

            if(arglist.length)
                arglist[0].to(s, cc);
            else
            {
                Dfunction df;

                df = cc.realm.dRegexp;
                s = (cast(DregexpConstructor)df).input.text;
            }

            r = dr.re;
            dc = cast(DregexpConstructor)cc.realm.dRegexp;

            // Decide if we are multiline
            r.multiline = 0 != dr.multiline.dbool;

            if(r.global && rettype != EXEC_INDEX)
            {
                double n;
                dr.lastIndex.toInteger(n, cc);
                lasti = cast(int)n;
            }
            else
                lasti = 0;

            if(r.test(s, lasti))
            {   // Successful match
                Value* lastv;
                size_t nmatches;

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
                    Darray a = cc.realm.dArray();

                    auto val = Value(r.input);
                    a.Set(Key.input, val, Property.Attribute.None, cc);
                    val.put(r.index);
                    a.Set(Key.index, val, Property.Attribute.None, cc);
                    val.put(r.lastIndex);
                    a.Set(Key.lastIndex, val,
                          Property.Attribute.DontConfig, cc);

                    a.Set(PropertyKey(0), *dc.lastMatch,
                          Property.Attribute.None, cc);

                    // [1]..[nparens]
                    if (nmatches < 9)
                        nmatches = 9;
                    for(i = 1; i <= nmatches; i++)
                    {
                        if(i > r.nmatches)
                        {
                            val.put(Text.Empty);
                            a.Set(PropertyKey(i), val,
                                  Property.Attribute.None, cc);
                        }
                        // Reuse values already put into dc.dollar[]
                        else if(r.nmatches <= 9)
                            a.Set(PropertyKey(i), *dc.dollar[i],
                                  Property.Attribute.None, cc);
                        else if(i > r.nmatches - 9)
                            a.Set(PropertyKey(i),
                                  *dc.dollar[i - (r.nmatches - 9)],
                                  Property.Attribute.None, cc);
                        else if(r.captures(i) is null)
                        {
                            val.putVundefined;
                            a.Set(PropertyKey(i), val,
                                  Property.Attribute.None, cc);
                        }
                        else
                        {
                            val.put(r.captures(i));
                            a.Set(PropertyKey(i), val,
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
            return NotTransferrableError(cc, "RegExp.prototype.exec()");
        }

        return null;
    }

    // mixin Initializer!DregexpConstructor;
}



package
{
    class RegExp
    {
        import std.regex : Regex, RegexMatch, regex;
        import std.bitmanip : bitfields;
        string pattern, flags;
        mixin (bitfields!(
                   bool, "global", 1,
                   bool, "ignoreCase", 1,
                   bool, "multiline", 1,
                   bool, "unicode", 1,
                   bool, "sticky", 1,
                   uint, "_padding", 3));
        Throwable errors;

        nothrow
        this(string pattern, string attributes)
        {
            compile(pattern, attributes);
        }

        nothrow
        void compile(string pattern, string attributes)
        {
            import std.conv : to;
            import std.array : join;

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
                case 'u':
                    unicode = true;
                    break;
                case 'y':
                    sticky = true;
                    break;
                default:
                }
            }

            // pattern = pattern.convertToStdRegexPattern(ignoreCase, unicode);
            attributes = [ignoreCase ? "i" : "", multiline  ? "m" : ""].join;

            try
            {
                r = regex(pattern, attributes);
            }
            catch(Throwable t)
            {
                errors = t;
            }
            try m.destroy;
            catch (Throwable){}
            src = null;
        }

        bool test(string str, size_t startIndex)
        {
            import std.regex : match;
            src = str;
            assert(r !is typeof(r).init);
            m = src[startIndex..$].match(r);
            assert(m !is typeof(m).init);

            return !m.empty;
        }

        @property
        size_t index()
        {
            assert(m !is typeof(m).init && !m.empty && src !is null);
            return cast(size_t)(m.hit.ptr - (cast(string)src).ptr);
        }

        @property
        size_t lastIndex()
        {
            assert(m !is typeof(m).init && !m.empty && src !is null);
            return cast(size_t)(m.post.ptr - (cast(string)src).ptr);
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
            return src[0..(m.hit.ptr - (cast(string)src).ptr)];
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
                return m.front[i].ptr - (cast(string)src).ptr;
            else
                return -1;
        }

        sizediff_t capturesLastIndex(size_t i)
        {
            assert(m !is typeof(m).init && !m.empty && src !is null);
            if (i < m.front.length)
                return m.front[i].ptr - (cast(string)src).ptr
                    + m.front[i].length;
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
        string src;
    }
}

//==============================================================================
private:
enum Key : PropertyKey
{
    RegExp = PKey.RegExp,
    prototype = PKey.prototype,
    constructor = PKey.constructor,
    global = PKey.global,

    input = PropertyKey("input"),
    multiline = PropertyKey("multiline"),
    lastIndex = PropertyKey("lastIndex"),
    lastMatch = PropertyKey("lastMatch"),
    lastParen = PropertyKey("lastParen"),
    leftContext = PropertyKey("leftContext"),
    rightContext = PropertyKey("rightContext"),

    dollar1 = PropertyKey("$1"),
    dollar2 = PropertyKey("$2"),
    dollar3 = PropertyKey("$3"),
    dollar4 = PropertyKey("$4"),
    dollar5 = PropertyKey("$5"),
    dollar6 = PropertyKey("$6"),
    dollar7 = PropertyKey("$7"),
    dollar8 = PropertyKey("$8"),
    dollar9 = PropertyKey("$9"),
    index = PropertyKey("index"),

    source = PropertyKey("source"),
    ignoreCase = PropertyKey("ignoreCase"),
    exec = PropertyKey("exec"),
}

/+
//------------------------------------------------------------------------------
auto regex(const(char)[] pattern, const(char)[] flags = "")
{
    import std.functional : memoize;
    enum cacheSize = 8; //TODO: invent nice interface to control regex caching
    return memoize!(regexImpl, cacheSize)(pattern, flags);
}

//------------------------------------------------------------------------------
public auto regexImpl(const(char)[] pattern, const(char)[] flags="")
{
    import std.regex.internal.parser : CodeGen;

    auto parser = Parser!CodeGen(pattern, flags);
    auto r = parser.program;
    return r;
}

//------------------------------------------------------------------------------
struct Parser(Generator)
{
    import std.regex.internal.parser : TBaseParser = Parser;

    alias BaseParser = TBaseParser!(const(char)[], Generator);
    BaseParser p;
    alias p this;

    enum RegexOption: uint
    {
        global = 0x1,
        casefold = 0x2,
        freeform = 0x4,
        nonunicode = 0x8,
        multiline = 0x10,
        singleline = 0x20
    }

    //--------------------------------------------------------------------
    @trusted
    this(const(char)[] pattern, const(char)[] flags)
    {
        p.pat = p.origin = pattern;
        parseFlags(flags);
        p.front = ' ';
        p._popFront;
        p.g.start(cast(uint)p.pat.length);
        try
        {
            p.parseRegex();
        }
        catch (Exception e)
        {
            p.error(e.msg);
        }
        p.g.endPattern(1);
    }

    //--------------------------------------------------------------------
    @trusted
    void parseFlags(const(char)[] flags)
    {
        import std.conv : text;
        import std.meta : AliasSeq;
        import std.regex.internal.ir : RegexException;

        alias RegexOptionNames = AliasSeq!('g', 'i', 'x', 'U', 'm', 's');

        foreach (ch; flags)//flags are ASCII anyway
        {
        L_FlagSwitch:
            switch (ch)
            {
                foreach (i, op; __traits(allMembers, RegexOption))
                {
                    case RegexOptionNames[i]:
                            if (re_flags & mixin("RegexOption."~op))
                                throw new RegexException(text("redundant flag specified: ",ch));
                            re_flags |= mixin("RegexOption."~op);
                            break L_FlagSwitch;
                }
                default:
                    throw new RegexException(text("unknown regex flag '",ch,"'"));
            }
        }
    }

    //--------------------------------------------------------------------
    //parse and store IR for regex pattern
    @trusted void parseRegex()
    {
        import std.ascii : isAlpha, isDigit;
        import std.exception : enforce;
        import std.regex.internal.ir : IR;

        uint fix;//fixup pointer

        while (!p.empty)
        {
            switch (p.front)
            {
            case '(':
                p.popFront;
                if (p.front == '?')
                {
                    p.popFront;
                    switch (p.front)
                    {
                    case '#':
                        for (;;)
                        {
                            p.popFront;
                            if (p.empty)
                                p.error("Unexpected end of pattern");
                            if (p.front == ')')
                            {
                                p.popFront;
                                break;
                            }
                        }
                        break;
                    case ':':
                        p.g.genLogicGroup();
                        p.popFront;
                        break;
                    case '=':
                        p.g.genLookaround(IR.LookaheadStart);
                        p.popFront;
                        break;
                    case '!':
                        p.g.genLookaround(IR.NeglookaheadStart);
                        p.popFront;
                        break;
                    case 'P':
                        p.popFront;
                        if (p.front != '<')
                            p.error("Expected '<' in named group");
                        string name;
                        p.popFront;
                        if (p.empty || !(isAlpha(p.front) || p.front == '_'))
                            error("Expected alpha starting a named group");
                        do
                        {
                            name ~= p.front;
                            p.popFront;
                        }
                        while (!p.empty &&
                               (isAlpha(p.front) ||
                                p.front == '_' || isDigit(p.front)));

                        if (p.front != '>')
                            p.error("Expected '>' closing named group");
                        p.popFront;
                        p.g.genNamedGroup(name);
                        break;
                    case '<':
                        p.popFront;
                        if (p.front == '=')
                            p.g.genLookaround(IR.LookbehindStart);
                        else if (p.front == '!')
                            p.g.genLookaround(IR.NeglookbehindStart);
                        else
                            p.error("'!' or '=' expected after '<'");
                        p.popFront;
                        break;
                    default:
                        uint enableFlags, disableFlags;
                        bool enable = true;
                        do
                        {
                            switch (p.front)
                            {
                            case 's':
                                if (enable)
                                    enableFlags |= RegexOption.singleline;
                                else
                                    disableFlags |= RegexOption.singleline;
                                break;
                            case 'x':
                                if (enable)
                                    enableFlags |= RegexOption.freeform;
                                else
                                    disableFlags |= RegexOption.freeform;
                                break;
                            case 'i':
                                if (enable)
                                    enableFlags |= RegexOption.casefold;
                                else
                                    disableFlags |= RegexOption.casefold;
                                break;
                            case 'm':
                                if (enable)
                                    enableFlags |= RegexOption.multiline;
                                else
                                    disableFlags |= RegexOption.multiline;
                                break;
                            case '-':
                                if (!enable)
                                    p.error(" unexpected second '-' in flags");
                                enable = false;
                                break;
                            default:
                                p.error(" 's', 'x', 'i', 'm' or '-' expected after '(?' ");
                            }
                            p.popFront;
                        }while (p.front != ')');
                        p.popFront;
                        p.re_flags |= enableFlags;
                        p.re_flags &= ~disableFlags;
                    }
                }
                else
                {
                    p.g.genGroup();
                }
                break;
            case ')':
                enforce(p.g.nesting, "Unmatched ')'");
                p.popFront;
                auto pair = p.g.onClose();
                if (pair[0])
                    p.parseQuantifier(pair[1]);
                break;
            case '|':
                p.popFront;
                p.g.fixAlternation();
                break;
            default://no groups or whatever
                immutable start = p.g.length;
                parseAtom();
                p.parseQuantifier(start);
            }
        }

        if (p.g.fixupLength != 1)
        {
            fix = p.g.popFixup();
            p.g.finishAlternation(fix);
            enforce(p.g.fixupLength == 1, "no matching ')'");
        }
    }

    //parse and store IR for atom
    void parseAtom()
    {
        if (p.empty)
            return;

        if (p.front == '\\')
        {
            p.parseEscape;
        }
        else
            p.parseAtom;
    }
}
// +/
