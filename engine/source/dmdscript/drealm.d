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

module dmdscript.drealm;

import dmdscript.dobject : Dobject;
import dmdscript.value : Value;
import dmdscript.dnative : DnativeFunction, DFD = DnativeFunctionDescriptor,
    installConstants;
import dmdscript.property : Property;
alias PA = Property.Attribute;
import dmdscript.callcontext: CallContext;
import dmdscript.derror: Derror, onError;

debug import std.stdio;

//------------------------------------------------------------------------------
// Configuration
enum MAJOR_VERSION = 5;       /// ScriptEngineMajorVersion
enum MINOR_VERSION = 5;       /// ScriptEngineMinorVersion

enum BUILD_VERSION = 1;       /// ScriptEngineBuildVersion

enum JSCRIPT_CATCH_BUG = 1;   /// emulate Jscript's bug in scoping of
                              /// catch objects in violation of ECMA
enum JSCRIPT_ESCAPEV_BUG = 0; /// emulate Jscript's bug where \v is
                              /// not recognized as vertical tab

enum COPYRIGHT = "Copyright (c) 1999-2010 by Digital Mars"; ///
enum WRITTEN = "by Walter Bright"; ///

///
@safe pure nothrow
string banner()
{
    import std.array : join;
    return [
        "DMDSsript-2 v0.1rc1",
        "Compiled by Digital Mars DMD D compiler",
        "http://www.digitalmars.com",
        "Fork of the original DMDScript 1.16",
        WRITTEN,
        COPYRIGHT,
        ].join("\n");
}

//==============================================================================
///
class Drealm : Dobject // aka global environment.
{
    import dmdscript.dobject: Dobject, DobjectConstructor;
    import dmdscript.dfunction: DfunctionConstructor, Dfunction;
    import dmdscript.darray: DarrayConstructor;
    import dmdscript.dstring: DstringConstructor;
    import dmdscript.dboolean: DbooleanConstructor;
    import dmdscript.dnumber: DnumberConstructor;
    import dmdscript.ddate: DdateConstructor;
    import dmdscript.dregexp: DregexpConstructor;
    // import dmdscript.derror;
    import dmdscript.dmath: Dmath;
    import dmdscript.dsymbol: DsymbolConstructor, Dsymbol;
    import dmdscript.dproxy: DproxyConstructor;
    import dmdscript.dbigint: DbigIntConstructor;

    import dmdscript.protoerror: SyntaxError, EvalError, ReferenceError,
        RangeError, TypeError, UriError;

    import dmdscript.primitive: PropertyKey, ModulePool, Key;
    import dmdscript.callcontext: CallContext;

    Dobject rootPrototype, functionPrototype;
    DobjectConstructor dObject;
    DfunctionConstructor dFunction;
    DarrayConstructor dArray;
    DregexpConstructor dRegexp;
    DbooleanConstructor dBoolean;
    DnumberConstructor dNumber;
    DstringConstructor dString;
    DsymbolConstructor dSymbol;
    DproxyConstructor dProxy;
    DbigIntConstructor dBigInt;
    DdateConstructor dDate;

    SyntaxError dSyntaxError;
    EvalError dEvalError;
    ReferenceError dReferenceError;
    RangeError dRangeError;
    TypeError dTypeError;
    UriError dUriError;

    Dmath dMath;

    this(string id, ModulePool modulePool, bool strictMode)
    {
        import dmdscript.primitive: PropertyKey;
        import dmdscript.dnative: install;

        _id = id;
        _modulePool = modulePool;

        rootPrototype = new Dobject(null);
        functionPrototype = new Dobject(rootPrototype, Key.Function);

        // Dglobal.prototype is implementation-dependent
        super(rootPrototype, Key.global);

        Dsymbol.init;

        Value val;

        void init(T...)(ref T args)
        {
            foreach (ref one; args)
            {
                one = new typeof(one)(rootPrototype, functionPrototype);
                val.put(one);
                DefineOwnProperty(one.name, val, PA.DontEnum);
            }
        }

        init(dObject, dFunction,
             dArray, dRegexp, dBoolean, dNumber, dString, dSymbol, dProxy,
             dBigInt, dDate,
             dSyntaxError, dEvalError, dReferenceError, dRangeError,
             dTypeError, dUriError);

        val.put(this);
        DefineOwnProperty(Key.global, val, PA.DontEnum);

        // ECMA 15.1
        installConstants!(
            "NaN", double.nan,
            "Infinity", double.infinity,
            "undefined", undefined)(
                this, PA.DontEnum | PA.DontDelete | PA.ReadOnly);

        debug
        {
            auto cc = CallContext.push(this, false);
            Value* v;
            assert (Get(PropertyKey("Infinity"), v, cc) is null);
            assert (v !is null);
            assert (!v.isUndefined);
            assert (v.type == Value.Type.Number);
            assert (v.number is double.infinity);
        }

        install!(dmdscript.drealm)(this, functionPrototype);

        dMath = new Dmath(rootPrototype, functionPrototype, strictMode);
        val.put(dMath);
        DefineOwnProperty(Key.Math, val, Property.Attribute.DontEnum);

        debug
        {
            import dmdscript.primitive : PropertyKey;

            assert(dString.Get(PropertyKey("fromCharCode"), v, cc) is null);
            assert (v !is null);

            auto prop = dObject.classPrototype
                .GetOwnProperty(PropertyKey("__proto__"));
            assert (prop !is null);
            assert (prop.isAccessor);
        }
    }

