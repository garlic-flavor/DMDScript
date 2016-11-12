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

module dmdscript.statement;

// import std.string;
// import std.math;
// import std.format;
// import std.traits;
// import std.exception;
// import std.utf;

import dmdscript.script;
import dmdscript.value;
import dmdscript.scopex;
import dmdscript.expression;
import dmdscript.irstate;
import dmdscript.symbol;
import dmdscript.identifier;
import dmdscript.ir;
import dmdscript.lexer;
import dmdscript.errmsgs;
import dmdscript.functiondefinition;
import dmdscript.opcodes;

debug import std.stdio;

enum
{
    TOPSTATEMENT,
    FUNCTIONDEFINITION,
    EXPSTATEMENT,
    VARSTATEMENT,
}


/******************************** TopStatement ***************************/

class TopStatement
{
    enum uint TOPSTATEMENT_SIGNATURE = 0xBA3FE1F3;
    uint signature = TOPSTATEMENT_SIGNATURE;

    Loc loc;
    int done;           // 0: parsed
                        // 1: semantic
                        // 2: toIR
    int st;

    this(Loc loc)
    {
        this.loc = loc;
        this.done = 0;
        this.st = TOPSTATEMENT;
    }

    invariant()
    {
        assert(signature == TOPSTATEMENT_SIGNATURE);
    }

    void toBuffer(ref tchar[] buf)
    {
        buf ~= "TopStatement.toBuffer()\n";
    }

    Statement semantic(Scope *sc)
    {
        debug writefln("TopStatement.semantic(%p)", this);
        return null;
    }

    void toIR(IRstate *irs)
    {
        debug writefln("TopStatement.toIR(%p)", this);
    }

    deprecated
    void error(ARGS...)(Scope* sc, string fmt, ARGS args)
    {
        import std.format : format;
        import std.conv : to;

        d_string sourcename;

        if(sc.funcdef)
        {
            if(sc.funcdef.isAnonymous)
                sourcename = "anonymous";
            else if(sc.funcdef.name)
                sourcename ~= sc.funcdef.name.toString;
        }

        if (sc.exception is null)
        {
            sc.exception = new ScriptException(
                format(fmt, args), sourcename.to!string, sc.getSource, loc);
        }
//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// Should I throw the exception?
    }

    void error(Scope* sc, ScriptException se)
    {
        assert(sc !is null);
        assert(se !is null);

        if (sc.exception is null)
        {
            d_string sourcename;
            if (sc.funcdef !is null)
            {
                if      (sc.funcdef.isAnonymous)
                    sourcename = "anonymous";
                else if (sc.funcdef.name)
                    sourcename = sc.funcdef.name.toString;
            }

            se.addSource(sourcename, sc.getSource, loc);
            sc.exception = se;
        }
    }

    TopStatement ImpliedReturn()
    {
        return this;
    }
}

/******************************** Statement ***************************/

class Statement : TopStatement
{
    LabelSymbol* label;

    this(Loc loc)
    {
        super(loc);
        this.loc = loc;
    }

    override void toBuffer(ref tchar[] buf)
    {
        buf ~= "Statement.toBuffer()\n";
    }

    override Statement semantic(Scope *sc)
    {
        debug writef("Statement.semantic(%p)\n", this);
        return this;
    }

    override void toIR(IRstate *irs)
    {
        debug writef("Statement.toIR(%p)\n", this);
    }

    uint getBreak()
    {
        assert(0);
    }

    uint getContinue()
    {
        assert(0);
    }

    uint getGoto()
    {
        assert(0);
    }

    uint getTarget()
    {
        assert(0);
    }

    ScopeStatement getScope()
    {
        return null;
    }
}

/******************************** EmptyStatement ***************************/

class EmptyStatement : Statement
{
    this(Loc loc)
    {
        super(loc);
        this.loc = loc;
    }

    override void toBuffer(ref tchar[] buf)
    {
        buf ~= ";\n";
    }

    override Statement semantic(Scope* sc)
    {
        //writef("EmptyStatement.semantic(%p)\n", this);
        return this;
    }

    override void toIR(IRstate* irs)
    {
    }
}

/******************************** ExpStatement ***************************/

class ExpStatement : Statement
{
    Expression exp;

    this(Loc loc, Expression exp)
    {
        //writef("ExpStatement.ExpStatement(this = %x, exp = %x)\n", this, exp);
        super(loc);
        st = EXPSTATEMENT;
        this.exp = exp;
    }

    override void toBuffer(ref tchar[] buf)
    {
        if(exp)
            exp.toBuffer(buf);
        buf ~= ";\n";
    }

    override Statement semantic(Scope* sc)
    {
        //writef("exp = '%s'\n", exp.toString());
        //writef("ExpStatement.semantic(this = %x, exp = %x, exp.vptr = %x, %x, %x)\n", this, exp, ((uint *)exp)[0], /*(*(uint **)exp)[12],*/ *(uint *)(*(uint **)exp)[12]);
        if(exp)
            exp = exp.semantic(sc);
        //writef("-semantic()\n");
        return this;
    }

    override TopStatement ImpliedReturn()
    {
        return new ImpliedReturnStatement(loc, exp);
    }

