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

/* Lexical Analyzer
 */

module dmdscript.lexer;

import std.ascii :
    isoctal = isOctalDigit,
    isasciidigit = isDigit,
    isasciilower = isLower,
    isasciiupper = isUpper,
    ishex = isHexDigit;

import dmdscript.script;
import dmdscript.text;
import dmdscript.identifier;
import dmdscript.scopex;
import dmdscript.errmsgs;

debug import std.stdio;

/* Tokens:
        (	)
        [	]
        {	}
        <	>	<=	>=	==	!=
        ===     !==
        <<	>>	<<=	>>=	>>>	>>>=
 +	-	+=	-=
 *	/	%	*=	/=	%=
        &	|   ^	&=	|=	^=
        =	!	~
 ++	--
        .	:	,
        ?	&&	||
 */

enum Tok : int
{
    reserved,

    // Other
    Lparen, Rparen,
    Lbracket, Rbracket,
    Lbrace, Rbrace,
    Colon, Neg,
    Pos,
    Semicolon, Eof,
    Array, Call,
    Arraylit, Objectlit,
    Comma, Assert,

    // Operators
    Less, Greater,
    Lessequal, Greaterequal,
    Equal, Notequal,
    Identity, Nonidentity,
    Shiftleft, Shiftright,
    Shiftleftass, Shiftrightass,
    Ushiftright, Ushiftrightass,
    Plus, Minus, Plusass, Minusass,
    Multiply, Divide, Percent,
    Multiplyass, Divideass, Percentass,
    And, Or, Xor,
    Andass, Orass, Xorass,
    Assign, Not, Tilde,
    Plusplus, Minusminus, Dot,
    Question, Andand, Oror,

    // Leaf operators
    Number, Identifier, String,
    Regexp, Real,

    // Keywords
    Break, Case, Continue,
    Default, Delete, Do,
    Else, Export, False,
    For, Function, If,
    Import, In, New,
    Null, Return,
    Switch, This, True,
    Typeof, Var, Void,
    While, With,

    // Reserved for ECMA extensions
    Catch, Class,
    Const, Debugger,
    Enum, Extends,
    Finally, Super,
    Throw, Try,

    // Java keywords reserved for unknown reasons
    Abstract, Boolean,
    Byte, Char,
    Double, Final,
    Float, Goto,
    Implements, Instanceof,
    Int, Interface,
    Long, Native,
    Package, Private,
    Protected, Public,
    Short, Static,
    Synchronized,
    Transient,
}

/******************************************************/

struct Token
{
    private Token* next;
    // pointer to first character of this token within buffer
    immutable(tchar)* ptr;
    uint   linnum;
    Tok    value;
    // where we saw the last line terminator
    immutable(tchar)* sawLineTerminator;
    union
    {
        number_t    intvalue;
        real_t      realvalue;
        d_string    str;
        Identifier* ident;
    };

    // static d_string[Tok.max+1] tochars;
    // alias tochars = ._tochars;

    debug void print()
    {
        writefln(toString());
    }

    d_string toString()
    {
        import std.conv : to;

        d_string p;

        switch(value)
        {
        case Tok.Number:
            p = intvalue.to!d_string;
            break;

        case Tok.Real:
            long l = cast(long)realvalue;
            if(l == realvalue)
                p = l.to!d_string;
            else
                p = realvalue.to!d_string;
            break;

        case Tok.String:
        case Tok.Regexp:
            p = str;
            break;

        case Tok.Identifier:
            p = ident.toString;
            break;

        default:
            p = toString(value);
            break;
        }
        return p;
    }

    alias toString = .tochars;
}

/*******************************************************************/

class Lexer
{
    import std.outbuffer : OutBuffer;

    private Identifier[d_string] stringtable;
    private Token* freelist;

    private d_string sourcename;        // for error message strings

    private d_string base;              // pointer to start of buffer
    private immutable(char)* end;      // past end of buffer
    private immutable(char)* p;        // current character
    uint currentline;
    Token token;
    private OutBuffer stringbuffer;
    private int useStringtable;         // use for Identifiers

    ErrInfo errinfo;            // syntax error information


    private Token* allocToken()
    {
        Token* t;

        if(freelist)
        {
            t = freelist;
            freelist = t.next;
            return t;
        }

        return new Token();
    }


    this(d_string sourcename, d_string base, int useStringtable)
    {
        //writefln("Lexer::Lexer(base = '%s')\n",base);

        this.useStringtable = useStringtable;
        this.sourcename = sourcename;
        if(base.length == 0 || (base[$ - 1] != '\0' && base[$ - 1] != 0x1A))
            base ~= cast(tchar)0x1A;
        this.base = base;
        this.end = base.ptr + base.length;
        p = base.ptr;
        currentline = 1;
        freelist = null;
    }

