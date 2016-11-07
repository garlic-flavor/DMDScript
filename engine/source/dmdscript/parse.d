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


module dmdscript.parse;

import dmdscript.script;
import dmdscript.lexer;
import dmdscript.functiondefinition;
import dmdscript.expression;
import dmdscript.statement;
import dmdscript.identifier;
import dmdscript.ir;
import dmdscript.errmsgs;

class Parser : Lexer
{
    uint flags;

    enum
    {
        normal          = 0,
        initial         = 1,

        allowIn         = 0,
        noIn            = 2,

        // Flag if we're in the for statement header, as
        // automatic semicolon insertion is suppressed inside it.
        inForHeader     = 4,
    }

    FunctionDefinition lastnamedfunc;


    this(d_string sourcename, d_string base, int useStringtable)
    {
        //writefln("Parser.this(base = '%s')", base);
        super(sourcename, base, useStringtable);
        nextToken();            // start up the scanner
    }

    ~this()
    {
        lastnamedfunc = null;
    }


    /**********************************************
     * Return !=0 on error, and fill in *perrinfo.
     */

    static int parseFunctionDefinition(out FunctionDefinition pfd,
                                       immutable(char)[] params, immutable(char)[] bdy, out ErrInfo perrinfo)
    {
        Parser p;
        Identifier*[] parameters;
        TopStatement[] topstatements;
        FunctionDefinition fd = null;
        int result;

        p = new Parser("anonymous", params, 0);

        // Parse FormalParameterList
        while(p.token.value != Tok.Eof)
        {
            if(p.token.value != Tok.Identifier)
            {
                p.error(Err.FplExpectedIdentifier, p.token.toString);
                goto Lreturn;
            }
            parameters ~= p.token.ident;
            p.nextToken();
            if(p.token.value == Tok.Comma)
                p.nextToken();
            else if(p.token.value == Tok.Eof)
                break;
            else
            {
                p.error(Err.FplExpectedComma, p.token.toString);
                goto Lreturn;
            }
        }
        if(p.errinfo.message)
            goto Lreturn;

        delete p;

        // Parse StatementList
        p = new Parser("anonymous", bdy, 0);
        for(;; )
        {
            TopStatement ts;

            if(p.token.value == Tok.Eof)
                break;
            ts = p.parseStatement();
            topstatements ~= ts;
        }

        fd = new FunctionDefinition(0, 0, null, parameters, topstatements);


        Lreturn:
        pfd = fd;
        perrinfo = p.errinfo;
        result = (p.errinfo.message != null);
        delete p;
        p = null;
        return result;
    }

    /**********************************************
     * Return !=0 on error, and fill in *perrinfo.
     */

    int parseProgram(out TopStatement[] topstatements, ErrInfo *perrinfo)
    {
        topstatements = parseTopStatements();
        check(Tok.Eof);
        //writef("parseProgram done\n");
        *perrinfo = errinfo;
        //clearstack();
        return errinfo.message != null;
    }

    TopStatement[] parseTopStatements()
    {
        TopStatement[] topstatements;
        TopStatement ts;

        //writefln("parseTopStatements()");
        for(;; )
        {
            switch(token.value)
            {
            case Tok.Function:
                ts = parseFunction(0);
                topstatements ~= ts;
                break;

            case Tok.Eof:
                return topstatements;

            case Tok.Rbrace:
                return topstatements;

            default:
                ts = parseStatement();
                topstatements ~= ts;
                break;
            }
        }
        assert(0);
    }

    /***************************
     * flag:
     *	0	Function statement
     *	1	Function literal
     */

