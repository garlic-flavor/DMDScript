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
import std.file;
import std.stdio;
import std.exception;
import core.sys.posix.stdlib;
import core.memory;

import dmdscript.primitive;
import dmdscript.callcontext;
// import dmdscript.program;
import dmdscript.drealm;
import dmdscript.errmsgs;

enum
{
    EXITCODE_INIT_ERROR = 1,
    EXITCODE_INVALID_ARGS = 2,
    EXITCODE_RUNTIME_ERROR = 3,
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
    import std.algorithm : startsWith;
    import dmdscript.drealm : banner;

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
                includes ~= args[i][2..$];
            }
            else if (args[i].startsWith("-"))
            {
                BadSwitchError(args[i]).toString.writefln;
                errors++;
            }
            else
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
        catch (Throwable t)
        {
            errout(t);
            return EXITCODE_RUNTIME_ERROR;
        }

        debug
        {
            if (compileOnly) continue;
        }

        if (verbose)
            writefln("execute %s:", m.srcfile);
        try m.execute();
        catch(Throwable t)
        {
            errout(t);
            return EXITCODE_RUNTIME_ERROR;
        }
    }
    return EXIT_SUCCESS;
}

void errout(Throwable t) nothrow
{
    import dmdscript.exception : ScriptException;
    import std.stdio : stderr, stdout;

    version (Windows)
    {
        //
        static void setConsoleColorRed(void delegate() proc)
        {
            import core.sys.windows.windows;

            auto hConsole = GetStdHandle(STD_OUTPUT_HANDLE);
            assert (hConsole !is INVALID_HANDLE_VALUE);
            CONSOLE_SCREEN_BUFFER_INFO consoleInfo;
            GetConsoleScreenBufferInfo(hConsole, &consoleInfo);
            auto saved_attributes = consoleInfo.wAttributes;
            SetConsoleTextAttribute(hConsole, FOREGROUND_RED);

            scope (exit)
                SetConsoleTextAttribute(hConsole, saved_attributes);

            proc();
        }

        //
        static void setConsoleColorIntensity(void delegate() proc)
        {
            import core.sys.windows.windows;

            auto hConsole = GetStdHandle(STD_OUTPUT_HANDLE);
            assert (hConsole !is INVALID_HANDLE_VALUE);
            CONSOLE_SCREEN_BUFFER_INFO consoleInfo;
            GetConsoleScreenBufferInfo(hConsole, &consoleInfo);
            auto saved_attributes = consoleInfo.wAttributes;
            SetConsoleTextAttribute(hConsole, FOREGROUND_INTENSITY);

            scope (exit)
                SetConsoleTextAttribute(hConsole, saved_attributes);

            proc();
        }
    }

    try
    {
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


        if (auto se = cast(ScriptException)t)
        {
            stdout.flush;
            stderr.flush;

            se.firstTrace(&sink);
            sink(": ");
            setConsoleColorIntensity(
                (){
                    sink(se.type);
                    sink(": ");
                });

            setConsoleColorRed((){sink(se.msg);});
            sink("\n--------------------\n");

            foreach (one; se.traces)
            {
                setConsoleColorIntensity(
                    (){one.scriptNameAndLine(&sink);});

                one.dFileAndLine(&sink);
                sink("\n");

                one.sourceTrace(&sink);
                sink("\n");

                one.irTrace(&sink);
                sink("\n");
            }

            sink("\n--------------------\n");
            se.restInfo(&sink);
            sink("\n--------------------\n");
            se.nextInfo(&sink);

            sink("\n");
            stderr.flush;

        }
        else
        {
            stdout.flush;
            stderr.flush;
            t.toString(&sink);
            sink("\n");
            stderr.flush;
        }
    }
    catch(Throwable){}
}


class SrcFile
{
    string srcfile;
    string[] includes;

    DscriptRealm realm;
    string buffer;
    bool strictMode;

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
        /* Create a DMDScript program, and compile our text buffer.
         */

        realm = new DscriptRealm();

        debug
        {
            realm.dumpMode = dumpMode;
        }

        try realm.compile (srcfile, buffer, &modulePool, strictMode);
        catch (ScriptException e)
        {
            e.setSourceInfo (&getSourceInfo);
            throw e;
        }
        finally
            buffer = null;
    }

    void execute()
    {
        import dmdscript.value: Value;
        import dmdscript.exception;
        /* Execute the resulting program.
         */

        Value ret;

        auto err = realm.execute;
        if (err !is null)
        {
            err.setSourceInfo (&getSourceInfo);
            throw err.toScriptException(realm);
        }
    }


    auto getSourceInfo(string bufferId)
    {
        import dmdscript.exception : ScriptException;
        alias SESource = ScriptException.Source;

        import std.conv : to;
        import std.exception : assumeUnique;

        auto sources = new SESource[includes.length + 1];

        foreach (i, name; includes ~ bufferId)
        {
            auto size = cast(size_t)std.file.getSize(name);
            auto buf = new char[size+1];
            buf[0..size] = cast(char[])std.file.read(name);
            buf[size] = '\n';
            sources[i] = new SESource(name, buf.assumeUnique);
        }
        return sources;
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

        if (!moduleSpecifier.exists)
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

        return buffer.assumeUnique;
    }

debug public:
    Drealm.DumpMode dumpMode;
}

