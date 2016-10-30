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


module dmdscript.irstate;

import core.stdc.stdarg;
import core.sys.posix.stdlib;
import core.stdc.string;
import std.outbuffer;
import core.memory;

debug import std.stdio;

import dmdscript.script;
import dmdscript.statement;
import dmdscript.opcodes;
import dmdscript.ir;
import dmdscript.identifier;

// The state of the interpreter machine as seen by the code generator, not
// the interpreter.

struct IRstate
{
    OutBuffer      codebuf;             // accumulate code here
    Statement      breakTarget;         // current statement that 'break' applies to
    Statement      continueTarget;      // current statement that 'continue' applies to
    ScopeStatement scopeContext;        // current ScopeStatement we're inside
    size_t[]         fixups;

    //void next();	// close out current Block, and start a new one

    uint locali = 1;            // leave location 0 as our "null"
    uint nlocals = 1;

    void ctor()
    {
        codebuf = new OutBuffer();
    }

    void validate()
    {
        assert(codebuf.offset <= codebuf.data.length);
        debug
        {
            if(codebuf.data.length > codebuf.data.capacity)
            {
                writeln("ptr %p, length %d, capacity %d", codebuf.data.ptr, codebuf.data.length, core.memory.GC.sizeOf(codebuf.data.ptr));
                assert(0);
            }
        }
        for(size_t u = 0; u < codebuf.offset; )
        {
            IR* code = cast(IR*)(codebuf.data.ptr + u);
            assert(code.opcode < IRMAX);
            u += IR.size(code.opcode) * IR.sizeof;
        }
    }

    /**********************************
     * Allocate a block of local variables, and return an
     * index to them.
     */

    size_t alloc(size_t nlocals)
    {
        size_t n;

        n = locali;
        locali += nlocals;
        if(locali > this.nlocals)
            this.nlocals = locali;
        assert(n);
        return n * INDEX_FACTOR;
    }

    /****************************************
     * Release this block of n locals starting at local.
     */

    void release(size_t local, size_t n)
    {
        /*
            local /= INDEX_FACTOR;
            //assert(local + n == locali);
            if (local + n == locali)
                locali = local;
        //*/
    }

    size_t mark()
    {
        return locali;
    }

    void release(size_t i)
    {
        /*
        assert(i);
        locali = i;
        //*/
    }

    /***************************************
     * Generate code.
     */

    static size_t combine(Loc loc, uint opcode)
    {
        static if      (size_t.sizeof == 4)
            return (loc << 16) | (opcode & 0xff);
        else static if (size_t.sizeof == 8)
            return ((cast(size_t)loc) << 32) | (opcode & 0xff);
        else static assert(0);
    }

    void gen0(Loc loc, uint opcode)
    {
        codebuf.write(combine(loc, opcode));
    }

    void gen1(Loc loc, uint opcode, size_t arg)
    {
        codebuf.reserve(2 * size_t.sizeof);
        // Inline ourselves for speed (compiler doesn't do a good job)
        auto data = cast(size_t*)(codebuf.data.ptr + codebuf.offset);
        codebuf.offset += 2 * size_t.sizeof;
        data[0] = combine(loc, opcode);
        data[1] = arg;
    }

    void gen2(Loc loc, uint opcode, size_t arg1, size_t arg2)
    {
        codebuf.reserve(3 * size_t.sizeof);
        // Inline ourselves for speed (compiler doesn't do a good job)
        auto data = cast(size_t*)(codebuf.data.ptr + codebuf.offset);
        codebuf.offset += 3 * size_t.sizeof;
        data[0] = combine(loc, opcode);
        data[1] = arg1;
        data[2] = arg2;
    }

    void gen3(Loc loc, uint opcode, size_t arg1, size_t arg2, size_t arg3)
    {
        codebuf.reserve(4 * size_t.sizeof);
        // Inline ourselves for speed (compiler doesn't do a good job)
        auto data = cast(uint*)(codebuf.data.ptr + codebuf.offset);
        codebuf.offset += 4 * size_t.sizeof;
        data[0] = combine(loc, opcode);
        data[1] = arg1;
        data[2] = arg2;
        data[3] = arg3;
    }