    override void toIR(IRstate* irs)
    {
        //writef("ExpStatement.toIR(%p)\n", exp);
        if(exp)
        {
            uint marksave = irs.mark();

            assert(exp);
            exp.toIR(irs, 0);
            irs.release(marksave);

            exp = null;         // release to garbage collector
        }
    }
}

/****************************** VarDeclaration ******************************/

class VarDeclaration
{
    Loc loc;
    Identifier* name;
    Expression init;

    this(Loc loc, Identifier* name, Expression init)
    {
        this.loc = loc;
        this.init = init;
        this.name = name;
    }
}

/******************************** VarStatement ***************************/

class VarStatement : Statement
{
    VarDeclaration[] vardecls;

    this(Loc loc)
    {
        super(loc);
        st = VARSTATEMENT;
    }

    override Statement semantic(Scope* sc)
    {
        FunctionDefinition fd;
        uint i;

        // Collect all the Var statements in order in the function
        // declaration, this is so it is easy to instantiate them
        fd = sc.funcdef;
        //fd.varnames.reserve(vardecls.length);

        for(i = 0; i < vardecls.length; i++)
        {
            VarDeclaration vd;

            vd = vardecls[i];
            if(vd.init)
                vd.init = vd.init.semantic(sc);
            fd.varnames ~= vd.name;
        }

        return this;
    }

    override void toBuffer(ref tchar[] buf)
    {
        uint i;

        if(vardecls.length)
        {
            buf ~= "var ";

            for(i = 0; i < vardecls.length; i++)
            {
                VarDeclaration vd;

                vd = vardecls[i];
                buf ~= vd.name.toString();
                if(vd.init)
                {
                    buf ~= " = ";
                    vd.init.toBuffer(buf);
                }
            }
            buf ~= ";\n";
        }
    }

    override void toIR(IRstate* irs)
    {
        uint i;
        uint ret;

        if(vardecls.length)
        {
            uint marksave;

            marksave = irs.mark();
            ret = irs.alloc(1);

            for(i = 0; i < vardecls.length; i++)
            {
                VarDeclaration vd;

                vd = vardecls[i];

                // This works like assignment statements:
                //	name = init;
                IR property;

                if(vd.init)
                {
                    vd.init.toIR(irs, ret);
                    property.id = Identifier.build(vd.name.toString());
                    irs.gen_!(Opcode.PutThis)(loc, ret, property.id);
                }
            }
            irs.release(marksave);
            vardecls[] = null;          // help gc
        }
    }
}

/******************************** BlockStatement ***************************/

class BlockStatement : Statement
{
    TopStatement[] statements;

    this(Loc loc)
    {
        super(loc);
    }

    override Statement semantic(Scope* sc)
    {
        uint i;

        //writefln("BlockStatement.semantic()");
        for(i = 0; i < statements.length; i++)
        {
            TopStatement s;

            s = statements[i];
            assert(s);
            statements[i] = s.semantic(sc);
        }

        return this;
    }

    override TopStatement ImpliedReturn()
    {
        uint i = statements.length;

        if(i)
        {
            TopStatement ts = statements[i - 1];
            ts = ts.ImpliedReturn();
            statements[i - 1] = cast(Statement)ts;
        }
        return this;
    }


    override void toBuffer(ref tchar[] buf)
    {
        buf ~= "{\n";

        foreach(TopStatement s; statements)
        {
            s.toBuffer(buf);
        }

        buf ~= "}\n";
    }

    override void toIR(IRstate* irs)
    {
        foreach(TopStatement s; statements)
        {
            s.toIR(irs);
        }

        // Release to garbage collector
        statements[] = null;
        statements = null;
    }
}

/******************************** LabelStatement ***************************/

class LabelStatement : Statement
{
    Identifier* ident;
    Statement statement;
    uint gotoIP;
    uint breakIP;
    ScopeStatement scopeContext;
    Scope whichScope;

    this(Loc loc, Identifier* ident, Statement statement)
    {
        //writef("LabelStatement.LabelStatement(%p, '%s', %p)\n", this, ident.toChars(), statement);
        super(loc);
        this.ident = ident;
        this.statement = statement;
        gotoIP = ~0u;
        breakIP = ~0u;
        scopeContext = null;
    }

    override Statement semantic(Scope* sc)
    {
        LabelSymbol ls;

        //writef("LabelStatement.semantic('%ls')\n", ident.toString());
        scopeContext = sc.scopeContext;
        whichScope = *sc;
        ls = sc.searchLabel(ident);
        if(ls)
        {
            // Ignore multiple definition errors
            //if (ls.statement)
            //error(sc, "label '%s' is already defined", ident.toString());
            ls.statement = this;
        }
        else
        {
            ls = new LabelSymbol(loc, ident, this);
            sc.insertLabel(ls);
        }
        if(statement)
            statement = statement.semantic(sc);
        return this;
    }

    override TopStatement ImpliedReturn()
    {
        if(statement)
            statement = cast(Statement)statement.ImpliedReturn();
        return this;
    }

    override void toBuffer(ref tchar[] buf)
    {
        buf ~= ident.toString();
        buf ~= ": ";
        if(statement)
            statement.toBuffer(buf);
        else
            buf ~= '\n';
    }

    override void toIR(IRstate* irs)
    {
        gotoIP = irs.getIP();
        statement.toIR(irs);
        breakIP = irs.getIP();
    }

