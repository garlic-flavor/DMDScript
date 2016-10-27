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

module dmdscript.value;

import std.math;
import std.string;
import std.stdio;
import std.conv;
import core.stdc.string;

import dmdscript.script;
import dmdscript.dobject;
import dmdscript.iterator;
import dmdscript.identifier;
import dmdscript.errmsgs;
import dmdscript.text;
import dmdscript.program;
import dmdscript.dstring;
import dmdscript.dnumber;
import dmdscript.dboolean;

// Porting issues:
// A lot of scaling is done on arrays of Value's. Therefore, adjusting
// it to come out to a size of 16 bytes makes the scaling an efficient
// operation. In fact, in some cases (opcodes.c) we prescale the addressing
// by 16 bytes at compile time instead of runtime.
// So, Value must be looked at in any port to verify that:
// 1) the size comes out as 16 bytes, padding as necessary
// 2) Value::copy() copies the used data bytes, NOT the padding.
//    It's faster to not copy the padding, and the
//    padding can contain garbage stack pointers which can
//    prevent memory from being garbage collected.

version(DigitalMars)
    version(D_InlineAsm)
        version = UseAsm;

enum
{
    V_REF_ERROR = 0,//triggers ReferenceError expcetion when accessed
    V_UNDEFINED = 1,
    V_NULL      = 2,
    V_BOOLEAN   = 3,
    V_NUMBER    = 4,
    V_STRING    = 5,
    V_OBJECT    = 6,
    V_ITER      = 7,
}

struct Value
{
    uint  hash;                 // cache 'hash' value
    ubyte vtype = V_UNDEFINED;
    union
    {
        d_boolean dbool;        // can be true or false
        d_number  number;
        d_string  text;
        Dobject   object;
        d_int32   int32;
        d_uint32  uint32;
        d_uint16  uint16;

        Iterator* iter;         // V_ITER
    }
    void checkReference(){
        if(vtype == V_REF_ERROR)
            throwRefError();
    }
    void throwRefError() const{
        throw new ErrorValue(Dobject.ReferenceError(errmsgtbl[ERR_UNDEFINED_VAR], text));
    }
    
    void putSignalingUndefined(d_string id){
        vtype = V_REF_ERROR;
        text = id;
    }
    void putVundefined()
    {
        vtype = V_UNDEFINED;
        hash = 0;
        text = null;
    }

    void putVnull()
    {
        vtype = V_NULL;
    }

    void putVboolean(d_boolean b)
    in
    {
        assert(b == 1 || b == 0);
    }
    body
    { vtype = V_BOOLEAN;
      dbool = b; }

    void putVnumber(d_number n)
    {
        vtype = V_NUMBER;
        number = n;
    }

    void putVtime(d_time n)
    {
        vtype = V_NUMBER;
        number = (n == d_time_nan) ? d_number.nan : n;
    }

    void putVstring(d_string s)
    {
        vtype = V_STRING;
        hash = 0;
        text = s;
    }

    void putVstring(d_string s, uint hash)
    {
        vtype = V_STRING;
        this.hash = hash;
        this.text = s;
    }

    void putVobject(Dobject o)
    {
        vtype = V_OBJECT;
        object = o;
    }

    void putViterator(Iterator* i)
    {
        vtype = V_ITER;
        iter = i;
    }

    invariant()
    {
/+
        switch (vtype)
        {
            case V_UNDEFINED:
            case V_NULL:
                break;
            case V_BOOLEAN:
                assert(dbool == 1 || dbool == 0);
                break;
            case V_NUMBER:
            case V_STRING:
            case V_OBJECT:
            case V_ITER:
                break;
            case V_NONE:
                break;
            default:
                writefln("vtype = %d", vtype);
                assert(0);
                break;
        }
 +/
    }

    static void copy(Value* to, Value* from)
    in { }
    out { assert(memcmp(to, from, Value.sizeof) == 0); }
    body
 
