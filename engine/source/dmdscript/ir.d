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


// Opcodes for our Intermediate Representation (IR)

module dmdscript.ir;

/* More self explanatory internal representation.
(This is a test implementation.)

# An example of memory mapping.

## about IRnumber

 +--- = Opcode.Number
 |
 |    +-----+-----------+--- Native Byte order.
 |    |     |           |
0|1 2 | 4   |   8       |       16
|-+-+---|-------|---------------|---- --- -- -  -
|O|P|Lin|  ACC  |               |
|p|a|Num|       |               |
|c|d|   |                       |
|o|d|   |         64bit data    |
|d|i|   |  acc  =   itself      |
|e|n|   |                       |
| |g|   | idx_t |    d_number   |
|-+-+---|-------|-------|-------|---- --- -- -  -


## about IRadd.

 +--- = Opcode.Add
 |
0|1 2   4       8       12      16
|-+-+---|-------|-------|-------|---- --- -- -  -
|O|P|Lin|  ACC  |Operand|Operand|
|p|a|Num|       |   1   |   2   |
|c|d|   |       |       |       |
|o|d|   |                       |
|d|i|   |  acc  =   A   +   B   |
|e|n|   |                       |
| |g|   | idx_t | idx_t | idx_t |
|-+-+---|-------|-------|-------|---- --- -- -  -
            \       \       \
             \       \       \
              \       \       \
               \       \       \
                V       V       V
 - -- --- ----+-------+-------+-------+---- --- -- -
              |Value* |Value* |Value* |
 - -- --- ----+-------+-------+-------+---- --- -- -
            An array of local variables.
*/

debug import std.conv : text;
debug import std.format : format;
import std.meta : AliasSeq;

import dmdscript.primitive : Identifier;
import dmdscript.functiondefinition : FunctionDefinition;
import dmdscript.value : Value;

//
enum OpOffset : ubyte
{
    None,
    S,
    Scope,
    V,
}

//
enum Opcode : ubyte
{
    Error = 0,
    Nop,                      // No Operation
    End,                      // End Of Function
    String,
    ThisGet,
    Number,
    Object,
    This,
    Null,
    Undefined,
    Boolean,
    Call,
    CallS     = Call + OpOffset.S,
    CallScope = Call + OpOffset.Scope,
    CallV     = Call + OpOffset.V,
    PutCall,
    PutCallS     = PutCall + OpOffset.S,
    PutCallScope = PutCall + OpOffset.Scope,
    PutCallV     = PutCall + OpOffset.V,
    Get,
    GetS     = Get + OpOffset.S,    // 'S(tring)' Versions Must Be Original + 1
    GetScope = Get + OpOffset.Scope,
    Put,
    PutS     = Put + OpOffset.S,
    PutScope = Put + OpOffset.Scope,
    PutGetter,                      // Put getter property.
    PutGetterS    = PutGetter + OpOffset.S,
    PutSetter,                      // Put setter property.
    PutSetterS = PutSetter + OpOffset.S,
    Del,
    DelS     = Del + OpOffset.S,
    DelScope = Del + OpOffset.Scope,
    Next,
    NextS     = Next + OpOffset.S,
    NextScope = Next + OpOffset.Scope,
    AddAsS,
    AddAsSS     = AddAsS + OpOffset.S,
    AddAsSScope = AddAsS + OpOffset.Scope,
    PutThis,
    PutDefault,
    Mov,
    Ret,
    RetExp,
    ImpRet,
    Neg,
    Pos,
    Com,
    Not,
    Add,
    Sub,
    Mul,
    Div,
    Mod,
    ShL,
    ShR,
    UShR,
    And,
    Or,
    Xor,
    In,
    PreInc,
    PreIncS     = PreInc + OpOffset.S,
    PreIncScope = PreInc + OpOffset.Scope,

    PreDec,
    PreDecS     = PreDec + OpOffset.S,
    PreDecScope = PreDec + OpOffset.Scope,

    PostInc,
    PostIncS     = PostInc + OpOffset.S,
    PostIncScope = PostInc + OpOffset.Scope,

    PostDec,
    PostDecS     = PostDec + OpOffset.S,
    PostDecScope = PostDec + OpOffset.Scope,

    New,

    CLT,
    CLE,
    CGT,
    CGE,
    CEq,
    CNE,
    CID,
    CNID,

    JT,
    JF,
    JTB,
    JFB,
    Jmp,

    JLT,              // Commonly Appears As Loop Control
    JLE,              // Commonly Appears As Loop Control

    JLTC,             // Commonly Appears As Loop Control
    JLEC,             // Commonly Appears As Loop Control

    Typeof,
    Instance,

    Push,
    Pop,

    Iter,
    Assert,

    Throw,
    TryCatch,
    TryFinally,
    FinallyRet,
    CheckRef,//Like Scope Get W/O Target, Occures Mostly On (Legal) Programmer Mistakes
}

// this holds an index value that points a Value* in the local variable array.
alias idx_t = size_t;
//
enum idx_t idxNull = 0;