    TopStatement parseFunction(int flag)
    {
        Identifier* name;
        Identifier*[] parameters;
        TopStatement[] topstatements;
        FunctionDefinition f;
        Expression e = null;
        Loc loc;

        //writef("parseFunction()\n");
        loc = currentline;
        nextToken();
        name = null;
        if(token.value == Tok.Identifier)
        {
            name = token.ident;
            nextToken();

            if(!flag && token.value == Tok.Dot)
            {
                // Regard:
                //	function A.B() { }
                // as:
                //	A.B = function() { }
                // This is not ECMA, but a jscript feature

                e = new IdentifierExpression(loc, name);
                name = null;

                while(token.value == Tok.Dot)
                {
                    nextToken();
                    if(token.value == Tok.Identifier)
                    {
                        e = new DotExp(loc, e, token.ident);
                        nextToken();
                    }
                    else
                    {
                        error(Err.ExpectedIdentifier2param, ".", token.toString);
                        break;
                    }
                }
            }
        }

        check(Tok.Lparen);
        if(token.value == Tok.Rparen)
            nextToken();
        else
        {
            for(;; )
            {
                if(token.value == Tok.Identifier)
                {
                    parameters ~= token.ident;
                    nextToken();
                    if(token.value == Tok.Comma)
                    {
                        nextToken();
                        continue;
                    }
                    if(!check(Tok.Rparen))
                        break;
                }
                else
                    error(Err.ExpectedIdentifier);
                break;
            }
        }

        check(Tok.Lbrace);
        topstatements = parseTopStatements();
        check(Tok.Rbrace);

        f = new FunctionDefinition(loc, 0, name, parameters, topstatements);
        f.isliteral = flag;
        lastnamedfunc = f;

        //writef("parseFunction() done\n");
        if(!e)
            return f;

        // Construct:
        //	A.B = function() { }

        Expression e2 = new FunctionLiteral(loc, f);

        e = new AssignExp(loc, e, e2);

        Statement s = new ExpStatement(loc, e);

        return s;
    }

    /*****************************************
     */

