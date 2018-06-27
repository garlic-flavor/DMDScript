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

module testscript;

import std.path;
static import std.file;
import std.stdio;
import std.exception;
import core.sys.posix.stdlib;
import core.memory;

import dmdscript.primitive;
import dmdscript.callcontext;
// import dmdscript.program;
import dmdscript.drealm;
import dmdscript.errmsgs;
import dmdscript.exception;
import dmdscript.derror: Derror;

enum
{
    EXITCODE_INIT_ERROR = 1,
    EXITCODE_INVALID_ARGS = 2,
    EXITCODE_RUNTIME_ERROR = 3,
    EXITCODE_COMPILE_ERROR = 4,
}

/**************************************************
Usage:

    ds
        will run test.ds

    ds foo
        will run foo.ds

    ds foo.js
        will run foo.js

    ds foo1 foo2 foo.bar
        will run foo1.ds, foo2.ds, foo.bar

    The -iinc flag will prefix the source files with the contents of file inc.
    There can be multiple -i's. The include list is reset to empty any time
    a new -i is encountered that is not preceded by a -i.

    ds -iinc foo
        will prefix foo.ds with inc

    ds -iinc1 -iinc2 foo bar
        will prefix foo.ds with inc1+inc2, and will prefix bar.ds
        with inc1+inc2

    ds -iinc1 -iinc2 foo -iinc3 bar
        will prefix foo.ds with inc1+inc2, and will prefix bar.ds
        with inc3

    ds -iinc1 -iinc2 foo -i bar
        will prefix foo.ds with inc1+inc2, and will prefix bar.ds
        with nothing

 */

int main(string[] args)
{
    import std.algorithm: startsWith;
    import std.string: strip;
    import dmdscript.drealm: banner;

    uint errors = 0;
    string[] includes;
    SrcFile[] srcfiles;
    int result;

    bool verbose;
    bool strictMode;

    debug
    {
        bool compileOnly;
        Drealm.DumpMode dumpMode;
    }

    if(args.length == 1)
        stderr.writefln(banner);
    for (size_t i = 1; i < args.length; i++)
    {
        switch (args[i])
        {
        case "-v":
            verbose = true;
            break;
        case "-s":
            strictMode = true;
            break;
        debug
        {
            case "-c":
                compileOnly = true;
                break;
            case "-dumpStatement":
                dumpMode |= Drealm.DumpMode.Statement;
                break;
            case "-dumpIR":
                dumpMode |= Drealm.DumpMode.IR;
                break;
            case "-dump":
                dumpMode |= Drealm.DumpMode.All;
                break;
        }
        default:
            if      (args[i].startsWith("-i"))
            {
                includes ~= args[i][2..$].strip;
            }
            else if (args[i].startsWith("-"))
            {
                BadSwitchError(args[i]).writefln;
                errors++;
            }
            else if (0 < args[i].strip.length)
            {
                srcfiles ~= new SrcFile(args[i], includes, strictMode);
                includes = null;
            }
        }
    }
    if (0 < errors)
        return EXITCODE_INVALID_ARGS;

    if (srcfiles.length == 0)
    {
        srcfiles ~= new SrcFile("test", null, strictMode);
    }

//    stderr.writefln("%d source files", srcfiles.length);

    // Read files, parse them, execute them
    foreach (SrcFile m; srcfiles)
    {
        debug
        {
            m.dumpMode = dumpMode;
        }
        if (verbose)
            writefln("read    %s:", m.srcfile);
        m.read();

        if (verbose)
            writefln("compile %s:", m.srcfile);
        try m.compile();
        catch (SyntaxException se)
        {
            errout(se, m);
            return EXITCODE_COMPILE_ERROR;
        }
        catch (EarlyException ee)
        {
            errout(ee, m);
            return EXITCODE_COMPILE_ERROR;
        }

        debug
        {
            if (compileOnly) continue;
        }
        if (verbose)
            writefln("execute %s:", m.srcfile);

        if (auto err = m.execute())
        {
            errout(err, m);
            return EXITCODE_RUNTIME_ERROR;
        }
    }
    return EXIT_SUCCESS;
}

class SrcFile
{
    import dmdscript.functiondefinition: FunctionDefinition;
    string srcfile;
    string[] includes;

    string buffer;
    bool strictMode;
    FunctionDefinition fd;

    this(string srcfilename, string[] includes, bool strictMode = false)
    {
        /* DMDScript source files default to a '.ds' extension
         */
        srcfile = defaultExtension(srcfilename, "ds");
        this.includes = includes;
        this.strictMode = strictMode;
    }