    //--------------------------------------------------------------------
    ///
    @property @safe @nogc pure nothrow
    string id() const
    {
        return _id;
    }

    ///
    @property @safe @nogc pure nothrow
    ModulePool modulePool()
    {
        return _modulePool;
    }

    //--------------------------------------------------------------------
    /** Get the current interrupting flag.

    When this is true, dmdscript.opcodes.IR.call will return immediately.
    */
    @property @safe @nogc pure nothrow
    bool isInterrupting() const
    {
        return _interrupt;
    }

    /// Make the interrupting flag to true.
    @property @safe @nogc pure nothrow
    void interrupt()
    {
        _interrupt = true;
    }

    debug
    {
        enum DumpMode
        {
            None       = 0x00,
            Statement  = 0x01,
            IR         = 0x02,
            All        = 0x03,
        }

        DumpMode dumpMode;
    }

private:
    string _id;
    ModulePool _modulePool;
    bool _interrupt;               // true if cancelled due to interrupt
}

//------------------------------------------------------------------------------
class DmoduleRealm: Drealm
{
    import dmdscript.functiondefinition: FunctionDefinition;

    FunctionDefinition _fd;

    this (string id, ModulePool modulePool, FunctionDefinition fd,
          bool strictMode)
    {
        super(id, modulePool, strictMode);

        this._fd = fd;
    }

    override
    Derror Call(CallContext* cc, Dobject othis, out Value ret, Value[] args)
    {
        import dmdscript.program: execute;

        Derror err;
        _fd.execute (this, ret).onError(err);
        return err;
    }
}

//==============================================================================

@DFD(1)
Derror CreateRealm (
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import dmdscript.ddeclaredfunction: DdeclaredFunction;

    Value* v;
    string moduleId;
    Dobject o;

    if (0 < arglist.length)
    {
        v = &arglist[0];
        if (!v.isUndefinedOrNull)
            v.to(moduleId, cc);
    }

    o = new DmoduleRealm(moduleId, cc.realm.modulePool, null, cc.strictMode);
    assert (o !is null);
    ret.put(o);
    return null;
}

