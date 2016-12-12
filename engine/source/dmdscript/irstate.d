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

import dmdscript.primitive : StringKey;
import dmdscript.callcontext;
import dmdscript.statement;
import dmdscript.opcodes;
import dmdscript.ir;

debug import std.stdio;

// The state of the interpreter machine as seen by the code generator, not
// the interpreter.

struct IRstate
{
    import std.outbuffer : OutBuffer;

    OutBuffer      codebuf;        // accumulate code here
    Statement      breakTarget;    // current statement that 'break' applies to
    Statement      continueTarget; // current statement that 'continue' applies to
    ScopeStatement scopeContext;   // current ScopeStatement we're inside
    private size_t[]         fixups;

    //void next();	// close out current Block, and start a new one

    LocalVariablesManager lvm;            // leave location 0 as our "null"


    @safe pure nothrow
    void ctor()
    {
        codebuf = new OutBuffer;
    }

    /**********************************
     * Allocate a block of local variables, and return an
     * index to them.
     */
    @safe pure nothrow
    auto alloc(size_t nlocals)
    {
        return lvm.alloc(nlocals);
    }

    /****************************************
     * Release this block of n locals starting at local.
     */
    @safe @nogc pure nothrow
    void release(LocalVariables lv)
    {
        lvm.release(lv);
    }

    @safe pure nothrow
    auto mark()
    {
        return lvm.mark;
    }

    /***************************************
     * Generate code.
     */
    //
    @trusted
    void gen(Opcode OP, A...)(A args)
    {
        alias T = IRTypes[OP];
        codebuf.reserve(T.sizeof);
        auto data = cast(T*)(codebuf.data.ptr + codebuf.offset);
        codebuf.offset += T.sizeof;
        *data = T(args);
    }

    //
    @trusted
    void gen(T, A...)(A args)
    {
        codebuf.reserve(T.sizeof);
        auto data = cast(T*)(codebuf.data.ptr + codebuf.offset);
        codebuf.offset += T.sizeof;
        *data = T(args);
    }

    @safe
    void pops(uint npops)
    {
        while(npops--)
            gen!(Opcode.Pop)(0);
    }

    /******************************
     * Get the current "instruction pointer"
     */
    @safe @nogc pure nothrow
    size_t getIP()
    {
        if(!codebuf)
            return 0;
        return codebuf.offset / IR.sizeof;
    }

    /******************************
     * Patch a value into the existing codebuf.
     */

    @trusted @nogc pure nothrow
    void patchJmp(size_t index, size_t value)
    {
        assert((index + 1) * IR.sizeof < codebuf.offset);
        (cast(IR*)(codebuf.data))[index + 1].offset = value - index;
    }

    /*******************************
     * Add this IP to list of jump instructions to patch.
     */
    @safe pure nothrow
    void addFixup(size_t index)
    {
        fixups ~= index;
    }