    {
        /+version(all /*UseAsm*/)
        {
            asm
            { naked;
              push ESI;
              mov ECX, [EAX];
              mov ESI, 8[ESP];
              mov     [ESI], ECX;
              mov EDX, 4[EAX];
              mov ECX, 8[EAX];
              mov EAX, 12[EAX];
              mov     4[ESI], EDX;
              mov     8[ESI], ECX;
              mov     12[ESI], EAX;
              pop ESI;
              ret     4; }
        }
        else+/
        {
            *to = *from;
            //(cast(uint *)to)[0] = (cast(uint *)from)[0];
            //(cast(uint *)to)[1] = (cast(uint *)from)[1];
            //(cast(uint *)to)[2] = (cast(uint *)from)[2];
            //(cast(uint *)to)[3] = (cast(uint *)from)[3];
        }
    }

    void* toPrimitive(Value* v, d_string PreferredType)
    {
        if(vtype == V_OBJECT)
        {
            /*	ECMA 9.1
                Return a default value for the Object.
                The default value of an object is retrieved by
                calling the internal [[DefaultValue]] method
                of the object, passing the optional hint
                PreferredType. The behavior of the [[DefaultValue]]
                method is defined by this specification for all
                native ECMAScript objects (see section 8.6.2.6).
                If the return value is of type Object or Reference,
                a runtime error is generated.
             */
            void* a;

            assert(object);
            a = object.DefaultValue(v, PreferredType);
            if(a)
                throw new ErrorValue(cast(Value*)a);
            if(!v.isPrimitive())
            {
                ErrInfo errinfo;

                v.putVundefined();
                throw new ErrorValue(Dobject.RuntimeError(&errinfo, errmsgtbl[ERR_OBJECT_CANNOT_BE_PRIMITIVE]));
            }
        }
        else
        {
            copy(v, &this);
        }
        return null;
    }


    d_boolean toBoolean()
    {
        switch(vtype)
        {
        case V_REF_ERROR:
            throwRefError();
            assert(0);
        case V_UNDEFINED:
        case V_NULL:
            return false;
        case V_BOOLEAN:
            return dbool;
        case V_NUMBER:
            return !(number == 0.0 || isNaN(number));
        case V_STRING:
            return text.length ? true : false;
        case V_OBJECT:
            return true;
        default:
            assert(0);
        }
        assert(0);
    }


    d_number toNumber()
    {
        switch(vtype)
        {
        case V_REF_ERROR:
            throwRefError();
            assert(0);
        case V_UNDEFINED:
            return d_number.nan;
        case V_NULL:
            return 0;
        case V_BOOLEAN:
            return dbool ? 1 : 0;
        case V_NUMBER:
            return number;
        case V_STRING:
        {
            d_number n;
            size_t len;
            size_t endidx;

            len = text.length;
            n = StringNumericLiteral(text, endidx, 0);

            // Consume trailing whitespace
            //writefln("n = %s, string = '%s', endidx = %s, length = %s", n, string, endidx, string.length);
            foreach(dchar c; text[endidx .. $])
            {
                if(!isStrWhiteSpaceChar(c))
                {
                    n = d_number.nan;
                    break;
                }
            }

            return n;
        }
        case V_OBJECT:
        { Value val;
          Value* v;
          void* a;

          //writefln("Vobject.toNumber()");
          v = &val;
          a = toPrimitive(v, TypeNumber);
          /*if(a)//rerr
                  return d_number.nan;*/
          if(v.isPrimitive())
              return v.toNumber();
          else
              return d_number.nan;
        }
        default:
            assert(0);
        }
        assert(0);
    }


    d_time toDtime()
    {
        return cast(d_time)toNumber();
    }


