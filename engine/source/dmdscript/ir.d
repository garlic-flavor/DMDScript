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

enum
{
    IRerror,
    IRnop,                      // no operation
    IRend,                      // end of function
    IRstring,
    IRthisget,
    IRnumber,
    IRobject,
    IRthis,
    IRnull,
    IRundefined,
    IRboolean,
    IRcall,
    IRcalls = IRcall + 1,
    IRcallscope = IRcalls + 1,
    IRcallv = IRcallscope + 1,
    IRputcall,
    IRputcalls = IRputcall + 1,
    IRputcallscope = IRputcalls + 1,
    IRputcallv = IRputcallscope + 1,
    IRget,
    IRgets = IRget + 1,         // 's' versions must be original + 1
    IRgetscope = IRgets + 1,
    IRput,
    IRputs = IRput + 1,
    IRputscope = IRputs + 1,
    IRdel,
    IRdels = IRdel + 1,
    IRdelscope = IRdels + 1,
    IRnext,
    IRnexts = IRnext + 1,
    IRnextscope = IRnexts + 1,
    IRaddass,
    IRaddasss = IRaddass + 1,
    IRaddassscope = IRaddasss + 1,
    IRputthis,
    IRputdefault,
    IRmov,
    IRret,
    IRretexp,
    IRimpret,
    IRneg,
    IRpos,
    IRcom,
    IRnot,
    IRadd,
    IRsub,
    IRmul,
    IRdiv,
    IRmod,
    IRshl,
    IRshr,
    IRushr,
    IRand,
    IRor,
    IRxor,
    IRin,
    IRpreinc,
    IRpreincs = IRpreinc + 1,
    IRpreincscope = IRpreincs + 1,

    IRpredec,
    IRpredecs = IRpredec + 1,
    IRpredecscope = IRpredecs + 1,

    IRpostinc,
    IRpostincs = IRpostinc + 1,
    IRpostincscope = IRpostincs + 1,

    IRpostdec,
    IRpostdecs = IRpostdec + 1,
    IRpostdecscope = IRpostdecs + 1,

    IRnew,

    IRclt,
    IRcle,
    IRcgt,
    IRcge,
    IRceq,
    IRcne,
    IRcid,
    IRcnid,

    IRjt,
    IRjf,
    IRjtb,
    IRjfb,
    IRjmp,

    IRjlt,              // commonly appears as loop control
    IRjle,              // commonly appears as loop control

    IRjltc,             // commonly appears as loop control
    IRjlec,             // commonly appears as loop control

    IRtypeof,
    IRinstance,

    IRpush,
    IRpop,

    IRiter,
    IRassert,

    IRthrow,
    IRtrycatch,
    IRtryfinally,
    IRfinallyret,
    IRcheckref,//like scope get w/o target, occures mostly on (legal) programmer mistakes
    IRMAX
}