    /*******************************
     * Go through the list of fixups and patch them.
     */
    @trusted
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
            assert((cast(IR*)codebuf.data)[index].opcode == Opcode.Jmp);
            s = (cast(Statement*)codebuf.data)[index + 1];
            value = s.getTarget();
            patchJmp(index, value);
        }
    }

    void optimize()
    {
        import core.sys.posix.stdlib : alloca;
        import core.stdc.string : memmove;
        import std.bitmanip : BitArray;

        // Determine the length of the code array
        IR* c;
        IR* c2;
        IR* code;
        size_t length;
        size_t i;

        code = cast(IR*)codebuf.data;
        for(c = code; c.opcode != Opcode.End; c += IR.size(c.opcode)) {}
        length = c - code + 1;

        // Allocate a bit vector for the array
        // byte[] b = new byte[length]; //TODO: that was a bit array, maybe should use std.container

        BitArray b;
        b.length = length;

        // Set bit for each target of a jump
        for(c = code; c.opcode != Opcode.End; c += IR.size(c.opcode))
        {
            switch(c.opcode)
            {
            case Opcode.JF:
            case Opcode.JT:
            case Opcode.JFB:
            case Opcode.JTB:
            case Opcode.Jmp:
            case Opcode.JLT:
            case Opcode.JLE:
            case Opcode.JLTC:
            case Opcode.JLEC:
            case Opcode.TryCatch:
            case Opcode.TryFinally:
            case Opcode.NextScope:
            case Opcode.Next:
            case Opcode.NextS:
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
        if(lvm.max < 128)
            plocals = cast(IR**)alloca(lvm.max * local[0].sizeof);

        if(plocals)
        {
            local = plocals[0 .. lvm.max];
            local[] = null;
        }
        else
        {
            p1 = new IR*[lvm.max];
            local = p1;
        }

        // Optimize
        for(c = code; c.opcode != Opcode.End; c += IR.size(c.opcode))
        {
            uint offset = (c - code);

            if(b[offset])       // if target of jump
            {
                // Reset contents of locals
                local[] = null;
            }

            switch(c.opcode)
            {
            case Opcode.Nop:
                break;

            case Opcode.Number:
            case Opcode.String:
            case Opcode.Boolean:
                local[(c + 1).index] = c;
                break;

            case Opcode.Add:
            case Opcode.Sub:
            case Opcode.CLE:
                local[(c + 1).index] = c;
                break;

            case Opcode.PutThis:
                local[(c + 1).index] = c;
                goto Lreset;

            case Opcode.PutScope:
                local[(c + 1).index] = c;
                break;

            case Opcode.GetScope:
            {
                StringKey* cs = (c + 2).id;
                IR* cimax = null;
                for(i = lvm.max; i--; )
                {
                    IR* ci = local[i];
                    if(ci &&
                       (ci.opcode == Opcode.GetScope ||
                        ci.opcode == Opcode.PutScope) &&
                       (*(ci + 2).id) == (*cs)
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
                    c.opcode = Opcode.Mov;
                    (c + 2).index = (cimax + 1).index;
                    local[(c + 1).index] = cimax;
                }
                else
                    local[(c + 1).index] = c;
                break;
            }

            case Opcode.New:
                local[(c + 1).index] = c;
                goto Lreset;

            case Opcode.CallScope:
            case Opcode.PutCall:
            case Opcode.PutCallS:
            case Opcode.PutCallScope:
            case Opcode.PutCallV:
            case Opcode.CallV:
                local[(c + 1).index] = c;
                goto Lreset;

            case Opcode.Mov:
                local[(c + 1).index] = local[(c + 2).index];
                break;

            case Opcode.Put:
            case Opcode.PostIncScope:
            case Opcode.AddAsSScope:
                goto Lreset;

            case Opcode.JF:
            case Opcode.JFB:
            case Opcode.JTB:
            case Opcode.Jmp:
            case Opcode.JT:
            case Opcode.Ret:
            case Opcode.JLT:
            case Opcode.JLE:
            case Opcode.JLTC:
            case Opcode.JLEC:
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
        for(c = code; c.opcode != Opcode.End; )
        {
            size_t offset;
            size_t o;
            size_t c2off;

            if(c.opcode == Opcode.Nop)
            {
                offset = (c - code);
                for(c2 = code; c2.opcode != Opcode.End;
                    c2 += IR.size(c2.opcode))
                {
                    switch(c2.opcode)
                    {
                    case Opcode.JF:
                    case Opcode.JT:
                    case Opcode.JFB:
                    case Opcode.JTB:
                    case Opcode.Jmp:
                    case Opcode.JLT:
                    case Opcode.JLE:
                    case Opcode.JLTC:
                    case Opcode.JLEC:
                    case Opcode.NextScope:
                    case Opcode.TryFinally:
                    case Opcode.TryCatch:
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
                memmove(c, c + 1, (length - offset) * IR.sizeof);
            }
            else
                c += IR.size(c.opcode);
        }
    }

    debug
    void validate()
    {
        import core.memory : GC;
        assert(codebuf.offset <= codebuf.data.length);
        if(codebuf.data.length > codebuf.data.capacity)
        {
            writeln("ptr %p, length %d, capacity %d", codebuf.data.ptr,
                    codebuf.data.length, GC.sizeOf(codebuf.data.ptr));
            assert(0);
        }
        for(size_t u = 0; u < codebuf.offset; )
        {
            IR* code = cast(IR*)(codebuf.data.ptr + u);
            assert(code.opcode <= Opcode.max);
            u += IR.size(code.opcode) * IR.sizeof;
        }
    }
}

// sliced range of LocalVariablesManager.
struct LocalVariables
{
    @safe @nogc pure nothrow
    idx_t opIndex(size_t i) const
    {
        if (r !is null)
        {
            assert(i < r.num);
            return r.head + i;
        }
        else
            return 0;
    }

    @property @safe @nogc pure nothrow
    size_t opDollar(size_t dim : 0)() const
    {
        return r ? r.num : 0;
    }
    alias length = opDollar!0;

private:
    LocalVariablesManager._range* r;
}

// count local variables.
private struct LocalVariablesManager
{
    @safe pure nothrow
    LocalVariables alloc(size_t nlocals)
    {
        _range* r;
        if (0 < nlocals)
        {
            r = alloc;

            r.head = top;
            r.num = nlocals;
            top += nlocals;
            if (maxTop < top)
                maxTop = top;
            assert(0 < r.head);
        }
        return LocalVariables(r);
    }

    @safe @nogc pure nothrow
    void release(ref LocalVariables lv)
    {
        auto r = lv.r;
        if (r is null) return;
        assert(0 < r.head);

        if      (r.num == 0 || r.head + r.num == top)
        {
            top = r.head;
            free(r);

            loop:for(;;)
            {
                for (auto it = &toRelease; (*it) !is null; it = &(*it).next)
                {
                    if ((*it).head + (*it).num == top || top <= (*it).head)
                    {
                        auto tmp = (*it);
                        top = tmp.head;
                        (*it) = tmp.next;
                        free(tmp);
                        continue loop;
                    }
                }
                break;
            }
        }
        else if (top <= r.head)
        {
            free(r);
        }
        else
        {
            r.next = toRelease;
            toRelease = r;
        }

        lv.r = null;
        assert(0 < top);
    }

    @safe @nogc pure nothrow
    void collect(LocalVariables lv)
    {
        if (auto r = lv.r)
            free(r);
        lv.r = null;
    }

    @property @safe @nogc pure nothrow
    idx_t max() const
    {
        return maxTop;
    }

    @property @safe pure nothrow
    auto mark()
    {
        auto r = alloc;
        r.head = top;
        r.num = 0;
        return LocalVariables(r);
    }

    debug string toString() const
    {
        import std.conv : text;

        size_t flc;
        for (auto it = cast(_range*)freelist; it !is null; it = it.next)
            ++flc;
        string tor;
        if (toRelease !is null)
            tor = toRelease.toString;
        else
            tor = "[]";

        return text("[", top, "/", maxTop, ", ", flc, ", ", tor, "]");
    }

private:
    struct _range
    {
        idx_t head;
        size_t num;

        _range* next;

        debug string toString() const
        {
            import std.conv : text;
            return text("[", head, ":", num, "]") ~
                (next is null ? "" : next.toString);
        }
    }

    idx_t top = 1;    // 0 means null.
    idx_t maxTop = 1;
    _range* freelist;
    _range* toRelease;

    @safe pure nothrow
    _range* alloc()
    {
        _range* r;
        if (freelist !is null)
        {
            r = freelist;
            freelist = freelist.next;
        }
        else
            r = new _range();
        assert (r !is null);
        return r;
    }

    @safe @nogc pure nothrow
    void free(_range* r)
    {
        assert(r !is null);
        r.next = freelist;
        freelist = r;
    }
}

unittest
{
    auto lm = LocalVariablesManager();

    auto l1 = lm.alloc(5);

    assert(l1[0] == 1);
    // l1[5].writeln; // causes assertion failure.

    auto l2 = lm.alloc(3);
    assert(l2[0] == 6);

    lm.release(l2);

    l2 = lm.alloc(10);
    assert(l2[0] == 6);

    lm.release(l1);
    l1 = lm.alloc(4);
    assert(l1[0] == 16);

    lm.release(l2);
    lm.release(l1);

    l1 = lm.alloc(2);
    assert(l1[0] == 1);
}