    d_number toInteger()
    {
        switch(vtype)
        {
        case V_REF_ERROR:
            throwRefError();
            assert(0);
        case V_UNDEFINED:
            return d_number.nan;
        case V_NULL:
            return 0;
        case V_BOOLEAN:
            return dbool ? 1 : 0;

        default:
        { d_number number;

          number = toNumber();
          if(isNaN(number))
              number = 0;
          else if(number == 0 || std.math.isinf(number))
          {
          }
          else if(number > 0)
              number = std.math.floor(number);
          else
              number = -std.math.floor(-number);
          return number; }
        }
        assert(0);
    }


    d_int32 toInt32()
    {
        switch(vtype)
        {
        case V_REF_ERROR:
            throwRefError();
            assert(0);
        case V_UNDEFINED:
        case V_NULL:
            return 0;
        case V_BOOLEAN:
            return dbool ? 1 : 0;

        default:
        { d_int32 int32;
          d_number number;
          long ll;

          number = toNumber();
          if(isNaN(number))
              int32 = 0;
          else if(number == 0 || std.math.isinf(number))
              int32 = 0;
          else
          {
              if(number > 0)
                  number = std.math.floor(number);
              else
                  number = -std.math.floor(-number);

              ll = cast(long)number;
              int32 = cast(int)ll;
          }
          return int32; }
        }
        assert(0);
    }


    d_uint32 toUint32()
    {
        switch(vtype)
        {
        case V_REF_ERROR:
            throwRefError();
            assert(0);
        case V_UNDEFINED:
        case V_NULL:
            return 0;
        case V_BOOLEAN:
            return dbool ? 1 : 0;

        default:
        { d_uint32 uint32;
          d_number number;
          long ll;

          number = toNumber();
          if(isNaN(number))
              uint32 = 0;
          else if(number == 0 || std.math.isinf(number))
              uint32 = 0;
          else
          {
              if(number > 0)
                  number = std.math.floor(number);
              else
                  number = -std.math.floor(-number);

              ll = cast(long)number;
              uint32 = cast(uint)ll;
          }
          return uint32; }
        }
        assert(0);
    }

    d_uint16 toUint16()
    {
        switch(vtype)
        {
        case V_REF_ERROR:
            throwRefError();
            assert(0);
        case V_UNDEFINED:
        case V_NULL:
            return 0;
        case V_BOOLEAN:
            return cast(d_uint16)(dbool ? 1 : 0);

        default:
        { d_uint16 uint16;
          d_number number;

          number = toNumber();
          if(isNaN(number))
              uint16 = 0;
          else if(number == 0 || std.math.isinf(number))
              uint16 = 0;
          else
          {
              if(number > 0)
                  number = std.math.floor(number);
              else
                  number = -std.math.floor(-number);

              uint16 = cast(ushort)number;
          }
          return uint16; }
        }
        assert(0);
    }

    d_string toString()
    {
        switch(vtype)
        {
        case V_REF_ERROR:
            throwRefError();
            assert(0);
        case V_UNDEFINED:
            return TEXT_undefined;
        case V_NULL:
            return TEXT_null;
        case V_BOOLEAN:
            return dbool ? TEXT_true : TEXT_false;
        case V_NUMBER:
        { d_string str;
          static enum d_string[10]  strs =
          [   TEXT_0, TEXT_1, TEXT_2, TEXT_3, TEXT_4,
                      TEXT_5, TEXT_6, TEXT_7, TEXT_8, TEXT_9 ];

          //writefln("Vnumber.tostr(%g)", number);
          if(isNaN(number))
              str = TEXT_NaN;
          else if(number >= 0 && number <= 9 && number == cast(int)number)
              str = strs[cast(int)number];
          else if(std.math.isinf(number))
          {
              if(number < 0)
                  str = TEXT_negInfinity;
              else
                  str = TEXT_Infinity;
          }
          else
          {
              tchar[100] buffer;                // should shrink this to max size,
                                                // but doesn't really matter
              tchar* p;

              // ECMA 262 requires %.21g (21 digits) of precision. But, the
              // C runtime library doesn't handle that. Until the C runtime
              // library is upgraded to ANSI C 99 conformance, use
              // 16 digits, which is all the GCC library will round correctly.

              std.string.sformat(buffer, "%.16g\0", number);
              //std.c.stdio.sprintf(buffer.ptr, "%.16g", number);

              // Trim leading spaces
              for(p = buffer.ptr; *p == ' '; p++)
              {
              }


              {             // Trim any 0's following exponent 'e'
                  tchar* q;
                  tchar* t;

                  for(q = p; *q; q++)
                  {
                      if(*q == 'e')
                      {
                          q++;
                          if(*q == '+' || *q == '-')
                              q++;
                          t = q;
                          while(*q == '0')
                              q++;
                          if(t != q)
                          {
                              for(;; )
                              {
                                  *t = *q;
                                  if(*t == 0)
                                      break;
                                  t++;
                                  q++;
                              }
                          }
                          break;
                      }
                  }
              }
              str = p[0 .. core.stdc.string.strlen(p)].idup;
          }
          //writefln("str = '%s'", str);
          return str; }
        case V_STRING:
            return text;
        case V_OBJECT:
        { Value val;
          Value* v = &val;
          void* a;

          //writef("Vobject.toString()\n");
          a = toPrimitive(v, TypeString);
          //assert(!a);
          if(v.isPrimitive())
              return v.toString();
          else
              return v.toObject().classname;
        }
        default:
            assert(0);
        }
        assert(0);
    }