//------------------------------------------------------------------------------
@DFD(1)
Derror eval(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import core.sys.posix.stdlib : alloca;
    import dmdscript.functiondefinition : FunctionDefinition;
    import dmdscript.statement : TopStatement;
    import dmdscript.parse : Parser;
    import dmdscript.scopex : Scope;
    import dmdscript.lexer : Mode;
    import dmdscript.property : Property;
    import dmdscript.opcodes : IR;
    import dmdscript.program: parse, analyze, generate, execute;
    import dmdscript.exception: SyntaxException, EarlyException;

    // ECMA 15.1.2.1
    Value* v;
    string s;
    FunctionDefinition fd;
    // ScriptException exception;
    Derror result;
    // Dobject callerothis;
    // Dobject[] scopes;

    // Parse program
    v = arglist.length ? &arglist[0] : &undefined;
    if(v.type != Value.Type.String)
    {
        ret = *v;
        return null;
    }
    v.to(s, cc);

    // auto p = new Parser!(Mode.None)(s, cc.realm.modulePool, cc.strictMode);
    // topstatements = p.parseProgram;
    try fd = s.parse(cc.realm.modulePool, cc.strictMode);
    catch (SyntaxException se)
    {
        Value msg = Value(cc.realm.dSyntaxError(se.msg));
        return new Derror(se, msg);
    }

    fd.iseval = 1;
    debug
    {
        if (cc.realm.dumpMode & Drealm.DumpMode.Statement)
            TopStatement.dump(fd.topstatements, b=>b.write);
    }

    try fd.analyze.generate;
    catch (EarlyException ee)
    {
        import dmdscript.protoerror: toError;
        ee.base = s;
        auto msg = Value(ee.type.toError(ee.msg, cc.realm));
        return new Derror(ee, msg);
    }

    debug
    {
        if (cc.realm.dumpMode & Drealm.DumpMode.IR)
            FunctionDefinition.dump(fd, b=>b.write);
    }

    Dobject actobj = cc.realm.dObject();
    auto ncc = CallContext.push(cc, actobj, pthis, fd, othis);
    if (fd.execute(ncc, ret).onError(result))
    {
        result.addInfo("eval", "global", cc.strictMode);
        result.addSource(s);
//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        // result.addInfo(cc, id=>ModuleCode(s, "eval", s));
    }
    CallContext.pop(ncc);
    // }
    // catch (Throwable t)
    // {
    //     auto o = cc.realm.dEvalError(t.msg);
    //     auto vo = Value(o);
    //     return new Derror(cc, t, vo);

    //     // auto se = t.ScriptException ("in eval");
    //     // se.setSourceInfo(id=>[new ScriptException.Source("eval", s)]);

    //     // ret.putVundefined();
    //     // return new DError(cc, se);
    // }

    return result;
//     // Analyze, generate code
//     fd = new FunctionDefinition(topstatements, cc.strictMode);
//     fd.iseval = 1;
//     try
//     {
//         Scope sc;
//         sc.ctor(fd);
//         fd.semantic(&sc);
//         // exception = sc.exception;
//         sc.dtor();
//     }
//     catch (Throwable t)
//     {

// //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// // solve this.
//     // For eval()'s, use location of caller, not the string
//     // errinfo.linnum = 0;
//         ret.putVundefined();
//         return new DError(cc.realm.dSyntaxError(t));
//     }



    // fd.toIR(null);

    // Execute code
    // Value[] locals;
    // Value[] p1 = null;

    // Value* v1 = null;
    // static ntry = 0;

    // if(fd.nlocals < 128)
    //     v1 = cast(Value*)alloca(fd.nlocals * Value.sizeof);
    // if(v1)
    //     locals = v1[0 .. fd.nlocals];
    // else
    // {
    //     p1 = new Value[fd.nlocals];
    //     locals = p1;
    // }

    // version(none)
    // {
    //     Array scopex;
    //     scopex.reserve(realm.scoperoot + fd.withdepth + 2);
    //     for(uint u = 0; u < realm.scoperoot; u++)
    //         scopex.push(realm.scopex.data[u]);

    //     Array *scopesave = realm.scopex;
    //     realm.scopex = &scopex;
    //     Dobject variablesave = realm.variable;
    //     realm.variable = realm;

    //     fd.instantiate(realm, 0);

    //     // The this value is the same as the this value of the
    //     // calling context.
    //     result = IR.call(realm, othis, fd.code, ret, locals);

    //     delete p1;
    //     realm.variable = variablesave;
    //     realm.scopex = scopesave;
    //     return result;
    // }
    // else
    // {

        // The scope chain is initialized to contain the same objects,
        // in the same order, as the calling context's scope chain.
        // This includes objects added to the calling context's
        // scope chain by WithStatement.
//    cc.scopex.reserve(fd.withdepth);

        // The this value is the same as the this value of the
        // calling context.
        // scopes = realm.scopes;
        // assert (0 < scopes.length);
        // assert (realm.callerothis);
        // auto dfs = new DefinedFunctionScope(scopes[0..$-1], scopes[$-1],
        //                                     pthis, fd, realm.callerothis);
        // Dobject actobj = cc.realm.dObject();
        // auto ncc = CallContext.push(cc, actobj, pthis, fd, cc.callerothis);

        // Variable instantiation is performed using the calling
        // context's variable object and using empty
        // property attributes
        // fd.instantiate(ncc, Property.Attribute.None);
        // fd.instantiate(cc.scopex, cc.variable, Property.Attribute.None);


        // realm.push(dfs);
        // result = IR.call(ncc, othis, fd.code, ret, locals.ptr);
        // if (result !is null)
        // {
        //     result.addInfo("string", "anonymous", cc.strictMode);
        //     result.setSourceInfo(id=>[new ScriptException.Source("eval", s)]);
        // }

        // realm.pop(dfs);
        // CallContext.pop(ncc);

        // if(p1)
        // {
        //     p1.destroy;
        //     p1 = null;
        // }
        // fd = null;

        // return result;
    // }

}