    void read()
    {
        buffer = modulePool(srcfile);
    }

    void compile()
    {
        import dmdscript.exception;
        import dmdscript.value: Value;
        import dmdscript.primitive: PropertyKey;
        import dmdscript.property: Property;
        import dmdscript.dnative: install;
        import dmdscript.program: parse, analyze, generate;
        import dmdscript.statement: TopStatement;
        /* Create a DMDScript program, and compile our text buffer.
         */

        try
        {
            fd = buffer.parse(&modulePool, strictMode);

            debug
            {
                if (dumpMode & Drealm.DumpMode.Statement)
                    TopStatement.dump(fd.topstatements,b=>b.write);
            }

            fd.analyze.generate;

            debug
            {
                if (dumpMode & Drealm.DumpMode.IR)
                    FunctionDefinition.dump(fd, b=>b.write);
            }
        }
        finally
            buffer = null;
    }

    Derror execute()
    {
        import dmdscript.value: Value;
        import dmdscript.exception;
        import dmdscript.program: execute;
        import dmdscript.dnative: install;
        /* Execute the resulting program.
         */

        Value ret;
        auto realm = new Drealm(srcfile, &modulePool);

        debug
        {
            realm.dumpMode = dumpMode;
        }
        realm.install(
            "$262", new Test262(realm.rootPrototype, realm.functionPrototype));

        return fd.execute(realm, ret);
    }

    string modulePool(string moduleSpecifier)
    {
        /* Read the source file, prepend the include files,
         * and put it all in buffer[]. Allocate an extra byte
         * to buffer[] and terminate it with a 0x1A.
         * (If the 0x1A isn't at the end, the lexer will put
         * one there, forcing an extra copy to be made of the
         * source text.)
         */
        /*
          When the include file does not end with line terminator,
          the line number of the error message is wrong.
          So, each include files have a sentinel of line terminator.
        */

        //writef("read file '%s'\n",srcfile);

        assert (0 < moduleSpecifier.length);

        if (auto pbuf = moduleSpecifier in pool)
            return *pbuf;

        if (!std.file.exists(moduleSpecifier))
            throw new Exception (moduleSpecifier ~ " is not found.");

        // Read the includes[] files
        size_t i;
        void[] buf;
        ulong len;

        len = std.file.getSize(moduleSpecifier);
        foreach (string filename; includes)
        {
            len += std.file.getSize(filename);
            len++; // room for sentinal of line terminator
        }
        len++; // leave room for sentinel

        assert(len < uint.max);

        // Prefix the includes[] files

        int sz = cast(int)len;
        auto buffer = new char[sz];

        foreach (string filename; includes)
        {
            buf = std.file.read(filename);
            buffer[i .. i + buf.length] = cast(string)buf[];
            i += buf.length;

            buffer[i] = '\n';
            ++i;
        }

        buf = std.file.read(moduleSpecifier);
        buffer[i .. i + buf.length] = cast(string)buf[];
        i += buf.length;

        buffer[i] = 0x1A; // ending sentinal
        i++;
        assert(i == len);

        auto ret = buffer.assumeUnique;
        pool[moduleSpecifier] = ret;
        return ret;
    }
    string[string] pool;

    bool searchInfo(in string base, in const(char)* head,
                    out string name, out string line,
                    out size_t linnum, out size_t column)
    {
        string bufferSpec;
        foreach (key, val; pool)
        {
            if (val.ptr is base.ptr)
            {
                bufferSpec = key;
                assert (val.length == base.length);
                assert (val[$-1] == 0x1A);
                assert (base[$-1] == 0x1A);
                break;
            }
        }
        if (0 == bufferSpec.length)
            return false;

        auto start = base.ptr;
        foreach (n; includes ~ bufferSpec)
        {
            auto len = std.file.getSize(n) + 1;
            if (start + len <= head)
            {
                start += len;
                continue;
            }

            name = n;
            return searchInfo(start[0..cast(size_t)len], head,
                              line, linnum, column);
        }

        return false;
    }

    bool searchInfo(in string base, in const(char)* head,
                    out string line, out size_t linnum, out size_t column)
    {
        auto start = base.ptr;
        linnum = 1;
        for (auto ite = start; ite < start + base.length; ++ite)
        {
            if ((*ite) == '\n' || (*ite) == 0x1A)
            {
                if (head <= ite || (*ite) == 0x1A)
                {
                    column = head - start;
                    line = start[0..ite - start];
                    return true;
                }

                ++linnum;
                start = ite + 1;
            }
        }

        return false;
    }

