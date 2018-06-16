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

import dmdscript.primitive : Key;
import dmdscript.dobject : Dobject;
import dmdscript.value : Value, DError, vundefined;
import dmdscript.dnative : DnativeFunction, DFD = DnativeFunctionDescriptor,
    installConstants;
import dmdscript.property : Property;
import dmdscript.callcontext: CallContext;

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
    // import dmdscript.ddate;
    import dmdscript.dregexp: DregexpConstructor;
    // import dmdscript.derror;
    import dmdscript.dmath: Dmath;
    import dmdscript.dsymbol: DsymbolConstructor, Dsymbol;
    import dmdscript.dproxy: DproxyConstructor;
    import dmdscript.dbigint: DbigIntConstructor;

    import dmdscript.protoerror: SyntaxError, EvalError, ReferenceError,
        RangeError, TypeError, UriError;

    import dmdscript.primitive: PropertyKey, ModulePool;
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

    SyntaxError dSyntaxError;
    EvalError dEvalError;
    ReferenceError dReferenceError;
    RangeError dRangeError;
    TypeError dTypeError;
    UriError dUriError;

    Dmath dMath;

    this(string id, ModulePool modulePool)
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

        void init(T...)(ref T args)
        {
            Value val;
            foreach (ref one; args)
            {
                one = new typeof(one)(rootPrototype, functionPrototype);
                val.put(one);
                DefineOwnProperty(one.name, val, Property.Attribute.DontEnum);
            }
        }

        init(dObject, dFunction,
             dArray, dRegexp, dBoolean, dNumber, dString, dSymbol, dProxy,
             dBigInt,
             dSyntaxError, dEvalError, dReferenceError, dRangeError,
             dTypeError, dUriError);

        // ECMA 15.1
        installConstants!(
            "NaN", double.nan,
            "Infinity", double.infinity,
            "undefined", vundefined)(this,
                                     Property.Attribute.DontEnum |
                                     Property.Attribute.DontDelete);

        debug
        {
            auto cc = CallContext.push(this, false);
            auto v = Get(PropertyKey("Infinity"), cc);
            assert (!v.isUndefined);
            assert (v.type == Value.Type.Number);
            assert (v.number is double.infinity);
        }

        install!(dmdscript.drealm)(this, functionPrototype);

        dMath = new Dmath(rootPrototype, functionPrototype);
        Value val;
        val.put(dMath);
        DefineOwnProperty(Key.Math, val, Property.Attribute.DontEnum);

        debug
        {
            import dmdscript.primitive : PropertyKey;

            assert(dString.Get(PropertyKey("fromCharCode"), cc));

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

    this (string id, ModulePool modulePool, FunctionDefinition fd)
    {
        import dmdscript.program: analyze, generate, execute;
        super(id, modulePool);

        Value ret;
        DError* err;
        if (fd !is null)
        {
            try fd.analyze.generate.execute (this, ret);
            catch (Throwable t)
            {
//##############################################################################
// UNDER CONSTRUCTION
            // exports to outer realm.
            }
        }
        // this.globalfunction = fd;

        // semantic;
        // toIR;

        // Value ret;
        // auto err = execute(ret, null);
    }
}

//==============================================================================

@DFD(1, Key.CreateRealm)
DError* CreateRealm (
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
            moduleId = v.toString(cc);
    }

    o = new DmoduleRealm(moduleId, cc.realm.modulePool, null);
    assert (o !is null);
    ret.put(o);
    return null;
}