    override uint getGoto()
    {
        return gotoIP;
    }

    override uint getBreak()
    {
        return breakIP;
    }

    override uint getContinue()
    {
        return statement.getContinue();
    }

    override ScopeStatement getScope()
    {
        return scopeContext;
    }
}

/******************************** IfStatement ***************************/

class IfStatement : Statement
{
    Expression condition;
    Statement ifbody;
    Statement elsebody;

    this(Loc loc, Expression condition, Statement ifbody, Statement elsebody)
    {
        super(loc);
        this.condition = condition;
        this.ifbody = ifbody;
        this.elsebody = elsebody;
    }

    override Statement semantic(Scope* sc)
    {
        //writef("IfStatement.semantic(%p)\n", sc);
        assert(condition);
        condition = condition.semantic(sc);
        ifbody = ifbody.semantic(sc);
        if(elsebody)
            elsebody = elsebody.semantic(sc);

        return this;
    }

    override TopStatement ImpliedReturn()
    {
        assert(condition);
        ifbody = cast(Statement)ifbody.ImpliedReturn();
        if(elsebody)
            elsebody = cast(Statement)elsebody.ImpliedReturn();
        return this;
    }



    override void toIR(IRstate* irs)
    {
        uint c;
        uint u1;
        uint u2;

        assert(condition);
        c = irs.alloc(1);
        condition.toIR(irs, c);
        u1 = irs.getIP();
        if (condition.isBooleanResult)
            irs.gen_!(Opcode.JFB)(loc, 0, c);
        else
            irs.gen_!(Opcode.JF)(loc, 0, c);
        irs.release(c, 1);
        ifbody.toIR(irs);
        if(elsebody)
        {
            u2 = irs.getIP();
            irs.gen_!(Opcode.Jmp)(loc, 0);
            irs.patchJmp(u1, irs.getIP());
            elsebody.toIR(irs);
            irs.patchJmp(u2, irs.getIP());
        }
        else
        {
            irs.patchJmp(u1, irs.getIP());
        }

        // Help GC
        condition = null;
        ifbody = null;
        elsebody = null;
    }
}

/******************************** SwitchStatement ***************************/

class SwitchStatement : Statement
{
    Expression condition;
    Statement bdy;
    uint breakIP;
    ScopeStatement scopeContext;

    DefaultStatement swdefault;
    CaseStatement[] cases;

    this(Loc loc, Expression c, Statement b)
    {
        super(loc);
        condition = c;
        bdy = b;
        breakIP = ~0u;
        scopeContext = null;

        swdefault = null;
        cases = null;
    }

    override Statement semantic(Scope* sc)
    {
        condition = condition.semantic(sc);

        SwitchStatement switchSave = sc.switchTarget;
        Statement breakSave = sc.breakTarget;

        scopeContext = sc.scopeContext;
        sc.switchTarget = this;
        sc.breakTarget = this;

        bdy = bdy.semantic(sc);

        sc.switchTarget = switchSave;
        sc.breakTarget = breakSave;

        return this;
    }

    override void toIR(IRstate* irs)
    {
        idx_t c;
        uint udefault;
        uint marksave;

        //writef("SwitchStatement.toIR()\n");
        marksave = irs.mark();
        c = irs.alloc(1);
        condition.toIR(irs, c);

        // Generate a sequence of cmp-jt
        // Not the most efficient, but we await a more formal
        // specification of switch before we attempt to optimize

        if(cases.length)
        {
            idx_t x;

            x = irs.alloc(1);
            for(uint i = 0; i < cases.length; i++)
            {
                CaseStatement cs;

                x = irs.alloc(1);
                cs = cases[i];
                cs.exp.toIR(irs, x);
                irs.gen_!(Opcode.CID)(loc, x, c, x);
                cs.patchIP = irs.getIP();
                irs.gen_!(Opcode.JT)(loc, 0, x);
            }
        }
        udefault = irs.getIP();
        irs.gen_!(Opcode.Jmp)(loc, 0);

        Statement breakSave = irs.breakTarget;
        irs.breakTarget = this;
        bdy.toIR(irs);

        irs.breakTarget = breakSave;
        breakIP = irs.getIP();

        // Patch jump addresses
        if(cases.length)
        {
            for(uint i = 0; i < cases.length; i++)
            {
                CaseStatement cs;

                cs = cases[i];
                irs.patchJmp(cs.patchIP, cs.caseIP);
            }
        }
        if(swdefault)
            irs.patchJmp(udefault, swdefault.defaultIP);
        else
            irs.patchJmp(udefault, breakIP);
        irs.release(marksave);

        // Help gc
        condition = null;
        bdy = null;
    }

    override uint getBreak()
    {
        return breakIP;
    }

    override ScopeStatement getScope()
    {
        return scopeContext;
    }
}


/******************************** CaseStatement ***************************/

class CaseStatement : Statement
{
    Expression exp;
    uint caseIP;
    uint patchIP;

    this(Loc loc, Expression exp)
    {
        super(loc);
        this.exp = exp;
        caseIP = ~0u;
        patchIP = ~0u;
    }