    bool searchInfo(in string id, ref size_t linnum,
                    out string name, out string line)
    {
        auto moduleSpec = 0 < id.length ? id : srcfile;
        string buf = modulePool(moduleSpec);
        auto start = buf.ptr;
        foreach (n; includes ~ moduleSpec)
        {
            auto len = std.file.getSize(n) + 1;
            if (searchInfo(start[0..cast(size_t)len], linnum, line))
            {
                name = n;
                return true;
            }
            else
                start += len;
        }
        return false;
    }

    bool searchInfo(string buf, ref size_t linnum, out string line)
    {
        auto start = buf.ptr;
        size_t l;
        for (auto ite = start; ; ++ite)
        {
            if ((*ite) == '\n' || ite == buf.ptr + buf.length)
            {
                if      (l + 1 == linnum)
                {
                    line = start[0..ite - start];
                    return true;
                }
                ++l;
                start = ite + 1;

                if (&buf[$-1] <= ite)
                    break;
            }
        }
        linnum -= l;
        return false;
    }

debug public:
    Drealm.DumpMode dumpMode;

}

//------------------------------------------------------------------------------
class Test262 : Dobject
{
    import dmdscript.dnative: DFD = DnativeFunctionDescriptor,
        DnativeFunction, install;
    import dmdscript.value: Value;
    import dmdscript.derror: Derror;

    this (Dobject superPrototype, Dobject functionPrototype)
    {
        super (new Dobject(superPrototype));

        install!Test262(this, functionPrototype);
    }

static:

    @DFD(0)
    Derror createRealm(
        DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
        Value[] arglist)
    {
        Value* v;
        string moduleId = "anonymous";
        Dobject o;

        if (0 < arglist.length)
        {
            v = &arglist[0];
            if (!v.isUndefinedOrNull)
                v.to(moduleId, cc);
        }

        o = new DemptyRealm(moduleId, cc.realm.modulePool);
        assert (o !is null);

        o.install("global", o);

        ret.put(o);
        return null;
    }

}

//------------------------------------------------------------------------------
class DemptyRealm: Drealm
{
    import dmdscript.value: Value;
    import dmdscript.derror: Derror;
    import dmdscript.primitive: ModulePool;
    import dmdscript.functiondefinition: FunctionDefinition;
    import dmdscript.dnative: DnativeFunction, DFD = DnativeFunctionDescriptor;

    this(string scriptId, ModulePool modulePool/*, bool strictMode*/)
    {
        import dmdscript.dnative: install;
        super(scriptId, modulePool);

        install!DemptyRealm(this, functionPrototype);
    }

static:
    @DFD(1)
    Derror eval(
        DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
        Value[] arglist)
    {
        import dmdscript.drealm: superEval = eval;
        assert (cast(Drealm)othis !is null);

        auto ncc = CallContext.push(cast(Drealm)othis, cc.strictMode);
        auto r = superEval(pthis, ncc, othis, ret, arglist);
        CallContext.pop(ncc);
        return r;
    }
}

//==============================================================================

void sink(in char[] b)
{
    version (Windows)
    {
        import std.windows.charset : toMBSz;

        auto buf = b.toMBSz;
        for (size_t i = 0; i < size_t.max; ++i)
        {
            if (buf[i] == '\0')
            {
                stderr.write(buf[0..i]);
                break;
            }
        }
    }
    else
        stderr.write(b);
}

void errout(SyntaxException se, ref SrcFile sf)
{
    import std.string: stripLeft;
    import std.array: array;
    import std.range: repeat, take;
    import core.internal.string: unsignedToTempString;
    char[20] tmpBuf = void;

    assert (se !is null);

    string name, line;
    size_t linnum, column;

    stdout.flush;
    stderr.flush;
    scope(exit) stderr.flush;

    if (!sf.searchInfo(se.base, se.head, name, line, linnum, column) &&
        !sf.searchInfo(se.base, se.head, line, linnum, column))
    {
        sink(se.toString);
        sink("\n");
        return;
    }
    if (0 == name.length)
        name = "anonymous";

    setConsoleColorRed({sink("SyntaxError");});
    sink("@"); sink(se.file);
    sink("("); sink(unsignedToTempString(se.line, tmpBuf, 10)); sink(")");
    if (se.strictMode)
        sink("[STRICT MODE]");
    if (0 < se.msg.length)
    {
        sink(": ");
        setConsoleColorIntensity({sink(se.msg);});
    }

    sink("\n"); sink(name);
    sink("("); sink(unsignedToTempString(linnum, tmpBuf, 10)); sink(")\n");
    sink(" >");
    sink(line); sink("\n");

    auto rline = line.stripLeft;
    sink(line[0..$-rline.length]); // output indent.
    ' '.repeat.take(column - line.length + rline.length + 2).array.sink;
    sink("^\n");

    errinfo(se);
}

