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
module dmdscript.exception;
debug import std.stdio;

//------------------------------------------------------------------------------
///
class ScriptException : Exception
{
    import dmdscript.opcodes : IR;

    // int code; // for what?

    //--------------------------------------------------------------------
    ///
    @nogc @safe pure nothrow
    this(string type, string msg,
         string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
        typename = type;
    }

    ///
    @nogc @safe pure nothrow
    this(string type, string msg, Throwable next,
         string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line, next);
        typename = type;
    }

    /// ditto
    @safe pure
    this(string type, string message, string funcname, uint linnum,
         string file = __FILE__, size_t line = __LINE__)
    {
        super(message, file, line);
        addTrace(funcname, linnum, file, line);
        typename = type;
    }

    /// ditto
    @safe pure
    this(string type, string msg, uint linnum, string file = __FILE__,
         size_t line = __LINE__)
    {
        super(msg, file, line);
        addTrace(linnum, file, line);
        typename = type;
    }

    //--------------------------------------------------------------------
    ///
    @safe pure nothrow
    void addMessage(string message)
    {
        msg ~= message;
    }

    ///
    @property @safe @nogc pure nothrow
    string type() const
    {
        return typename;
    }

    //--------------------------------------------------------------------
    ///
    @safe pure
    void addTrace(string funcname, uint linnum,
                  string file = __FILE__, size_t line = __LINE__)
    {
        auto sd = TraceDescriptor(funcname, linnum, file, line);
        if (!alreadyExists(sd))
            trace ~= sd;
    }

    @safe pure
    void addTrace (uint linnum, size_t offset,
                   string f = __FILE__, size_t l = __LINE__)
    {
        auto sd = TraceDescriptor (linnum, offset, f, l);
        if (!alreadyExists(sd))
            trace ~= sd;
    }


    /// ditto
    @safe pure
    void addTrace(uint linnum, string f = __FILE__, size_t l = __LINE__)
    {
        auto sd = TraceDescriptor(linnum, f, l);
        if (!alreadyExists(sd))
            trace ~= sd;
    }
    /// ditto
    @safe pure
    void addTrace(const(IR)* base, const(IR)* code,
                  string f = __FILE__, size_t l = __LINE__)
    {
        auto sd = TraceDescriptor(base, code, f, l);
        if (!alreadyExists(sd))
            trace ~= sd;
    }
    /// ditto
    @safe @nogc pure nothrow
    void addTrace(string funcname)
    {
        foreach (ref one; trace)
            one.addTrace(funcname);
    }

    //
    static class Source
    {
        string filename;
        string buffer;

        this (string filename, string buffer)
        {
            import std.algorithm : count;

            this.filename = filename;
            this.buffer = buffer;

            this.lineCount = cast(size_t)buffer.count('\n');
        }

    private:
        size_t lineCount;
    }

    ///
    void addSourceInfo(Source[] sources)
    {
        foreach (ref one; trace)
            one.addSourceInfo(sources);
    }

    //--------------------------------------------------------------------
    ///
    override void toString(scope void delegate(in char[]) sink) const
    {
        debug
        {
            import std.conv : to;

            sink(typeid(this).name);
            sink("@"); sink(file);
            sink("("); sink(line.to!string); sink(")");

            if (0 < msg.length)
                sink(": ");
            else
                sink("\n");
        }

        sink(typename);
        sink(": ");

        if (0 < msg.length)
        {
            auto savedcolor = setConsoleColorRed;
            sink(msg);
            setConsoleColor(savedcolor);
            sink("\n");
        }

        sink("--------------------\n");

        try
        {
            foreach (one; trace)
                one.toString(sink);
        }
        catch (Throwable){}

        debug
        {
            if (info)
            {
                try
                {
                    sink("\n--------------------");
                    foreach (t; info)
                    { sink("\n"); sink(t); }
                }
                catch (Throwable){}
            }
        }

        if (next !is null)
        {
            sink("\n--------------------\n");
            next.toString(sink);
        }
    }
    alias toString = super.toString;

    //====================================================================
    // import core.internal.traits : externDFunc;
    // alias sizeToTempString = externDFunc!(
    //     "core.internal.string.unsignedToTempString",
    //     char[] function(ulong, char[], uint) @safe pure nothrow @nogc);
