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

import dmdscript.primitive : string_t, char_t;

//------------------------------------------------------------------------------
///
class ScriptException : Exception
{
    import dmdscript.opcodes : IR;

    // int code; // for what?

    //--------------------------------------------------------------------
    ///
    @nogc @safe pure nothrow
    this(string_t msg, string_t file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
    /// ditto
    @safe pure
    this(string_t message, string_t sourcename, string_t source,
         immutable(char_t)* pos, string file = __FILE__, size_t line = __LINE__)
    {
        super(message, file, line); addTrace(sourcename, source, pos);
    }
    /// ditto
    @safe pure
    this(string_t message, string_t sourcename, string_t source,
         uint linnum, string file = __FILE__, size_t line = __LINE__)
    {
        super(message, file, line); addTrace(sourcename, source, linnum);
    }
    /// ditto
    @safe pure
    this(string_t msg, uint linnum, string file = __FILE__,
         size_t line = __LINE__)
    {
        super(msg, file, line); addTrace(linnum);
    }

    //--------------------------------------------------------------------
    ///
    @safe pure
    void addTrace(string_t sourcename, string_t source, uint linnum)
    {
        trace ~= SourceDescriptor(sourcename, source, linnum);
    }
    /// ditto
    @safe pure
    void addTrace(string_t sourcename, string_t source,
                   immutable(char_t)* pos)
    {
        trace ~= SourceDescriptor(sourcename, source, pos);
    }
    /// ditto
    @safe pure
    void addTrace(uint linnum)
    {
        trace ~= SourceDescriptor(linnum);
    }
    /// ditto
    @safe pure
    void addTrace(const(IR)* base, const(IR)* code)
    {
        trace ~= SourceDescriptor(base, code);
    }
    /// ditto
    @safe @nogc pure nothrow
    void addTrace(string_t sourcename, string_t source)
    {
        foreach (ref one; trace) one.addTrace(sourcename, source);
    }

    //--------------------------------------------------------------------
    ///
    override void toString(scope void delegate(in char[]) sink) const
    {
        debug
        {
            char[20] tmpBuff = void;

            sink(typeid(this).name);
            sink("@"); sink(file);
            sink("("); sink(sizeToTempString(line, tmpBuff, 10)); sink(")");

            if (0 < msg.length)
                sink(": ");
            else
                sink("\n");
        }

        if (0 < msg.length)
        { sink(msg); sink("\n"); }

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
    }
    alias toString = super.toString;

    //====================================================================
private:
    import core.internal.traits : externDFunc;
    alias sizeToTempString = externDFunc!(
        "core.internal.string.unsignedToTempString",
        char[] function(ulong, char[], uint) @safe pure nothrow @nogc);

    //--------------------------------------------------------------------
    struct SourceDescriptor
    {
        //----------------------------------------------------------
        @trusted @nogc pure nothrow
        this(string_t name, string_t buf, immutable(char_t)* pos)
        {
            this.name = name;
            this.buf = buf;
            this.pos = pos;

            assert (buf.length == 0 || pos is null ||
                    (buf.ptr <= pos && pos < buf.ptr + buf.length));
        }
        //
        @safe @nogc pure nothrow
        this(string_t name, string_t buf, uint linnum)
        {
            this.name = name;
            this.buf = buf;
            this.linnum = linnum;
        }
        //
        @safe @nogc pure nothrow
        this(const(IR)* base, const(IR)* code)
        {
            this.base = base;
            this.code = code;
            assert(base !is null);
            assert(code !is null);
            assert(base <= code);
        }
        //
        @safe @nogc pure nothrow
        this(uint linnum)
        {
            this.linnum = linnum;
        }

        //----------------------------------------------------------
        @trusted @nogc pure nothrow
        void addTrace(string_t name, string_t buf)
        {
            if (this.name.length == 0 && this.buf.length == 0)
            {
                this.name = name;
                this.buf = buf;
            }

            assert (buf.length == 0 || pos is null ||
                    (buf.ptr <= pos && pos < buf.ptr + buf.length));
        }

        //----------------------------------------------------------
        void toString(scope void delegate(in char[]) sink) const
        {
             import std.conv : to;
             import std.array : replace;
             import std.range : repeat, take;
             import dmdscript.ir : Opcode;

             char[2] tmpBuff = void;
             string srcline;
             int charpos = -1;
             uint linnum = code !is null ? code.opcode.linnum : this.linnum;
             enum Tab = "    ";

             if (0 < buf.length)
             {
                 if      (pos !is null)
                     srcline = buf.getLineAt(pos, linnum, charpos);
                 else if (0 < linnum)
                     srcline = buf.getLineAt(linnum);
             }

             if (0 < name.length && 0 < linnum)
             {
                 sink(name);
                 sink("(");
                 sink(sizeToTempString(linnum, tmpBuff, 10));
                 sink(")");
             }

             if (0 < srcline.length)
             {
                 sink("\n"); sink(srcline.replace("\t", Tab).to!string);

                 if (0 <= charpos)
                 {
                     size_t col = 0;

                     for (size_t i = 0; i < srcline.length && i < charpos; ++i)
                     {
                         if (srcline[i] == '\t') col += Tab.length;
                         else ++col;
                     }

                     sink("\n");
                     sink(' '.repeat.take(col).to!string);
                     sink("^");
                 }
             }

             debug
             {
                 if (base !is null && code !is null && 0 < linnum)
                 {
                     for (const(IR)* ite = base; ; ite += IR.size(ite.opcode))
                     {
                         if (ite.opcode == Opcode.End ||
                             ite.opcode == Opcode.Error ||
                             linnum < ite.opcode.linnum)
                             break;
                         if (ite.opcode.linnum < linnum)
                             continue;
                         sink(ite is code ? "\n*" : "\n ");
                         IR.toBuffer(0, ite, sink);
                     }
                     sink("\n");
                 }
             }
        }

        //==========================================================
    private:
        string_t name;

        string_t buf;
        immutable(char_t)* pos; // pos is in buf.

        const(IR)* base;
        const(IR)* code;

        uint linnum; // source line number (1 based, 0 if not available)
    }
    SourceDescriptor[] trace;
}

//==============================================================================
private:

//------------------------------------------------------------------------------
@trusted @nogc pure nothrow
string_t getLineAt(string_t base, const(char_t)* p,
                   out uint linnum, out int charpos)
{
    immutable(char)* s;
    immutable(char)* slinestart;

    linnum = 1;
    if (0 == base.length || p is null) return null;

    assert(base.ptr <= p && p <= base.ptr + base.length);

    // Find the beginning of the line
    slinestart = base.ptr;
    for(s = base.ptr; s < p; ++s)
    {
        if(*s == '\n')
        {
            ++linnum;
            slinestart = s + 1;
        }
    }
    charpos = cast(int)(p - slinestart);

    // Find the end of the line
    loop: for(;;)
    {
        switch(*s)
        {
        case '\n':
        case 0:
        case 0x1A:
            break loop;
        default:
            ++s;
        }
    }
    while(slinestart < s && s[-1] == '\r') --s;
    return slinestart[0.. s - slinestart];
}

//------------------------------------------------------------------------------
@safe @nogc pure nothrow
string_t getLineAt(string_t src, uint linnum)
{
    size_t slinestart = 0;
    size_t i;
    uint ln = 1;

    if(0 == src.length)
        return null;
    loop: for(i = 0; i < src.length; ++i)
    {
        switch(src[i])
        {
        case '\n':
            if(linnum <= ln) break loop;
            slinestart = i + 1;
            ++ln;
            break;

        case 0:
        case 0x1A:
            break loop;
        default:
        }
    }

    // Remove trailing \r's
    while(slinestart < i && src[i-1] == '\r') --i;

    return src[slinestart .. i];
}