//------------------------------------------------------------------------------
@DFD(2)
Derror parseInt(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.utf : decode;
    import std.uni : isWhite;

    // ECMA 15.1.2.2
    Value* v2;
    immutable(char)* s;
    immutable(char)* z;
    int radix;
    int sign = 1;
    double number;
    size_t i;
    string str;

    str = arg0string(cc, arglist);

    //writefln("Dglobal_parseInt('%s')", string);

    while(i < str.length)
    {
        size_t idx = i;
        dchar c = decode(str, idx);
        if(!c.isWhite)
            break;
        i = idx;
    }
    s = str.ptr + i;
    i = str.length - i;

    if(i)
    {
        if(*s == '-')
        {
            sign = -1;
            s++;
            i--;
        }
        else if(*s == '+')
        {
            s++;
            i--;
        }
    }

    radix = 0;
    if(arglist.length >= 2)
    {
        v2 = &arglist[1];
        v2.to(radix, cc);
    }

    if(radix)
    {
        if(radix < 2 || radix > 36)
        {
            number = double.nan;
            goto Lret;
        }
        if(radix == 16 && i >= 2 && *s == '0' &&
           (s[1] == 'x' || s[1] == 'X'))
        {
            s += 2;
            i -= 2;
        }
    }
    else if(i >= 1 && *s != '0')
    {
        radix = 10;
    }
    else if(i >= 2 && (s[1] == 'x' || s[1] == 'X'))
    {
        radix = 16;
        s += 2;
        i -= 2;
    }
    else
        radix = 8;

    number = 0;
    for(z = s; i; z++, i--)
    {
        int n;
        char c;

        c = *z;
        if('0' <= c && c <= '9')
            n = c - '0';
        else if('A' <= c && c <= 'Z')
            n = c - 'A' + 10;
        else if('a' <= c && c <= 'z')
            n = c - 'a' + 10;
        else
            break;
        if(radix <= n)
            break;
        number = number * radix + n;
    }
    if(z == s)
    {
        number = double.nan;
        goto Lret;
    }
    if(sign < 0)
        number = -number;

    version(none)     // ECMA says to silently ignore trailing characters
    {
        while(z - &str[0] < str.length)
        {
            if(!isStrWhiteSpaceChar(*z))
            {
                number = double.nan;
                goto Lret;
            }
            z++;
        }
    }

    Lret:
    ret.put(number);
    return null;
}

//------------------------------------------------------------------------------
@DFD(1)
Derror parseFloat(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import dmdscript.primitive : StringNumericLiteral;

    // ECMA 15.1.2.3
    double n;
    size_t endidx;

    string str = arg0string(cc, arglist);
    n = StringNumericLiteral(str, endidx, 1);

    ret.put(n);
    return null;
}

//------------------------------------------------------------------------------
int ISURIALNUM(dchar c)
{
    return (c >= 'a' && c <= 'z') ||
           (c >= 'A' && c <= 'Z') ||
           (c >= '0' && c <= '9');
}

char[16 + 1] TOHEX = "0123456789ABCDEF";

@DFD(1)
Derror escape(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.exception : assumeUnique;
    import std.string : indexOf;

    // ECMA 15.1.2.4
    string s;
    uint escapes;
    uint unicodes;
    size_t slen;

    s = arg0string(cc, arglist);
    escapes = 0;
    unicodes = 0;
    foreach(dchar c; s)
    {
        slen++;
        if(c >= 0x100)
            unicodes++;
        else
        if(c == 0 || c >= 0x80 || (!ISURIALNUM(c) && indexOf("*@-_+./", c) == -1))
            escapes++;
    }
    if((escapes + unicodes) == 0)
    {
        ret.put(assumeUnique(s));
        return null;
    }
    else
    {
        //writefln("s.length = %d, escapes = %d, unicodes = %d", s.length, escapes, unicodes);
        char[] R = new char[slen + escapes * 2 + unicodes * 5];
        char* r = R.ptr;
        foreach(dchar c; s)
        {
            if(c >= 0x100)
            {
                r[0] = '%';
                r[1] = 'u';
                r[2] = TOHEX[(c >> 12) & 15];
                r[3] = TOHEX[(c >> 8) & 15];
                r[4] = TOHEX[(c >> 4) & 15];
                r[5] = TOHEX[c & 15];
                r += 6;
            }
            else if(c == 0 || c >= 0x80 || (!ISURIALNUM(c) && indexOf("*@-_+./", c) == -1))
            {
                r[0] = '%';
                r[1] = TOHEX[c >> 4];
                r[2] = TOHEX[c & 15];
                r += 3;
            }
            else
            {
                r[0] = cast(char)c;
                r++;
            }
        }
        assert(r - R.ptr == R.length);
        ret.put(assumeUnique(R));
        return null;
    }
}

