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
class SyntaxException: Exception
{
    string base;
    const(char)* head;
    bool strictMode;

    @safe @nogc pure nothrow
    this(string message, string base, const(char)* head, bool sm,
         string file = __FILE__, size_t line = __LINE__, Throwable n = null)
    {
        super(message, file, line, n);
        this.base = base;
        this.head = head;
        strictMode = sm;
    }
}

//------------------------------------------------------------------------------
///
class EarlyException: Exception
{
    string id;
    string type;
    string funcname;
    size_t linnum;
    string base;

    @safe @nogc pure nothrow
    this(string t, string msg, string fn, size_t ln,
         string f = __FILE__, size_t l = __LINE__)
    {
        super(msg, f, l);
        this.type = t;
        this.funcname = fn;
        this.linnum = ln;
    }
}


//------------------------------------------------------------------------------
// class SyntaxException2: Exception
// {
//     string funcname;
//     size_t linnum;

//     @safe @nogc pure nothrow
//     this(string msg, string fn, size_t ln,
//          string f = __FILE__, size_t l = __LINE__)
//     {
//         super(msg, f, l);
//         funcname = fn;
//         linnum = ln;
//     }
// }

//------------------------------------------------------------------------------
///
// class ParserException: Exception
// {
//     string id;
//     string line;
//     size_t linnum;
//     size_t col;
//     bool strictMode;

//     @safe @nogc pure nothrow
//     this(string id, string l, size_t ln, size_t c, ParserException1 se1)
//     {
//         super(se1.msg, se1.file, se1.line, se1.next);
//         this.id = id;
//         line = l;
//         linnum = ln;
//         col = c;
//         strictMode = se1.strictMode;
//     }
// }


//------------------------------------------------------------------------------
///
// class ScriptException : Exception
// {
//     import dmdscript.opcodes: IR;
//     import dmdscript.primitive: PropertyKey;
//     import dmdscript.value: DError;

//     // int code; // for what?

//     //--------------------------------------------------------------------
//     @nogc @safe pure nothrow
//     this(DError* err, string file = __FILE__, size_t line = __LINE__)
//     {
//         _error = *err;
//         assert (_error.isObject);
//         assert (cast(D0base)_error.object);
//         super(_error.object.value.toString, file, line, d0.next);
//     }

//     @property @nogc pure nothrow
//     DError error()
//     {
//         return _error;
//     }

    // //--------------------------------------------------------------------
    // //
    // static class Source
    // {
    //     string filename;
    //     string buffer;

    //     this (string filename, string buffer)
    //     {
    //         import std.algorithm : count;

    //         this.filename = filename;
    //         this.buffer = buffer;

    //         this.lineCount = cast(size_t)buffer.count('\n');
    //         if (0 < buffer.length && buffer[$-1] != '\n')
    //             ++this.lineCount;
    //     }

    // private:
    //     size_t lineCount;
    // }


    //--------------------------------------------------------------------
    //
    // void firstTrace(scope void delegate(in char[]) sink) const
    // {
    //     import core.internal.string : unsignedToTempString;

    //     char[20] tmpBuff = void;

    //     sink(typeid(this).name);
    //     sink("@");
    //     sink(file);
    //     sink("(");
    //     sink(unsignedToTempString(line, tmpBuff, 10));
    //     sink(")");
    // }

    // //
    // auto traces()
    // {
    //     return _d0.traces;
    // }

    // //
    // void restInfo(scope void delegate(in char[]) sink) const
    // {
    //     foreach (t; info)
    //     {
    //         sink(t);
    //         sink("\n");
    //     }
    // }

    // //
    // void nextInfo(scope void delegate(in char[]) sink) const
    // {
    //     if (next !is null)
    //         next.toString(sink);
    // }


//     //====================================================================
// private:
//     //--------------------------------------------------------------------
//     struct TraceDescriptor
//     {
//         //
//         @safe @nogc pure nothrow
//         this(string funcname, uint linnum, string dfile, size_t dline)
//         {
//             this.funcname = funcname;
//             this.linnum = linnum;

//             this.dFilename = dfile;
//             this.dLinnum = dline;
//         }
//         //
//         @safe @nogc pure nothrow
//         this(const(IR)* base, const(IR)* code, string dfile, size_t dline)
//         {
//             this.base = base;
//             this.code = code;
//             assert(base !is null);
//             assert(code !is null);
//             assert(base <= code);

//             if (linnum == 0)
//                 linnum = code.opcode.linnum;
//             this.dFilename = dfile;
//             this.dLinnum = dline;
//         }
//         //
//         @safe @nogc pure nothrow
//         this(uint linnum, string dfile, size_t dline)
//         {
//             this.linnum = linnum;

//             this.dFilename = dfile;
//             this.dLinnum = dline;
//         }

