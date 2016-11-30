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
import dmdscript.property;

debug import std.stdio;

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

// version(DigitalMars)
//     version(D_InlineAsm)
//         version = UseAsm;

struct Value
{
    uint  hash;               // cache 'hash' value

    enum Type : ubyte
    {
        RefError = 0,//triggers ReferenceError expcetion when accessed
        Undefined = 1,
        Null      = 2,
        Boolean   = 3,
        Number    = 4,
        String    = 5,
        Object    = 6,
        Iter      = 7,
    }
    Type vtype = Type.Undefined;

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

    @trusted
    void checkReference() const
    {
        if(vtype == Type.RefError)
            throwRefError();
    }

    @trusted
    void throwRefError() const
    {
        throw UndefinedVarError.toThrow(text);
    }

    @trusted @nogc pure nothrow
    void putSignalingUndefined(d_string id)
    {
        vtype = Type.RefError;
        text = id;
    }
    @trusted @nogc pure nothrow
    void putVundefined()
    {
        vtype = Type.Undefined;
        hash = 0;
        text = null;
    }

    @safe @nogc pure nothrow
    void putVnull()
    {
        vtype = Type.Null;
    }

    @trusted @nogc pure nothrow
    void put(T : d_boolean)(T b)
    {
        assert(b == 1 || b == 0);
        vtype = Type.Boolean;
        dbool = b;
    }

    @trusted @nogc pure nothrow
    void put(T : d_number)(T n)
    {
        vtype = Type.Number;
        number = n;
    }

    @trusted @nogc pure nothrow
    void putVtime(d_time n)
    {
        vtype = Type.Number;
        number = (n == d_time_nan) ? d_number.nan : n;
    }

    @trusted @nogc pure nothrow
    void put(T : d_string)(T s)
    {
        vtype = Type.String;
        hash = 0;
        text = s;
    }

    @trusted @nogc pure nothrow
    void put(d_string s, size_t hash)
    {
        vtype = Type.String;
        this.hash = hash;
        this.text = s;
    }

    @trusted @nogc pure nothrow
    void put(T : Dobject)(T o)
    {
        vtype = Type.Object;
        object = o;
    }

    @trusted @nogc pure nothrow
    void put(T : Iterator*)(T i)
    {
        vtype = Type.Iter;
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

    void toPrimitive(ref CallContext cc, out Value v, in d_string PreferredType)
    {
        if(vtype == Type.Object)
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
            DError* a;

            assert(object);
            a = object.DefaultValue(cc, v, PreferredType);
            if(a)
                throw a.toScriptException;
            if(!v.isPrimitive)
            {
                v.putVundefined;
                throw ObjectCannotBePrimitiveError.toThrow;
            }
        }
        else
        {
            v = this;
        }
    }


    @trusted
    d_boolean toBoolean() const
    {
        import std.math : isNaN;

        final switch(vtype)
        {
        case Type.RefError:
            throwRefError();
            assert(0);
        case Type.Undefined:
        case Type.Null:
        case Type.Iter:
            return false;
        case Type.Boolean:
            return dbool;
        case Type.Number:
            return !(number == 0.0 || isNaN(number));
        case Type.String:
            return text.length ? true : false;
        case Type.Object:
            return true;
        }
        assert(0);
    }

    @trusted
    d_number toNumber()
    {
        final switch(vtype)
        {
        case Type.RefError:
            throwRefError();
            assert(0);
        case Type.Undefined:
        case Type.Iter:
            return d_number.nan;
        case Type.Null:
            return 0;
        case Type.Boolean:
            return dbool ? 1 : 0;
        case Type.Number:
            return number;
        case Type.String:
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
        case Type.Object:
        { Value val;
          Value* v;
          CallContext cc;
          // void* a;

          //writefln("Vobject.toNumber()");
          v = &val;
          toPrimitive(cc, *v, TypeName.Number);
          /*a = toPrimitive(v, TypeNumber);
          if(a)//rerr
                  return d_number.nan;*/
          if(v.isPrimitive)
              return v.toNumber;
          else
              return d_number.nan;
        }
        }
        assert(0);
    }

    @safe
    d_time toDtime()
    {
        return cast(d_time)toNumber();
    }