    void gen4(Loc loc, uint opcode, size_t arg1, size_t arg2, size_t arg3,
              uint arg4)
    {
        codebuf.reserve(5 * size_t.sizeof);
        // Inline ourselves for speed (compiler doesn't do a good job)
        auto data = cast(size_t*)(codebuf.data.ptr + codebuf.offset);
        codebuf.offset += 5 * size_t.sizeof;
        data[0] = combine(loc, opcode);
        data[1] = arg1;
        data[2] = arg2;
        data[3] = arg3;
        data[4] = arg4;
    }

    deprecated void gen(Loc loc, uint opcode, uint argc, ...)
    {
        codebuf.reserve((1 + argc) * uint.sizeof);
        codebuf.write(combine(loc, opcode));
        for(uint i = 1; i <= argc; i++)
        {
            codebuf.write(va_arg!(uint)(_argptr));
        }
    }

    /*
      This is more safe than the above one.
      When the size of an argument is less than the size of uint,
      the above function do a mistake.
     */
    void gen_(A...)(Loc loc, uint opcode, A args)
    {
        template size(T)
        { enum size_t size = (T.sizeof - 1) / size_t.sizeof + 1; }

        template total(T...)
        {
            static if (0 == T.length)
                enum size_t total = 0;
            else
                enum size_t total = size!(T[0]) + total!(T[1..$]);
        }

        codebuf.reserve((1 + total!A) * size_t.sizeof);
        auto data = cast(size_t*)(codebuf.data.ptr + codebuf.offset);
        codebuf.offset += (1 + total!A) * size_t.sizeof;
        *data = combine(loc, opcode);
        ++data;
        foreach (one; args)
        {
            static if (size!(typeof(one)) == 1)
            {
                *data = cast(size_t)one;
                ++data;
            }
            else
            {
                *(cast(typeof(one)*)data) = one;
                data += size!(typeof(one));
            }
        }
    }


    void pops(uint npops)
    {
        while(npops--)
            gen0(0, IRpop);
    }

    /******************************
     * Get the current "instruction pointer"
     */

    size_t getIP()
    {
        if(!codebuf)
            return 0;
        return codebuf.offset / IR.sizeof;
    }

    /******************************
     * Patch a value into the existing codebuf.
     */

    void patchJmp(size_t index, size_t value)
    {
        assert((index + 1) * IR.sizeof < codebuf.offset);
        (cast(size_t*)(codebuf.data))[index + 1] = value - index;
    }

    /*******************************
     * Add this IP to list of jump instructions to patch.
     */

    void addFixup(size_t index)
    {
        fixups ~= index;
    }

    /*******************************
     * Go through the list of fixups and patch them.
     */

    void doFixups()
    {
        size_t i;
        size_t index;
        size_t value;
        Statement s;

        for(i = 0; i < fixups.length; i++)
        {
            index = fixups[i];
            assert((index + 1) * IR.sizeof < codebuf.offset);
            s = (cast(Statement*)codebuf.data)[index + 1];
            value = s.getTarget();
            patchJmp(index, value);
        }
    }