    Statement parseStatement()
    {
        Statement s;
        Token* t;
        Loc loc;

        //writefln("parseStatement()");
        loc = currentline;
        switch(token.value)
        {
        case Tok.Identifier:
        case Tok.This:
            // Need to look ahead to see if it is a declaration, label, or expression
            t = peek(&token);
            if(t.value == Tok.Colon && token.value == Tok.Identifier)
            {       // It's a label
                Identifier *ident;

                ident = token.ident;
                nextToken();
                nextToken();
                s = parseStatement();
                s = new LabelStatement(loc, ident, s);
            }
            else if(t.value == Tok.Assign ||
                    t.value == Tok.Dot ||
                    t.value == Tok.Lbracket)
            {
                Expression exp;

                exp = parseExpression();
                parseOptionalSemi();
                s = new ExpStatement(loc, exp);
            }
            else
            {
                Expression exp;

                exp = parseExpression(initial);
                parseOptionalSemi();
                s = new ExpStatement(loc, exp);
            }
            break;

        case Tok.Real:
        case Tok.String:
        case Tok.Delete:
        case Tok.Lparen:
        case Tok.Plusplus:
        case Tok.Minusminus:
        case Tok.Plus:
        case Tok.Minus:
        case Tok.Not:
        case Tok.Tilde:
        case Tok.Typeof:
        case Tok.Null:
        case Tok.New:
        case Tok.True:
        case Tok.False:
        case Tok.Void:
        { Expression exp;

          exp = parseExpression(initial);
          parseOptionalSemi();
          s = new ExpStatement(loc, exp);
          break; }

        case Tok.Var:
        {
            Identifier *ident;
            Expression init;
            VarDeclaration v;
            VarStatement vs;

            vs = new VarStatement(loc);
            s = vs;

            nextToken();
            for(;; )
            {
                loc = currentline;

                if(token.value != Tok.Identifier)
                {
                    error(Err.ExpectedIdentifierParam, token.toString);
                    break;
                }
                ident = token.ident;
                init = null;
                nextToken();
                if(token.value == Tok.Assign)
                {
                    uint flags_save;

                    nextToken();
                    flags_save = flags;
                    flags &= ~initial;
                    init = parseAssignExp();
                    flags = flags_save;
                }
                v = new VarDeclaration(loc, ident, init);
                vs.vardecls ~= v;
                if(token.value != Tok.Comma)
                    break;
                nextToken();
            }
            if(!(flags & inForHeader))
                parseOptionalSemi();
            break;
        }

        case Tok.Lbrace:
        { BlockStatement bs;

          nextToken();
          bs = new BlockStatement(loc);
          /*while(token.value != Tok.Rbrace)
          {
              if(token.value == Tok.Eof)
              {         
                  error(ERR_UNTERMINATED_BLOCK);
                  break;
              }
              bs.statements ~= parseStatement();
          }*/
          bs.statements ~= parseTopStatements();
          s = bs;
          nextToken();

          // The following is to accommodate the jscript bug:
          //	if (i) {return(0);}; else ...
          /*if(token.value == Tok.Semicolon)
              nextToken();*/

          break; }

        case Tok.If:
        { Expression condition;
          Statement ifbody;
          Statement elsebody;

          nextToken();
          condition = parseParenExp();
          ifbody = parseStatement();
          if(token.value == Tok.Else)
          {
              nextToken();
              elsebody = parseStatement();
          }
          else
              elsebody = null;
          s = new IfStatement(loc, condition, ifbody, elsebody);
          break; }

        case Tok.Switch:
        { Expression condition;
          Statement bdy;

          nextToken();
          condition = parseParenExp();
          bdy = parseStatement();
          s = new SwitchStatement(loc, condition, bdy);
          break; }

        case Tok.Case:
        { Expression exp;

          nextToken();
          exp = parseExpression();
          check(Tok.Colon);
          s = new CaseStatement(loc, exp);
          break; }

        case Tok.Default:
            nextToken();
            check(Tok.Colon);
            s = new DefaultStatement(loc);
            break;

        case Tok.While:
        { Expression condition;
          Statement bdy;

          nextToken();
          condition = parseParenExp();
          bdy = parseStatement();
          s = new WhileStatement(loc, condition, bdy);
          break; }

        case Tok.Semicolon:
            nextToken();
            s = new EmptyStatement(loc);
            break;

        case Tok.Do:
        { Statement bdy;
          Expression condition;

          nextToken();
          bdy = parseStatement();
          check(Tok.While);
          condition = parseParenExp();
          //We do what most browsers now do, ie allow missing ';' 
          //like " do{ statement; }while(e) statement; " and that even w/o linebreak
          if(token.value == Tok.Semicolon)
              nextToken();
          //parseOptionalSemi();
          s = new DoStatement(loc, bdy, condition);
          break; }

        case Tok.For:
        {
            Statement init;
            Statement bdy;

            nextToken();
            flags |= inForHeader;
            check(Tok.Lparen);
            if(token.value == Tok.Var)
            {
                init = parseStatement();
            }
            else
            {
                Expression e;

                e = parseOptionalExpression(noIn);
                init = e ? new ExpStatement(loc, e) : null;
            }

            if(token.value == Tok.Semicolon)
            {
                Expression condition;
                Expression increment;

                nextToken();
                condition = parseOptionalExpression();
                check(Tok.Semicolon);
                increment = parseOptionalExpression();
                check(Tok.Rparen);
                flags &= ~inForHeader;

                bdy = parseStatement();
                s = new ForStatement(loc, init, condition, increment, bdy);
            }
            else if(token.value == Tok.In)
            {
                Expression inexp;
                VarStatement vs;

                // Check that there's only one VarDeclaration
                // in init.
                if(init.st == VARSTATEMENT)
                {
                    vs = cast(VarStatement)init;
                    if(vs.vardecls.length != 1)
                        error(Err.TooManyInVars, vs.vardecls.length);
                }

                nextToken();
                inexp = parseExpression();
                check(Tok.Rparen);
                flags &= ~inForHeader;
                bdy = parseStatement();
                s = new ForInStatement(loc, init, inexp, bdy);
            }
            else
            {
                error(Err.InExpected, token.toString);
                s = null;
            }
            break;
        }

        case Tok.With:
        { Expression exp;
          Statement bdy;

          nextToken();
          exp = parseParenExp();
          bdy = parseStatement();
          s = new WithStatement(loc, exp, bdy);
          break; }

        case Tok.Break:
        { Identifier* ident;

          nextToken();
          if(token.sawLineTerminator && token.value != Tok.Semicolon)
          {         // Assume we saw a semicolon
              ident = null;
          }
          else
          {
              if(token.value == Tok.Identifier)
              {
                  ident = token.ident;
                  nextToken();
              }
              else
                  ident = null;
              parseOptionalSemi();
          }
          s = new BreakStatement(loc, ident);
          break; }

        case Tok.Continue:
        { Identifier* ident;

          nextToken();
          if(token.sawLineTerminator && token.value != Tok.Semicolon)
          {         // Assume we saw a semicolon
              ident = null;
          }
          else
          {
              if(token.value == Tok.Identifier)
              {
                  ident = token.ident;
                  nextToken();
              }
              else
                  ident = null;
              parseOptionalSemi();
          }
          s = new ContinueStatement(loc, ident);
          break; }

        case Tok.Goto:
        { Identifier* ident;

          nextToken();
          if(token.value != Tok.Identifier)
          {
              error(Err.GotoLabelExpected, token.toString);
              s = null;
              break;
          }
          ident = token.ident;
          nextToken();
          parseOptionalSemi();
          s = new GotoStatement(loc, ident);
          break; }

        case Tok.Return:
        { Expression exp;

          nextToken();
          if(token.sawLineTerminator && token.value != Tok.Semicolon)
          {         // Assume we saw a semicolon
              s = new ReturnStatement(loc, null);
          }
          else
          {
              exp = parseOptionalExpression();
              parseOptionalSemi();
              s = new ReturnStatement(loc, exp);
          }
          break; }

        case Tok.Throw:
        { Expression exp;

          nextToken();
          exp = parseExpression();
          parseOptionalSemi();
          s = new ThrowStatement(loc, exp);
          break; }

        case Tok.Try:
        { Statement bdy;
          Identifier* catchident;
          Statement catchbody;
          Statement finalbody;

          nextToken();
          bdy = parseStatement();
          if(token.value == Tok.Catch)
          {
              nextToken();
              check(Tok.Lparen);
              catchident = null;
              if(token.value == Tok.Identifier)
                  catchident = token.ident;
              check(Tok.Identifier);
              check(Tok.Rparen);
              catchbody = parseStatement();
          }
          else
          {
              catchident = null;
              catchbody = null;
          }

          if(token.value == Tok.Finally)
          {
              nextToken();
              finalbody = parseStatement();
          }
          else
              finalbody = null;

          if(!catchbody && !finalbody)
          {
              error(Err.TryCatchExpected);
              s = null;
          }
          else
          {
              s = new TryStatement(loc, bdy, catchident, catchbody, finalbody);
          }
          break; }

        default:
            error(Err.StatementExpected, token.toString);
            nextToken();
            s = null;
            break;
        }

        //writefln("parseStatement() done");
        return s;
    }