/* More self explanatory internal representation.
(This is a test implementation.)

# An example of memory mapping.

## about IRnumber

    +--- I choose fixed order. (The original depends on the machine's native.)
    |
|-------|

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

import std.meta : AliasSeq;

import dmdscript.script : Loc, d_number, d_boolean;
import dmdscript.identifier : Identifier;
import dmdscript.functiondefinition : FunctionDefinition;

enum Opcode : ubyte
{
    Error,
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
    CallS = Call + 1,
    CallScope = CallS + 1,
    CallV = CallScope + 1,
    PutCall,
    PutCallS = PutCall + 1,
    PutCallScope = PutCallS + 1,
    PutCallV = PutCallScope + 1,
    Get,
    GetS = Get + 1,         // 'S(ymbol)' Versions Must Be Original + 1
    GetScope = GetS + 1,
    Put,
    PutS = Put + 1,
    PutScope = PutS + 1,
    Del,
    DelS = Del + 1,
    DelScope = DelS + 1,
    Next,
    NextS = Next + 1,
    NextScope = NextS + 1,
    AddAsS,
    AddAsSS = AddAsS + 1,
    AddAsSScope = AddAsSS + 1,
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
    PreIncS = PreInc + 1,
    PreIncScope = PreIncS + 1,

    PreDec,
    PreDecS = PreDec + 1,
    PreDecScope = PreDecS + 1,

    PostInc,
    PostIncS = PostInc + 1,
    PostIncScope = PostIncS + 1,

    PostDec,
    PostDecS = PostDec + 1,
    PostDecScope = PostDecS + 1,

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

// this holds an index value that points a Value* in local variable array.
alias idx_t = size_t;

//
struct Instruction
{
    static if      (size_t.sizeof == 4)
    {
        Opcode opcode;
        private ubyte _padding;
        ushort linnum;
    }
    else static if (size_t.sizeof == 8)
    {
        Opcode opcode;
        private ubyte[3] _padding;
        uint linnum;
    }
    else static assert(0);

    this(Loc loc, Opcode op)
    {
        linnum = cast(typeof(linnum))loc;
        opcode = op;
    }
}
static assert (Instruction.sizeof == size_t.sizeof);

//
struct IR0(Opcode CODE)
{
    enum Opcode code = CODE;

    Instruction ir;

    this(Loc loc)
    { ir = Instruction(loc, code); }
}
//
struct IR1(Opcode CODE)
{
    enum Opcode code = CODE;

    Instruction ir;
    idx_t acc;  // the position of an acc buffer in local variable array.

    this(Loc loc, idx_t acc)
    {
        ir = Instruction(loc, code);
        this.acc = acc;
    }
}

//
struct IR2(Opcode CODE, T)
{
    enum Opcode code = CODE;

    Instruction ir;
    idx_t acc;
    T operand;

    this(Loc loc, idx_t acc, T operand)
    {
        ir = Instruction(loc, code);
        this.acc = acc;
        this.operand = operand;
    }
}

//
struct IR3(Opcode CODE, T, U)
{
    enum Opcode code = CODE;

    Instruction ir;
    idx_t acc;
    T operand1;
    U operand2;

    this(Loc loc, idx_t acc, T o1, U o2)
    {
        ir = Instruction(loc, code);
        this.acc = acc;
        operand1 = o1;
        operand2 = o2;
    }
}

//
struct IRcall4(Opcode CODE, T)
{
    enum Opcode code = CODE;
    alias code this;

    Instruction ir;
    idx_t acc;
    T func; // the name of the function. idx_t or Identifier*.
    size_t argc;
    idx_t argv;

    this(Loc loc, idx_t acc, T func, size_t argc, idx_t argv)
    {
        ir = Instruction(loc, code);
        this.acc = acc;
        this.func = func;
        this.argc = argc;
        this.argv = argv;
    }
}
//
struct IRcall5(Opcode CODE, T)
{
    enum Opcode code = CODE;
    alias code this;

    Instruction ir;
    idx_t acc;
    idx_t owner; // the owner of the method.
    T method;    // the name of the method. idx_t or Identifier*
    size_t argc;
    idx_t argv;

    this(Loc loc, idx_t acc, idx_t owner, T method, size_t argc, idx_t argv)
    {
        ir = Instruction(loc, code);
        this.acc = acc;
        this.owner = owner;
        this.method = method;
        this.argc = argc;
        this.argv = argv;
    }
}

//
struct IRget3(Opcode CODE, T)
{
    enum Opcode code = CODE;
    alias code this;

    Instruction ir;
    idx_t acc;
    idx_t owner;
    T method;

    this(Loc loc, idx_t acc, idx_t owner, T method)
    {
        ir = Instruction(loc, code);
        this.acc = acc;
        this.owner = owner;
        this.method = method;
    }
}

// if (!(func = iter)) goto offset; iter = iter.next;
struct IRnext3(Opcode CODE, T)
{
    enum Opcode code = CODE;
    alias code this;

    Instruction ir;
    sizediff_t offset;
    T func;
    idx_t iter;

    this(Loc loc, sizediff_t offset, T func, idx_t iter)
    {
        ir = Instruction(loc, code);
        this.offset = offset;
        this.func = func;
        this.iter = iter;
    }
}

// if (!(owner.method = iter)) goto offset; iter = iter.next;
struct IRnext4(Opcode CODE, T)
{
    enum Opcode code = CODE;
    alias code this;

    Instruction ir;
    sizediff_t offset;
    idx_t owner;
    T method;
    idx_t iter;

    this(Loc loc, sizediff_t offset, idx_t owner, T method, idx_t iter)
    {
        ir = Instruction(loc, code);
        this.offset = offset;
        this.owner = owner;
        this.method = method;
        this.iter = iter;
    }
}

//
struct IRjump1(Opcode CODE)
{
    enum Opcode code = CODE;
    alias code this;

    Instruction ir;
    sizediff_t offset;

    this(Loc loc, sizediff_t offset)
    {
        ir = Instruction(loc, code);
        this.offset = offset;
    }
}
//
struct IRjump2(Opcode CODE)
{
    enum Opcode code = CODE;
    alias code this;

    Instruction ir;
    sizediff_t offset;
    idx_t cond;

    this(Loc loc, sizediff_t offset, idx_t cond)
    {
        ir = Instruction(loc, code);
        this.offset = offset;
        this.cond = cond;
    }
}
//
struct IRjump3(Opcode CODE, T = idx_t)
{
    enum Opcode code = CODE;
    alias code this;

    Instruction ir;
    sizediff_t offset;
    idx_t operand1;
    T operand2;

    this(Loc loc, sizediff_t offset, idx_t o1, T o2)
    {
        ir = Instruction(loc, code);
        this.offset = offset;
        this.operand1 = o1;
        this.operand2 = o2;
    }
}

//
struct IRTryCatch
{
    enum Opcode code = Opcode.TryCatch;

    Instruction ir;
    sizediff_t offset;
    Identifier* name;

    this(Loc loc, sizediff_t offset, Identifier* name)
    {
        ir = Instruction(loc, code);
        this.offset = offset;
        this.name = name;
    }
}

//
struct IRCheckRef
{
    enum Opcode code = Opcode.CheckRef;

    Instruction ir;
    Identifier* operand;

    this(Loc loc, Identifier* operand)
    {
        ir = Instruction(loc, code);
        this.operand = operand;
    }
}

//
alias IRTypes = AliasSeq!(
    IR0!(Opcode.Error),
    IR0!(Opcode.Nop), // no operation
    IR0!(Opcode.End), // end of function

    IR2!(Opcode.String, Identifier*),        // acc = "string"
    IR2!(Opcode.ThisGet, Identifier*),      // acc = othis.operand
    IR2!(Opcode.Number, d_number),           // acc = number
    IR2!(Opcode.Object, FunctionDefinition),
                                         // acc = new DdeclaredFunction(operand)
    IR1!(Opcode.This),                         // acc = this
    IR1!(Opcode.Null),                         // acc = null
    IR1!(Opcode.Undefined),               // acc = undefined
    IR2!(Opcode.Boolean, d_boolean),        // acc = operand

    IRcall5!(Opcode.Call, idx_t), // acc = owner.method(argv[0..argc])
    IRcall5!(Opcode.CallS, Identifier*), // acc = owner.method(argv[0..argc])
    IRcall4!(Opcode.CallScope, Identifier*), // acc = func(argv[0..argv])
    IRcall4!(Opcode.CallV, idx_t),     // func(argv[0..argv]) = acc
    IRcall5!(Opcode.PutCall, idx_t), // owner.method(argv[0..argc]) = acc
    IRcall5!(Opcode.PutCallS, Identifier*), // owner.method(argv[0..argc]) = acc
    IRcall4!(Opcode.PutCallScope, Identifier*), // func(argv[0..argc]) = acc
    IRcall4!(Opcode.PutCallV, idx_t), // func(argv[0..argc]) = acc

    IRget3!(Opcode.Get, idx_t), // acc = owner.method
    IRget3!(Opcode.GetS, Identifier*), // acc = owner.method
    IR2!(Opcode.GetScope, Identifier*), // acc = operand
    IRget3!(Opcode.Put, idx_t), // owner.method = acc
    IRget3!(Opcode.PutS, Identifier*), // owner.method = acc
    IR2!(Opcode.PutScope, Identifier*), // s = acc,
    IRget3!(Opcode.Del, idx_t), // acc = delete owner.method
    IRget3!(Opcode.DelS, Identifier*), // acc = delete owner.method
    IR2!(Opcode.DelScope, Identifier*), // acc = delete operand

    IRnext4!(Opcode.Next, idx_t),
                   // if (!(owner.method = iter)) goto offset, iter = iter.next
    IRnext4!(Opcode.NextS, Identifier*),
                   // if (!(owner.method = iter)) goto offset, iter = iter.next
    IRnext3!(Opcode.NextScope, Identifier*),

    IRget3!(Opcode.AddAsS, idx_t),  // acc = (owner.method += acc)
    IRget3!(Opcode.AddAsSS, Identifier*), // acc = (owner.method += acc)
    IR2!(Opcode.AddAsSScope, Identifier*), // acc = (operand += acc)
    IR2!(Opcode.PutThis, Identifier*), // operand = acc,
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
    IRget3!(Opcode.PreIncS, Identifier*), // acc = ++owner.method
    IR2!(Opcode.PreIncScope, Identifier*), // acc = ++operand,
    IRget3!(Opcode.PreDec, idx_t), // acc = --owner.method
    IRget3!(Opcode.PreDecS, Identifier*), // acc = --owner.method
    IR2!(Opcode.PreDecScope, Identifier*), // acc = --operand
    IRget3!(Opcode.PostInc, idx_t), // acc = owner.method++,
    IRget3!(Opcode.PostIncS, Identifier*), // acc = owner.method++,
    IR2!(Opcode.PostIncScope, Identifier*), // acc = operand++,
    IRget3!(Opcode.PostDec, idx_t), // acc = owner.method--,
    IRget3!(Opcode.PostDecS, Identifier*), // acc = owner.method--,
    IR2!(Opcode.PostDecScope, Identifier*), // acc = operand--,
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
    IRjump3!(Opcode.JLTC, d_number), // if (operand < constant) goto offset,
    IRjump3!(Opcode.JLEC, d_number), // if (operand <= constant) goto offset

    IR1!(Opcode.Typeof), // acc = typeof acc,
    IR3!(Opcode.Instance, idx_t, idx_t), // acc = operand1 instanceof operand2

    IR1!(Opcode.Push), //
    IR0!(Opcode.Pop), //

    IR2!(Opcode.Iter, idx_t), // acc = iter(operand),
    IR1!(Opcode.Assert), //
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