    dchar get(immutable(tchar)* p)
    {
        import std.utf : decode;
        assert(base.ptr <= p && p < base.ptr + base.length);
        size_t idx = p - base.ptr;
        return decode(base, idx);
    }

    immutable(tchar)* inc(immutable(tchar) * p)
    {
        import std.utf : stride;
        assert(base.ptr <= p && p < base.ptr + base.length);
        size_t idx = p - base.ptr;
        return base.ptr + idx + stride(base, idx);
    }

    void error(ARGS...)(string fmt, ARGS args)
    {
        import std.format : format;

        if(!errinfo.message)
        {
            errinfo.message = format(fmt, args);
            errinfo.sourcename = sourcename;
            errinfo.source = base;
            errinfo.pos = p;
        }

        // Consume input until the end
        assert(base.ptr < end);
        p = end - 1;

        token.next = null;              // dump any lookahead

        debug throw new Exception(errinfo.toString);
    }

    Tok nextToken()
    {
        Token* t;

        if(token.next)
        {
            t = token.next;
            token = *t;
            t.next = freelist;
            freelist = t;
        }
        else
        {
            scan(&token);
        }
        return token.value;
    }

    Token* peek(Token* ct)
    {
        Token* t;

        if(ct.next)
            t = ct.next;
        else
        {
            t = allocToken();
            scan(t);
            t.next = null;
            ct.next = t;
        }
        return t;
    }

    void insertSemicolon(immutable(tchar)* loc)
    {
        // Push current token back into the input, and
        // create a new current token that is a semicolon
        Token *t;

        t = allocToken();
        *t = token;
        token.next = t;
        token.value = Tok.Semicolon;
        token.ptr = loc;
        token.sawLineTerminator = null;
    }

    /**********************************
     * Horrible kludge to support disambiguating TOKregexp from TOKdivide.
     * The idea is, if we are looking for a TOKdivide, and find instead
     * a TOKregexp, we back up and rescan.
     */

    void rescan()
    {
        token.next = null;      // no lookahead
        // should put on freelist
        p = token.ptr + 1;
    }


    /****************************
     * Turn next token in buffer into a token.
     */