    override Statement semantic(Scope* sc)
    {
        //writef("CaseStatement.semantic(%p)\n", sc);
        exp = exp.semantic(sc);
        if(sc.switchTarget)
        {
            SwitchStatement sw = sc.switchTarget;
            uint i;

            // Look for duplicate
            for(i = 0; i < sw.cases.length; i++)
            {
                CaseStatement cs = sw.cases[i];

                if(exp == cs.exp)
                {
                    error(sc, SwitchRedundantCaseError(exp.toString));
                    return null;
                }
            }
            sw.cases ~= this;
        }
        else
        {
            error(sc, MisplacedSwitchCaseError(exp.toString));
            return null;
        }
        return this;
    }

    override void toIR(IRstate* irs)
    {
        caseIP = irs.getIP();
    }
}

/******************************** DefaultStatement ***************************/

class DefaultStatement : Statement
{
    uint defaultIP;

    this(Loc loc)
    {
        super(loc);
        defaultIP = ~0u;
    }

    override Statement semantic(Scope* sc)
    {
        if(sc.switchTarget)
        {
            SwitchStatement sw = sc.switchTarget;

            if(sw.swdefault)
            {
                error(sc, SwitchRedundantDefaultError);
                return null;
            }
            sw.swdefault = this;
        }
        else
        {
            error(sc, MisplacedSwitchDefaultError);
            return null;
        }
        return this;
    }

    override void toIR(IRstate* irs)
    {
        defaultIP = irs.getIP();
    }
}

/******************************** DoStatement ***************************/

class DoStatement : Statement
{
    Statement bdy;
    Expression condition;
    uint breakIP;
    uint continueIP;
    ScopeStatement scopeContext;

    this(Loc loc, Statement b, Expression c)
    {
        super(loc);
        bdy = b;
        condition = c;
        breakIP = ~0u;
        continueIP = ~0u;
        scopeContext = null;
    }

    override Statement semantic(Scope* sc)
    {
        Statement continueSave = sc.continueTarget;
        Statement breakSave = sc.breakTarget;

        scopeContext = sc.scopeContext;
        sc.continueTarget = this;
        sc.breakTarget = this;

        bdy = bdy.semantic(sc);
        condition = condition.semantic(sc);

        sc.continueTarget = continueSave;
        sc.breakTarget = breakSave;

        return this;
    }

    override TopStatement ImpliedReturn()
    {
        if(bdy)
            bdy = cast(Statement)bdy.ImpliedReturn();
        return this;
    }

    override void toIR(IRstate* irs)
    {
        uint c;
        uint u1;
        Statement continueSave = irs.continueTarget;
        Statement breakSave = irs.breakTarget;
        uint marksave;

        irs.continueTarget = this;
        irs.breakTarget = this;

        marksave = irs.mark();
        u1 = irs.getIP();
        bdy.toIR(irs);
        c = irs.alloc(1);
        continueIP = irs.getIP();
        condition.toIR(irs, c);
        if (condition.isBooleanResult)
            irs.gen_!(Opcode.JTB)(loc, u1 - irs.getIP(), c);
        else
            irs.gen_!(Opcode.JT)(loc, u1 - irs.getIP(), c);
        breakIP = irs.getIP();
        irs.release(marksave);

        irs.continueTarget = continueSave;
        irs.breakTarget = breakSave;

        // Help GC
        condition = null;
        bdy = null;
    }

    override uint getBreak()
    {
        return breakIP;
    }

    override uint getContinue()
    {
        return continueIP;
    }

    override ScopeStatement getScope()
    {
        return scopeContext;
    }
}

/******************************** WhileStatement ***************************/

class WhileStatement : Statement
{
    Expression condition;
    Statement bdy;
    uint breakIP;
    uint continueIP;
    ScopeStatement scopeContext;

    this(Loc loc, Expression c, Statement b)
    {
        super(loc);
        condition = c;
        bdy = b;
        breakIP = ~0u;
        continueIP = ~0u;
        scopeContext = null;
    }

    override Statement semantic(Scope* sc)
    {
        Statement continueSave = sc.continueTarget;
        Statement breakSave = sc.breakTarget;

        scopeContext = sc.scopeContext;
        sc.continueTarget = this;
        sc.breakTarget = this;

        condition = condition.semantic(sc);
        bdy = bdy.semantic(sc);

        sc.continueTarget = continueSave;
        sc.breakTarget = breakSave;

        return this;
    }

    override TopStatement ImpliedReturn()
    {
        if(bdy)
            bdy = cast(Statement)bdy.ImpliedReturn();
        return this;
    }

    override void toIR(IRstate* irs)
    {
        uint c;
        uint u1;
        uint u2;

        Statement continueSave = irs.continueTarget;
        Statement breakSave = irs.breakTarget;
        uint marksave = irs.mark();

        irs.continueTarget = this;
        irs.breakTarget = this;

        u1 = irs.getIP();
        continueIP = u1;
        c = irs.alloc(1);
        condition.toIR(irs, c);
        u2 = irs.getIP();
        if (condition.isBooleanResult)
            irs.gen_!(Opcode.JFB)(loc, 0, c);
        else
            irs.gen_!(Opcode.JF)(loc, 0, c);
        bdy.toIR(irs);
        irs.gen_!(Opcode.Jmp)(loc, u1 - irs.getIP());
        irs.patchJmp(u2, irs.getIP());
        breakIP = irs.getIP();

        irs.release(marksave);
        irs.continueTarget = continueSave;
        irs.breakTarget = breakSave;

        // Help GC
        condition = null;
        bdy = null;
    }