//------------------------------------------------------------------------------
@DFD(1)
Derror unescape(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.exception : assumeUnique;
    import std.traits : Unqual, ForeachType;
    import std.utf : encode;

    // ECMA 15.1.2.5
    string s;
    char[] R; // char[] type is assumed.
    char[4] tmp;
    size_t len;

    s = arg0string(cc, arglist);
    //writefln("Dglobal.unescape(s = '%s')", s);
    for(size_t k = 0; k < s.length; k++)
    {
        char c = s[k];

        if(c == '%')
        {
            if(k + 6 <= s.length && s[k + 1] == 'u')
            {
                uint u;

                u = 0;
                for(int i = 2;; i++)
                {
                    uint x;

                    if(i == 6)
                    {
                        len = encode(tmp, cast(dchar)u);
                        R ~= tmp[0..len];
                        k += 5;
                        goto L1;
                    }
                    x = s[k + i];
                    if('0' <= x && x <= '9')
                        x = x - '0';
                    else if('A' <= x && x <= 'F')
                        x = x - 'A' + 10;
                    else if('a' <= x && x <= 'f')
                        x = x - 'a' + 10;
                    else
                        break;
                    u = (u << 4) + x;
                }
            }
            else if(k + 3 <= s.length)
            {
                uint u;

                u = 0;
                for(int i = 1;; i++)
                {
                    uint x;

                    if(i == 3)
                    {
                        len = encode(tmp, cast(dchar)u);
                        R ~= tmp[0..len];
                        k += 2;
                        goto L1;
                    }
                    x = s[k + i];
                    if('0' <= x && x <= '9')
                        x = x - '0';
                    else if('A' <= x && x <= 'F')
                        x = x - 'A' + 10;
                    else if('a' <= x && x <= 'f')
                        x = x - 'a' + 10;
                    else
                        break;
                    u = (u << 4) + x;
                }
            }
        }
        R ~= c;
        L1:
        ;
    }

    ret.put(R.assumeUnique);
    return null;
}

//------------------------------------------------------------------------------
@DFD(1)
Derror isNaN(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.math : isNaN;

    // ECMA 15.1.2.6
    Value* v;
    double n;
    bool b;

    if(arglist.length)
        v = &arglist[0];
    else
        v = &undefined;
    v.to(n, cc);
    b = isNaN(n) ? true : false;
    ret.put(b);
    return null;
}

//------------------------------------------------------------------------------
@DFD(1)
Derror isFinite(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.math : isFinite;

    // ECMA 15.1.2.7
    Value* v;
    double n;
    bool b;

    if(arglist.length)
        v = &arglist[0];
    else
        v = &undefined;
    v.to(n, cc);
    b = isFinite(n) ? true : false;
    ret.put(b);
    return null;
}

//------------------------------------------------------------------------------
Derror URI_error(CallContext* cc, string s)
{
    auto msg = s ~ "() failure";
    auto o = cc.realm.dUriError(msg);
    auto v = Value(o);
    return new Derror(v);
}
@DFD(1)
Derror decodeURI(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.uri : decode, URIException;
    // ECMA v3 15.1.3.1
    string s;

    s = arg0string(cc, arglist);
    try
    {
        s = decode(s);
    }
    catch(URIException u)
    {
        ret.putVundefined();
        return URI_error(cc, __FUNCTION__);
    }
    ret.put(s);
    return null;
}

//------------------------------------------------------------------------------
@DFD(1)
Derror decodeURIComponent(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.uri : decodeComponent, URIException;
    import dmdscript.primitive;
    // ECMA v3 15.1.3.2
    string s;

    s = arg0string(cc, arglist);
    try
    {
        s = decodeComponent(s);
    }
    catch(URIException u)
    {
        ret.putVundefined();
        return URI_error(cc, __FUNCTION__);
    }
    ret.put(s);
    return null;
}