    void scan(Token* t)
    {
        import std.ascii : isAlphaNum, isDigit, isPrintable;
        import std.algorithm : startsWith;
        import std.range : popFront;
        import std.traits : Unqual, ForeachType;
        import std.uni : isAlpha;
        import std.utf : encode;

        tchar c;
        dchar d;
        d_string id;
        Unqual!(ForeachType!d_string)[] buf;

        //writefln("Lexer.scan()");
        t.sawLineTerminator = null;
        for(;; )
        {
            t.ptr = p;
            //t.linnum = currentline;
            //writefln("p = %x",cast(uint)p);
            //writefln("p = %x, *p = x%02x, '%s'",cast(uint)p,*p,*p);
            switch(*p)
            {
            case 0:
            case 0x1A:
                t.value = Tok.Eof;               // end of file
                return;

            case ' ':
            case '\t':
            case '\v':
            case '\f':
            case 0xA0:                          // no-break space
                p++;
                continue;                       // skip white space

            case '\n':                          // line terminator
                currentline++;
                goto case;
            case '\r':
                t.sawLineTerminator = p;
                p++;
                continue;

            case '"':
            case '\'':
                t.str = chompString(*p);
                t.value = Tok.String;
                return;

            case '0':       case '1':   case '2':   case '3':   case '4':
            case '5':       case '6':   case '7':   case '8':   case '9':
                t.value = number(t);
                return;

            case 'a':       case 'b':   case 'c':   case 'd':   case 'e':
            case 'f':       case 'g':   case 'h':   case 'i':   case 'j':
            case 'k':       case 'l':   case 'm':   case 'n':   case 'o':
            case 'p':       case 'q':   case 'r':   case 's':   case 't':
            case 'u':       case 'v':   case 'w':   case 'x':   case 'y':
            case 'z':
            case 'A':       case 'B':   case 'C':   case 'D':   case 'E':
            case 'F':       case 'G':   case 'H':   case 'I':   case 'J':
            case 'K':       case 'L':   case 'M':   case 'N':   case 'O':
            case 'P':       case 'Q':   case 'R':   case 'S':   case 'T':
            case 'U':       case 'V':   case 'W':   case 'X':   case 'Y':
            case 'Z':
            case '_':
            case '$':
                Lidentifier:
                {
                  id = null;

                  static bool isidletter(dchar d)
                  {
                      return isAlphaNum(d) || d == '_' || d == '$' || (d >= 0x80 && isAlpha(d));
                  }

                  do
                  {
                      p = inc(p);
                      d = get(p);
                      if(d == '\\' && p[1] == 'u')
                      {
                          Lidentifier2:
                          id = t.ptr[0 .. p - t.ptr].idup;
                          auto ps = p;
                          p++;
                          d = unicode();
                          if(!isidletter(d))
                          {
                              p = ps;
                              break;
                          }
                          buf = null;
                          encode(buf, d);
                          id ~= buf;
                          for(;; )
                          {
                              d = get(p);
                              if(d == '\\' && p[1] == 'u')
                              {
                                  auto pstart = p;
                                  p++;
                                  d = unicode();
                                  if(isidletter(d))
                                  {
                                      buf = null;
                                      encode(buf, d);
                                      id ~= buf;
                                  }
                                  else
                                  {
                                      p = pstart;
                                      goto Lidentifier3;
                                  }
                              }
                              else if(isidletter(d))
                              {
                                  buf = null;
                                  encode(buf, d);
                                  id ~= buf;
                                  p = inc(p);
                              }
                              else
                                  goto Lidentifier3;
                          }
                      }
                  } while(isidletter(d));
                  id = t.ptr[0 .. p - t.ptr];
                  Lidentifier3:
                  //printf("id = '%.*s'\n", id);
                  t.value = isKeyword(id);
                  if(t.value)
                      return;
                  if(useStringtable)
                  {     //Identifier* i = &stringtable[id];
                      Identifier* i = id in stringtable;
                      if(!i)
                      {
                          stringtable[id] = Identifier.init;
                          i = id in stringtable;
                      }
                      i.value.putVstring(id);
                      i.value.toHash();
                      t.ident = i;
                  }
                  else
                      t.ident = Identifier.build(id);
                  t.value = Tok.Identifier;
                  return; }

            case '/':
                p++;
                c = *p;
                if(c == '=')
                {
                    p++;
                    t.value = Tok.Divideass;
                    return;
                }
                else if(c == '*')
                {
                    p++;
                    for(;; p++)
                    {
                        c = *p;
                        Lcomment:
                        switch(c)
                        {
                        case '*':
                            p++;
                            c = *p;
                            if(c == '/')
                            {
                                p++;
                                break;
                            }
                            goto Lcomment;

                        case '\n':
                            currentline++;
                            goto case;
                        case '\r':
                            t.sawLineTerminator = p;
                            continue;

                        case 0:
                        case 0x1A:
                            error(Err.BadCComment);
                            t.value = Tok.Eof;
                            return;

                        default:
                            continue;
                        }
                        break;
                    }
                    continue;
                }
                else if(c == '/')
                {
                    auto r = p[0..end-p];
                    uint j;
                    do{
                        r.popFront();
                        j = startsWith(r,'\n','\r','\0',0x1A,'\u2028','\u2029');
                    }while(!j);
                    p = &r[0];
                    switch(j){
                        case 1:
                            currentline++;
                            goto case;
                        case 2: case 5: case 6:
                            t.sawLineTerminator = p;
                            break;
                        case 3: case 4:
                            t.value = Tok.Eof;
                            return;
                        default:
                            assert(0);
                    }
                    p = inc(p);
                    continue;
                    /*for(;; )
                    {
                        p++;
                        switch(*p)
                        {
                        case '\n':
                            currentline++;
                        case '\r':
                            t.sawLineTerminator = p;
                            break;

                        case 0:
                        case 0x1A:                              // end of file
                            t.value = TOKeof;
                            return;

                        default:
                            continue;
                        }
                        break;
                    }
                    p++;
                    continue;*/
                }
                else if((t.str = regexp()) != null)
                    t.value = Tok.Regexp;
                else
                    t.value = Tok.Divide;
                return;

            case '.':
                immutable(tchar) * q;
                q = p + 1;
                c = *q;
                if(isDigit(c))
                    t.value = number(t);
                else
                {
                    t.value = Tok.Dot;
                    p = q;
                }
                return;

            case '&':
                p++;
                c = *p;
                if(c == '=')
                {
                    p++;
                    t.value = Tok.Andass;
                }
                else if(c == '&')
                {
                    p++;
                    t.value = Tok.Andand;
                }
                else
                    t.value = Tok.And;
                return;

            case '|':
                p++;
                c = *p;
                if(c == '=')
                {
                    p++;
                    t.value = Tok.Orass;
                }
                else if(c == '|')
                {
                    p++;
                    t.value = Tok.Oror;
                }
                else
                    t.value = Tok.Or;
                return;

            case '-':
                p++;
                c = *p;
                if(c == '=')
                {
                    p++;
                    t.value = Tok.Minusass;
                }
                else if(c == '-')
                {
                    p++;

                    // If the last token in the file is -. then
                    // treat it as EOF. This is to accept broken
                    // scripts that forgot to protect the closing -.
                    // with a // comment.
                    if(*p == '>')
                    {
                        // Scan ahead to see if it's the last token
                        immutable(tchar) * q;

                        q = p;
                        for(;; )
                        {
                            switch(*++q)
                            {
                            case 0:
                            case 0x1A:
                                t.value = Tok.Eof;
                                p = q;
                                return;

                            case ' ':
                            case '\t':
                            case '\v':
                            case '\f':
                            case '\n':
                            case '\r':
                            case 0xA0:                  // no-break space
                                continue;

                            default:
                                assert(0);
                            }
                        }
                    }
                    t.value = Tok.Minusminus;
                }
                else
                    t.value = Tok.Minus;
                return;

            case '+':
                p++;
                c = *p;
                if(c == '=')
                {
                    p++;
                    t.value = Tok.Plusass;
                }
                else if(c == '+')
                {
                    p++;
                    t.value = Tok.Plusplus;
                }
                else
                    t.value = Tok.Plus;
                return;

            case '<':
                p++;
                c = *p;
                if(c == '=')
                {
                    p++;
                    t.value = Tok.Lessequal;
                }
                else if(c == '<')
                {
                    p++;
                    c = *p;
                    if(c == '=')
                    {
                        p++;
                        t.value = Tok.Shiftleftass;
                    }
                    else
                        t.value = Tok.Shiftleft;
                }
                else if(c == '!' && p[1] == '-' && p[2] == '-')
                {       // Special comment to end of line
                    p += 2;
                    for(;; )
                    {
                        p++;
                        switch(*p)
                        {
                        case '\n':
                            currentline++;
                            goto case;
                        case '\r':
                            t.sawLineTerminator = p;
                            break;

                        case 0:
                        case 0x1A:                              // end of file
                            error(Err.BadHTMLComment);
                            t.value = Tok.Eof;
                            return;

                        default:
                            continue;
                        }
                        break;
                    }
                    p++;
                    continue;
                }
                else
                    t.value = Tok.Less;
                return;

            case '>':
                p++;
                c = *p;
                if(c == '=')
                {
                    p++;
                    t.value = Tok.Greaterequal;
                }
                else if(c == '>')
                {
                    p++;
                    c = *p;
                    if(c == '=')
                    {
                        p++;
                        t.value = Tok.Shiftrightass;
                    }
                    else if(c == '>')
                    {
                        p++;
                        c = *p;
                        if(c == '=')
                        {
                            p++;
                            t.value = Tok.Ushiftrightass;
                        }
                        else
                            t.value = Tok.Ushiftright;
                    }
                    else
                        t.value = Tok.Shiftright;
                }
                else
                    t.value = Tok.Greater;
                return;

            case '(': p++; t.value = Tok.Lparen;    return;
            case ')': p++; t.value = Tok.Rparen;    return;
            case '[': p++; t.value = Tok.Lbracket;  return;
            case ']': p++; t.value = Tok.Rbracket;  return;
            case '{': p++; t.value = Tok.Lbrace;    return;
            case '}': p++; t.value = Tok.Rbrace;    return;
            case '~': p++; t.value = Tok.Tilde;     return;
            case '?': p++; t.value = Tok.Question;  return;
            case ',': p++; t.value = Tok.Comma;     return;
            case ';': p++; t.value = Tok.Semicolon; return;
            case ':': p++; t.value = Tok.Colon;     return;

            case '*':
                p++;
                c = *p;
                if(c == '=')
                {
                    p++;
                    t.value = Tok.Multiplyass;
                }
                else
                    t.value = Tok.Multiply;
                return;

            case '%':
                p++;
                c = *p;
                if(c == '=')
                {
                    p++;
                    t.value = Tok.Percentass;
                }
                else
                    t.value = Tok.Percent;
                return;

            case '^':
                p++;
                c = *p;
                if(c == '=')
                {
                    p++;
                    t.value = Tok.Xorass;
                }
                else
                    t.value = Tok.Xor;
                return;

            case '=':
                p++;
                c = *p;
                if(c == '=')
                {
                    p++;
                    c = *p;
                    if(c == '=')
                    {
                        p++;
                        t.value = Tok.Identity;
                    }
                    else
                        t.value = Tok.Equal;
                }
                else
                    t.value = Tok.Assign;
                return;

            case '!':
                p++;
                c = *p;
                if(c == '=')
                {
                    p++;
                    c = *p;
                    if(c == '=')
                    {
                        p++;
                        t.value = Tok.Nonidentity;
                    }
                    else
                        t.value = Tok.Notequal;
                }
                else
                    t.value = Tok.Not;
                return;

            case '\\':
                if(p[1] == 'u')
                {
                    // \uXXXX starts an identifier
                    goto Lidentifier2;
                }
                goto default;
            default:
                d = get(p);
                if(d >= 0x80 && isAlpha(d))
                    goto Lidentifier;
                else if(isStrWhiteSpaceChar(d))
                {
                    p = inc(p);            //also skip unicode whitespace
                    continue;
                }
                else
                {
                    if(isPrintable(d))
                        error(Err.BadCharC, d);
                    else
                        error(Err.BadCharX, d);
                }
                continue;
            }
        }
    }