void errout(EarlyException ee, ref SrcFile sf)
{
    import core.internal.string: unsignedToTempString;
    char[20] tmpBuf = void;

    assert (ee !is null);
    string name, line;
    size_t linnum = ee.linnum;

    stdout.flush;
    stderr.flush;
    scope(exit) stderr.flush;

    if ((0 < ee.base.length && !sf.searchInfo(ee.base, linnum, line)) ||
        (0 == ee.base.length && !sf.searchInfo(ee.id, linnum, name, line)))
    {
        sink(ee.toString);
        sink("\n");
        return;
    }

    setConsoleColorRed({sink(ee.type); sink("[early]"); });
    sink("@"); sink(ee.file);
    sink("("); sink(unsignedToTempString(ee.line, tmpBuf, 10)); sink(")");
    if (0 < ee.msg.length)
    {
        sink(": ");
        setConsoleColorIntensity({sink(ee.msg);});
    }

    sink("\n");
    sink(name);
    sink("("); sink(unsignedToTempString(linnum, tmpBuf, 10)); sink(")\n");
    sink(" >"); sink(line); sink("\n");

    errinfo(ee);
}

void errinfo(Throwable t)
{
    debug
    {
        if (t.info !is null)
        {
            try
            {
                sink("\n----------");
                foreach (i; t.info)
                {
                    sink("\n");
                    sink(i);
                }
            }
            catch (Throwable){}
        }
        sink("\n");
        if (t.next !is null)
            sink(t.next.toString);
    }
}

void errout(Derror e, ref SrcFile sf)
{
    import std.format: format;
    import dmdscript.ir: Opcode;
    import dmdscript.opcodes: IR;
    import core.internal.string: unsignedToTempString;
    char[20] tmpBuf = void;

    assert (e !is null);
    assert (sf !is null);


    stdout.flush;
    stderr.flush;
    scope(exit) stderr.flush;

next:
    setConsoleColorRed({sink(e.message);}); sink("\n");

    if (auto t = e.throwable)
    {
        if      (auto se = cast(SyntaxException)t)
            errout(se, sf);
        else if (auto ee = cast(EarlyException)t)
            errout(e, sf);
        else
            sink(t.toString);
        sink("\n");
    }

    for (auto t = e.trace; t !is null; t = t.next)
    {
        debug
        {
            sink(t.dFile);
            sink("(");
            sink(unsignedToTempString(t.dLine, tmpBuf, 10));
            sink(")\n");
        }

        if (t.code is null)
            continue;

        string name, line;
        size_t linnum = t.code.opcode.linnum;
        if ((0 < t.src.length && !sf.searchInfo(t.src, linnum, line)) ||
            (0 == t.src.length &&
             !sf.searchInfo(t.bufferId, linnum, name, line)))
        {
            sink("\n");
            continue;
        }

        if      (0 < name.length){}
        else if (0 < t.bufferId.length)
            name = t.bufferId;
        else
            name = "anonymous";

        setConsoleColorYellow(
            {
                sink(name); sink(":"); sink(t.funcname);
                sink("("); sink(unsignedToTempString(linnum, tmpBuf, 10));
                sink(")");
                if (t.strictMode)
                    sink("[STRICT MODE]");
                sink("\n");
            });

        sink("@ "); sink(line); sink("\n\n");

        debug
        {
            for (auto ite = t.base;
                 ite.opcode != Opcode.End && ite.opcode != Opcode.Error;
                 ite += IR.size(ite.opcode))
            {
                if (ite.opcode.linnum == t.code.opcode.linnum)
                {
                    sink(ite is t.code ? "@" : " ");
                    sink("% 4d[%04d]:".format(linnum, ite - t.base));
                    IR.toBuffer(0, ite, a=>sink(a));
                    sink("\n");
                }
            }
        }
        sink("\n");
    }

    if (auto p = e.previous)
    {
        sink("----------\n");
        e = p;
        goto next;
    }
}