    d_string toLocaleString()
    {
        return toString();
    }

    d_string toString(int radix)
    {
        if(vtype == V_NUMBER)
        {
            assert(2 <= radix && radix <= 36);
            if(!isFinite(number))
                return toString();
            return number >= 0.0 ? std.conv.to!(d_string)(cast(long)number, radix) : "-"~std.conv.to!(d_string)(cast(long)-number,radix);
        }
        else
        {
            return toString();
        }
    }

    d_string toSource()
    {
        switch(vtype)
        {
        case V_STRING:
        { d_string s;

          s = "\"" ~ text ~ "\"";
          return s; }
        case V_OBJECT:
        { Value* v;

          //writefln("Vobject.toSource()");
          v = Get(TEXT_toSource);
          if(!v)
              v = &vundefined;
          if(v.isPrimitive())
              return v.toSource();
          else          // it's an Object
          {
              void* a;
              CallContext *cc;
              Dobject o;
              Value* ret;
              Value val;

              o = v.object;
              cc = Program.getProgram().callcontext;
              ret = &val;
              a = o.Call(cc, this.object, ret, null);
              if(a)                             // if exception was thrown
              {
                  /*return a;*/
                  debug writef("Vobject.toSource() failed with %x\n", a);
              }
              else if(ret.isPrimitive())
                  return ret.toString();
          }
          return TEXT_undefined; }
        default:
            return toString();
        }
        assert(0);
    }

    Dobject toObject()
    {
        switch(vtype)
        {
        case V_REF_ERROR:
            throwRefError();
            assert(0);
        case V_UNDEFINED:
            //RuntimeErrorx("cannot convert undefined to Object");
            return null;
        case V_NULL:
            //RuntimeErrorx("cannot convert null to Object");
            return null;
        case V_BOOLEAN:
            return new Dboolean(dbool);
        case V_NUMBER:
            return new Dnumber(number);
        case V_STRING:
            return new Dstring(text);
        case V_OBJECT:
            return object;
        default:
            assert(0);
        }
        assert(0);
    }

    const bool opEquals(ref const (Value)v)
    {
        return(opCmp(v) == 0);
    }

    /*********************************
     * Use this instead of std.string.cmp() because
     * we don't care about lexicographic ordering.
     * This is faster.
     */

    static int stringcmp(d_string s1, d_string s2)
    {
        int c = s1.length - s2.length;
        if(c == 0)
        {
            if(s1.ptr == s2.ptr)
                return 0;
            c = memcmp(s1.ptr, s2.ptr, s1.length);
        }
        return c;
    }