    override uint getBreak()
    {
        return breakIP;
    }

    override uint getContinue()
    {
        return continueIP;
    }

    override ScopeStatement getScope()
    {
        return scopeContext;
    }
}

/******************************** ForStatement ***************************/

class ForStatement : Statement
{
    Statement init;
    Expression condition;
    Expression increment;
    Statement bdy;
    uint breakIP;
    uint continueIP;
    ScopeStatement scopeContext;

    this(Loc loc, Statement init, Expression condition, Expression increment, Statement bdy)
    {
        super(loc);
        this.init = init;
        this.condition = condition;
        this.increment = increment;
        this.bdy = bdy;
        breakIP = ~0u;
        continueIP = ~0u;
        scopeContext = null;
    }

    override Statement semantic(Scope* sc)
    {
        Statement continueSave = sc.continueTarget;
        Statement breakSave = sc.breakTarget;

        if(init)
            init = init.semantic(sc);
        if(condition)
            condition = condition.semantic(sc);
        if(increment)
            increment = increment.semantic(sc);

        scopeContext = sc.scopeContext;
        sc.continueTarget = this;
        sc.breakTarget = this;

        bdy = bdy.semantic(sc);

        sc.continueTarget = continueSave;
        sc.breakTarget = breakSave;

        return this;
    }

    override TopStatement ImpliedReturn()
    {
        if(bdy)
            bdy = cast(Statement)bdy.ImpliedReturn();
        return this;
    }

    override void toIR(IRstate* irs)
    {
        import std.math : isNaN;

        uint u1;
        uint u2 = 0;    // unneeded initialization keeps lint happy

        Statement continueSave = irs.continueTarget;
        Statement breakSave = irs.breakTarget;
        uint marksave = irs.mark();

        irs.continueTarget = this;
        irs.breakTarget = this;

        if(init)
            init.toIR(irs);
        u1 = irs.getIP();
        if(condition)
        {
            if(condition.op == Tok.Less || condition.op == Tok.Lessequal)
            {
                BinExp be = cast(BinExp)condition;
                RealExpression re;
                uint b;
                uint c;

                b = irs.alloc(1);
                be.e1.toIR(irs, b);
                re = cast(RealExpression )be.e2;
                if(be.e2.op == Tok.Real && !isNaN(re.value))
                {
                    u2 = irs.getIP();
                    if (condition.op == Tok.Less)
                        irs.gen_!(Opcode.JLTC)(loc, 0, b, re.value);
                    else
                        irs.gen_!(Opcode.JLEC)(loc, 0, b, re.value);
                }
                else
                {
                    c = irs.alloc(1);
                    be.e2.toIR(irs, c);
                    u2 = irs.getIP();
                    if (condition.op == Tok.Less)
                        irs.gen_!(Opcode.JLT)(loc, 0, b, c);
                    else
                        irs.gen_!(Opcode.JLE)(loc, 0, b, c);
                }
            }
            else
            {
                uint c;

                c = irs.alloc(1);
                condition.toIR(irs, c);
                u2 = irs.getIP();
                if (condition.isBooleanResult)
                    irs.gen_!(Opcode.JFB)(loc, 0, c);
                else
                    irs.gen_!(Opcode.JF)(loc, 0, c);
            }
        }
        bdy.toIR(irs);
        continueIP = irs.getIP();
        if(increment)
            increment.toIR(irs, 0);
        irs.gen_!(Opcode.Jmp)(loc, u1 - irs.getIP);
        if(condition)
            irs.patchJmp(u2, irs.getIP());

        breakIP = irs.getIP();

        irs.release(marksave);
        irs.continueTarget = continueSave;
        irs.breakTarget = breakSave;

        // Help GC
        init = null;
        condition = null;
        bdy = null;
        increment = null;
    }

    override uint getBreak()
    {
        return breakIP;
    }

    override uint getContinue()
    {
        return continueIP;
    }

    override ScopeStatement getScope()
    {
        return scopeContext;
    }
}

/******************************** ForInStatement ***************************/

class ForInStatement : Statement
{
    Statement init;
    Expression inexp;
    Statement bdy;
    uint breakIP;
    uint continueIP;
    ScopeStatement scopeContext;

    this(Loc loc, Statement init, Expression inexp, Statement bdy)
    {
        super(loc);
        this.init = init;
        this.inexp = inexp;
        this.bdy = bdy;
        breakIP = ~0u;
        continueIP = ~0u;
        scopeContext = null;
    }

    override Statement semantic(Scope* sc)
    {
        Statement continueSave = sc.continueTarget;
        Statement breakSave = sc.breakTarget;

        init = init.semantic(sc);

        if(init.st == EXPSTATEMENT)
        {
            ExpStatement es;

            es = cast(ExpStatement)(init);
            es.exp.checkLvalue(sc);
        }
        else if(init.st == VARSTATEMENT)
        {
        }
        else
        {
            error(sc, InitNotExpressionError);
            return null;
        }

        inexp = inexp.semantic(sc);

        scopeContext = sc.scopeContext;
        sc.continueTarget = this;
        sc.breakTarget = this;

        bdy = bdy.semantic(sc);

        sc.continueTarget = continueSave;
        sc.breakTarget = breakSave;

        return this;
    }