    Expression parseOptionalExpression(uint flags = 0)
    {
        Expression e;

        if(token.value == Tok.Semicolon || token.value == Tok.Rparen)
            e = null;
        else
            e = parseExpression(flags);
        return e;
    }

    // Follow ECMA 7.8.1 rules for inserting semicolons
    void parseOptionalSemi()
    {
        if(token.value != Tok.Eof &&
           token.value != Tok.Rbrace &&
           !(token.sawLineTerminator && (flags & inForHeader) == 0)
           )
            check(Tok.Semicolon);
    }

    int check(Tok value)
    {
        if(token.value != value)
        {
            error(Err.ExpectedGeneric, token.toString, Token.toString(value));
            return 0;
        }
        nextToken();
        return 1;
    }

    /********************************* Expression Parser ***************************/


    Expression parseParenExp()
    {
        Expression e;

        check(Tok.Lparen);
        e = parseExpression();
        check(Tok.Rparen);
        return e;
    }

    Expression parsePrimaryExp(int innew)
    {
        Expression e;
        Loc loc;

        loc = currentline;
        switch(token.value)
        {
        case Tok.This:
            e = new ThisExpression(loc);
            nextToken();
            break;

        case Tok.Null:
            e = new NullExpression(loc);
            nextToken();
            break;
        case Tok.True:
            e = new BooleanExpression(loc, 1);
            nextToken();
            break;

        case Tok.False:
            e = new BooleanExpression(loc, 0);
            nextToken();
            break;

        case Tok.Real:
            e = new RealExpression(loc, token.realvalue);
            nextToken();
            break;

        case Tok.String:
            e = new StringExpression(loc, token.str);
            token.str = null;        // release to gc
            nextToken();
            break;

        case Tok.Regexp:
            e = new RegExpLiteral(loc, token.str);
            token.str = null;        // release to gc
            nextToken();
            break;

        case Tok.Identifier:
            e = new IdentifierExpression(loc, token.ident);
            token.ident = null;                 // release to gc
            nextToken();
            break;

        case Tok.Lparen:
            e = parseParenExp();
            break;

        case Tok.Lbracket:
            e = parseArrayLiteral();
            break;

        case Tok.Lbrace:
            /*if(flags & initial)
            {
                error(ERR_OBJ_LITERAL_IN_INITIALIZER);
                nextToken();
                return null;
            }*/
            e = parseObjectLiteral();
            break;

        case Tok.Function:
            //	    if (flags & initial)
            //		goto Lerror;
            e = parseFunctionLiteral();
            break;

        case Tok.New:
        { Expression newarg;
          Expression[] arguments;

          nextToken();
          newarg = parsePrimaryExp(1);
          arguments = parseArguments();
          e = new NewExp(loc, newarg, arguments);
          break; }

        default:
            //	Lerror:
            error(Err.ExpectedExpression, token.toString);
            nextToken();
            return null;
        }
        return parsePostExp(e, innew);
    }