    /*******************************************
     * Parse escape sequence.
     */

    dchar escapeSequence()
    {
        import std.ascii : isDigit, isLower;

        uint c;
        int n;

        c = *p;
        p++;
        switch(c)
        {
        case '\'':
        case '"':
        case '?':
        case '\\':
            break;
        case 'a':
            c = 7;
            break;
        case 'b':
            c = 8;
            break;
        case 'f':
            c = 12;
            break;
        case 'n':
            c = 10;
            break;
        case 'r':
            c = 13;
            break;
        case 't':
            c = 9;
            break;

        case 'v':
            version(JSCRIPT_ESCAPEV_BUG)
            {
            }
            else
            {
                c = 11;
            }
            break;

        case 'x':
            c = *p;
            p++;
            if(ishex(c))
            {
                uint v;

                n = 0;
                v = 0;
                for(;; )
                {
                    if(isDigit(c))
                        c -= '0';
                    else if(isLower(c))
                        c -= 'a' - 10;
                    else            // 'A' <= c && c <= 'Z'
                        c -= 'A' - 10;
                    v = v * 16 + c;
                    c = *p;
                    if(++n >= 2 || !ishex(c))
                        break;
                    p++;
                }
                if(n == 1)
                    error(Err.BadHexSequence);
                c = v;
            }
            else
                error(Err.UndefinedEscSequence, c);
            break;

        default:
            if(c > 0x7F)
            {
                p--;
                c = get(p);
                p = inc(p);
            }
            if(isoctal(c))
            {
                uint v;

                n = 0;
                v = 0;
                for(;; )
                {
                    v = v * 8 + (c - '0');
                    c = *p;
                    if(++n >= 3 || !isoctal(c))
                        break;
                    p++;
                }
                c = v;
            }
            // Don't throw error, just accept it
            //error("undefined escape sequence \\%c\n",c);
            break;
        }
        return c;
    }