    @safe
    d_number toInteger()
    {
        import std.math : floor, isInfinity, isNaN;

        final switch(vtype)
        {
        case Type.RefError:
            throwRefError;
            assert(0);
        case Type.Undefined:
            return d_number.nan;
        case Type.Null:
            return 0;
        case Type.Boolean:
            return dbool ? 1 : 0;

        case Type.Number, Type.String, Type.Object, Type.Iter:
        {
            d_number number;

            number = toNumber;
            if(number.isNaN)
                number = 0;
            else if(number == 0 || isInfinity(number))
            {
            }
            else if(number > 0)
                number = floor(number);
            else
                number = -floor(-number);
            return number;
        }
        }
        assert(0);
    }

    @safe
    d_int32 toInt32()
    {
        import std.math : floor, isInfinity, isNaN;

        final switch(vtype)
        {
        case Type.RefError:
            throwRefError();
            assert(0);
        case Type.Undefined:
        case Type.Null:
            return 0;
        case Type.Boolean:
            return dbool ? 1 : 0;

        case Type.Number, Type.String, Type.Object, Type.Iter:
        {
            d_int32 int32;
            d_number number;
            long ll;

            number = toNumber();
            if(isNaN(number))
                int32 = 0;
            else if(number == 0 || isInfinity(number))
                int32 = 0;
            else
            {
                if(number > 0)
                    number = floor(number);
                else
                    number = -floor(-number);

                ll = cast(long)number;
                int32 = cast(int)ll;
            }
            return int32;
        }
        }
        assert(0);
    }

    @safe
    d_uint32 toUint32()
    {
        import std.math : floor, isInfinity, isNaN;

        final switch(vtype)
        {
        case Type.RefError:
            throwRefError();
            assert(0);
        case Type.Undefined:
        case Type.Null:
            return 0;
        case Type.Boolean:
            return dbool ? 1 : 0;

        case Type.Number, Type.String, Type.Object, Type.Iter:
        {
            d_uint32 uint32;
            d_number number;
            long ll;

            number = toNumber();
            if(isNaN(number))
                uint32 = 0;
            else if(number == 0 || isInfinity(number))
                uint32 = 0;
            else
            {
                if(number > 0)
                    number = floor(number);
                else
                    number = -floor(-number);

                ll = cast(long)number;
                uint32 = cast(uint)ll;
            }
            return uint32;
        }
        }
        assert(0);
    }

    @safe
    d_uint16 toUint16()
    {
        import std.math : floor, isInfinity, isNaN;

        final switch(vtype)
        {
        case Type.RefError:
            throwRefError();
            assert(0);
        case Type.Undefined:
        case Type.Null:
            return 0;
        case Type.Boolean:
            return cast(d_uint16)(dbool ? 1 : 0);

        case Type.Number, Type.String, Type.Object, Type.Iter:
        {
            d_uint16 uint16;
            d_number number;

            number = toNumber();
            if(isNaN(number))
                uint16 = 0;
            else if(number == 0 || isInfinity(number))
                uint16 = 0;
            else
            {
                if(number > 0)
                    number = floor(number);
                else
                    number = -floor(-number);

                uint16 = cast(ushort)number;
            }
            return uint16;
        }
        }
        assert(0);
    }

    d_string toString()
    {
        import std.format : sformat;
        import std.math : isInfinity, isNaN;
        import core.stdc.string : strlen;

        final switch(vtype)
        {
        case Type.RefError:
            throwRefError();
            assert(0);
        case Type.Undefined:
            return Text.undefined;
        case Type.Null:
            return Text._null;
        case Type.Boolean:
            return dbool ? Text._true : Text._false;
        case Type.Number:
        {
            d_string str;
            static enum d_string[10]  strs =
                [   Text._0, Text._1, Text._2, Text._3, Text._4,
                    Text._5, Text._6, Text._7, Text._8, Text._9 ];

            //writefln("Vnumber.tostr(%g)", number);
            if(isNaN(number))
                str = Text.NaN;
            else if(number >= 0 && number <= 9 && number == cast(int)number)
                str = strs[cast(int)number];
            else if(isInfinity(number))
            {
                if(number < 0)
                    str = Text.negInfinity;
                else
                    str = Text.Infinity;
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

                sformat(buffer, "%.16g\0", number);
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
                str = p[0 .. strlen(p)].idup;
            }
            //writefln("str = '%s'", str);
            return str;
        }
        case Type.String:
            return text;
        case Type.Object:
        {
            Value val;
            Value* v = &val;
            CallContext cc;
            // void* a;

            //writef("Vobject.toString()\n");
            toPrimitive(cc, *v, TypeName.String);
            //assert(!a);
            if(v.isPrimitive)
                return v.toString;
            else
                return v.toObject.classname;
        }
        case Type.Iter:
            assert(0);
        }
        assert(0);
    }