// string getLineAt(string base, uint linnum, bool haveOffset, ref size_t offset)
// {
//     size_t l = 1;
//     bool thisLine = false;
//     size_t lineStart = 0;

//     if (l == linnum)
//         thisLine = true;

//     for (size_t i = 0; i < base.length; ++i)
//     {
//         if (base[i] == '\n')
//         {
//             if (thisLine)
//                 return base[lineStart .. i];

//             ++l;
//             if (l == linnum)
//             {
//                 thisLine = true;
//                 lineStart = i+1;
//                 if (haveOffset)
//                     offset -= lineStart;
//             }
//         }
//     }
//     if (thisLine)
//         return base[lineStart .. $];
//     else
//         return null;
// }


// void errout(Throwable t, ref SrcFile sf) nothrow
// {
//     import std.stdio : stderr, stdout;


//     try
//     {
//         import core.internal.string : unsignedToTempString;
//         import std.array: replace;
//         import std.string: stripRight;
//         import dmdscript.ir: Opcode;
//         char[20] tmpBuff = void;
//         enum Tab = "    ";

//         void sink(in char[] b)
//         {
//             version (Windows)
//             {
//                 import std.windows.charset : toMBSz;

//                 auto buf = b.toMBSz;
//                 for (size_t i = 0; i < size_t.max; ++i)
//                 {
//                     if (buf[i] == '\0')
//                     {
//                         stderr.write(buf[0..i]);
//                         break;
//                     }
//                 }
//             }
//             else
//                 stderr.write(b);
//         }


//         // if (auto se = cast(ScriptException)t)
//         // {
//         //     stdout.flush;
//         //     stderr.flush;

//         //     se.firstTrace(&sink);
//         //     sink(": ");
//         //     setConsoleColorIntensity(
//         //         (){
//         //             sink(se.type);
//         //             sink(": ");
//         //         });

//         //     setConsoleColorRed((){sink(se.msg);});
//         //     sink("\n--------------------\n");

//         //     foreach (one; se.traces)
//         //     {
//         //         if (0 == one.bufferId.length)
//         //             continue;

//         //         auto sources = sf.getSoucreInfo(one.bufferId);
//         //         string sourcename = "";
//         //         string buffer = "";
//         //         size_t lineshift = 0;
//         //         foreach (s; sources)
//         //         {
//         //             if (one.line <= lineshift + s.lineCount)
//         //             {
//         //                 sourcename = s.filename;
//         //                 buffer = s.buffer;
//         //                 break;
//         //             }
//         //             else
//         //                 lineshift += s.lineCount;
//         //         }

//         //         setConsoleColorIntensity(
//         //             (){
//         //                 sink("(#");
//         //                 sink(one.bufferId);
//         //                 sink(")");
//         //                 if ((0 < sourcename.length || one.funcname.length)
//         //                     && 0 < one.linnum)
//         //                     sink("@");
//         //                 if (0 < sourcename.length)
//         //                     sink(sourcename);
//         //                 if (0 < one.funcname.length)
//         //                 {
//         //                     if (0 < soucename.length)
//         //                         sink("/");
//         //                     sink(one.funcname);
//         //                 }
//         //                 if (0 < linnum)
//         //                 {
//         //                     sink("(");
//         //                     sink(unsignedToTempString(
//         //                              linnum - lineshift, tmpBuff, 10));
//         //                     sink(")");
//         //                 }
//         //                 if (strictMode)
//         //                     sink("[STRICT MODE]");
//         //             });

//         //         sink("[@");
//         //         sink(one.dFilename);
//         //         sink("(");
//         //         sink(unsignedToTempString(one.dLinnum, tmpBuff, 10));
//         //         sink(")]");
//         //         sink("\n");

//         //         auto ofs = one.offset;
//         //         auto line = getLineAt(buffer, one.linnum - lineshift,
//         //                               one.haveOffset, ofs);
//         //         if (0 < line.length)
//         //         {
//         //             sink(">");
//         //             sink(line.replace("\t", Tab).stripRight);
//         //             if (one.haveOffset)
//         //             {
//         //                 sink("\n");
//         //                 for (size_t i = 0; i < line.length && i < ofs; ++i)
//         //                 {
//         //                     if (line[i] == '\t')
//         //                         sink(Tab);
//         //                     else
//         //                         sink(" ");
//         //                 }
//         //                 sink(" ^\n");
//         //             }
//         //         }

//         //         sink("\n");