    /**************************************
     */

    d_string chompString(tchar quote)
    {
        import std.traits : Unqual, ForeachType;
        import std.exception : assumeUnique;
        import std.utf : encode;

        tchar c;
        dchar d;
        Unqual!(ForeachType!d_string)[] stringbuffer = null;

        //printf("Lexer.string('%c')\n", quote);
        p++;
        for(;; )
        {
            c = *p;
            switch(c)
            {
            case '"':
            case '\'':
                p++;
                if(c == quote)
                    return stringbuffer.assumeUnique;
                break;

            case '\\':
                p++;
                if(*p == 'u')
                    d = unicode();
                else
                    d = escapeSequence();
                encode(stringbuffer, d);
                continue;

            case '\n':
            case '\r':
                p++;
                error(Err.StringNoEndQuote, quote);
                return null;

            case 0:
            case 0x1A:
                error(Err.UnterminatedString);
                return null;

            default:
                p++;
                break;
            }
            stringbuffer ~= c;
        }
        assert(0);
    }

    /**************************************
     * Scan regular expression. Return null with buffer
     * pointer intact if it is not a regexp.
     */

    d_string regexp()
    {
        import std.ascii : isAlphaNum;

        tchar c;
        immutable(tchar) * s;
        immutable(tchar) * start;

        /*
            RegExpLiteral:  RegExpBody RegExpFlags
              RegExpFlags:
                  empty
         |  RegExpFlags ContinuingIdentifierCharacter
              RegExpBody:  / RegExpFirstChar RegExpChars /
              RegExpFirstChar:
                  OrdinaryRegExpFirstChar
         |  \ NonTerminator
              OrdinaryRegExpFirstChar:  NonTerminator except \ | / | *
              RegExpChars:
                  empty
         |  RegExpChars RegExpChar
              RegExpChar:
                  OrdinaryRegExpChar
         |  \ NonTerminator
              OrdinaryRegExpChar: NonTerminator except \ | /
         */

        //writefln("Lexer.regexp()\n");
        start = p - 1;
        s = p;

        // Do RegExpBody
        for(;; )
        {
            c = *s;
            s++;
            switch(c)
            {
            case '\\':
                if(s == p)
                    return null;
                c = *s;
                switch(c)
                {
                case '\r':
                case '\n':                      // new line
                case 0:                         // end of file
                case 0x1A:                      // end of file
                    return null;                // not a regexp
                default:
                    break;
                }
                s++;
                continue;

            case '/':
                if(s == p + 1)
                    return null;
                break;

            case '\r':
            case '\n':                          // new line
            case 0:                             // end of file
            case 0x1A:                          // end of file
                return null;                    // not a regexp

            case '*':
                if(s == p + 1)
                    return null;
                goto default;
            default:
                continue;
            }
            break;
        }

        // Do RegExpFlags
        for(;; )
        {
            c = *s;
            if(isAlphaNum(c) || c == '_' || c == '$')
            {
                s++;
            }
            else
                break;
        }

        // Finish pattern & return it
        p = s;
        return start[0 .. s - start].idup;
    }