    Expression[] parseArguments()
    {
        Expression[] arguments = null;

        if(token.value == Tok.Lparen)
        {
            nextToken();
            if(token.value != Tok.Rparen)
            {
                for(;; )
                {
                    Expression arg;

                    arg = parseAssignExp();
                    arguments ~= arg;
                    if(token.value == Tok.Rparen)
                        break;
                    if(!check(Tok.Comma))
                        break;
                }
            }
            nextToken();
        }
        return arguments;
    }

    Expression parseArrayLiteral()
    {
        Expression e;
        Expression[] elements;
        Loc loc;

        //writef("parseArrayLiteral()\n");
        loc = currentline;
        check(Tok.Lbracket);
        if(token.value != Tok.Rbracket)
        {
            for(;; )
            {
                if(token.value == Tok.Comma)
                    // Allow things like [1,2,,,3,]
                    // Like Explorer 4, and unlike Netscape, the
                    // trailing , indicates another null element.
                    //Netscape was right - FIXED
                    elements ~= cast(Expression)null;
                else if(token.value == Tok.Rbracket)
                {
                    //elements ~= cast(Expression)null;
                    break;
                }
                else
                {
                    e = parseAssignExp();
                    elements ~= e;
                    if(token.value != Tok.Comma)
                        break;
                }
                nextToken();
            }
        }
        check(Tok.Rbracket);
        e = new ArrayLiteral(loc, elements);
        return e;
    }

    Expression parseObjectLiteral()
    {
        Expression e;
        Field[] fields;
        Loc loc;

        //writef("parseObjectLiteral()\n");
        loc = currentline;
        check(Tok.Lbrace);
        if(token.value == Tok.Rbrace)
            nextToken();
        else
        {
            for(;; )
            {
                Field f;
                Identifier* ident;
                switch(token.value){
                    case Tok.Identifier:
                        ident = token.ident;
                        break;
                    case Tok.String,Tok.Number,Tok.Real:
                        ident = Identifier.build(token.toString);
                    break;
                    default:
                        error(Err.ExpectedIdentifier);
                    break;
                }
                nextToken();
                check(Tok.Colon);
                f = new Field(ident, parseAssignExp());
                fields ~= f;
                if(token.value != Tok.Comma)
                    break;
                nextToken();
                if(token.value == Tok.Rbrace)//allow trailing comma
                    break;
            }
            check(Tok.Rbrace);
        }
        e = new ObjectLiteral(loc, fields);
        return e;
    }