//
struct Instruction
{
align(1):
    static if      (size_t.sizeof == 4)
    {
        version(LittleEndian)
        {
            Opcode opcode;
            private ubyte _padding;
            ushort linnum;
        }
        else // for backward compatibility.
        {
            ushort linnum;
            private ubyte _padding;
            Opcode opcode;
        }
    }
    else static if (size_t.sizeof == 8)
    {
        Opcode opcode;
        private ubyte[3] _padding;
        uint linnum;
    }
    else static assert(0);

    alias opcode this;

    this(uint linnum, Opcode op)
    {
        this.linnum = cast(typeof(this.linnum))linnum;
        opcode = op;
    }

    Opcode opAssign(in Opcode op){ opcode = op; return opcode;}

    debug string toString() const
    {
        return format("% 4d:%s", linnum, opcode);
    }
}
static assert (Instruction.sizeof == size_t.sizeof);

//
private struct IR0(Opcode CODE)
{
    enum Opcode code = CODE;
    enum size_t size = typeof(this).sizeof / Instruction.sizeof;

    Instruction ir;

    this(uint linnum)
    { ir = Instruction(linnum, code); }

    debug string toString() const
    { return ir.toString; }
}

//
private struct IR1(Opcode CODE)
{
    enum Opcode code = CODE;
    enum size_t size = typeof(this).sizeof / Instruction.sizeof;

align(size_t.sizeof):
    Instruction ir;
    idx_t acc;  // the position of an acc buffer in local variable array.

    this(uint linnum, idx_t acc)
    {
        ir = Instruction(linnum, code);
        this.acc = acc;
    }

    this(uint linnum, Opcode op, idx_t acc)
    {
        ir = Instruction(linnum, op);
        this.acc = acc;
    }

    debug string toString() const
    { return text(ir, " ", acc); }
}

//
private struct IR2(Opcode CODE, T)
{
    enum Opcode code = CODE;
    enum size_t size = typeof(this).sizeof / Instruction.sizeof;

align(size_t.sizeof):
    Instruction ir;
    idx_t acc;
    T operand;

    this(uint linnum, idx_t acc, T operand)
    {
        ir = Instruction(linnum, code);
        this.acc = acc;
        this.operand = operand;
    }

    debug string toString()
    {
        import dmdscript.opcodes : IR;
        static if      (is(T : Identifier))
            auto opName = text("\"", *operand, "\"");
        else static if (is(T : Value*))
            auto opName = text("\"", operand.text, "\"");
        else static if (is(T : FunctionDefinition))
            auto opName = text("function\n{\n", IR.toString(operand.code),
                               "}");
        else
            auto opName = text("[", operand, "]");

        static if (isGet!CODE)
            return text(ir, " [", acc, "] = ", opName);
        else
            return text(ir, " ", opName, " = [", acc, "]");
    }
}

//
private struct IR3(Opcode CODE, T, U)
{
    enum Opcode code = CODE;
    enum size_t size = typeof(this).sizeof / Instruction.sizeof;

align(size_t.sizeof):
    Instruction ir;
    idx_t acc;
    T operand1;
    U operand2;

    this(uint linnum, idx_t acc, T o1, U o2)
    {
        ir = Instruction(linnum, code);
        this.acc = acc;
        operand1 = o1;
        operand2 = o2;
    }

    this(uint linnum, Opcode op, idx_t acc, T o1, U o2)
    {
        ir = Instruction(linnum, op);
        this.acc = acc;
        operand1 = o1;
        operand2 = o2;
    }

    debug string toString()
    { return text(ir, " ", acc, ", ", operand1, ", ", operand2); }
}

//
private struct IRcall4(Opcode CODE, T)
{
    enum Opcode code = CODE;
    enum size_t size = typeof(this).sizeof / Instruction.sizeof;

align(size_t.sizeof):
    Instruction ir;
    idx_t acc;
    T func; // the name of the function. idx_t or Identifier.
    size_t argc;
    idx_t argv;

    this(uint linnum, idx_t acc, T func, size_t argc, idx_t argv)
    {
        ir = Instruction(linnum, code);
        this.acc = acc;
        this.func = func;
        this.argc = argc;
        this.argv = argv;
    }

    debug string toString() const
    {
        static if (is(T : Identifier))
            return text(ir, " [", acc, "] = ", func.toString,
                        "([", argv, "..", argv + argc, "])");
        else
            return text(ir, " [", acc, "] = [", func,
                        "]([", argv, "..", argv + argc, "])");
    }
}
//
private struct IRcall5(Opcode CODE, T)
{
    enum Opcode code = CODE;
    enum size_t size = typeof(this).sizeof / Instruction.sizeof;

align(size_t.sizeof):
    Instruction ir;
    idx_t acc;
    idx_t owner; // the owner of the method.
    T method;    // the name of the method. idx_t or Identifier
    size_t argc;
    idx_t argv;

    this(uint linnum, idx_t acc, idx_t owner, T method, size_t argc, idx_t argv)
    {
        ir = Instruction(linnum, code);
        this.acc = acc;
        this.owner = owner;
        this.method = method;
        this.argc = argc;
        this.argv = argv;
    }