    /***************************************
     */

    dchar unicode()
    {
        import std.ascii : isDigit;
        dchar value;
        uint n;
        dchar c;

        value = 0;
        p++;
        for(n = 0; n < 4; n++)
        {
            c = *p;
            if(!ishex(c))
            {
                error(Err.BadUSequence);
                break;
            }
            p++;
            if(isDigit(c))
                c -= '0';
            else if(isasciilower(c))
                c -= 'a' - 10;
            else    // 'A' <= c && c <= 'Z'
                c -= 'A' - 10;
            value <<= 4;
            value |= c;
        }
        return value;
    }

    /********************************************
     * Read a number.
     */

    Tok number(Token *t)
    {
        import std.ascii : isDigit;
        import std.string : toStringz;
        import core.sys.posix.stdlib : strtod;

        immutable(tchar) * start;
        number_t intvalue;
        real realvalue;
        int base = 10;
        tchar c;

        start = p;
        for(;; )
        {
            c = *p;
            p++;
            switch(c)
            {
            case '0':
                // ECMA grammar implies that numbers with leading 0
                // like 015 are illegal. But other scripts allow them.
                if(p - start == 1)              // if leading 0
                    base = 8;
                goto case;
            case '1': case '2': case '3': case '4': case '5':
            case '6': case '7':
                break;

            case '8': case '9':                         // decimal digits
                if(base == 8)                           // and octal base
                    base = 10;                          // means back to decimal base
                break;

            default:
                p--;
                Lnumber:
                if(base == 0)
                    base = 10;
                intvalue = 0;
                foreach(tchar v; start[0 .. p - start])
                {
                    if('0' <= v && v <= '9')
                        v -= '0';
                    else if('a' <= v && v <= 'f')
                        v -= ('a' - 10);
                    else if('A' <= v && v <= 'F')
                        v -= ('A' - 10);
                    else
                        assert(0);
                    assert(v < base);
                    if((number_t.max - v) / base < intvalue)
                    {
                        realvalue = 0;
                        foreach(tchar w; start[0 .. p - start])
                        {
                            if('0' <= w && w <= '9')
                                w -= '0';
                            else if('a' <= w && w <= 'f')
                                w -= ('a' - 10);
                            else if('A' <= w && w <= 'F')
                                w -= ('A' - 10);
                            else
                                assert(0);
                            realvalue *= base;
                            realvalue += v;
                        }
                        t.realvalue = realvalue;
                        return Tok.Real;
                    }
                    intvalue *= base;
                    intvalue += v;
                }
                t.realvalue = cast(double)intvalue;
                return Tok.Real;

            case 'x':
            case 'X':
                if(p - start != 2 || !ishex(*p))
                    goto Lerr;
                do
                    p++;
                while(ishex(*p));
                start += 2;
                base = 16;
                goto Lnumber;

            case '.':
                while(isDigit(*p))
                    p++;
                if(*p == 'e' || *p == 'E')
                {
                    p++;
                    goto Lexponent;
                }
                goto Ldouble;

            case 'e':
            case 'E':
                Lexponent:
                if(*p == '+' || *p == '-')
                    p++;
                if(!isDigit(*p))
                    goto Lerr;
                do
                    p++;
                while(isDigit(*p));
                goto Ldouble;

                Ldouble:
                // convert double
                realvalue = strtod(toStringz(start[0 .. p - start]), null);
                t.realvalue = realvalue;
                return Tok.Real;
            }
        }

        Lerr:
        error(Err.UnrecognizedNLiteral);
        return Tok.Eof;
    }