    d_string toLocaleString()
    {
        return toString();
    }

    d_string toString(in int radix)
    {
        import std.math : isFinite;
        import std.conv : to;

        if(vtype == Type.Number)
        {
            assert(2 <= radix && radix <= 36);
            if(!isFinite(number))
                return toString();
            return number >= 0.0 ? to!(d_string)(cast(long)number, radix) : "-"~to!(d_string)(cast(long)-number,radix);
        }
        else
        {
            return toString();
        }
    }

    d_string toSource(ref CallContext cc)
    {
        switch(vtype)
        {
        case Type.String:
        {
            d_string s;

            s = "\"" ~ text ~ "\"";
            return s;
        }
        case Type.Object:
        {
            Value* v;
//            CallContext cc;

            //writefln("Vobject.toSource()");
            v = Get(Text.toSource, cc);
            if(!v)
                v = &vundefined;
            if(v.isPrimitive())
                return v.toSource(cc);
            else          // it's an Object
            {
                DError* a;
                // CallContext* pcc;
                Dobject o;
                Value* ret;
                Value val;

                o = v.object;
                // pcc = &Program.getProgram.callcontext;
                ret = &val;
                a = o.Call(cc, this.object, *ret, null);
                if(a)                             // if exception was thrown
                {
                    /*return a;*/
                    debug writef("Vobject.toSource() failed with %x\n", a);
                }
                else if(ret.isPrimitive())
                    return ret.toString();
            }
            return Text.undefined;
        }
        default:
            return toString();
        }
        assert(0);
    }

    @trusted
    Dobject toObject()
    {
        final switch(vtype)
        {
        case Type.RefError:
            throwRefError();
            assert(0);
        case Type.Undefined:
            //RuntimeErrorx("cannot convert undefined to Object");
            return null;
        case Type.Null:
            //RuntimeErrorx("cannot convert null to Object");
            return null;
        case Type.Boolean:
            return new Dboolean(dbool);
        case Type.Number:
            return new Dnumber(number);
        case Type.String:
            return new Dstring(text);
        case Type.Object:
            return object;
        case Type.Iter:
            assert(0);
        }
        assert(0);
    }

    @safe
    bool opEquals(in ref Value v) const
    {
        return(opCmp(v) == 0);
    }

    /*********************************
     * Use this instead of std.string.cmp() because
     * we don't care about lexicographic ordering.
     * This is faster.
     */

    static @trusted @nogc pure nothrow
    int stringcmp(in d_string s1, in d_string s2)
    {
        import core.stdc.string : memcmp;

        int c = s1.length - s2.length;
        if(c == 0)
        {
            if(s1.ptr == s2.ptr)
                return 0;
            c = memcmp(s1.ptr, s2.ptr, s1.length);
        }
        return c;
    }

    @trusted
    int opCmp()(in auto ref Value v) const
    {
        import std.math : isNaN;
        import core.stdc.string : memcmp;

        final switch(vtype)
        {
        case Type.RefError:
            throwRefError();
            assert(0);
        case Type.Undefined:
            if(vtype == v.vtype)
                return 0;
            break;
        case Type.Null:
            if(vtype == v.vtype)
                return 0;
            break;
        case Type.Boolean:
            if(vtype == v.vtype)
                return v.dbool - dbool;
            break;
        case Type.Number:
            if(v.vtype == Type.Number)
            {
                if(number == v.number)
                    return 0;
                if(isNaN(number) && isNaN(v.number))
                    return 0;
                if(number > v.number)
                    return 1;
            }
            else if(v.vtype == Type.String)
            {
                return stringcmp((cast(Value*)&this).toString(), v.text);    //TODO: remove this hack!
            }
            break;
        case Type.String:
            if(v.vtype == Type.String)
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
            else if(v.vtype == Type.Number)
            {
                //writefln("'%s'.compareTo(%g)\n", text, v.number);
                return stringcmp(text, (cast(Value*)&v).toString());    //TODO: remove this hack!
            }
            break;
        case Type.Object:
            if(v.object == object)
                return 0;
            break;
        case Type.Iter:
            assert(0);
        }
        return -1;
    }


    enum TypeName
    {
        Undefined = "Undefined",
        Null = "Null",
        Boolean = "Boolean",
        Number = "Number",
        String = "String",
        Object = "Object",