    this(uint linnum, Opcode op, idx_t acc, idx_t owner, T method, size_t argc,
         idx_t argv)
    {
        ir = Instruction(linnum, op);
        this.acc = acc;
        this.owner = owner;
        this.method = method;
        this.argc = argc;
        this.argv = argv;
    }

    debug string toString() const
    {
        static if (is(T : Identifier))
            return text(ir, " [", acc, "] = [", owner, "].\"", method.toString,
                        "\"([", argv, " .. ", argv + argc, "])");
        else
            return text(ir, " [", acc, "] = [", owner, "].[", method,
                        "]([", argv, " .. ", argv + argc, "])");
    }
}

//
private struct IRget3(Opcode CODE, T)
{
    enum Opcode code = CODE;
    enum size_t size = typeof(this).sizeof / Instruction.sizeof;

align(size_t.sizeof):
    Instruction ir;
    idx_t acc;
    idx_t owner;
    T method;

    this(uint linnum, idx_t acc, idx_t owner, T method)
    {
        ir = Instruction(linnum, code);
        this.acc = acc;
        this.owner = owner;
        this.method = method;
    }

    debug string toString() const
    {
        static if (is(T : Identifier))
            auto mName = text("\"", *method, "\"");
        else
            auto mName = text("[", method, "]");

        static if (isGet!CODE)
            return text(ir, " [", acc, "] = [", owner, "].", mName);
        else
            return text(ir, " [", owner, "].", mName, " = [", acc, "]");
    }
}

private struct IRScope3(Opcode CODE)
{
    enum Opcode code = CODE;
    enum size_t size = typeof(this).sizeof / Instruction.sizeof;

align(size_t.sizeof):
    Instruction ir;
    idx_t acc;
    Identifier operand;
    size_t hash;

    this(uint linnum, idx_t acc, Identifier operand, size_t hash)
    {
        ir = Instruction(linnum, code);
        this.acc = acc;
        this.operand = operand;
        this.hash = hash;
    }

    this(uint linnum, Opcode op, idx_t acc, Identifier operand, size_t hash)
    {
        ir = Instruction(linnum, op);
        this.acc = acc;
        this.operand = operand;
        this.hash = hash;
    }

    debug string toString() const
    {
        static if (CODE == Opcode.AddAsSScope)
            return text(ir, " [", acc, "] = \"", *operand,
                        "\"(#", hash, ") += [", acc, "]");
        else
            return text(ir, " [", acc, "] = \"", *operand, "\"(#", hash, ")");
    }
}

// if (func iter) goto offset; iter = iter.next;
private struct IRnext3(Opcode CODE, T)
{
    enum Opcode code = CODE;
    enum size_t size = typeof(this).sizeof / Instruction.sizeof;

align(size_t.sizeof):
    Instruction ir;
    sizediff_t offset;
    T func;
    idx_t iter;

    this(uint linnum, sizediff_t offset, T func, idx_t iter)
    {
        ir = Instruction(linnum, code);
        this.offset = offset;
        this.func = func;
        this.iter = iter;
    }

    debug string toString(size_t base = 0) const
    { return text(ir, " if(", func, ", ", iter, ") goto ", offset + base); }
}

// if (owner.method iter) goto offset; iter = iter.next;
private struct IRnext4(Opcode CODE, T)
{
    enum Opcode code = CODE;
    enum size_t size = typeof(this).sizeof / Instruction.sizeof;

align(size_t.sizeof):
    Instruction ir;
    sizediff_t offset;
    idx_t owner;
    T method;
    idx_t iter;

    this(uint linnum, sizediff_t offset, idx_t owner, T method, idx_t iter)
    {
        ir = Instruction(linnum, code);
        this.offset = offset;
        this.owner = owner;
        this.method = method;
        this.iter = iter;
    }

    debug string toString(size_t base = 0) const
    {
        return text(ir, " if(", owner, ".", method, ", ", iter, ") goto ",
                    offset + base);
    }
}

//
private struct IRjump1(Opcode CODE)
{
    enum Opcode code = CODE;
    enum size_t size = typeof(this).sizeof / Instruction.sizeof;

align(size_t.sizeof):
    Instruction ir;
    sizediff_t offset;

    this(uint linnum, sizediff_t offset)
    {
        ir = Instruction(linnum, code);
        this.offset = offset;
    }

    debug string toString(size_t base = 0) const
    {
        return "%s goto %04d".format(ir, offset + base);
    }
}
//
private struct IRjump2(Opcode CODE)
{
    enum Opcode code = CODE;
    enum size_t size = typeof(this).sizeof / Instruction.sizeof;

align(size_t.sizeof):
    Instruction ir;
    sizediff_t offset;
    idx_t cond;

    this(uint linnum, sizediff_t offset, idx_t cond)
    {
        ir = Instruction(linnum, code);
        this.offset = offset;
        this.cond = cond;
    }