    Expression parseFunctionLiteral()
    {
        FunctionDefinition f;
        Loc loc;

        loc = currentline;
        f = cast(FunctionDefinition)parseFunction(1);
        return new FunctionLiteral(loc, f);
    }

    Expression parsePostExp(Expression e, int innew)
    {
        Loc loc;

        for(;; )
        {
            loc = currentline;
            //loc = (Loc)token.ptr;
            switch(token.value)
            {
            case Tok.Dot:
                nextToken();
                if(token.value == Tok.Identifier)
                {
                    e = new DotExp(loc, e, token.ident);
                }
                else
                {
                    error(Err.ExpectedIdentifier2param, ".", token.toString);
                    return e;
                }
                break;

            case Tok.Plusplus:
                if(token.sawLineTerminator && !(flags & inForHeader))
                    goto Linsert;
                e = new PostIncExp(loc, e);
                break;

            case Tok.Minusminus:
                if(token.sawLineTerminator && !(flags & inForHeader))
                {
                    Linsert:
                    // insert automatic semicolon
                    insertSemicolon(token.sawLineTerminator);
                    return e;
                }
                e = new PostDecExp(loc, e);
                break;

            case Tok.Lparen:
            {       // function call
                Expression[] arguments;

                if(innew)
                    return e;
                arguments = parseArguments();
                e = new CallExp(loc, e, arguments);
                continue;
            }

            case Tok.Lbracket:
            {       // array dereference
                Expression index;

                nextToken();
                index = parseExpression();
                check(Tok.Rbracket);
                e = new ArrayExp(loc, e, index);
                continue;
            }

            default:
                return e;
            }
            nextToken();
        }
        assert(0);
    }

    Expression parseUnaryExp()
    {
        Expression e;
        Loc loc;

        loc = currentline;
        switch(token.value)
        {
        case Tok.Plusplus:
            nextToken();
            e = parseUnaryExp();
            e = new PreExp(loc, Opcode.PreInc, e);
            break;

        case Tok.Minusminus:
            nextToken();
            e = parseUnaryExp();
            e = new PreExp(loc, Opcode.PreDec, e);
            break;

        case Tok.Minus:
            nextToken();
            e = parseUnaryExp();
            e = new XUnaExp(loc, Tok.Neg, Opcode.Neg, e);
            break;

        case Tok.Plus:
            nextToken();
            e = parseUnaryExp();
            e = new XUnaExp(loc, Tok.Pos, Opcode.Pos, e);
            break;

        case Tok.Not:
            nextToken();
            e = parseUnaryExp();
            e = new NotExp(loc, e);
            break;

        case Tok.Tilde:
            nextToken();
            e = parseUnaryExp();
            e = new XUnaExp(loc, Tok.Tilde, Opcode.Com, e);
            break;

        case Tok.Delete:
            nextToken();
            e = parsePrimaryExp(0);
            e = new DeleteExp(loc, e);
            break;

        case Tok.Typeof:
            nextToken();
            e = parseUnaryExp();
            e = new XUnaExp(loc, Tok.Typeof, Opcode.Typeof, e);
            break;

        case Tok.Void:
            nextToken();
            e = parseUnaryExp();
            e = new XUnaExp(loc, Tok.Void, Opcode.Undefined, e);
            break;

        default:
            e = parsePrimaryExp(0);
            break;
        }
        return e;
    }