        Iterator = "Iterator",
    }

    @safe @nogc nothrow
    d_string getType() const
    {
        d_string s;

        final switch(vtype)
        {
        case Type.RefError:
        case Type.Undefined:   s = TypeName.Undefined; break;
        case Type.Null:        s = TypeName.Null;      break;
        case Type.Boolean:     s = TypeName.Boolean;   break;
        case Type.Number:      s = TypeName.Number;    break;
        case Type.String:      s = TypeName.String;    break;
        case Type.Object:      s = TypeName.Object;    break;
        case Type.Iter:        s = TypeName.Iterator;  break;
        }
        return s;
    }

    @trusted
    d_string getTypeof()
    {
        d_string s;

        final switch(vtype)
        {
        case Type.RefError:
        case Type.Undefined:   s = Text.undefined;     break;
        case Type.Null:        s = Text.object;        break;
        case Type.Boolean:     s = Text.boolean;       break;
        case Type.Number:      s = Text.number;        break;
        case Type.String:      s = Text.string;        break;
        case Type.Object:      s = object.getTypeof(); break;
        case Type.Iter:
            assert(0);
        }
        return s;
    }

    @property @safe @nogc pure nothrow
    bool isEmpty() const
    {
        return vtype == Type.RefError;
    }

    @property @safe @nogc pure nothrow
    bool isUndefined() const
    {
        return vtype == Type.Undefined;
    }
    @property @safe @nogc pure nothrow
    bool isNull() const
    {
        return vtype == Type.Null;
    }
    @property @safe @nogc pure nothrow
    bool isBoolean() const
    {
        return vtype == Type.Boolean;
    }
    @property @safe @nogc pure nothrow
    bool isNumber() const
    {
        return vtype == Type.Number;
    }
    @property @safe @nogc pure nothrow
    bool isString() const
    {
        return vtype == Type.String;
    }
    @property @safe @nogc pure nothrow
    bool isObject() const
    {
        return vtype == Type.Object;
    }
    @property @safe @nogc pure nothrow
    bool isIterator() const
    {
        return vtype == Type.Iter;
    }

    @property @safe @nogc pure nothrow
    bool isUndefinedOrNull() const
    {
        return vtype == Type.Undefined || vtype == Type.Null;
    }
    @property @safe @nogc pure nothrow
    bool isPrimitive() const
    {
        return vtype != Type.Object;
    }

    @trusted
    bool isArrayIndex(out d_uint32 index)
    {
        switch(vtype)
        {
        case Type.Number:
            index = toUint32();
            return true;
        case Type.String:
            return StringToIndex(text, index);
        default:
            index = 0;
            return false;
        }
        assert(0);
    }

    static @safe @nogc pure nothrow
    size_t calcHash(in size_t u)
    {
        static if (size_t.sizeof == 4)
            return u ^ 0x55555555;
        else static assert(0);
    }

    static @safe @nogc pure nothrow
    size_t calcHash(in double d)
    {
        return calcHash(cast(size_t)d);
    }