    debug string toString(size_t base = 0) const
    { return text(ir, " if(", cond, ") ", offset + base); }
}
//
private struct IRjump3(Opcode CODE, T = idx_t)
{
    enum Opcode code = CODE;
    enum size_t size = typeof(this).sizeof / Instruction.sizeof;

align(size_t.sizeof):
    Instruction ir;
    sizediff_t offset;
    idx_t operand1;
    T operand2;

    this(uint linnum, sizediff_t offset, idx_t o1, T o2)
    {
        ir = Instruction(linnum, code);
        this.offset = offset;
        this.operand1 = o1;
        this.operand2 = o2;
    }

    debug string toString(size_t base = 0) const
    {
        import std.format;

        static if      (CODE == Opcode.JLT || CODE == Opcode.JLTC)
            enum cmp = "<";
        else static if (CODE == Opcode.JLE || CODE == Opcode.JLEC)
            enum cmp = "<=";
        else
            enum cmp = ", ";

        static if      (CODE == Opcode.JLT || CODE == Opcode.JLE)
            return "%s if([%d] %s [%d]) else goto %04d".format(
                ir, operand1, cmp, operand2, base + offset);
        else static if (CODE == Opcode.JLTC || CODE == Opcode.JLEC)
            return "%s if([%d] %s %s) else goto %04d".format(
                ir, operand1, cmp, operand2, base + offset);
        else
            return "%s if([%d] %s %s) else goto %04d".format(
                ir, operand1, cmp, operand2, base + offset);
    }
}

//
struct IRJmpToStatement
{
    import dmdscript.statement : Statement;

    enum Opcode code = Opcode.Jmp;
    enum size_t size = typeof(this).sizeof / Instruction.sizeof;

align(size_t.sizeof):
    Instruction ir;
    Statement statement;

    this(uint linnum, Statement statement)
    {
        ir = Instruction(linnum, code);
        this.statement = statement;
    }

    debug string toString(size_t base = 0) const
    { return text(ir, " ", (cast(size_t)cast(void*)statement) + base); }
}

//
private struct IRTryCatch
{
    enum Opcode code = Opcode.TryCatch;
    enum size_t size = typeof(this).sizeof / Instruction.sizeof;

align(size_t.sizeof):
    Instruction ir;
    sizediff_t offset;
    Identifier name;

    this(uint linnum, sizediff_t offset, Identifier name)
    {
        ir = Instruction(linnum, code);
        this.offset = offset;
        this.name = name;
    }

    debug string toString(size_t base = 0) const
    {
        if (name !is null)
            return text(ir, " ", *name, ", ", offset + base);
        else
            return text(ir, " \"\"", offset + base);
    }
}

//
private struct IRCheckRef
{
    enum Opcode code = Opcode.CheckRef;
    enum size_t size = typeof(this).sizeof / Instruction.sizeof;

align(size_t.sizeof):
    Instruction ir;
    Identifier operand;

    this(uint linnum, Identifier operand)
    {
        ir = Instruction(linnum, code);
        this.operand = operand;
    }

    debug string toString() const
    {
        if (operand !is null)
            return text(ir, " ", *operand);
        else
            return text(ir, " \"\"");
    }
}

//
private struct IRAssert
{
    enum Opcode code = Opcode.Assert;
    enum size_t size = typeof(this).sizeof / Instruction.sizeof;

    Instruction ir;

    this(uint linnum)
    {
        ir = Instruction(linnum, code);
    }

    debug string toString() const
    { return text(ir, " at line ", ir.linnum); }
}