    void optimize()
    {
        // Determine the length of the code array
        IR* c;
        IR* c2;
        IR* code;
        size_t length;
        size_t i;

        code = cast(IR*)codebuf.data;
        for(c = code; c.opcode != IRend; c += IR.size(c.opcode))
        {
        }
        length = c - code + 1;

        // Allocate a bit vector for the array
        byte[] b = new byte[length]; //TODO: that was a bit array, maybe should use std.container

        // Set bit for each target of a jump
        for(c = code; c.opcode != IRend; c += IR.size(c.opcode))
        {
            switch(c.opcode)
            {
            case IRjf:
            case IRjt:
            case IRjfb:
            case IRjtb:
            case IRjmp:
            case IRjlt:
            case IRjle:
            case IRjltc:
            case IRjlec:
            case IRtrycatch:
            case IRtryfinally:
            case IRnextscope:
            case IRnext:
            case IRnexts:
                //writefln("set %d", (c - code) + (c + 1).offset);
                b[(c - code) + (c + 1).offset] = true;
                break;
            default:
                break;
            }
        }

        // Allocate array of IR contents for locals.
        IR*[] local;
        IR*[] p1 = null;

        // Allocate on stack for smaller arrays
        IR** plocals;
        if(nlocals < 128)
            plocals = cast(IR**)alloca(nlocals * local[0].sizeof);

        if(plocals)
        {
            local = plocals[0 .. nlocals];
            local[] = null;
        }
        else
        {
            p1 = new IR *[nlocals];
            local = p1;
        }

        // Optimize
        for(c = code; c.opcode != IRend; c += IR.size(c.opcode))
        {
            uint offset = (c - code);

            if(b[offset])       // if target of jump
            {
                // Reset contents of locals
                local[] = null;
            }

            switch(c.opcode)
            {
            case IRnop:
                break;

            case IRnumber:
            case IRstring:
            case IRboolean:
                local[(c + 1).index / INDEX_FACTOR] = c;
                break;

            case IRadd:
            case IRsub:
            case IRcle:
                local[(c + 1).index / INDEX_FACTOR] = c;
                break;

            case IRputthis:
                local[(c + 1).index / INDEX_FACTOR] = c;
                goto Lreset;

            case IRputscope:
                local[(c + 1).index / INDEX_FACTOR] = c;
                break;

            case IRgetscope:
            {
                Identifier* cs = (c + 2).id;
                IR* cimax = null;
                for(i = nlocals; i--; )
                {
                    IR* ci = local[i];
                    if(ci &&
                       (ci.opcode == IRgetscope || ci.opcode == IRputscope) &&
                       (ci + 2).id.value.text == cs.value.text
                       )
                    {
                        if(cimax)
                        {
                            if(cimax < ci)
                                cimax = ci;     // select most recent instruction
                        }
                        else
                            cimax = ci;
                    }
                }
                if(1 && cimax)
                {
                    //writef("IRgetscope . IRmov %d, %d\n", (c + 1).index, (cimax + 1).index);
                    c.opcode = IRmov;
                    (c + 2).index = (cimax + 1).index;
                    local[(c + 1).index / INDEX_FACTOR] = cimax;
                }
                else
                    local[(c + 1).index / INDEX_FACTOR] = c;
                break;
            }

            case IRnew:
                local[(c + 1).index / INDEX_FACTOR] = c;
                goto Lreset;

            case IRcallscope:
            case IRputcall:
            case IRputcalls:
            case IRputcallscope:
            case IRputcallv:
            case IRcallv:
                local[(c + 1).index / INDEX_FACTOR] = c;
                goto Lreset;

            case IRmov:
                local[(c + 1).index / INDEX_FACTOR] = local[(c + 2).index / INDEX_FACTOR];
                break;

            case IRput:
            case IRpostincscope:
            case IRaddassscope:
                goto Lreset;

            case IRjf:
            case IRjfb:
            case IRjtb:
            case IRjmp:
            case IRjt:
            case IRret:
            case IRjlt:
            case IRjle:
            case IRjltc:
            case IRjlec:
                break;

            default:
                Lreset:
                // Reset contents of locals
                local[] = null;
                break;
            }
        }

        delete p1;

        //return;
        // Remove all IRnop's
        for(c = code; c.opcode != IRend; )
        {
            uint offset;
            uint o;
            uint c2off;

            if(c.opcode == IRnop)
            {
                offset = (c - code);
                for(c2 = code; c2.opcode != IRend; c2 += IR.size(c2.opcode))
                {
                    switch(c2.opcode)
                    {
                    case IRjf:
                    case IRjt:
                    case IRjfb:
                    case IRjtb:
                    case IRjmp:
                    case IRjlt:
                    case IRjle:
                    case IRjltc:
                    case IRjlec:
                    case IRnextscope:
                    case IRtryfinally:
                    case IRtrycatch:
                        c2off = c2 - code;
                        o = c2off + (c2 + 1).offset;
                        if(c2off <= offset && offset < o)
                            (c2 + 1).offset--;
                        else if(c2off > offset && o <= offset)
                            (c2 + 1).offset++;
                        break;
                    /+
                                        case IRtrycatch:
                                            o = (c2 + 1).offset;
                                            if (offset < o)
                                                (c2 + 1).offset--;
                                            break;
                     +/
                    default:
                        continue;
                    }
                }

                length--;
                memmove(c, c + 1, (length - offset) * uint.sizeof);
            }
            else
                c += IR.size(c.opcode);
        }
    }
}