    static @trusted @nogc pure nothrow
    size_t calcHash(in d_string s)
    {
        size_t hash;

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
            {
                uint len = s.length;
                ubyte* str = cast(ubyte*)s.ptr;

                hash = 0;
                while(1)
                {
                    switch(len)
                    {
                    case 0:
                        break;

                    case 1:
                        hash *= 9;
                        hash += *cast(ubyte*)str;
                        break;

                    case 2:
                        hash *= 9;
                        if (__ctfe)
                            hash += str[0..2].toNative!ushort;
                        else
                            hash += *cast(ushort*)str;
                        break;

                    case 3:
                        hash *= 9;
                        if (__ctfe)
                            hash += (str[0..2].toNative!ushort << 8) +
                                (cast(ubyte*)str)[2];
                        else
                            hash += (*cast(ushort*)str << 8) +
                                (cast(ubyte*)str)[2];
                        break;

                    default:
                        hash *= 9;
                        if (__ctfe)
                            hash += str[0..4].toNative!uint;
                        else
                            hash += *cast(uint*)str;
                        str += 4;
                        len -= 4;
                        continue;
                    }
                    break;
                }
                break;
            }
            // return s.hash;
            }
        }
        return calcHash(hash);
    }

    // only calculation. not caching.
    static @trusted
    size_t calcHash(in ref Value v)
    {
        final switch(v.vtype)
        {
        case Type.RefError:
            v.throwRefError();
            assert(0);
        case Type.Undefined:
        case Type.Null:
            return 0;
        case Type.Boolean:
            return v.dbool ? 1 : 0;
        case Type.Number:
            return calcHash(v.number);
        case Type.String:
            // Since strings are immutable, if we've already
            // computed the hash, use previous value
            return calcHash(v.text);
        case Type.Object:
            /* Uses the address of the object as the hash.
             * Since the object never moves, it will work
             * as its hash.
             * BUG: shouldn't do this.
             */
            return cast(uint)cast(void*)v.object;
        case Type.Iter:
            assert(0);
        }
        assert(0);
    }

    @trusted
    size_t toHash()
    {
        size_t h;

        final switch(vtype)
        {
        case Type.RefError:
            throwRefError();
            assert(0);
        case Type.Undefined:
        case Type.Null:
            h = 0;
            break;
        case Type.Boolean:
            h = dbool ? 1 : 0;
            break;
        case Type.Number:
            h = calcHash(number);
            break;
        case Type.String:
            // Since strings are immutable, if we've already
            // computed the hash, use previous value
            if(!hash)
                hash = calcHash(text);
            h = hash;
            break;
        case Type.Object:
            /* Uses the address of the object as the hash.
             * Since the object never moves, it will work
             * as its hash.
             * BUG: shouldn't do this.
             */
            h = cast(uint)cast(void*)object;
            break;
        case Type.Iter:
            assert(0);
        }
        return h;
    }

    DError* Put(in d_string PropertyName, ref Value value, ref CallContext cc)
    {
        if(vtype == Type.Object)
            return object.Set(PropertyName, value, Property.Attribute.None, cc);
        else
        {
            return CannotPutToPrimitiveError(
                PropertyName, value.toString, getType);
        }
    }

    DError* Put(in d_uint32 index, ref Value vindex, ref Value value,
                ref CallContext cc)
    {
        if(vtype == Type.Object)
            return object.Set(index, vindex, value,
                              Property.Attribute.None, cc);
        else
        {
            return CannotPutIndexToPrimitiveError(
                index, value.toString, getType);
        }
    }

    Value* Get(in d_string PropertyName, ref CallContext cc)
    {
        import std.format : format;

        if(vtype == Type.Object)
            return object.Get(PropertyName, cc);
        else
        {
            // Should we generate the error, or just return undefined?
            throw CannotGetFromPrimitiveError
                .toThrow(PropertyName, getType, toString);
            //return &vundefined;
        }
    }

    Value* Get(in d_uint32 index, ref CallContext cc)
    {
        import std.format : format;

        if(vtype == Type.Object)
            return object.Get(index, cc);
        else
        {
            // Should we generate the error, or just return undefined?
            throw CannotGetIndexFromPrimitiveError
                .toThrow(index, getType, toString);
            //return &vundefined;
        }
    }

    Value* Get(ref Identifier id, ref CallContext cc)
    {
        import std.format : format;

        if(vtype == Type.Object)
            return object.Get(id, cc);
        else if(vtype == Type.RefError){
            throwRefError();
            assert(0);
        }
        else
        {
            // Should we generate the error, or just return undefined?
            throw CannotGetFromPrimitiveError
                .toThrow(id.toString, getType, toString);
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
    DError* Construct(ref CallContext cc, out Value ret, Value[] arglist)
    {
        if(vtype == Type.Object)
            return object.Construct(cc, ret, arglist);
        else if(vtype == Type.RefError){
            throwRefError();
            assert(0);
        }
        else
        {
            ret.putVundefined();
            return PrimitiveNoConstructError(getType);
        }
    }

    DError* Call(ref CallContext cc, Dobject othis, out Value ret,
                 Value[] arglist)
    {
        if(vtype == Type.Object)
        {
            DError* a;

            a = object.Call(cc, othis, ret, arglist);
            //if (a) writef("Vobject.Call() returned %x\n", a);
            return a;
        }
        else if(vtype == Type.RefError){
            throwRefError();
            assert(0);
        }
        else
        {
            //PRINTF("Call method not implemented for primitive %p (%s)\n", this, d_string_ptr(toString()));
            ret.putVundefined();
            return PrimitiveNoCallError(getType);
        }
    }

    DError* putIterator(out Value v)
    {
        if(vtype == Type.Object)
            return object.putIterator(v);
        else
        {
            v.putVundefined();
            return ForInMustBeObjectError;
        }
    }

    debug void dump()
    {
        import std.stdio : writef;

        uint* v = cast(uint*)&this;

        writef("v[%x] = %8x, %8x, %8x, %8x\n", cast(uint)v, v[0], v[1], v[2], v[3]);
    }
}
static if (size_t.sizeof == 4)
  static assert(Value.sizeof == 16);
else static if (size_t.sizeof == 8)
  static assert(Value.sizeof == 24); //fat string point 2*8 + type tag & hash
else static assert(0, "This machine is not supported.");

//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// How do I make these to be enum?
Value vundefined = { vtype: Value.Type.Undefined };
Value vnull = { vtype: Value.Type.Null };

@safe pure nothrow
Value* signalingUndefined(in d_string id)
{
    auto p = new Value;
    p.putSignalingUndefined(id);
    return p;
}

/* DError contains the ending status of a function.
Mostly, this contains a ScriptException.
DError is needed for catch statements in ths script.
 */
struct DError
{
    import dmdscript.opcodes : IR;

    Value entity;
    alias entity this;

    @safe
    ScriptException toScriptException()
    {
        import dmdscript.protoerror;

        auto d0 = cast(D0base)entity.toObject;
        assert(d0);
        assert(d0.exception);

        return d0.exception;
    }

    @safe
    void addTrace(d_string name, d_string srctext)
    {
        import dmdscript.protoerror;

        if (auto d0 = cast(D0base)entity.toObject)
        {
            assert(d0.exception);
            d0.exception.addTrace(name, srctext);
        }
        else
            assert(0);
    }

    @safe
    void addTrace(const(IR)* base, const(IR)* code)
    {
        import dmdscript.protoerror;

        if (auto d0 = cast(D0base)entity.toObject)
        {
            assert(d0.exception);
            d0.exception.addTrace(base, code);
        }
        else
            assert(0);
    }
}

package @trusted
DError* toDError(alias Proto = typeerror)(Throwable t)
{
    assert(t !is null);
    ScriptException exception;

    if (auto se = cast(ScriptException)t) exception = se;
    else exception = new ScriptException(t.toString, t.file, t.line);
    assert(exception !is null);

    auto v = new DError;
    v.put(new Proto.D0(exception));
    return v;
}


// for Value.calcHash at CTFE.
private @safe @nogc pure nothrow
T toNative(T, size_t N = T.sizeof)(in ubyte[] buf)
{
    assert(N <= buf.length);
    static if      (N == 1)
        return buf[0];
    else static if (N == 2)
    {
        version      (BigEndian)
            return ((cast(ushort)buf[0]) << 8) | (cast(ushort)buf[1]);
        else version (LittleEndian)
            return (cast(ushort)buf[0]) | ((cast(ushort)buf[1]) << 8);
        else static assert(0);
    }
    else static if (N == 4)
    {
        version      (BigEndian)
            return ((cast(uint)buf[0]) << 24) |
                   ((cast(uint)buf[1]) << 16) |
                   ((cast(uint)buf[2]) << 8) |
                   (cast(uint)buf[3]);
        else version (LittleEndian)
            return (cast(uint)buf[0]) |
                   ((cast(uint)buf[1]) << 8) |
                   ((cast(uint)buf[2]) << 16) |
                   ((cast(uint)buf[3]) << 24);
        else static assert(0);
    }
    else static if (N == 8)
    {
        version      (BigEndian)
            return ((cast(ulong)buf[0]) << 56) |
                   ((cast(ulong)buf[1]) << 48) |
                   ((cast(ulong)buf[2]) << 40) |
                   ((cast(ulong)buf[3]) << 32) |
                   ((cast(ulong)buf[4]) << 24) |
                   ((cast(ulong)buf[5]) << 16) |
                   ((cast(ulong)buf[6]) << 8) |
                   (cast(ulong)buf[7]);
        else version (LittleEndian)
            return (cast(ulong)buf[0]) |
                   ((cast(ulong)buf[1]) << 8) |
                   ((cast(ulong)buf[2]) << 16) |
                   ((cast(ulong)buf[3]) << 24) |
                   ((cast(ulong)buf[4]) << 32) |
                   ((cast(ulong)buf[5]) << 40) |
                   ((cast(ulong)buf[6]) << 48) |
                   ((cast(ulong)buf[7]) << 56);
        else static assert(0);
    }
    else static assert(0);
}