//
alias IRTypes = AliasSeq!(
    IR0!(Opcode.Error),
    IR0!(Opcode.Nop), // no operation
    IR0!(Opcode.End), // end of function

    IR2!(Opcode.String, Value*),        // acc = "string"
    IR2!(Opcode.ThisGet, Identifier),      // acc = othis.operand
    IR2!(Opcode.Number, double),           // acc = number
    IR2!(Opcode.Object, FunctionDefinition),
                                         // acc = new DdeclaredFunction(operand)
    IR1!(Opcode.This),                         // acc = this
    IR1!(Opcode.Null),                         // acc = null
    IR1!(Opcode.Undefined),               // acc = undefined
    IR2!(Opcode.Boolean, bool),        // acc = operand

    IRcall5!(Opcode.Call, idx_t), // acc = owner.method(argv[0..argc])
    IRcall5!(Opcode.CallS, Identifier), // acc = owner.method(argv[0..argc])
    IRcall4!(Opcode.CallScope, Identifier), // acc = func(argv[0..argv])
    IRcall4!(Opcode.CallV, idx_t),     // func(argv[0..argv]) = acc
    IRcall5!(Opcode.PutCall, idx_t), // owner.method(argv[0..argc]) = acc
    IRcall5!(Opcode.PutCallS, Identifier), // owner.method(argv[0..argc]) = acc
    IRcall4!(Opcode.PutCallScope, Identifier), // func(argv[0..argc]) = acc
    IRcall4!(Opcode.PutCallV, idx_t), // func(argv[0..argc]) = acc

    IRget3!(Opcode.Get, idx_t), // acc = owner.method
    IRget3!(Opcode.GetS, Identifier), // acc = owner.method
    IR2!(Opcode.GetScope, Identifier), // acc = operand
    IRget3!(Opcode.Put, idx_t), // owner.method = acc
    IRget3!(Opcode.PutS, Identifier), // owner.method = acc
    IR2!(Opcode.PutScope, Identifier), // s = acc,

    IRget3!(Opcode.PutGetter, idx_t),       // owner.property = getter
    IRget3!(Opcode.PutGetterS, Identifier),
    IRget3!(Opcode.PutSetter, idx_t),       // owner.property = setter
    IRget3!(Opcode.PutSetterS, Identifier),

    IRget3!(Opcode.Del, idx_t), // acc = delete owner.method
    IRget3!(Opcode.DelS, Identifier), // acc = delete owner.method
    IR2!(Opcode.DelScope, Identifier), // acc = delete operand

    IRnext4!(Opcode.Next, idx_t),
                   // if (!(owner.method = iter)) goto offset, iter = iter.next
    IRnext4!(Opcode.NextS, Identifier),
                   // if (!(owner.method = iter)) goto offset, iter = iter.next
    IRnext3!(Opcode.NextScope, Identifier),

    IRget3!(Opcode.AddAsS, idx_t),  // acc = (owner.method += acc)
    IRget3!(Opcode.AddAsSS, Identifier), // acc = (owner.method += acc)
    IRScope3!(Opcode.AddAsSScope), // acc = (operand += acc)
    IR2!(Opcode.PutThis, Identifier), // operand = acc,
    IR2!(Opcode.PutDefault, idx_t), // operand = acc,
    IR2!(Opcode.Mov, idx_t), // acc = operand,
    IR0!(Opcode.Ret),         // return,
    IR1!(Opcode.RetExp),   // return acc,
    IR1!(Opcode.ImpRet),   // return acc,
    IR1!(Opcode.Neg), // acc = -acc,
    IR1!(Opcode.Pos), // acc = acc,
    IR1!(Opcode.Com), // acc = ~acc,
    IR1!(Opcode.Not), // acc = !acc,
    IR3!(Opcode.Add, idx_t, idx_t), // acc = operand1 + operand2
    IR3!(Opcode.Sub, idx_t, idx_t), // acc = operand1 - operand2
    IR3!(Opcode.Mul, idx_t, idx_t), // acc = operand1 * operand2
    IR3!(Opcode.Div, idx_t, idx_t), // acc = operand1 / operand2
    IR3!(Opcode.Mod, idx_t, idx_t), // acc = operand1 % operand2
    IR3!(Opcode.ShL, idx_t, idx_t), // acc = operand1 << operand2
    IR3!(Opcode.ShR, idx_t, idx_t), // acc = operand1 >> operand2
    IR3!(Opcode.UShR, idx_t, idx_t), // acc = operand1 >>> operand2
    IR3!(Opcode.And, idx_t, idx_t), // acc = operand1 & operand2
    IR3!(Opcode.Or, idx_t, idx_t), // acc = operand1 | operand2
    IR3!(Opcode.Xor, idx_t, idx_t), // acc = operand1 ^ operand2
    IR3!(Opcode.In, idx_t, idx_t), // acc = operand1 in operand2
    IRget3!(Opcode.PreInc, idx_t), // acc = ++owner.method
    IRget3!(Opcode.PreIncS, Identifier), // acc = ++owner.method
    IRScope3!(Opcode.PreIncScope), // acc = ++operand,
    IRget3!(Opcode.PreDec, idx_t), // acc = --owner.method
    IRget3!(Opcode.PreDecS, Identifier), // acc = --owner.method
    IRScope3!(Opcode.PreDecScope), // acc = --operand
    IRget3!(Opcode.PostInc, idx_t), // acc = owner.method++,
    IRget3!(Opcode.PostIncS, Identifier), // acc = owner.method++,
    IR2!(Opcode.PostIncScope, Identifier), // acc = operand++,
    IRget3!(Opcode.PostDec, idx_t), // acc = owner.method--,
    IRget3!(Opcode.PostDecS, Identifier), // acc = owner.method--,
    IR2!(Opcode.PostDecScope, Identifier), // acc = operand--,
    IRcall4!(Opcode.New, idx_t), // acc = new func(argv[0..argc]),
    IR3!(Opcode.CLT, idx_t, idx_t), // acc = (operand1 < operand2)
    IR3!(Opcode.CLE, idx_t, idx_t), // acc = (operand1 <= operand2)
    IR3!(Opcode.CGT, idx_t, idx_t), // acc = (operand1 > operand2)
    IR3!(Opcode.CGE, idx_t, idx_t), // acc = (operand1 >= operand2)
    IR3!(Opcode.CEq, idx_t, idx_t), // acc = (operand1 == operand2)
    IR3!(Opcode.CNE, idx_t, idx_t), // acc = (operand1 != operand2)
    IR3!(Opcode.CID, idx_t, idx_t), // acc = (operand1 === operand2)
    IR3!(Opcode.CNID, idx_t, idx_t), // acc = (operand1 !== operand2)

    IRjump2!(Opcode.JT), // if (cond) goto offset,
    IRjump2!(Opcode.JF), // if (!cond) goto offset,
    IRjump2!(Opcode.JTB), // if (cond) goto offset, (dbool ver)
    IRjump2!(Opcode.JFB), // if (!cond) goto offset, (dbool ver)
    IRjump1!(Opcode.Jmp), // goto offset,

    // commonly appears as loop control
    IRjump3!(Opcode.JLT), // if (operand1 < operand2) goto offset,
    IRjump3!(Opcode.JLE), // if (operand1 <= operand2) goto offset,
    IRjump3!(Opcode.JLTC, double), // if (operand < constant) goto offset,
    IRjump3!(Opcode.JLEC, double), // if (operand <= constant) goto offset

    IR1!(Opcode.Typeof), // acc = typeof acc,
    IR3!(Opcode.Instance, idx_t, idx_t), // acc = operand1 instanceof operand2

    IR1!(Opcode.Push), //
    IR0!(Opcode.Pop), //

    IR2!(Opcode.Iter, idx_t), // acc = iter(operand),
    IRAssert, //
    IR1!(Opcode.Throw), //
    IRTryCatch,
    IRjump1!(Opcode.TryFinally),
    IR0!(Opcode.FinallyRet),
    IRCheckRef,
    );