    override TopStatement ImpliedReturn()
    {
        bdy = cast(Statement)bdy.ImpliedReturn();
        return this;
    }

    override void toIR(IRstate* irs)
    {
        idx_t e;
        idx_t iter;
        ExpStatement es;
        VarStatement vs;
        uint base;
        IR property;
        OpOffset opoff;
        uint marksave = irs.mark();

        e = irs.alloc(1);
        inexp.toIR(irs, e);
        iter = irs.alloc(1);
        irs.gen_!(Opcode.Iter)(loc, iter, e);

        Statement continueSave = irs.continueTarget;
        Statement breakSave = irs.breakTarget;

        irs.continueTarget = this;
        irs.breakTarget = this;

        if(init.st == EXPSTATEMENT)
        {
            es = cast(ExpStatement)(init);
            es.exp.toLvalue(irs, base, &property, opoff);
        }
        else if(init.st == VARSTATEMENT)
        {
            VarDeclaration vd;

            vs = cast(VarStatement)(init);
            assert(vs.vardecls.length == 1);
            vd = vs.vardecls[0];

            property.id = Identifier.build(vd.name.toString());
            opoff = OpOffset.Scope;
            base = ~0u;
        }
        else
        {   // Error already reported by semantic()
            return;
        }

        continueIP = irs.getIP();
        final switch (opoff)
        {
        case OpOffset.None:
            irs.gen_!(Opcode.Next)(loc, 0, base, property.index, iter);
            break;
        case OpOffset.S:
            irs.gen_!(Opcode.NextS)(loc, 0, base, property.id, iter);
            break;
        case OpOffset.Scope:
            irs.gen_!(Opcode.NextScope)(loc, 0, property.id, iter);
            break;
        case OpOffset.V:
            assert(0);
        }
        bdy.toIR(irs);
        irs.gen_!(Opcode.Jmp)(loc, continueIP - irs.getIP());
        irs.patchJmp(continueIP, irs.getIP());

        breakIP = irs.getIP();

        irs.continueTarget = continueSave;
        irs.breakTarget = breakSave;
        irs.release(marksave);

        // Help GC
        init = null;
        inexp = null;
        bdy = null;
    }

    override uint getBreak()
    {
        return breakIP;
    }

    override uint getContinue()
    {
        return continueIP;
    }

    override ScopeStatement getScope()
    {
        return scopeContext;
    }
}

/******************************** ScopeStatement ***************************/

class ScopeStatement : Statement
{
    ScopeStatement enclosingScope;
    int depth;                  // syntactical nesting level of ScopeStatement's
    int npops;                  // how many items added to scope chain

    this(Loc loc)
    {
        super(loc);
        enclosingScope = null;
        depth = 1;
        npops = 1;
    }
}

/******************************** WithStatement ***************************/

class WithStatement : ScopeStatement
{
    Expression exp;
    Statement bdy;

    this(Loc loc, Expression exp, Statement bdy)
    {
        super(loc);
        this.exp = exp;
        this.bdy = bdy;
    }

    override Statement semantic(Scope* sc)
    {
        exp = exp.semantic(sc);

        enclosingScope = sc.scopeContext;
        sc.scopeContext = this;

        // So enclosing FunctionDeclaration knows how deep the With's
        // can nest
        if(enclosingScope)
            depth = enclosingScope.depth + 1;
        if(depth > sc.funcdef.withdepth)
            sc.funcdef.withdepth = depth;

        sc.nestDepth++;
        bdy = bdy.semantic(sc);
        sc.nestDepth--;

        sc.scopeContext = enclosingScope;
        return this;
    }

    override TopStatement ImpliedReturn()
    {
        bdy = cast(Statement)bdy.ImpliedReturn();
        return this;
    }



    override void toIR(IRstate* irs)
    {
        uint c;
        uint marksave = irs.mark();

        irs.scopeContext = this;

        c = irs.alloc(1);
        exp.toIR(irs, c);
        irs.gen_!(Opcode.Push)(loc, c);
        bdy.toIR(irs);
        irs.gen_!(Opcode.Pop)(loc);

        irs.scopeContext = enclosingScope;
        irs.release(marksave);

        // Help GC
        exp = null;
        bdy = null;
    }
}

/******************************** ContinueStatement ***************************/

class ContinueStatement : Statement
{
    Identifier* ident;
    Statement target;

    this(Loc loc, Identifier* ident)
    {
        super(loc);
        this.ident = ident;
        target = null;
    }

    override Statement semantic(Scope* sc)
    {
        if(ident == null)
        {
            target = sc.continueTarget;
            if(!target)
            {
                error(sc, MisplacedContinueError);
                return null;
            }
        }
        else
        {
            LabelSymbol ls;

            ls = sc.searchLabel(ident);
            if(!ls || !ls.statement)
            {
                error(sc, UndefinedStatementLabelError(ident.toString));
                return null;
            }
            else
                target = ls.statement;
        }
        return this;
    }

    override void toIR(IRstate* irs)
    {
        ScopeStatement w;
        ScopeStatement tw;

        tw = target.getScope();
        for(w = irs.scopeContext; !(w is tw); w = w.enclosingScope)
        {
            assert(w);
            irs.pops(w.npops);
        }
        irs.addFixup(irs.getIP());
        irs.gen_!IRJmpToStatement(loc, this);
    }