    Expression parseMulExp()
    {
        Expression e;
        Expression e2;
        Loc loc;

        loc = currentline;
        e = parseUnaryExp();
        for(;; )
        {
            switch(token.value)
            {
            case Tok.Multiply:
                nextToken();
                e2 = parseUnaryExp();
                e = new XBinExp(loc, Tok.Multiply, Opcode.Mul, e, e2);
                continue;

            case Tok.Regexp:
                // Rescan as if it was a "/"
                rescan();
                goto case;
            case Tok.Divide:
                nextToken();
                e2 = parseUnaryExp();
                e = new XBinExp(loc, Tok.Divide, Opcode.Div, e, e2);
                continue;

            case Tok.Percent:
                nextToken();
                e2 = parseUnaryExp();
                e = new XBinExp(loc, Tok.Percent, Opcode.Mod, e, e2);
                continue;

            default:
                break;
            }
            break;
        }
        return e;
    }

    Expression parseAddExp()
    {
        Expression e;
        Expression e2;
        Loc loc;

        loc = currentline;
        e = parseMulExp();
        for(;; )
        {
            switch(token.value)
            {
            case Tok.Plus:
                nextToken();
                e2 = parseMulExp();
                e = new AddExp(loc, e, e2);
                continue;

            case Tok.Minus:
                nextToken();
                e2 = parseMulExp();
                e = new XBinExp(loc, Tok.Minus, Opcode.Sub, e, e2);
                continue;

            default:
                break;
            }
            break;
        }
        return e;
    }

    Expression parseShiftExp()
    {
        Expression e;
        Expression e2;
        Loc loc;

        loc = currentline;
        e = parseAddExp();
        for(;; )
        {
            Opcode ircode;
            auto op = token.value;

            switch(op)
            {
            case Tok.Shiftleft:      ircode = Opcode.ShL;         goto L1;
            case Tok.Shiftright:     ircode = Opcode.ShR;         goto L1;
            case Tok.Ushiftright:    ircode = Opcode.UShR;        goto L1;

                L1: nextToken();
                e2 = parseAddExp();
                e = new XBinExp(loc, op, ircode, e, e2);
                continue;

            default:
                break;
            }
            break;
        }
        return e;
    }

    Expression parseRelExp()
    {
        Expression e;
        Expression e2;
        Loc loc;

        loc = currentline;
        e = parseShiftExp();
        for(;; )
        {
            Opcode ircode;
            auto op = token.value;

            switch(op)
            {
            case Tok.Less:           ircode = Opcode.CLT; goto L1;
            case Tok.Lessequal:      ircode = Opcode.CLE; goto L1;
            case Tok.Greater:        ircode = Opcode.CGT; goto L1;
            case Tok.Greaterequal:   ircode = Opcode.CGE; goto L1;

                L1:
                nextToken();
                e2 = parseShiftExp();
                e = new CmpExp(loc, op, ircode, e, e2);
                continue;

            case Tok.Instanceof:
                nextToken();
                e2 = parseShiftExp();
                e = new XBinExp(loc, Tok.Instanceof, Opcode.Instance, e, e2);
                continue;

            case Tok.In:
                if(flags & noIn)
                    break;              // disallow
                nextToken();
                e2 = parseShiftExp();
                e = new InExp(loc, e, e2);
                continue;

            default:
                break;
            }
            break;
        }
        return e;
    }

    Expression parseEqualExp()
    {
        Expression e;
        Expression e2;
        Loc loc;

        loc = currentline;
        e = parseRelExp();
        for(;; )
        {
            Opcode ircode;
            auto op = token.value;

            switch(op)
            {
            case Tok.Equal:       ircode = Opcode.CEq;        goto L1;
            case Tok.Notequal:    ircode = Opcode.CNE;        goto L1;
            case Tok.Identity:    ircode = Opcode.CID;        goto L1;
            case Tok.Nonidentity: ircode = Opcode.CNID;       goto L1;

                L1:
                nextToken();
                e2 = parseRelExp();
                e = new CmpExp(loc, op, ircode, e, e2);
                continue;

            default:
                break;
            }
            break;
        }
        return e;
    }

    Expression parseAndExp()
    {
        Expression e;
        Expression e2;
        Loc loc;

        loc = currentline;
        e = parseEqualExp();
        while(token.value == Tok.And)
        {
            nextToken();
            e2 = parseEqualExp();
            e = new XBinExp(loc, Tok.And, Opcode.And, e, e2);
        }
        return e;
    }