unittest
{
    template verify(Opcode OP)
    {
        static if (OP < Opcode.max)
            enum verify =
                (IRTypes[OP].code == OP) && verify!(cast(Opcode)(OP+1));
        else
            enum verify = (IRTypes[OP].code == OP);
    }
    assert(verify!(Opcode.Error));
}

alias GenIR1 = IR1!(Opcode.Nop);
alias GenIR3 = IR3!(Opcode.Nop, idx_t, idx_t);
alias GenIR3S = IR3!(Opcode.Nop, idx_t, Identifier);
alias GenIRScope3 = IRScope3!(Opcode.Nop);

/* suger.

Examples:
---
static size_t getSizeOf(T)(){ return T.sizeof / IR.sizeof; }
IRTypeDispatcher!getSizeOf(code.opcode) == the size of the operation.
---
 */
auto IRTypeDispatcher(alias PROC, ARGS...)(Opcode op, ARGS args)
{
    assert(op <= Opcode.max, text("Unrecognized IR instruction ", op));

    final switch(op)
    {
    case Opcode.Error:
        return PROC!(IRTypes[Opcode.Error])(args);
    case Opcode.Nop:
        return PROC!(IRTypes[Opcode.Nop])(args);
    case Opcode.End:
        return PROC!(IRTypes[Opcode.End])(args);
    case Opcode.String:
        return PROC!(IRTypes[Opcode.String])(args);
    case Opcode.ThisGet:
        return PROC!(IRTypes[Opcode.ThisGet])(args);
    case Opcode.Number:
        return PROC!(IRTypes[Opcode.Number])(args);
    case Opcode.Object:
        return PROC!(IRTypes[Opcode.Object])(args);
    case Opcode.This:
        return PROC!(IRTypes[Opcode.This])(args);
    case Opcode.Null:
        return PROC!(IRTypes[Opcode.Null])(args);
    case Opcode.Undefined:
        return PROC!(IRTypes[Opcode.Undefined])(args);
    case Opcode.Boolean:
        return PROC!(IRTypes[Opcode.Boolean])(args);
    case Opcode.Call:
        return PROC!(IRTypes[Opcode.Call])(args);
    case Opcode.CallS:
        return PROC!(IRTypes[Opcode.CallS])(args);
    case Opcode.CallScope:
        return PROC!(IRTypes[Opcode.CallScope])(args);
    case Opcode.CallV:
        return PROC!(IRTypes[Opcode.CallV])(args);
    case Opcode.PutCall:
        return PROC!(IRTypes[Opcode.PutCall])(args);
    case Opcode.PutCallS:
        return PROC!(IRTypes[Opcode.PutCallS])(args);
    case Opcode.PutCallScope:
        return PROC!(IRTypes[Opcode.PutCallScope])(args);
    case Opcode.PutCallV:
        return PROC!(IRTypes[Opcode.PutCallV])(args);
    case Opcode.Get:
        return PROC!(IRTypes[Opcode.Get])(args);
    case Opcode.GetS:
        return PROC!(IRTypes[Opcode.GetS])(args);
    case Opcode.GetScope:
        return PROC!(IRTypes[Opcode.GetScope])(args);
    case Opcode.Put:
        return PROC!(IRTypes[Opcode.Put])(args);
    case Opcode.PutS:
        return PROC!(IRTypes[Opcode.PutS])(args);
    case Opcode.PutScope:
        return PROC!(IRTypes[Opcode.PutScope])(args);

    case Opcode.PutGetter:
        return PROC!(IRTypes[Opcode.PutGetter])(args);
    case Opcode.PutGetterS:
        return PROC!(IRTypes[Opcode.PutGetterS])(args);
    case Opcode.PutSetter:
        return PROC!(IRTypes[Opcode.PutSetter])(args);
    case Opcode.PutSetterS:
        return PROC!(IRTypes[Opcode.PutSetterS])(args);

    case Opcode.Del:
        return PROC!(IRTypes[Opcode.Del])(args);
    case Opcode.DelS:
        return PROC!(IRTypes[Opcode.DelS])(args);
    case Opcode.DelScope:
        return PROC!(IRTypes[Opcode.DelScope])(args);
    case Opcode.Next:
        return PROC!(IRTypes[Opcode.Next])(args);
    case Opcode.NextS:
        return PROC!(IRTypes[Opcode.NextS])(args);
    case Opcode.NextScope:
        return PROC!(IRTypes[Opcode.NextScope])(args);
    case Opcode.AddAsS:
        return PROC!(IRTypes[Opcode.AddAsS])(args);
    case Opcode.AddAsSS:
        return PROC!(IRTypes[Opcode.AddAsSS])(args);
    case Opcode.AddAsSScope:
        return PROC!(IRTypes[Opcode.AddAsSScope])(args);
    case Opcode.PutThis:
        return PROC!(IRTypes[Opcode.PutThis])(args);
    case Opcode.PutDefault:
        return PROC!(IRTypes[Opcode.PutDefault])(args);
    case Opcode.Mov:
        return PROC!(IRTypes[Opcode.Mov])(args);
    case Opcode.Ret:
        return PROC!(IRTypes[Opcode.Ret])(args);
    case Opcode.RetExp:
        return PROC!(IRTypes[Opcode.RetExp])(args);
    case Opcode.ImpRet:
        return PROC!(IRTypes[Opcode.ImpRet])(args);
    case Opcode.Neg:
        return PROC!(IRTypes[Opcode.Neg])(args);
    case Opcode.Pos:
        return PROC!(IRTypes[Opcode.Pos])(args);
    case Opcode.Com:
        return PROC!(IRTypes[Opcode.Com])(args);
    case Opcode.Not:
        return PROC!(IRTypes[Opcode.Not])(args);
    case Opcode.Add:
        return PROC!(IRTypes[Opcode.Add])(args);
    case Opcode.Sub:
        return PROC!(IRTypes[Opcode.Sub])(args);
    case Opcode.Mul:
        return PROC!(IRTypes[Opcode.Mul])(args);
    case Opcode.Div:
        return PROC!(IRTypes[Opcode.Div])(args);
    case Opcode.Mod:
        return PROC!(IRTypes[Opcode.Mod])(args);
    case Opcode.ShL:
        return PROC!(IRTypes[Opcode.ShL])(args);
    case Opcode.ShR:
        return PROC!(IRTypes[Opcode.ShR])(args);
    case Opcode.UShR:
        return PROC!(IRTypes[Opcode.UShR])(args);
    case Opcode.And:
        return PROC!(IRTypes[Opcode.And])(args);
    case Opcode.Or:
        return PROC!(IRTypes[Opcode.Or])(args);
    case Opcode.Xor:
        return PROC!(IRTypes[Opcode.Xor])(args);
    case Opcode.In:
        return PROC!(IRTypes[Opcode.In])(args);
    case Opcode.PreInc:
        return PROC!(IRTypes[Opcode.PreInc])(args);
    case Opcode.PreIncS:
        return PROC!(IRTypes[Opcode.PreIncS])(args);
    case Opcode.PreIncScope:
        return PROC!(IRTypes[Opcode.PreIncScope])(args);
    case Opcode.PreDec:
        return PROC!(IRTypes[Opcode.PreDec])(args);
    case Opcode.PreDecS:
        return PROC!(IRTypes[Opcode.PreDecS])(args);
    case Opcode.PreDecScope:
        return PROC!(IRTypes[Opcode.PreDecScope])(args);
    case Opcode.PostInc:
        return PROC!(IRTypes[Opcode.PostInc])(args);
    case Opcode.PostIncS:
        return PROC!(IRTypes[Opcode.PostIncS])(args);
    case Opcode.PostIncScope:
        return PROC!(IRTypes[Opcode.PostIncScope])(args);
    case Opcode.PostDec:
        return PROC!(IRTypes[Opcode.PostDec])(args);
    case Opcode.PostDecS:
        return PROC!(IRTypes[Opcode.PostDecS])(args);
    case Opcode.PostDecScope:
        return PROC!(IRTypes[Opcode.PostDecScope])(args);
    case Opcode.New:
        return PROC!(IRTypes[Opcode.New])(args);
    case Opcode.CLT:
        return PROC!(IRTypes[Opcode.CLT])(args);
    case Opcode.CLE:
        return PROC!(IRTypes[Opcode.CLE])(args);
    case Opcode.CGT:
        return PROC!(IRTypes[Opcode.CGT])(args);
    case Opcode.CGE:
        return PROC!(IRTypes[Opcode.CGE])(args);
    case Opcode.CEq:
        return PROC!(IRTypes[Opcode.CEq])(args);
    case Opcode.CNE:
        return PROC!(IRTypes[Opcode.CNE])(args);
    case Opcode.CID:
        return PROC!(IRTypes[Opcode.CID])(args);
    case Opcode.CNID:
        return PROC!(IRTypes[Opcode.CNID])(args);
    case Opcode.JT:
        return PROC!(IRTypes[Opcode.JT])(args);
    case Opcode.JF:
        return PROC!(IRTypes[Opcode.JF])(args);
    case Opcode.JTB:
        return PROC!(IRTypes[Opcode.JTB])(args);
    case Opcode.JFB:
        return PROC!(IRTypes[Opcode.JFB])(args);
    case Opcode.Jmp:
        return PROC!(IRTypes[Opcode.Jmp])(args);
    case Opcode.JLT:
        return PROC!(IRTypes[Opcode.JLT])(args);
    case Opcode.JLE:
        return PROC!(IRTypes[Opcode.JLE])(args);
    case Opcode.JLTC:
        return PROC!(IRTypes[Opcode.JLTC])(args);
    case Opcode.JLEC:
        return PROC!(IRTypes[Opcode.JLEC])(args);
    case Opcode.Typeof:
        return PROC!(IRTypes[Opcode.Typeof])(args);
    case Opcode.Instance:
        return PROC!(IRTypes[Opcode.Instance])(args);
    case Opcode.Push:
        return PROC!(IRTypes[Opcode.Push])(args);
    case Opcode.Pop:
        return PROC!(IRTypes[Opcode.Pop])(args);
    case Opcode.Iter:
        return PROC!(IRTypes[Opcode.Iter])(args);
    case Opcode.Assert:
        return PROC!(IRTypes[Opcode.Assert])(args);
    case Opcode.Throw:
        return PROC!(IRTypes[Opcode.Throw])(args);
    case Opcode.TryCatch:
        return PROC!(IRTypes[Opcode.TryCatch])(args);
    case Opcode.TryFinally:
        return PROC!(IRTypes[Opcode.TryFinally])(args);
    case Opcode.FinallyRet:
        return PROC!(IRTypes[Opcode.FinallyRet])(args);
    case Opcode.CheckRef:
        return PROC!(IRTypes[Opcode.CheckRef])(args);
    }
}