//------------------------------------------------------------------------------
@DFD(1)
DError* eval(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import core.sys.posix.stdlib : alloca;
    import dmdscript.functiondefinition : FunctionDefinition;
    import dmdscript.exception : ScriptException;
    import dmdscript.statement : TopStatement;
    import dmdscript.parse : Parser;
    import dmdscript.scopex : Scope;
    import dmdscript.lexer : Mode;
    import dmdscript.property : Property;
    import dmdscript.opcodes : IR;
    import dmdscript.program: parse, analyze, generate, execute;

    // ECMA 15.1.2.1
    Value* v;
    string s;
    FunctionDefinition fd;
    // ScriptException exception;
    DError* result;
    // Dobject callerothis;
    // Dobject[] scopes;

    // Parse program
    try
    {
        v = arglist.length ? &arglist[0] : &undefined;
        if(v.type != Value.Type.String)
        {
            ret = *v;
            return null;
        }
        s = v.toString(cc);

        // auto p = new Parser!(Mode.None)(s, cc.realm.modulePool, cc.strictMode);
        // topstatements = p.parseProgram;
        fd = "string".parse(s, cc.realm.modulePool, cc.strictMode, "eval");
        fd.iseval = 1;
        debug
        {
            if (cc.realm.dumpMode & Drealm.DumpMode.Statement)
                TopStatement.dump(fd.topstatements, b=>b.write);
        }

        fd.analyze.generate;

        debug
        {
            if (cc.realm.dumpMode & Drealm.DumpMode.IR)
                FunctionDefinition.dump(fd, b=>b.write);
        }

        Dobject actobj = cc.realm.dObject();
        auto ncc = CallContext.push(cc, actobj, pthis, fd, othis);
        result = fd.execute(ncc, ret);
        if (result !is null)
            result.exception.setSourceInfo(
                id=>[new ScriptException.Source("eval", s)]);

        CallContext.pop(ncc);
    }
    catch (Throwable t)
    {
        auto se = t.ScriptException ("in eval");
        se.setSourceInfo(id=>[new ScriptException.Source("eval", s)]);

        ret.putVundefined();
        return new DError(cc, se);
    }

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
DError* parseInt(
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
        radix = v2.toInt32(cc);
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
DError* parseFloat(
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
DError* escape(
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
DError* unescape(
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
DError* isNaN(
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
    n = v.toNumber(cc);
    b = isNaN(n) ? true : false;
    ret.put(b);
    return null;
}

//------------------------------------------------------------------------------
@DFD(1)
DError* isFinite(
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
    n = v.toNumber(cc);
    b = isFinite(n) ? true : false;
    ret.put(b);
    return null;
}

//------------------------------------------------------------------------------
DError* URI_error(Drealm realm, string s)
{
    Dobject o = realm.dUriError(s ~ "() failure");
    auto v = new DError;
    v.put(o);
    return v;
}
@DFD(1)
DError* decodeURI(
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
        return URI_error(cc.realm, __FUNCTION__);
    }
    ret.put(s);
    return null;
}

//------------------------------------------------------------------------------
@DFD(1)
DError* decodeURIComponent(
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
        return URI_error(cc.realm, __FUNCTION__);
    }
    ret.put(s);
    return null;
}

//------------------------------------------------------------------------------
@DFD(1)
DError* encodeURI(
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
        return URI_error(cc.realm, __FUNCTION__);
    }
    ret.put(s);
    return null;
}

//------------------------------------------------------------------------------
@DFD(1)
DError* encodeURIComponent(
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
        return URI_error(cc.realm, __FUNCTION__);
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
                import dmdscript.protoerror : D0base;
                import std.windows.charset : toMBSz;

                // if (arglist[i].type == Value.Type.Object)
                // {
                //     if (auto err = cast(D0base)arglist[i].object)
                //     {
                //         err.exception.toString((b){printf("%s", b.toMBSz);});
                //         continue;
                //     }
                // }

                printf("%s", arglist[i].toString(cc).toMBSz);
            }
            else
            {
                string s = arglist[i].toString(cc);

                writef("%s", s);
            }
        }
    }

    ret.putVundefined();
}

//------------------------------------------------------------------------------
@DFD(1)
DError* print(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // Our own extension
    dglobal_print(cc, othis, ret, arglist);
    return null;
}

//------------------------------------------------------------------------------
@DFD(1)
DError* println(
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
DError* readln(
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
DError* getenv(
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
        string s = arglist[0].toString(cc);
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
DError* ScriptEngine(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import dmdscript.primitive : Text;

    ret.put(Text.DMDScript);
    return null;
}

//------------------------------------------------------------------------------
@DFD(0)
DError* ScriptEngineBuildVersion(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    ret.put(BUILD_VERSION);
    return null;
}

//------------------------------------------------------------------------------
@DFD(0)
DError* ScriptEngineMajorVersion(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    ret.put(MAJOR_VERSION);
    return null;
}

//------------------------------------------------------------------------------
@DFD(0)
DError* ScriptEngineMinorVersion(
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
    return v.toString(cc);
}

//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// I want to remove this.
public auto undefined = vundefined;