    Expression parseXorExp()
    {
        Expression e;
        Expression e2;
        Loc loc;

        loc = currentline;
        e = parseAndExp();
        while(token.value == Tok.Xor)
        {
            nextToken();
            e2 = parseAndExp();
            e = new XBinExp(loc, Tok.Xor, Opcode.Xor, e, e2);
        }
        return e;
    }

    Expression parseOrExp()
    {
        Expression e;
        Expression e2;
        Loc loc;

        loc = currentline;
        e = parseXorExp();
        while(token.value == Tok.Or)
        {
            nextToken();
            e2 = parseXorExp();
            e = new XBinExp(loc, Tok.Or, Opcode.Or, e, e2);
        }
        return e;
    }

    Expression parseAndAndExp()
    {
        Expression e;
        Expression e2;
        Loc loc;

        loc = currentline;
        e = parseOrExp();
        while(token.value == Tok.Andand)
        {
            nextToken();
            e2 = parseOrExp();
            e = new AndAndExp(loc, e, e2);
        }
        return e;
    }

    Expression parseOrOrExp()
    {
        Expression e;
        Expression e2;
        Loc loc;

        loc = currentline;
        e = parseAndAndExp();
        while(token.value == Tok.Oror)
        {
            nextToken();
            e2 = parseAndAndExp();
            e = new OrOrExp(loc, e, e2);
        }
        return e;
    }

    Expression parseCondExp()
    {
        Expression e;
        Expression e1;
        Expression e2;
        Loc loc;

        loc = currentline;
        e = parseOrOrExp();
        if(token.value == Tok.Question)
        {
            nextToken();
            e1 = parseAssignExp();
            check(Tok.Colon);
            e2 = parseAssignExp();
            e = new CondExp(loc, e, e1, e2);
        }
        return e;
    }

    Expression parseAssignExp()
    {
        Expression e;
        Expression e2;
        Loc loc;

        loc = currentline;
        e = parseCondExp();
        for(;; )
        {
            Opcode ircode;
            auto op = token.value;

            switch(op)
            {
            case Tok.Assign:
                nextToken();
                e2 = parseAssignExp();
                e = new AssignExp(loc, e, e2);
                continue;

            case Tok.Plusass:
                nextToken();
                e2 = parseAssignExp();
                e = new AddAssignExp(loc, e, e2);
                continue;

            case Tok.Minusass:       ircode = Opcode.Sub;  goto L1;
            case Tok.Multiplyass:    ircode = Opcode.Mul;  goto L1;
            case Tok.Divideass:      ircode = Opcode.Div;  goto L1;
            case Tok.Percentass:     ircode = Opcode.Mod;  goto L1;
            case Tok.Andass:         ircode = Opcode.And;  goto L1;
            case Tok.Orass:          ircode = Opcode.Or;   goto L1;
            case Tok.Xorass:         ircode = Opcode.Xor;  goto L1;
            case Tok.Shiftleftass:   ircode = Opcode.ShL;  goto L1;
            case Tok.Shiftrightass:  ircode = Opcode.ShR;  goto L1;
            case Tok.Ushiftrightass: ircode = Opcode.UShR; goto L1;

                L1: nextToken();
                e2 = parseAssignExp();
                e = new BinAssignExp(loc, op, ircode, e, e2);
                continue;

            default:
                break;
            }
            break;
        }
        return e;
    }

    Expression parseExpression(uint flags = 0)
    {
        Expression e;
        Expression e2;
        Loc loc;
        uint flags_save;

        //writefln("Parser.parseExpression()");
        flags_save = this.flags;
        this.flags = flags;
        loc = currentline;
        e = parseAssignExp();
        while(token.value == Tok.Comma)
        {
            nextToken();
            e2 = parseAssignExp();
            e = new CommaExp(loc, e, e2);
        }
        this.flags = flags_save;
        return e;
    }
}

/********************************* ***************************/