    int opCmp(const (Value)v) const
    {
        switch(vtype)
        {
        case V_REF_ERROR:
            throwRefError();
            assert(0);
        case V_UNDEFINED:
            if(vtype == v.vtype)
                return 0;
            break;
        case V_NULL:
            if(vtype == v.vtype)
                return 0;
            break;
        case V_BOOLEAN:
            if(vtype == v.vtype)
                return v.dbool - dbool;
            break;
        case V_NUMBER:
            if(v.vtype == V_NUMBER)
            {
                if(number == v.number)
                    return 0;
                if(isNaN(number) && isNaN(v.number))
                    return 0;
                if(number > v.number)
                    return 1;
            }
            else if(v.vtype == V_STRING)
            {
                return stringcmp((cast(Value*)&this).toString(), v.text);    //TODO: remove this hack!
            }
            break;
        case V_STRING:
            if(v.vtype == V_STRING)
            {
                //writefln("'%s'.compareTo('%s')", string, v.string);
                int len = text.length - v.text.length;
                if(len == 0)
                {
                    if(text.ptr == v.text.ptr)
                        return 0;
                    len = memcmp(text.ptr, v.text.ptr, text.length);
                }
                return len;
            }
            else if(v.vtype == V_NUMBER)
            {
                //writefln("'%s'.compareTo(%g)\n", text, v.number);
                return stringcmp(text, (cast(Value*)&v).toString());    //TODO: remove this hack!
            }
            break;
        case V_OBJECT:
            if(v.object == object)
                return 0;
            break;
        default:
            assert(0);
        }
        return -1;
    }

    void copyTo(Value* v)
    {   // Copy everything, including vptr
        copy(&this, v);
    }

    d_string getType()
    {
        d_string s;

        switch(vtype)
        {
        case V_REF_ERROR:
        case V_UNDEFINED:   s = TypeUndefined; break;
        case V_NULL:        s = TypeNull;      break;
        case V_BOOLEAN:     s = TypeBoolean;   break;
        case V_NUMBER:      s = TypeNumber;    break;
        case V_STRING:      s = TypeString;    break;
        case V_OBJECT:      s = TypeObject;    break;
        case V_ITER:        s = TypeIterator;  break;
        default:
            debug writefln("vtype = %d", vtype);
            assert(0);
        }
        return s;
    }

    d_string getTypeof()
    {
        d_string s;

        switch(vtype)
        {
        case V_REF_ERROR:
        case V_UNDEFINED:   s = TEXT_undefined;     break;
        case V_NULL:        s = TEXT_object;        break;
        case V_BOOLEAN:     s = TEXT_boolean;       break;
        case V_NUMBER:      s = TEXT_number;        break;
        case V_STRING:      s = TEXT_string;        break;
        case V_OBJECT:      s = object.getTypeof(); break;
        default:
            debug writefln("vtype = %d", vtype);
            assert(0);
        }
        return s;
    }

    int isUndefined()
    {
        return vtype == V_UNDEFINED;
    }
    int isNull()
    {
        return vtype == V_NULL;
    }
    int isBoolean()
    {
        return vtype == V_BOOLEAN;
    }
    int isNumber()
    {
        return vtype == V_NUMBER;
    }
    int isString()
    {
        return vtype == V_STRING;
    }
    int isObject()
    {
        return vtype == V_OBJECT;
    }
    int isIterator()
    {
        return vtype == V_ITER;
    }

    int isUndefinedOrNull()
    {
        return vtype == V_UNDEFINED || vtype == V_NULL;
    }
    int isPrimitive()
    {
        return vtype != V_OBJECT;
    }

    int isArrayIndex(out d_uint32 index)
    {
        switch(vtype)
        {
        case V_NUMBER:
            index = toUint32();
            return true;
        case V_STRING:
            return StringToIndex(text, index);
        default:
            index = 0;
            return false;
        }
        assert(0);
    }

    static uint calcHash(uint u)
    {
        return u ^ 0x55555555;
    }