    static Tok isKeyword(const (tchar)[] s)
    {
        if(s[0] >= 'a' && s[0] <= 'w')
            switch(s.length)
            {
            case 2:
                if(s[0] == 'i')
                {
                    if(s[1] == 'f')
                        return Tok.If;
                    if(s[1] == 'n')
                        return Tok.In;
                }
                else if(s[0] == 'd' && s[1] == 'o')
                    return Tok.Do;
                break;

            case 3:
                switch(s[0])
                {
                case 'f':
                    if(s[1] == 'o' && s[2] == 'r')
                        return Tok.For;
                    break;
                case 'i':
                    if(s[1] == 'n' && s[2] == 't')
                        return Tok.Int;
                    break;
                case 'n':
                    if(s[1] == 'e' && s[2] == 'w')
                        return Tok.New;
                    break;
                case 't':
                    if(s[1] == 'r' && s[2] == 'y')
                        return Tok.Try;
                    break;
                case 'v':
                    if(s[1] == 'a' && s[2] == 'r')
                        return Tok.Var;
                    break;
                default:
                    break;
                }
                break;

            case 4:
                switch(s[0])
                {
                case 'b':
                    if(s[1] == 'y' && s[2] == 't' && s[3] == 'e')
                        return Tok.Byte;
                    break;
                case 'c':
                    if(s[1] == 'a' && s[2] == 's' && s[3] == 'e')
                        return Tok.Case;
                    if(s[1] == 'h' && s[2] == 'a' && s[3] == 'r')
                        return Tok.Char;
                    break;
                case 'e':
                    if(s[1] == 'l' && s[2] == 's' && s[3] == 'e')
                        return Tok.Else;
                    if(s[1] == 'n' && s[2] == 'u' && s[3] == 'm')
                        return Tok.Enum;
                    break;
                case 'g':
                    if(s[1] == 'o' && s[2] == 't' && s[3] == 'o')
                        return Tok.Goto;
                    break;
                case 'l':
                    if(s[1] == 'o' && s[2] == 'n' && s[3] == 'g')
                        return Tok.Long;
                    break;
                case 'n':
                    if(s[1] == 'u' && s[2] == 'l' && s[3] == 'l')
                        return Tok.Null;
                    break;
                case 't':
                    if(s[1] == 'h' && s[2] == 'i' && s[3] == 's')
                        return Tok.This;
                    if(s[1] == 'r' && s[2] == 'u' && s[3] == 'e')
                        return Tok.True;
                    break;
                case 'w':
                    if(s[1] == 'i' && s[2] == 't' && s[3] == 'h')
                        return Tok.With;
                    break;
                case 'v':
                    if(s[1] == 'o' && s[2] == 'i' && s[3] == 'd')
                        return Tok.Void;
                    break;
                default:
                    break;
                }
                break;

            case 5:
                switch(s)
                {
                case "break":               return Tok.Break;
                case "catch":               return Tok.Catch;
                case "class":               return Tok.Class;
                case "const":               return Tok.Const;
                case "false":               return Tok.False;
                case "final":               return Tok.Final;
                case "float":               return Tok.Float;
                case "short":               return Tok.Short;
                case "super":               return Tok.Super;
                case "throw":               return Tok.Throw;
                case "while":               return Tok.While;
                default:
                    break;
                }
                break;

            case 6:
                switch(s)
                {
                case "delete":              return Tok.Delete;
                case "double":              return Tok.Double;
                case "export":              return Tok.Export;
                case "import":              return Tok.Import;
                case "native":              return Tok.Native;
                case "public":              return Tok.Public;
                case "return":              return Tok.Return;
                case "static":              return Tok.Static;
                case "switch":              return Tok.Switch;
                case "typeof":              return Tok.Typeof;
                default:
                    break;
                }
                break;

            case 7:
                switch(s)
                {
                case "boolean":             return Tok.Boolean;
                case "default":             return Tok.Default;
                case "extends":             return Tok.Extends;
                case "finally":             return Tok.Finally;
                case "package":             return Tok.Package;
                case "private":             return Tok.Private;
                default:
                    break;
                }
                break;

            case 8:
                switch(s)
                {
                case "abstract":    return Tok.Abstract;
                case "continue":    return Tok.Continue;
                case "debugger":    return Tok.Debugger;
                case "function":    return Tok.Function;
                default:
                    break;
                }
                break;

            case 9:
                switch(s)
                {
                case "interface":   return Tok.Interface;
                case "protected":   return Tok.Protected;
                case "transient":   return Tok.Transient;
                default:
                    break;
                }
                break;

            case 10:
                switch(s)
                {
                case "implements":  return Tok.Implements;
                case "instanceof":  return Tok.Instanceof;
                default:
                    break;
                }
                break;

            case 12:
                if(s == "synchronized")
                    return Tok.Synchronized;
                break;

            default:
                break;
            }
        return Tok.reserved;             // not a keyword
    }
}


/****************************************
 */