//         //
//         @safe @nogc pure nothrow
//         this(uint linnum, size_t offset, string dfile, size_t dline)
//         {
//             this.linnum = linnum;
//             this.offset = offset;
//             this.haveOffset = true;
//             this.dFilename = dfile;
//             this.dLinnum = dline;
//         }

//         //----------------------------------------------------------
//         @trusted @nogc pure nothrow
//         void addInfo(string bufferId, string funcname, bool strictMode)
//         {
//             if (this.bufferId.length == 0)
//                 this.bufferId = bufferId;
//             if (this.funcname.length == 0)
//             {
//                 this.funcname = funcname;
//                 this.strictMode = strictMode;
//             }
//         }

//         //----------------------------------------------------------
//         void setSourceInfo(Source[] delegate(string) callback)
//         {
//             size_t accOffset;
//             if (linnum == 0)
//                 return;
//             if (0 < sourcename.length)
//                 return;

//             if (0 == bufferId.length)
//                 return;

//             lineshift = 0;
//             foreach (one; callback(bufferId))
//             {
//                 if (linnum <= lineshift + one.lineCount)
//                 {
//                     sourcename = one.filename;
//                     if (haveOffset)
//                         offset -= accOffset;
//                     assert (lineshift <= linnum);
//                     line = getLineAt(one.buffer, linnum - lineshift,
//                                      haveOffset, offset);
//                     break;
//                 }
//                 lineshift += one.lineCount;
//                 accOffset += one.buffer.length;
//             }
//         }

//         //----------------------------------------------------------
//         void scriptNameAndLine(scope void delegate(in char[]) sink) const
//         {
//             import core.internal.string : unsignedToTempString;

//             char[20] tmpBuff = void;

//             if (0 < bufferId.length)
//             {
//                 sink("(#");
//                 sink(bufferId);
//                 sink(")");
//             }
//             if ((0 < sourcename.length || funcname.length) && 0 < linnum)
//                 sink("@");
//             if (0 < sourcename.length)
//                 sink(sourcename);
//             if (0 < funcname.length)
//             {
//                 if (0 < sourcename.length)
//                     sink("/");
//                 sink(funcname);
//             }
//             if (0 < linnum)
//             {
//                 sink("(");
//                 sink(unsignedToTempString(linnum - lineshift, tmpBuff, 10));
//                 sink(")");
//             }
//             if (strictMode)
//             {
//                 sink("[STRICT MODE]");
//             }
//         }

//         void dFileAndLine(scope void delegate(in char[]) sink) const
//         {
//             import core.internal.string : unsignedToTempString;

//             char[20] tmpBuff = void;

//             sink("[@");
//             sink(dFilename);
//             sink("(");
//             sink(unsignedToTempString(dLinnum, tmpBuff, 10));
//             sink(")]");
//         }

//         void sourceTrace(scope void delegate(in char[]) sink) const
//         {
//             import std.array : replace;
//             import std.string : stripRight;
//             enum Tab = "    ";

//             if (0 == line.length)
//                 return;

//             sink(">");
//             sink(line.replace("\t", Tab).stripRight);
//             if (haveOffset)
//             {
//                 sink("\n");
//                 for (size_t i = 0; i < line.length && i < offset; ++i)
//                 {
//                     if (line[i] == '\t')
//                         sink(Tab);
//                     else
//                         sink(" ");
//                 }
//                 sink(" ^\n");
//             }
//         }

//         void irTrace(scope void delegate(in char[]) sink) const
//         {
//             import dmdscript.ir : Opcode;
//             if (base is null || code is null || 0 == linnum)
//                 return;

//             for (const(IR)* ite = base; ; ite += IR.size(ite.opcode))
//             {
//                 if (ite.opcode == Opcode.End || ite.opcode == Opcode.Error ||
//                     code.opcode.linnum < ite.opcode.linnum)
//                     break;
//                 if (ite.opcode.linnum < code.opcode.linnum)
//                     continue;
//                 sink(ite is code ? "*" : " ");
//                 IR.toBuffer(0, ite, sink, lineshift);
//                 sink("\n");
//             }
//         }

//         //
//         @safe @nogc pure nothrow
//         bool opEquals(in ref TraceDescriptor r) const
//         {
//             return
//                 (base !is null && base is r.base &&
//                  code !is null && code is r.code);// ||

//                 // (0 < linnum && linnum is r.linnum) ||

//                 // (haveOffset && offset is r.offset);
//         }

//         //==========================================================
//         string sourcename;
//         string funcname;

//         string dFilename;
//         size_t dLinnum;

//         const(IR)* base;
//         const(IR)* code;

//         uint linnum; // line number (1 based, 0 if not available)
//         string line; //
//         bool haveOffset;//
//         size_t offset; //
//         uint lineshift;

//         string bufferId;
//         bool strictMode;
//     }

    //====================================================================
// private:
//     DError _error;
// }

// //==============================================================================
// private:

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

// enum Key : PropertyKey
// {
//     Unknown = PropertyKey("Unknown"),
// }