    static uint calcHash(double d)
    {
        return calcHash(cast(uint)d);
    }

    static uint calcHash(d_string s)
    {
        uint hash;

        /* If it looks like an array index, hash it to the
         * same value as if it was an array index.
         * This means that "1234" hashes to the same value as 1234.
         */
        hash = 0;
        foreach(tchar c; s)
        {
            switch(c)
            {
            case '0':       hash *= 10;             break;
            case '1':       hash = hash * 10 + 1;   break;

            case '2':
            case '3':
            case '4':
            case '5':
            case '6':
            case '7':
            case '8':
            case '9':
                hash = hash * 10 + (c - '0');
                break;

            default:
            { uint len = s.length;
              ubyte *str = cast(ubyte*)s.ptr;

              hash = 0;
              while(1)
              {
                  switch(len)
                  {
                  case 0:
                      break;

                  case 1:
                      hash *= 9;
                      hash += *cast(ubyte *)str;
                      break;

                  case 2:
                      hash *= 9;
                      hash += *cast(ushort *)str;
                      break;

                  case 3:
                      hash *= 9;
                      hash += (*cast(ushort *)str << 8) +
                              (cast(ubyte *)str)[2];
                      break;

                  default:
                      hash *= 9;
                      hash += *cast(uint *)str;
                      str += 4;
                      len -= 4;
                      continue;
                  }
                  break;
              }
              break; }
                // return s.hash;
            }
        }
        return calcHash(hash);
    }

    uint toHash()
    {
        uint h;

        switch(vtype)
        {
        case V_REF_ERROR:
            throwRefError();
            assert(0);
        case V_UNDEFINED:
        case V_NULL:
            h = 0;
            break;
        case V_BOOLEAN:
            h = dbool ? 1 : 0;
            break;
        case V_NUMBER:
            h = calcHash(number);
            break;
        case V_STRING:
            // Since strings are immutable, if we've already
            // computed the hash, use previous value
            if(!hash)
                hash = calcHash(text);
            h = hash;
            break;
        case V_OBJECT:
            /* Uses the address of the object as the hash.
             * Since the object never moves, it will work
             * as its hash.
             * BUG: shouldn't do this.
             */
            h = cast(uint)cast(void*)object;
            break;
        default:
            assert(0);
        }
        //writefln("\tValue.toHash() = %x", h);
        return h;
    }

    Value* Put(d_string PropertyName, Value* value)
    {
        if(vtype == V_OBJECT)
            return object.Put(PropertyName, value, 0);
        else
        {
            ErrInfo errinfo;

            return Dobject.RuntimeError(&errinfo,
                                        errmsgtbl[ERR_CANNOT_PUT_TO_PRIMITIVE],
                                        PropertyName, value.toString(),
                                        getType());
        }
    }

    Value* Put(d_uint32 index, Value* vindex, Value* value)
    {
        if(vtype == V_OBJECT)
            return object.Put(index, vindex, value, 0);
        else
        {
            ErrInfo errinfo;

            return Dobject.RuntimeError(&errinfo,
                                        errmsgtbl[ERR_CANNOT_PUT_INDEX_TO_PRIMITIVE],
                                        index,
                                        value.toString(), getType());
        }
    }

    Value* Get(d_string PropertyName)
    {
        if(vtype == V_OBJECT)
            return object.Get(PropertyName);
        else
        {
            // Should we generate the error, or just return undefined?
            d_string msg;

            msg = std.string.format(errmsgtbl[ERR_CANNOT_GET_FROM_PRIMITIVE],
                                    PropertyName, getType(), toString());
            throw new ScriptException(msg);
            //return &vundefined;
        }
    }

    Value* Get(d_uint32 index)
    {
        if(vtype == V_OBJECT)
            return object.Get(index);
        else
        {
            // Should we generate the error, or just return undefined?
            d_string msg;

            msg = std.string.format(errmsgtbl[ERR_CANNOT_GET_INDEX_FROM_PRIMITIVE],
                                    index, getType(), toString());
            throw new ScriptException(msg);
            //return &vundefined;
        }
    }

