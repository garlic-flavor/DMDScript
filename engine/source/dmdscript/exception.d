module dmdscript.exception;

import dmdscript.primitive;

//
class ScriptException : Exception
{
    import dmdscript.opcodes : IR;

    int code; // for what?

    @nogc @safe pure nothrow
    this(tstring msg, tstring file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }

    @safe pure
    this(tstring message, tstring sourcename, tstring source,
         immutable(tchar)* pos, string file = __FILE__, size_t line = __LINE__)
    {
        super(message, file, line); addTrace(sourcename, source, pos);
    }

    @safe pure
    this(tstring message, tstring sourcename, tstring source,
         line_number loc, string file = __FILE__, size_t line = __LINE__)
    {
        super(message, file, line); addTrace(sourcename, source, loc);
    }

    @safe pure
    this(tstring msg, line_number loc, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line); addTrace(loc);
    }

    @safe pure
    void addTrace(tstring sourcename, tstring source, line_number loc)
    {
        trace ~= SourceDescriptor(sourcename, source, loc);
    }

    @safe pure
    void addTrace(tstring sourcename, tstring source,
                   immutable(tchar)* pos)
    {
        trace ~= SourceDescriptor(sourcename, source, pos);
    }

    @safe pure
    void addTrace(line_number loc)
    {
        trace ~= SourceDescriptor(loc);
    }

    @safe pure
    void addTrace(const(IR)* base, const(IR)* code)
    {
        trace ~= SourceDescriptor(base, code);
    }

    @safe @nogc pure nothrow
    void addTrace(tstring sourcename, tstring source)
    {
        foreach (ref one; trace) one.addTrace(sourcename, source);
    }

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

private:
    import core.internal.traits : externDFunc;
    alias sizeToTempString = externDFunc!(
        "core.internal.string.unsignedToTempString",
        char[] function(ulong, char[], uint) @safe pure nothrow @nogc);

    struct SourceDescriptor
    {
        tstring name;

        tstring buf;
        immutable(tchar)* pos; // pos is in buf.

        const(IR)* base;
        const(IR)* code;

        line_number linnum; // source line number (1 based, 0 if not available)

        @trusted @nogc pure nothrow
        this(tstring name, tstring buf, immutable(tchar)* pos)
        {
            this.name = name;
            this.buf = buf;
            this.pos = pos;

            assert (buf.length == 0 || pos is null ||
                    (buf.ptr <= pos && pos < buf.ptr + buf.length));
        }

        @safe @nogc pure nothrow
        this(tstring name, tstring buf, line_number linnum)
        {
            this.name = name;
            this.buf = buf;
            this.linnum = linnum;
        }

        @safe @nogc pure nothrow
        this(const(IR)* base, const(IR)* code)
        {
            this.base = base;
            this.code = code;
            assert(base !is null);
            assert(code !is null);
            assert(base <= code);
        }

        @safe @nogc pure nothrow
        this(line_number linnum)
        {
            this.linnum = linnum;
        }

        @trusted @nogc pure nothrow
        void addTrace(tstring name, tstring buf)
        {
            if (this.name.length == 0 && this.buf.length == 0)
            {
                this.name = name;
                this.buf = buf;
            }

            assert (buf.length == 0 || pos is null ||
                    (buf.ptr <= pos && pos < buf.ptr + buf.length));
        }

        void toString(scope void delegate(in char[]) sink) const
        {
             import std.conv : to;
             import std.array : replace;
             import std.range : repeat, take;
             import dmdscript.ir : Opcode;

             char[2] tmpBuff = void;
             string srcline;
             int charpos = -1;
             line_number linnum = code !is null ? code.opcode.linnum : this.linnum;
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

    }
    SourceDescriptor[] trace;
}

//------------------------------------------------------------------------------
private:

//
@trusted @nogc pure nothrow
tstring getLineAt(tstring base, const(tchar)* p,
                   out line_number linnum, out int charpos)
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

//
@safe @nogc pure nothrow
tstring getLineAt(tstring src, line_number loc)
{
    size_t slinestart = 0;
    size_t i;
    uint linnum = 1;

    if(0 == src.length)
        return null;
    loop: for(i = 0; i < src.length; ++i)
    {
        switch(src[i])
        {
        case '\n':
            if(loc <= linnum) break loop;
            slinestart = i + 1;
            ++linnum;
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