// This function seems that only be called at error handling,
// and for debugging.
private d_string tochars(Tok tok)
{
    import std.conv : to;
    import std.string : toLower;

    switch(tok)
    {
    case Tok.Lbrace: return "{";
    case Tok.Rbrace: return "}";
    case Tok.Lparen: return "(";
    case Tok.Rparen: return "";
    case Tok.Lbracket: return "[";
    case Tok.Rbracket: return "]";
    case Tok.Colon: return ":";
    case Tok.Semicolon: return ";";
    case Tok.Comma: return ",";
    case Tok.Or: return "|";
    case Tok.Orass: return "|=";
    case Tok.Xor: return "^";
    case Tok.Xorass: return "^=";
    case Tok.Assign: return "=";
    case Tok.Less: return "<";
    case Tok.Greater: return ">";
    case Tok.Lessequal: return "<=";
    case Tok.Greaterequal: return ">=";
    case Tok.Equal: return "==";
    case Tok.Notequal: return "!=";
    case Tok.Identity: return "===";
    case Tok.Nonidentity: return "!==";
    case Tok.Shiftleft: return "<<";
    case Tok.Shiftright: return ">>";
    case Tok.Ushiftright: return ">>>";
    case Tok.Plus: return "+";
    case Tok.Plusass: return "+=";
    case Tok.Minus: return "-";
    case Tok.Minusass: return "-=";
    case Tok.Multiply: return "*";
    case Tok.Multiplyass: return "*=";
    case Tok.Divide: return "/";
    case Tok.Divideass: return "/=";
    case Tok.Percent: return "%";
    case Tok.Percentass: return "%=";
    case Tok.And: return "&";
    case Tok.Andass: return "&=";
    case Tok.Dot: return ".";
    case Tok.Question: return "?";
    case Tok.Tilde: return "~";
    case Tok.Not: return "!";
    case Tok.Andand: return "&&";
    case Tok.Oror: return "||";
    case Tok.Plusplus: return "++";
    case Tok.Minusminus: return "--";
    default:
        return tok.to!d_string.toLower;
    }
    assert(0);
}

/+
private enum string[] _tochars =
[
    // Keywords
    Tok.Break: "break",
    Tok.Case: "case",
    Tok.Continue: "continue",
    Tok.Default: "default",
    Tok.Delete: "delete",
    Tok.Do: "do",
    Tok.Else: "else",
    Tok.Export: "export",
    Tok.False: "false",
    Tok.For: "for",
    Tok.Function: "function",
    Tok.If: "if",
    Tok.Import: "import",
    Tok.In: "in",
    Tok.New: "new",
    Tok.Null: "null",
    Tok.Return: "return",
    Tok.Switch: "switch",
    Tok.This: "this",
    Tok.True: "true",
    Tok.Typeof: "typeof",
    Tok.Var: "var",
    Tok.Void: "void",
    Tok.While: "while",
    Tok.With: "with",

    Tok.Catch: "catch",
    Tok.Class: "class",
    Tok.Const: "const",
    Tok.Debugger: "debugger",
    Tok.Enum: "enum",
    Tok.Extends: "extends",
    Tok.Finally: "finally",
    Tok.Super: "super",
    Tok.Throw: "throw",
    Tok.Try: "try",

    Tok.Abstract: "abstract",
    Tok.Boolean: "boolean",
    Tok.Byte: "byte",
    Tok.Char: "char",
    Tok.Double: "double",
    Tok.Final: "final",
    Tok.Float: "float",
    Tok.Goto: "goto",
    Tok.Implements: "implements",
    Tok.Instanceof: "instanceof",
    Tok.Int: "int",
    Tok.Interface: "interface",
    Tok.Long: "long",
    Tok.Native: "native",
    Tok.Package: "package",
    Tok.Private: "private",
    Tok.Protected: "protected",
    Tok.Public: "public",
    Tok.Short: "short",
    Tok.Static: "static",
    Tok.Synchronized: "synchronized",
    Tok.Transient: "transient",

    //
    Tok.reserved: "reserved",
    Tok.Eof: "EOF",
    Tok.Lbrace: "{",
    Tok.Rbrace: "}",
    Tok.Lparen: "(",
    Tok.Rparen: "",
    Tok.Lbracket: "[",
    Tok.Rbracket: "]",
    Tok.Colon: ":",
    Tok.Semicolon: ";",
    Tok.Comma: ",",
    Tok.Or: "|",
    Tok.Orass: "|=",
    Tok.Xor: "^",
    Tok.Xorass: "^=",
    Tok.Assign: "=",
    Tok.Less: "<",
    Tok.Greater: ">",
    Tok.Lessequal: "<=",
    Tok.Greaterequal: ">=",
    Tok.Equal: "==",
    Tok.Notequal: "!=",
    Tok.Identity: "===",
    Tok.Nonidentity: "!==",
    Tok.Shiftleft: "<<",
    Tok.Shiftright: ">>",
    Tok.Ushiftright: ">>>",
    Tok.Plus: "+",
    Tok.Plusass: "+=",
    Tok.Minus: "-",
    Tok.Minusass: "-=",
    Tok.Multiply: "*",
    Tok.Multiplyass: "*=",
    Tok.Divide: "/",
    Tok.Divideass: "/=",
    Tok.Percent: "%",
    Tok.Percentass: "%=",
    Tok.And: "&",
    Tok.Andass: "&=",
    Tok.Dot: ".",
    Tok.Question: "?",
    Tok.Tilde: "~",
    Tok.Not: "!",
    Tok.Andand: "&&",
    Tok.Oror: "||",
    Tok.Plusplus: "++",
    Tok.Minusminus: "--",
    Tok.Call: "CALL",
];
debug static assert(_tochars.length == Tok.max+1);
+/