    Value* Get(Identifier *id)
    {
        if(vtype == V_OBJECT)
            return object.Get(id);
        else if(vtype == V_REF_ERROR){
            throwRefError();
            assert(0);
        }
        else
        {
            // Should we generate the error, or just return undefined?
            d_string msg;

            msg = std.string.format(errmsgtbl[ERR_CANNOT_GET_FROM_PRIMITIVE],
                                    id.toString(), getType(), toString());
            throw new ScriptException(msg);
            //return &vundefined;
        }
    }
/+
    Value* Get(d_string PropertyName, uint hash)
    {
        if (vtype == V_OBJECT)
            return object.Get(PropertyName, hash);
        else
        {
            // Should we generate the error, or just return undefined?
            tchar[] msg;

            msg = std.string.format(errmsgtbl[ERR_CANNOT_GET_FROM_PRIMITIVE],
                PropertyName, getType(), toString());
            throw new ScriptException(msg);
            //return &vundefined;
        }
    }
 +/
    void* Construct(CallContext *cc, Value *ret, Value[] arglist)
    {
        if(vtype == V_OBJECT)
            return object.Construct(cc, ret, arglist);
        else if(vtype == V_REF_ERROR){
            throwRefError();
            assert(0);
        }
        else
        {
            ErrInfo errinfo;
            ret.putVundefined();
            return Dobject.RuntimeError(&errinfo,
                                        errmsgtbl[ERR_PRIMITIVE_NO_CONSTRUCT], getType());
        }
    }

    void* Call(CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
    {
        if(vtype == V_OBJECT)
        {
            void* a;

            a = object.Call(cc, othis, ret, arglist);
            //if (a) writef("Vobject.Call() returned %x\n", a);
            return a;
        }
        else if(vtype == V_REF_ERROR){
            throwRefError();
            assert(0);
        }
        else
        {
            ErrInfo errinfo;
            //PRINTF("Call method not implemented for primitive %p (%s)\n", this, d_string_ptr(toString()));
            ret.putVundefined();
            return Dobject.RuntimeError(&errinfo,
                                        errmsgtbl[ERR_PRIMITIVE_NO_CALL], getType());
        }
    }

    Value* putIterator(Value* v)
    {
        if(vtype == V_OBJECT)
            return object.putIterator(v);
        else
        {
            ErrInfo errinfo;
            v.putVundefined();
            return Dobject.RuntimeError(&errinfo,
                                        errmsgtbl[ERR_FOR_IN_MUST_BE_OBJECT]);
        }
    }


    void getErrInfo(ErrInfo *perrinfo, int linnum)
    {
        if(vtype == V_OBJECT)
            object.getErrInfo(perrinfo, linnum);
        else
        {
            ErrInfo errinfo;

            if(linnum && errinfo.linnum == 0)
                errinfo.linnum = linnum;
            errinfo.message = "Unhandled exception: " ~ toString();
            if(perrinfo)
                *perrinfo = errinfo;
        }
    }

    void dump()
    {
        uint *v = cast(uint *)&this;

        writef("v[%x] = %8x, %8x, %8x, %8x\n", cast(uint)v, v[0], v[1], v[2], v[3]);
    }
}
static if(size_t.sizeof == 4)
  static assert(Value.sizeof == 16);
else
  static assert(Value.sizeof == 24); //fat string point 2*8 + type tag & hash

Value vundefined = { V_UNDEFINED };
Value vnull = { V_NULL };

string TypeUndefined = "Undefined";
string TypeNull = "Null";
string TypeBoolean = "Boolean";
string TypeNumber = "Number";
string TypeString = "String";
string TypeObject = "Object";

string TypeIterator = "Iterator";


Value* signalingUndefined(string id){
    Value* p;
    p = new Value;
    p.putSignalingUndefined(id);
    return p;
}