//         //         if (one.base !is null && one.code !is null && 0 < one.linnum)
//         //         {
//         //             for (const(IR)* ite = base; ; ite += IR.size(ite.opcode))
//         //             {
//         //                 if (ite.opcode == Opcode.End ||
//         //                     ite.opcode == Opcode.Error ||
//         //                     one.code.opcode.linnum < ite.opcode.linnum)
//         //                     break;
//         //                 if (ite.opcode.linnum < one.code.opcode.linnum)
//         //                     continue;
//         //                 sink(ite is code ? "*" : " ");
//         //                 IR.toBuffer(0, ite, sink, lineshift);
//         //                 sink("\n");
//         //             }
//         //         }
//         //         sink("\n");
//         //     }

//         //     sink("\n--------------------\n");
//         //     se.restInfo(&sink);
//         //     sink("\n--------------------\n");
//         //     se.nextInfo(&sink);

//         //     sink("\n");
//         //     stderr.flush;

//         // }
//         // else
//         // {
//             stdout.flush;
//             stderr.flush;
//             t.toString(&sink);
//             sink("\n");
//             stderr.flush;
//         // }
//     }
//     catch(Throwable){}
// }




/+
//------------------------------------------------------------------------------
struct ModuleCode
{
    string code; // whole code.
    alias code this;

    struct Block
    {
        string name; // filename, typically.
        string code;  // a slice of the whole code.
    }
    Block[] blocks;

    this(string[] srcs...)
    {
        if (0 == srcs.length)
            return;
        code = srcs[0];
        for (size_t i = 1; i < srcs.length - 1; i += 2)
        {
            assert (code.ptr <= srcs[i+1].ptr &&
                    srcs[i+1].ptr + srcs[i+1].length <= code.ptr + code.length);
            blocks ~= Block(srcs[i], srcs[i+1]);
        }
    }


    @property @safe @nogc pure nothrow
    bool empty() const
    {
        return 0 == code.length;
    }


    struct Result
    {
        bool found;
        string name;
        string line;
        size_t linnum;
        size_t column;
    }

    Result search(const(char)* head) const
    {
        static Result impl(in ref Block block, const(char)* head)
        {
            auto ite = block.code.ptr;
            auto linehead = block.code.ptr;
            size_t linnum = 1;
            for (; ite < head; ++ite)
            {
                if (*ite == '\n')
                {
                    linehead = ite + 1;
                    ++linnum;
                }
            }

            for (; ite < (block.code.ptr + block.code.length); ++ite)
            {
                if (*ite == '\n')
                    break;
            }
            return Result (
                true, block.name, linehead[0..ite - linehead],
                linnum, cast(size_t)(head - linehead));
        }

        foreach (ref block; blocks)
        {
            if (block.code.ptr <= head &&
                head < (block.code.ptr + block.code.length))
                return impl(block, head);
        }
        return Result();
    }

    Result search(size_t linnum) const
    {
        size_t l = 1;
        if (linnum == 1)
            return search(code.ptr);
        for(auto ite = code.ptr; ite < code.ptr + code.length; ++ite)
        {
            if (*ite == '\n')
            {
                ++l;
                if (l == linnum)
                    return search(ite+1);
            }
        }
        return Result();
    }
}
+/

void setConsoleColor(uint ATTR)(void delegate() proc)
{
    version (Windows)
    {
        import core.sys.windows.windows;

        auto hConsole = GetStdHandle(STD_OUTPUT_HANDLE);
        assert (hConsole !is INVALID_HANDLE_VALUE);
        CONSOLE_SCREEN_BUFFER_INFO consoleInfo;
        GetConsoleScreenBufferInfo(hConsole, &consoleInfo);
        auto saved_attributes = consoleInfo.wAttributes;

        stdout.flush;
        SetConsoleTextAttribute(hConsole, ATTR);
        scope (exit)
        {
            stdout.flush;
            SetConsoleTextAttribute(hConsole, saved_attributes);
        }
    }
    proc();
}

version(Windows)
{
    import core.sys.windows.windows;
    alias setConsoleColorRed = setConsoleColor!92;
    alias setConsoleColorIntensity = setConsoleColor!FOREGROUND_INTENSITY;
    alias setConsoleColorYellow = setConsoleColor!94;
    alias setConsoleColorHiContrast = setConsoleColor!15;
}
else
{
    alias setConsoleColorRed = setConsoleColor!0;
    alias setConsoleColorIntensity = setConsoleColor!0;
    alias setConsoleColorYellow = setConsoleColor!0;
    alias setConsoleColorHiContrast = setConsoleColor!15;
}