private:
    //--------------------------------------------------------------------
    struct TraceDescriptor
    {
        //
        @safe @nogc pure nothrow
        this(string funcname, uint linnum, string dfile, size_t dline)
        {
            this.funcname = funcname;
            this.linnum = linnum;

            this.dFilename = dfile;
            this.dLinnum = dline;
        }
        //
        @safe @nogc pure nothrow
        this(const(IR)* base, const(IR)* code, string dfile, size_t dline)
        {
            this.base = base;
            this.code = code;
            assert(base !is null);
            assert(code !is null);
            assert(base <= code);

            if (linnum == 0)
                linnum = code.opcode.linnum;
            this.dFilename = dfile;
            this.dLinnum = dline;
        }
        //
        @safe @nogc pure nothrow
        this(uint linnum, string dfile, size_t dline)
        {
            this.linnum = linnum;

            this.dFilename = dfile;
            this.dLinnum = dline;
        }

        //
        @safe @nogc pure nothrow
        this(uint linnum, size_t offset, string dfile, size_t dline)
        {
            this.linnum = linnum;
            this.offset = offset;
            this.haveOffset = true;
            this.dFilename = dfile;
            this.dLinnum = dline;
        }

        //----------------------------------------------------------
        @trusted @nogc pure nothrow
        void addTrace(string funcname)
        {
            if (this.funcname.length == 0)
                this.funcname = funcname;
        }

        //----------------------------------------------------------
        void addSourceInfo(Source[] sources)
        {
            size_t accLine;
            size_t accOffset;
            if (linnum == 0)
                return;

            foreach (one; sources)
            {
                if (linnum <= accLine + one.lineCount)
                {
                    sourcename = one.filename;
                    linnum -= accLine;
                    if (haveOffset)
                        offset -= accOffset;
                    line = getLineAt(one.buffer, linnum, haveOffset, offset);
                    break;
                }
                accLine += one.lineCount;
                accOffset += one.buffer.length;
            }
        }

        //----------------------------------------------------------
        void toString(scope void delegate(in char[]) sink) const
        {
             import std.conv : to;
             import std.array : replace;
             import std.range : repeat, take;
             import std.string : stripRight;
             import dmdscript.ir : Opcode;

             enum Tab = "    ";

             if ((0 < sourcename.length || 0 < funcname.length) && 0 < linnum)
             {
                 auto savedcolor = setConsoleColorIntensity;
                 sink("@");
                 if (0 < sourcename.length)
                     sink(sourcename);
                 if (0 < funcname.length)
                 {
                     if (0 < sourcename.length)
                         sink("/");
                     sink(funcname);
                 }
                 sink("(");
                 sink(linnum.to!string);
                 sink(")");
                 setConsoleColor(savedcolor);
             }

             debug
             {
                 sink("[@");
                 sink(dFilename);
                 sink("("); sink(dLinnum.to!string); sink(")]");
             }

             if (0 < line.length)
             {
                 sink("\n>"); sink(line.replace("\t", Tab).stripRight);
                 sink("\n");

                 if (haveOffset)
                 {
                     size_t col = 0;

                     for (size_t i = 0; i < line.length && i < offset; ++i)
                     {
                         if (line[i] == '\t') col += Tab.length;
                         else ++col;
                     }

                     sink(' '.repeat.take(col).to!string);
                     sink(" ^\n");
                 }
             }
             else
                 sink("\n");

             debug
             {
                 if (base !is null && code !is null && 0 < linnum)
                 {
                     for (const(IR)* ite = base; ; ite += IR.size(ite.opcode))
                     {
                         if (ite.opcode == Opcode.End ||
                             ite.opcode == Opcode.Error ||
                             code.opcode.linnum < ite.opcode.linnum)
                             break;
                         if (ite.opcode.linnum < code.opcode.linnum)
                             continue;
                         sink(ite is code ? "\n*" : "\n ");
                         IR.toBuffer(0, ite, sink);
                     }
                     sink("\n");
                 }
             }
        }

        //
        @safe @nogc pure nothrow
        bool opEquals(in ref TraceDescriptor r) const
        {
            return
                (base !is null && base is r.base &&
                 code !is null && code is r.code) ||

                (0 < linnum && linnum is r.linnum) ||

                (haveOffset && offset is r.offset);
        }

        //==========================================================
        string sourcename;
        string funcname;

        string dFilename;
        size_t dLinnum;

        const(IR)* base;
        const(IR)* code;

        uint linnum; // line number (1 based, 0 if not available)
        string line; //
        bool haveOffset;//
        size_t offset; //
    }

    //====================================================================
private:
    TraceDescriptor[] trace;
    string typename;

    //
    @safe @nogc pure nothrow
    bool alreadyExists(in ref TraceDescriptor sd) const
    {
        return 0 < trace.length && trace[$-1] == sd;
    }


    //
    static short setConsoleColorRed()
    {
        version (Windows)
        {
            import core.sys.windows.windows;

            auto hConsole = GetStdHandle(STD_OUTPUT_HANDLE);
            assert (hConsole !is INVALID_HANDLE_VALUE);
            CONSOLE_SCREEN_BUFFER_INFO consoleInfo;
            GetConsoleScreenBufferInfo(hConsole, &consoleInfo);
            auto saved_attributes = consoleInfo.wAttributes;
            SetConsoleTextAttribute(hConsole, FOREGROUND_RED);
            return saved_attributes;
        }
        else
            return 0;
    }

    //
    static short setConsoleColorIntensity()
    {
        version (Windows)
        {
            import core.sys.windows.windows;

            auto hConsole = GetStdHandle(STD_OUTPUT_HANDLE);
            assert (hConsole !is INVALID_HANDLE_VALUE);
            CONSOLE_SCREEN_BUFFER_INFO consoleInfo;
            GetConsoleScreenBufferInfo(hConsole, &consoleInfo);
            auto saved_attributes = consoleInfo.wAttributes;
            SetConsoleTextAttribute(hConsole, FOREGROUND_INTENSITY);
            return saved_attributes;
        }
        else
            return 0;
    }

    //
    static void setConsoleColor(short saved_attributes)
    {
        version (Windows)
        {
            import core.sys.windows.windows;

            auto hConsole = GetStdHandle(STD_OUTPUT_HANDLE);
            assert (hConsole !is INVALID_HANDLE_VALUE);
            SetConsoleTextAttribute(hConsole, saved_attributes);
        }
    }

}

//==============================================================================
private:

string getLineAt(string base, uint linnum, bool haveOffset, ref size_t offset)
{
    size_t l = 1;
    bool thisLine = false;
    size_t lineStart = 0;

    if (l == linnum)
        thisLine = true;

    for (size_t i = 0; i < base.length; ++i)
    {
        if (base[i] == '\n')
        {
            if (thisLine)
                return base[lineStart .. i];

            ++l;
            if (l == linnum)
            {
                thisLine = true;
                lineStart = i+1;
                if (haveOffset)
                    offset -= lineStart;
            }
        }
    }
    if (thisLine)
        return base[lineStart .. $];
    else
        return null;
}