//
private template isGet(Opcode CODE)
{
    bool _impl(Opcode code)
    {
        final switch(code)
        {
        case Opcode.Error, Opcode.Nop, Opcode.End,
            Opcode.PutCall, Opcode.PutCallS, Opcode.PutCallScope,
            Opcode.PutCallV,

            Opcode.Put, Opcode.PutS, Opcode.PutScope, Opcode.PutGetter,
            Opcode.PutGetterS, Opcode.PutSetter, Opcode.PutSetterS,

            Opcode.Next, Opcode.NextS, Opcode.NextScope,

            Opcode.PutThis, Opcode.PutDefault,

            Opcode.Ret, Opcode.RetExp, Opcode.ImpRet,

            Opcode.New,

            Opcode.JT, Opcode.JF, Opcode.JTB, Opcode.JFB, Opcode.Jmp,
            Opcode.JLT, Opcode.JLE, Opcode.JLTC, Opcode.JLEC,

            Opcode.Push, Opcode.Pop,
            Opcode.Assert,

            Opcode.Throw, Opcode.TryCatch, Opcode.TryFinally,
            Opcode.FinallyRet, Opcode.CheckRef:

            return false;

        case Opcode.String, Opcode.ThisGet, Opcode.Number, Opcode.Object,
            Opcode.This, Opcode.Null, Opcode.Undefined, Opcode.Boolean,
            Opcode.Call, Opcode.CallS, Opcode.CallScope, Opcode.CallV,
            Opcode.Get, Opcode.GetS, Opcode.GetScope,

            Opcode.Del, Opcode.DelS, Opcode.DelScope,

            Opcode.AddAsS, Opcode.AddAsSS, Opcode.AddAsSScope,

            Opcode.Mov,

            Opcode.Neg, Opcode.Pos, Opcode.Com, Opcode.Not, Opcode.Add,
            Opcode.Sub, Opcode.Mul, Opcode.Div, Opcode.Mod, Opcode.ShL,
            Opcode.ShR, Opcode.UShR, Opcode.And, Opcode.Or, Opcode.Xor,
            Opcode.In,
            Opcode.PreInc, Opcode.PreIncS, Opcode.PreIncScope, Opcode.PreDec,
            Opcode.PreDecS, Opcode.PreDecScope, Opcode.PostInc, Opcode.PostIncS,
            Opcode.PostIncScope, Opcode.PostDec, Opcode.PostDecS,
            Opcode.PostDecScope,

            Opcode.CLT, Opcode.CLE, Opcode.CGT, Opcode.CGE, Opcode.CEq,
            Opcode.CNE, Opcode.CID, Opcode.CNID,

            Opcode.Typeof, Opcode.Instance,

            Opcode.Iter:
            return true;
        }
    }
    enum isGet = _impl(CODE);
}