    override uint getTarget()
    {
        assert(target);
        return target.getContinue();
    }
}

/******************************** BreakStatement ***************************/

class BreakStatement : Statement
{
    Identifier* ident;
    Statement target;

    this(Loc loc, Identifier* ident)
    {
        super(loc);
        this.ident = ident;
        target = null;
    }

    override Statement semantic(Scope* sc)
    {
//      writef("BreakStatement.semantic(%p)\n", sc);
        if(ident == null)
        {
            target = sc.breakTarget;
            if(!target)
            {
                error(sc, MisplacedBreakError);
                return null;
            }
        }
        else
        {
            LabelSymbol ls;

            ls = sc.searchLabel(ident);
            if(!ls || !ls.statement)
            {
                error(sc, UndefinedStatementLabelError(ident.toString));
                return null;
            }
            else if(!sc.breakTarget)
            {
                error(sc, MisplacedBreakError);
            }
            else{
                //Scope* s;
                //for(s = sc; s && s != ls.statement.whichScope; s = s.enclosing){ }
                if(ls.statement.whichScope == *sc)
                    error(sc, CantBreakInternalError(ls.ident.value.text));
                target = ls.statement;
            }
        }
        return this;
    }

    override void toIR(IRstate* irs)
    {
        ScopeStatement w;
        ScopeStatement tw;

        assert(target);
        tw = target.getScope();
        for(w = irs.scopeContext; !(w is tw); w = w.enclosingScope)
        {
            assert(w);
            irs.pops(w.npops);
        }

        irs.addFixup(irs.getIP());
        irs.gen_!IRJmpToStatement(loc, this);
    }

    override uint getTarget()
    {
        assert(target);
        return target.getBreak();
    }
}

/******************************** GotoStatement ***************************/

class GotoStatement : Statement
{
    Identifier* ident;
    LabelSymbol label;

    this(Loc loc, Identifier * ident)
    {
        super(loc);
        this.ident = ident;
        label = null;
    }

    override Statement semantic(Scope* sc)
    {
        LabelSymbol ls;

        ls = sc.searchLabel(ident);
        if(!ls)
        {
            ls = new LabelSymbol(loc, ident, null);
            sc.insertLabel(ls);
        }
        label = ls;
        return this;
    }

    override void toIR(IRstate* irs)
    {
        assert(label);

        // Determine how many with pops we need to do
        for(ScopeStatement w = irs.scopeContext;; w = w.enclosingScope)
        {
            if(!w)
            {
                if(label.statement.scopeContext)
                {
                    assert(0); // BUG: should do next statement instead
                    //script.error(errmsgtbl[ERR_GOTO_INTO_WITH]);
                }
                break;
            }
            if(w is label.statement.scopeContext)
                break;
            irs.pops(w.npops);
        }

        irs.addFixup(irs.getIP());
        irs.gen_!IRJmpToStatement(loc, this);
    }

    override uint getTarget()
    {
        return label.statement.getGoto();
    }
}

/******************************** ReturnStatement ***************************/

class ReturnStatement : Statement
{
    Expression exp;

    this(Loc loc, Expression exp)
    {
        super(loc);
        this.exp = exp;
    }

    override Statement semantic(Scope* sc)
    {
        if(exp)
            exp = exp.semantic(sc);

        // Don't allow return from eval functions or global function
        if(sc.funcdef.iseval || sc.funcdef.isglobal)
            error(sc, MisplacedReturnError);

        return this;
    }

    override void toBuffer(ref tchar[] buf)
    {
        //writef("ReturnStatement.toBuffer()\n");
        buf ~= "return ";
        if(exp)
            exp.toBuffer(buf);
        buf ~= ";\n";
    }

    override void toIR(IRstate* irs)
    {
        ScopeStatement w;
        int npops;

        npops = 0;
        for(w = irs.scopeContext; w; w = w.enclosingScope)
            npops += w.npops;

        if(exp)
        {
            uint e;

            e = irs.alloc(1);
            exp.toIR(irs, e);
            if(npops)
            {
                irs.gen_!(Opcode.ImpRet)(loc, e);
                irs.pops(npops);
                irs.gen_!(Opcode.Ret)(loc);
            }
            else
                irs.gen_!(Opcode.RetExp)(loc, e);
            irs.release(e, 1);
        }
        else
        {
            if(npops)
                irs.pops(npops);
            irs.gen_!(Opcode.Ret)(loc);
        }

        // Help GC
        exp = null;
    }
}

/******************************** ImpliedReturnStatement ***************************/

// Same as ReturnStatement, except that the return value is set but the
// function does not actually return. Useful for setting the return
// value for loop bodies.

class ImpliedReturnStatement : Statement
{
    Expression exp;

    this(Loc loc, Expression exp)
    {
        super(loc);
        this.exp = exp;
    }

    override Statement semantic(Scope* sc)
    {
        if(exp)
            exp = exp.semantic(sc);
        return this;
    }

    override void toBuffer(ref tchar[] buf)
    {
        if(exp)
            exp.toBuffer(buf);
        buf ~= ";\n";
    }

    override void toIR(IRstate* irs)
    {
        if(exp)
        {
            uint e;

            e = irs.alloc(1);
            exp.toIR(irs, e);
            irs.gen_!(Opcode.ImpRet)(loc, e);
            irs.release(e, 1);

            // Help GC
            exp = null;
        }
    }
}