//------------------------------------------------------------------------------
@DFD(1)
Derror encodeURI(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.uri : encode, URIException;

    // ECMA v3 15.1.3.3
    string s;

    s = arg0string(cc, arglist);
    try
    {
        s = encode(s);
    }
    catch(URIException u)
    {
        ret.putVundefined();
        return URI_error(cc, __FUNCTION__);
    }
    ret.put(s);
    return null;
}

//------------------------------------------------------------------------------
@DFD(1)
Derror encodeURIComponent(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.uri : encodeComponent, URIException;
    // ECMA v3 15.1.3.4
    string s;

    s = arg0string(cc, arglist);
    try
    {
        s = encodeComponent(s);
    }
    catch(URIException u)
    {
        ret.putVundefined();
        return URI_error(cc, __FUNCTION__);
    }
    ret.put(s);
    return null;
}

//------------------------------------------------------------------------------
void dglobal_print(
    CallContext* cc, Dobject othis, out Value ret, Value[] arglist)
{
    import std.stdio : writef;
    // Our own extension
    if(arglist.length)
    {
        uint i;

        for(i = 0; i < arglist.length; i++)
        {
            version (Windows) // FUUU******UUUCK!!
            {
                import std.windows.charset : toMBSz;

                // if (arglist[i].type == Value.Type.Object)
                // {
                //     if (auto err = cast(D0base)arglist[i].object)
                //     {
                //         err.exception.toString((b){printf("%s", b.toMBSz);});
                //         continue;
                //     }
                // }

                string s;
                arglist[i].to(s, cc);
                printf("%s", s.toMBSz);
            }
            else
            {
                string s;
                arglist[i].toString(cc, s);

                writef("%s", s);
            }
        }
    }

    ret.putVundefined();
}

//------------------------------------------------------------------------------
@DFD(1)
Derror print(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // Our own extension
    dglobal_print(cc, othis, ret, arglist);
    return null;
}

//------------------------------------------------------------------------------
@DFD(1)
Derror println(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.stdio : writef;

    // Our own extension
    dglobal_print(cc, othis, ret, arglist);
    writef("\n");
    return null;
}

//------------------------------------------------------------------------------
@DFD(0)
Derror readln(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.exception : assumeUnique;
    import std.traits : Unqual, ForeachType;
    import std.stdio : EOF;
    import std.utf : encode;
    import core.stdc.stdio : getchar;

    // Our own extension
    dchar c;
    char[] s;
    char[4] tmp;
    size_t len;

    for(;; )
    {
        version(linux)
        {
            c = getchar();
            if(c == EOF)
                break;
        }
        else version(Windows)
        {
            c = getchar();
            if(c == EOF)
                break;
        }
        else version(OSX)
        {
            c = getchar();
            if(c == EOF)
                break;
        }
        else version(FreeBSD)
        {
            c = getchar();
            if(c == EOF)
                break;
        }
        else
        {
            static assert(0);
        }
        if(c == '\n')
            break;
        len = encode(tmp, c);
        s ~= tmp[0..len];
    }
    ret.put(s.assumeUnique);
    return null;
}

//------------------------------------------------------------------------------
@DFD(1)
Derror getenv(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.string : toStringz;
    import core.sys.posix.stdlib : getenv;
    import core.stdc.string : strlen;

    // Our own extension
    ret.putVundefined();
    if(arglist.length)
    {
        string s;
        arglist[0].to(s, cc);
        char* p = getenv(toStringz(s));
        if(p)
            ret.put(p[0 .. strlen(p)].idup);
        else
            ret.putVnull();
    }
    return null;
}


//------------------------------------------------------------------------------
@DFD(0)
Derror ScriptEngine(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import dmdscript.primitive : Text;

    ret.put(Text.DMDScript);
    return null;
}

//------------------------------------------------------------------------------
@DFD(0)
Derror ScriptEngineBuildVersion(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    ret.put(BUILD_VERSION);
    return null;
}

//------------------------------------------------------------------------------
@DFD(0)
Derror ScriptEngineMajorVersion(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    ret.put(MAJOR_VERSION);
    return null;
}

//------------------------------------------------------------------------------
@DFD(0)
Derror ScriptEngineMinorVersion(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    ret.put(MINOR_VERSION);
    return null;
}

//------------------------------------------------------------------------------

//
string arg0string(CallContext* cc, Value[] arglist)
{
    Value* v = arglist.length ? &arglist[0] : &undefined;
    string s;
    v.to(s, cc);
    return s;
}

//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// I want to remove this.
public auto undefined = Value(Value.Type.Undefined);
