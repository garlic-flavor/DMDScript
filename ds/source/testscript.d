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
import dmdscript.program;
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
    import dmdscript.dglobal : banner;

    uint errors = 0;
    string[] includes;
    SrcFile[] srcfiles;
    int result;

    bool verbose;

    debug
    {
        bool compileOnly;
        Program.DumpMode dumpMode;
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
        debug
        {
            case "-c":
                compileOnly = true;
                break;
            case "-dumpStatement":
                dumpMode |= Program.DumpMode.Statement;
                break;
            case "-dumpIR":
                dumpMode |= Program.DumpMode.IR;
                break;
            case "-dump":
                dumpMode |= Program.DumpMode.All;
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
                srcfiles ~= new SrcFile(args[i], includes);
                includes = null;
            }
        }
    }
    if (0 < errors)
        return EXITCODE_INVALID_ARGS;

    if (srcfiles.length == 0)
    {
        srcfiles ~= new SrcFile("test", null);
    }

    stderr.writefln("%d source files", srcfiles.length);

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
    version (Windows) // Fuuu****uuuck!
    {
        import std.windows.charset : toMBSz;
        import core.stdc.stdio : fprintf, stderr, fflush;

        try
        {
            stdout.flush;
            fflush(stderr);
            t.toString((b){fprintf(stderr, "%s", b.toMBSz);});
            fprintf(stderr, "\n");
            fflush(stderr);
        }
        catch(Throwable){}
    }
    else
    {
        try
        {
            stdout.flush;
            stderr.flush;
            stderr.writeln(t.toString);
            stderr.flush;
        }
        catch(Throwable){}
    }
}


class SrcFile
{
    string srcfile;
    string[] includes;

    Program program;
    char_t[] buffer;

    this(string srcfilename, string[] includes)
    {
        /* DMDScript source files default to a '.ds' extension
         */

        srcfile = defaultExtension(srcfilename, "ds");
        this.includes = includes;
    }

    void read()
    {
        /* Read the source file, prepend the include files,
         * and put it all in buffer[]. Allocate an extra byte
         * to buffer[] and terminate it with a 0x1A.
         * (If the 0x1A isn't at the end, the lexer will put
         * one there, forcing an extra copy to be made of the
         * source text.)
         */

        //writef("read file '%s'\n",srcfile);

        // Read the includes[] files
        size_t i;
        void[] buf;
        ulong len;

        len = std.file.getSize(srcfile);
        foreach (string filename; includes)
        {
            len += std.file.getSize(filename);
        }
        len++; // leave room for sentinal

        assert(len < uint.max);

        // Prefix the includes[] files

        int sz = cast(int)len;
        buffer = new char_t[sz];

        foreach (string filename; includes)
        {
            buf = std.file.read(filename);
            buffer[i .. i + buf.length] = cast(string)buf[];
            i += buf.length;
        }

        buf = std.file.read(srcfile);
        buffer[i .. i + buf.length] = cast(string)buf[];
        i += buf.length;

        buffer[i] = 0x1A; // ending sentinal
        i++;
        assert(i == len);
    }

    void compile()
    {
        /* Create a DMDScript program, and compile our text buffer.
         */

        program = new Program();

        debug
        {
            program.dumpMode = dumpMode;
        }

        program.compile(srcfile, assumeUnique(buffer), null);
    }

    void execute()
    {
        /* Execute the resulting program.
         */

        program.execute(null);
    }

debug public:
    Program.DumpMode dumpMode;
}