/******************************** ThrowStatement ***************************/

class ThrowStatement : Statement
{
    Expression exp;

    this(Loc loc, Expression exp)
    {
        super(loc);
        this.exp = exp;
    }

    override Statement semantic(Scope* sc)
    {
        if(exp)
            exp = exp.semantic(sc);
        else
        {
            error(sc, NoThrowExpressionError);
            return new EmptyStatement(loc);
        }
        return this;
    }

    override void toBuffer(ref tchar[] buf)
    {
        buf ~= "throw ";
        if(exp)
            exp.toBuffer(buf);
        buf ~= ";\n";
    }

    override void toIR(IRstate* irs)
    {
        uint e;

        assert(exp);
        e = irs.alloc(1);
        exp.toIR(irs, e);
        irs.gen_!(Opcode.Throw)(loc, e);
        irs.release(e, 1);

        // Help GC
        exp = null;
    }
}

/******************************** TryStatement ***************************/

class TryStatement : ScopeStatement
{
    Statement bdy;
    Identifier* catchident;
    Statement catchbdy;
    Statement finalbdy;

    this(Loc loc, Statement bdy,
         Identifier* catchident, Statement catchbdy,
         Statement finalbdy)
    {
        super(loc);
        this.bdy = bdy;
        this.catchident = catchident;
        this.catchbdy = catchbdy;
        this.finalbdy = finalbdy;
        if(catchbdy && finalbdy)
            npops = 2;          // 2 items in scope chain
    }

    override Statement semantic(Scope* sc)
    {
        enclosingScope = sc.scopeContext;
        sc.scopeContext = this;

        // So enclosing FunctionDeclaration knows how deep the With's
        // can nest
        if(enclosingScope)
            depth = enclosingScope.depth + 1;
        if(depth > sc.funcdef.withdepth)
            sc.funcdef.withdepth = depth;

        bdy.semantic(sc);
        if(catchbdy)
            catchbdy.semantic(sc);
        if(finalbdy)
            finalbdy.semantic(sc);

        sc.scopeContext = enclosingScope;
        return this;
    }

    override void toBuffer(ref tchar[] buf)
    {
        buf ~= "try\n";
        bdy.toBuffer(buf);
        if(catchident)
        {
            buf ~= "catch (" ~
            catchident.toString() ~
            ")\n";
        }
        if(catchbdy)
            catchbdy.toBuffer(buf);
        if(finalbdy)
        {
            buf ~= "finally\n";
            finalbdy.toBuffer(buf);
        }
    }

    override void toIR(IRstate* irs)
    {
        uint f;
        uint c;
        uint e;
        uint e2;
        uint marksave = irs.mark();

        irs.scopeContext = this;
        if(finalbdy)
        {
            f = irs.getIP();
            irs.gen_!(Opcode.TryFinally)(loc, 0);
            if(catchbdy)
            {
                c = irs.getIP();
                irs.gen_!(Opcode.TryCatch)(loc, 0, Identifier.build(catchident.toString));
                bdy.toIR(irs);
                irs.gen_!(Opcode.Pop)(loc);           // remove catch clause
                irs.gen_!(Opcode.Pop)(loc);           // call finalbdy

                e = irs.getIP();
                irs.gen_!(Opcode.Jmp)(loc, 0);
                irs.patchJmp(c, irs.getIP());
                catchbdy.toIR(irs);
                irs.gen_!(Opcode.Pop)(loc);           // remove catch object
                irs.gen_!(Opcode.Pop)(loc);           // call finalbdy code
                e2 = irs.getIP();
                irs.gen_!(Opcode.Jmp)(loc, 0);        // jmp past finalbdy

                irs.patchJmp(f, irs.getIP());
                irs.scopeContext = enclosingScope;
                finalbdy.toIR(irs);
                irs.gen_!(Opcode.FinallyRet)(loc);
                irs.patchJmp(e, irs.getIP());
                irs.patchJmp(e2, irs.getIP());
            }
            else // finalbdy only
            {
                bdy.toIR(irs);
                irs.gen_!(Opcode.Pop)(loc);
                e = irs.getIP();
                irs.gen_!(Opcode.Jmp)(loc, 0);
                irs.patchJmp(f, irs.getIP());
                irs.scopeContext = enclosingScope;
                finalbdy.toIR(irs);
                irs.gen_!(Opcode.FinallyRet)(loc);
                irs.patchJmp(e, irs.getIP());
            }
        }
        else // catchbdy only
        {
            c = irs.getIP();
            irs.gen_!(Opcode.TryCatch)(loc, 0, Identifier.build(catchident.toString));
            bdy.toIR(irs);
            irs.gen_!(Opcode.Pop)(loc);
            e = irs.getIP();
            irs.gen_!(Opcode.Jmp)(loc, 0);
            irs.patchJmp(c, irs.getIP());
            catchbdy.toIR(irs);
            irs.gen_!(Opcode.Pop)(loc);
            irs.patchJmp(e, irs.getIP());
        }
        irs.scopeContext = enclosingScope;
        irs.release(marksave);

        // Help GC
        bdy = null;
        catchident = null;
        catchbdy = null;
        finalbdy = null;
    }
}
