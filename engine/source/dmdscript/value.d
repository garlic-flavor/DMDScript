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

import dmdscript.primitive : Key, PropertyKey;
import dmdscript.dobject : Dobject;
import dmdscript.property : Property;
import dmdscript.errmsgs;
import dmdscript.callcontext : CallContext;
debug import std.stdio;

// !!! NOTICE !!!
// I can't implement this porting issues bellow.
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

struct Value
{
    // NEVER import dmdscript.dfunction : Dfunction at this.
    import dmdscript.iterator : Iterator;
    import dmdscript.primitive;
    import dmdscript.property : PropTable;

    //--------------------------------------------------------------------
    enum Type : ubyte
    {
        RefError,//triggers ReferenceError expcetion when accessed

        Undefined,
        Null,
        Boolean,
        Number,
        String,
        Object,

        Iter,
        Symbol,
    }

    //--------------------------------------------------------------------
    template canHave(T)
    {
        enum canHave = is(T == bool) || is(T == const(bool)) ||
            is(T : Type) || is(T : PropertyKey) || is(T : double) ||
            is(T : string) || is(T : Dobject) || is(T == Iterator*) ||
            is(T : Value);
    }

    //--------------------------------------------------------------------
    this(T)(auto ref T arg) if (canHave!T)
    {
        put(arg);
    }

    //--------------------------------------------------------------------
    this(T)(auto ref T arg, size_t h) if (canHave!T)
    {
        put(arg, h);
    }

    //--------------------------------------------------------------------
    @property @trusted @nogc pure nothrow
    {
        size_t hash() const
        {
            return _hash;
        }

        Type type() const
        {
            return _type;
        }

        bool dbool() const
        {
            assert (_type == Type.Boolean);
            return _dbool;
        }

        ref auto number() inout
        {
            assert (_type == Type.Number);
            return _number;
        }

        string text() const
        {
            assert (_type == Type.String || _type == Type.Symbol);
            return _text;
        }

        auto object() inout
        {
            assert (_type == Type.Object);
            assert (_object !is null);
            return _object;
        }

        auto iter() inout
        {
            assert (_type == Type.Iter);
            assert (_iter !is null);
            return _iter;
        }
    }

    //--------------------------------------------------------------------
    @trusted
    DError* checkReference() const
    {
        if(_type == Type.RefError)
            return UndefinedVarError(_text);
        return null;
    }

    //--------------------------------------------------------------------
    @trusted @nogc pure nothrow
    void putVundefined()
    {
        _type = Type.Undefined;
        _hash = 0;
        _text = null;
    }

    //--------------------------------------------------------------------
    @safe @nogc pure nothrow
    void putVnull()
    {
        _type = Type.Null;
    }

    //--------------------------------------------------------------------
    @trusted @nogc pure nothrow
    void putVtime(d_time n)
    {
        _type = Type.Number;
        _number = (n == d_time_nan) ? double.nan : n;
    }

    //--------------------------------------------------------------------
    @trusted pure nothrow
    void putVsymbol(string s)
    {
        auto pk = PropertyKey.symbol(s);
        _type = Type.Symbol;
        _text = pk.text;
        _hash = pk.hash;
    }

    //--------------------------------------------------------------------
    @trusted @nogc pure nothrow
    void put(T)(auto ref T t) if (canHave!T)
    {
        static if      (is(T == bool) || is(T == const(bool)))
        {
            _type = Type.Boolean;
            _dbool = t;
        }
        else static if (is(T : Type))
        {
            _type = t;
        }
        else static if (is(T : PropertyKey))
        {
            if (t.text !is null)
            {
                _type = Type.String;
                _text = t.text;
                _hash = t.hash;
            }
            else
            {
                _type = Type.Number;
                _number = t.hash;
            }
        }
        else static if (is(T : double))
        {
            _type = Type.Number;
            _number = t;
        }
        else static if (is(T : string))
        {
            _type = Type.String;
            _hash = 0;
            _text = t;
        }
        else static if (is(T : Dobject))
        {
            assert (t !is null);
            _type = Type.Object;
            _object = t;
        }
        else static if (is(T == Iterator*))
        {
            assert (t !is null);
            _type = Type.Iter;
            _iter = t;
        }
        else static if (is(T : Value))
        {
            this = t;
        }
        else static assert(0);
    }

    // ditto
    @trusted @nogc pure nothrow
    void put(T)(auto ref T t, size_t h) if (IsPrimitiveType!T)
    {
        assert(calcHash(t) == h);
        static if      (is(T == bool) || is(T == const(bool)))
        {
            _type = Type.Boolean;
            _dbool = t;
        }
        else static if (is(T : Type))
        {
            _type = t;
        }
        else static if (is(T : PropertyKey))
        {
            if (t.text !is null)
            {
                _type = Type.String;
                _text = t.text;
            }
            else
            {
                _type = Type.Number;
                _number = t.hash;
            }
        }
        else static if (is(T : double))
        {
            _type = Type.Number;
            _number = t;
        }
        else static if (is(T : string))
        {
            _type = Type.String;
            _text = t;
        }
        else static if (is(T : Dobject))
        {
            assert (t !is null);
            _type = Type.Object;
            _object = t;
        }
        else static if (is(T == Iterator*))
        {
            assert (t !is null);
            _type = Type.Iter;
            _iter = t;
        }
        else static if (is(T : Value))
        {
            this = t;
        }
        else static assert(0);
        _hash = h;
    }

    // ditto
    @trusted @nogc pure nothrow
    void put(Value* v)
    {
        if (v is null)
            putVundefined;
        else
            this = *v;
    }

    //--------------------------------------------------------------------
    void toPrimitive(ref CallContext cc, ref Value v,
                     in Type PreferredType = Type.RefError)
    {
        if(_type == Type.Object)
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
            assert(_object);
            if (auto a = _object.DefaultValue(cc, v, PreferredType))
                throw a.toScriptException(cc);
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

    //--------------------------------------------------------------------
    @trusted
    bool toBoolean() const
    {
        import std.math : isNaN;

        final switch(_type)
        {
        case Type.RefError:
            throwRefError();
            assert(0);
        case Type.Undefined, Type.Null, Type.Iter:
            return false;
        case Type.Boolean:
            return _dbool;
        case Type.Number:
            return !(_number == 0.0 || isNaN(_number));
        case Type.String:
            return 0 < _text.length;
        case Type.Symbol:
            return true;
        case Type.Object:
            return true;
        }
        assert(0);
    }

    //--------------------------------------------------------------------
    @trusted
    double toNumber(ref CallContext cc)
    {
        final switch(_type)
        {
        case Type.RefError:
            throwRefError();
            assert(0);
        case Type.Undefined, Type.Iter:
            return double.nan;
        case Type.Null:
            return 0;
        case Type.Boolean:
            return _dbool ? 1 : 0;
        case Type.Number:
            return _number;
        case Type.String, Type.Symbol:
        {
            double n;
            size_t len;
            size_t endidx;

            len = _text.length;
            n = StringNumericLiteral(_text, endidx, 0);

            // Consume trailing whitespace
            foreach(dchar c; _text[endidx .. $])
            {
                if(!isStrWhiteSpaceChar(c))
                {
                    n = double.nan;
                    break;
                }
            }

            return n;
        }
        case Type.Object:
        {
            Value val;
            Value* v;
            // void* a;

            v = &val;
            toPrimitive(cc, *v, Type.Number);
            /*a = toPrimitive(v, TypeNumber);
              if(a)//rerr
              return double.nan;*/
            if(v.isPrimitive)
                return v.toNumber(cc);
            else
                return double.nan;
        }
        }
        assert(0);
    }

    //--------------------------------------------------------------------
    @safe
    d_time toDtime(ref CallContext cc)
    {
        return cast(d_time)toNumber(cc);
    }

    //--------------------------------------------------------------------
    @safe
    double toInteger(ref CallContext cc)
    {
        import std.math : floor, isInfinity, isNaN;

        final switch(_type)
        {
        case Type.RefError:
            throwRefError;
            assert(0);
        case Type.Undefined:
            return double.nan;
        case Type.Null:
            return 0;
        case Type.Boolean:
            return _dbool ? 1 : 0;

        case Type.Number, Type.String, Type.Object, Type.Iter, Type.Symbol:
        {
            double number;

            number = toNumber(cc);
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

    //--------------------------------------------------------------------
    @safe
    int toInt32(ref CallContext cc)
    {
        import std.math : floor, isInfinity, isNaN;

        final switch(_type)
        {
        case Type.RefError:
            throwRefError();
            assert(0);
        case Type.Undefined, Type.Null:
            return 0;
        case Type.Boolean:
            return _dbool ? 1 : 0;

        case Type.Number, Type.String, Type.Object, Type.Iter, Type.Symbol:
        {
            int int32;
            double number;
            long ll;

            number = toNumber(cc);
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

    //--------------------------------------------------------------------
    @safe
    uint toUint32(ref CallContext cc)
    {
        import std.math : floor, isInfinity, isNaN;

        final switch(_type)
        {
        case Type.RefError:
            throwRefError();
            assert(0);
        case Type.Undefined, Type.Null:
            return 0;
        case Type.Boolean:
            return _dbool ? 1 : 0;

        case Type.Number, Type.String, Type.Object, Type.Iter, Type.Symbol:
        {
            uint uint32;
            double number;
            long ll;

            number = toNumber(cc);
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

    //--------------------------------------------------------------------
    @safe
    short toInt16(ref CallContext cc)
    {
        import std.math : floor, isInfinity, isNaN;

        final switch(_type)
        {
        case Type.RefError:
            throwRefError();
            assert(0);
        case Type.Undefined, Type.Null:
            return 0;
        case Type.Boolean:
            return cast(short)(_dbool ? 1 : 0);

        case Type.Number, Type.String, Type.Object, Type.Iter, Type.Symbol:
        {
            short int16;
            double number;

            number = toNumber(cc);
            if(isNaN(number))
                int16 = 0;
            else if(number == 0 || isInfinity(number))
                int16 = 0;
            else
            {
                if(number > 0)
                    number = floor(number);
                else
                    number = -floor(-number);

                int16 = cast(short)number;
            }
            return int16;
        }
        }
        assert(0);
    }

    //--------------------------------------------------------------------
    @safe
    ushort toUint16(ref CallContext cc)
    {
        import std.math : floor, isInfinity, isNaN;

        final switch(_type)
        {
        case Type.RefError:
            throwRefError();
            assert(0);
        case Type.Undefined, Type.Null:
            return 0;
        case Type.Boolean:
            return cast(ushort)(_dbool ? 1 : 0);

        case Type.Number, Type.String, Type.Object, Type.Iter, Type.Symbol:
        {
            ushort uint16;
            double number;

            number = toNumber(cc);
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

    //--------------------------------------------------------------------
    @safe
    byte toInt8(ref CallContext cc)
    {
        import std.math : floor, isInfinity, isNaN;

        final switch(_type)
        {
        case Type.RefError:
            throwRefError();
            assert(0);
        case Type.Undefined, Type.Null:
            return 0;
        case Type.Boolean:
            return cast(byte)(_dbool ? 1 : 0);

        case Type.Number, Type.String, Type.Object, Type.Iter, Type.Symbol:
        {
            byte int8;
            double number;

            number = toNumber(cc);
            if(isNaN(number))
                int8 = 0;
            else if(number == 0 || isInfinity(number))
                int8 = 0;
            else
            {
                if(number > 0)
                    number = floor(number);
                else
                    number = -floor(-number);

                int8 = cast(byte)number;
            }
            return int8;
        }
        }
        assert(0);
    }

    //--------------------------------------------------------------------
    @safe
    ubyte toUint8(ref CallContext cc)
    {
        import std.math : floor, isInfinity, isNaN;

        final switch(_type)
        {
        case Type.RefError:
            throwRefError();
            assert(0);
        case Type.Undefined, Type.Null:
            return 0;
        case Type.Boolean:
            return cast(ubyte)(_dbool ? 1 : 0);

        case Type.Number, Type.String, Type.Object, Type.Iter, Type.Symbol:
        {
            ubyte uint8;
            double number;

            number = toNumber(cc);
            if(isNaN(number))
                uint8 = 0;
            else if(number == 0 || isInfinity(number))
                uint8 = 0;
            else
            {
                if(number > 0)
                    number = floor(number);
                else
                    number = -floor(-number);

                uint8 = cast(ubyte)number;
            }
            return uint8;
        }
        }
        assert(0);
    }

    //--------------------------------------------------------------------
    @safe
    ubyte toUint8Clamp(ref CallContext cc)
    {
        import std.math : lrint, isInfinity, isNaN;

        final switch(_type)
        {
        case Type.RefError:
            throwRefError();
            assert(0);
        case Type.Undefined, Type.Null:
            return 0;
        case Type.Boolean:
            return cast(ubyte)(_dbool ? 1 : 0);

        case Type.Number, Type.String, Type.Object, Type.Iter, Type.Symbol:
        {
            ubyte uint8;
            double number;

            number = toNumber(cc);
            if      (isNaN(number))
                uint8 = 0;
            else if (number <= 0)
                uint8 = 0;
            else if (255 <= number)
                uint8 = 255;
            else if (isInfinity(number))
                uint8 = ubyte.max;
            else
                uint8 = cast(ubyte)lrint(number);
            return uint8;
        }
        }
        assert(0);
    }

    //--------------------------------------------------------------------
    PropertyKey toPropertyKey()
    {
        final switch(_type)
        {
        case Type.RefError:
            throwRefError();
            assert(0);
        case Type.Undefined:
            return Key.undefined;
        case Type.Null:
            return Key._null;
        case Type.Boolean:
            return _dbool ? Key._true : Key._false;
        case Type.Number:
        {
            if (0 <= _number)
            {
                auto i32 = cast(size_t)_number;
                if (_number == cast(double)i32)
                    return PropertyKey(i32);
            }
            return PropertyKey(NumberToString(_number));
        }
        case Type.String:
        {
            size_t i32;
            if      (StringToIndex(_text, i32))
                return PropertyKey(i32);
            else if (0 < _hash)
                return PropertyKey(_text, _hash);
            else
            {
                _hash = calcHash(_text);
                return PropertyKey(_text, _hash);
            }
        }
        case Type.Symbol:
            if (0 < _hash)
                return PropertyKey(_text, _hash);
            else
            {
                _hash = ~calcHash(_text);
                return PropertyKey(_text, _hash);
            }
        case Type.Object:
            return Key.Object;
        case Type.Iter:
            assert(0);
        }
        assert(0);
    }

    //--------------------------------------------------------------------
    @trusted
    string toString() const
    {
        final switch(_type)
        {
        case Type.RefError:
            return "RefError!";
        case Type.Undefined:
            return Key.undefined;
        case Type.Null:
            return Key._null;
        case Type.Boolean:
            return _dbool ? Key._true : Key._false;
        case Type.Number:
            return NumberToString(_number);
        case Type.String, Type.Symbol:
            return _text;
        case Type.Object:
            return Key.Object;
        case Type.Iter:
            assert(0);
        }
        assert(0);
    }


    //--------------------------------------------------------------------
    string toString(ref CallContext cc)
    {
        final switch(_type)
        {
        case Type.RefError:
            throwRefError();
            assert(0);
        case Type.Undefined:
            return Key.undefined;
        case Type.Null:
            return Key._null;
        case Type.Boolean:
            return _dbool ? Key._true : Key._false;
        case Type.Number:
            return NumberToString(_number);
        case Type.String, Type.Symbol:
            return _text;
        case Type.Object:
        {
            Value val;
            toPrimitive(cc, val, Type.String);
            if(val.isPrimitive)
                return val.toString(cc);
            else
                return val.toObject.classname;
        }
        case Type.Iter:
            assert(0);
        }
        assert(0);
    }

//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    // needs more implementation.
    string toLocaleString(ref CallContext cc)
    {
        return toString(cc);
    }

    //--------------------------------------------------------------------
    string toString(ref CallContext cc, in int radix)
    {
        import std.math : isFinite;
        import std.conv : to;

        if(_type == Type.Number)
        {
            assert(2 <= radix && radix <= 36);
            if(!isFinite(_number))
                return toString(cc);
            return _number >= 0.0 ?
                to!string(cast(long)_number, radix) :
                "-" ~ to!string(cast(long) - _number, radix);
        }
        else
        {
            return toString(cc);
        }
    }

    //--------------------------------------------------------------------
    string toSource(ref CallContext cc)
    {
        import dmdscript.dglobal : undefined;

        switch(_type)
        {
        case Type.String:
        {
            string s;

            s = "\"" ~ _text ~ "\"";
            return s;
        }
        case Type.Symbol:
            return _text;
        case Type.Object:
        {
            Value* v;

            auto pk = PropertyKey(Key.toSource);
            v = Get(pk, cc);
            if(!v)
                v = &undefined;
            if(v.isPrimitive())
                return v.toSource(cc);
            else          // it's an Object
            {
                DError* a;
                Dobject o;
                Value* ret;
                Value val;

                o = v._object;
                ret = &val;
                a = o.Call(cc, this._object, *ret, null);
                if(a)                             // if exception was thrown
                {
                    debug writef("Vobject.toSource() failed with %x\n", a);
                }
                else if(ret.isPrimitive())
                    return ret.toString(cc);
            }
            return Key.undefined;
        }
        default:
            return toString(cc);
        }
        assert(0);
    }

    //--------------------------------------------------------------------
    @trusted
    Dobject toObject()
    {
        import dmdscript.dstring : Dstring;
        import dmdscript.dnumber : Dnumber;
        import dmdscript.dboolean : Dboolean;
        import dmdscript.dsymbol : Dsymbol;

        final switch(_type)
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
            return new Dboolean(_dbool);
        case Type.Number:
            return new Dnumber(_number);
        case Type.String:
            return new Dstring(_text);
        case Type.Symbol:
            return new Dsymbol(this);
        case Type.Object:
            return _object;
        case Type.Iter:
            assert(0);
        }
        assert(0);
    }

    //--------------------------------------------------------------------
    @disable
    double ToLength(ref CallContext cc)
    {
        import std.math : isInfinity;
        enum MAX_LENGTH = (2UL ^^ 53) - 1;

        auto len = toInteger(cc);
        if      (len < 0) return 0;
        else if (len.isInfinity) return MAX_LENGTH;
        else if (MAX_LENGTH < len) return MAX_LENGTH;
        else return len;
    }

    //--------------------------------------------------------------------
    @safe
    bool opEquals(in ref Value v) const
    {
        return(opCmp(v) == 0);
    }

    //--------------------------------------------------------------------
    @trusted
    int opCmp()(in auto ref Value v) const
    {
        import std.math : isNaN;
        import dmdscript.primitive : stringcmp;

        final switch(_type)
        {
        case Type.RefError:
            throwRefError();
            assert(0);
        case Type.Undefined:
            if(_type == v._type)
                return 0;
            break;
        case Type.Null:
            if(_type == v._type)
                return 0;
            break;
        case Type.Boolean:
            if(_type == v._type)
                return v._dbool - _dbool;
            break;
        case Type.Number:
            if(v._type == Type.Number)
            {
                if(_number == v._number)
                    return 0;
                if(isNaN(_number) && isNaN(v._number))
                    return 0;
                if(_number > v._number)
                    return 1;
            }
            else if(v._type == Type.String)
            {
                return stringcmp(NumberToString(_number), v._text);
            }
            break;
        case Type.String:
            if(v._type == Type.String)
            {
                return stringcmp(_text, v._text);
            }
            else if(v._type == Type.Number)
            {
                return stringcmp(_text, NumberToString(v._number));
            }
            break;
        case Type.Symbol:
            if (v._type == Type.Symbol)
                return (_hash == v._hash) ? 0 : -1;
            else
                return -1;
        case Type.Object:
            if(v._object == _object)
                return 0;
            break;
        case Type.Iter:
            assert(0);
        }
        return -1;
    }

    //--------------------------------------------------------------------
    @trusted
    string getTypeof()
    {
        final switch(_type)
        {
        case Type.RefError:
        case Type.Undefined:   return Key.undefined;
        case Type.Null:        return Text.object;
        case Type.Boolean:     return Text.boolean;
        case Type.Number:      return Key.number;
        case Type.String:      return Text.string;
        case Type.Object:      return _object.getTypeof;
        case Type.Symbol:      return Key.Symbol;
        case Type.Iter:
            assert(0);
        }
    }

    //--------------------------------------------------------------------
    @property @safe @nogc pure nothrow
    bool isEmpty() const
    {
        return _type == Type.RefError;
    }

    @property @safe @nogc pure nothrow
    bool isUndefined() const
    {
        return _type == Type.Undefined;
    }
    @property @safe @nogc pure nothrow
    bool isNull() const
    {
        return _type == Type.Null;
    }
    @property @safe @nogc pure nothrow
    bool isBoolean() const
    {
        return _type == Type.Boolean;
    }
    @property @safe @nogc pure nothrow
    bool isNumber() const
    {
        return _type == Type.Number;
    }
    @property @safe @nogc pure nothrow
    bool isString() const
    {
        return _type == Type.String;
    }
    @property @safe @nogc pure nothrow
    bool isObject() const
    {
        return _type == Type.Object;
    }
    @property @safe @nogc pure nothrow
    bool isIterator() const
    {
        return _type == Type.Iter;
    }

    @property @safe @nogc pure nothrow
    bool isUndefinedOrNull() const
    {
        return _type == Type.Undefined || _type == Type.Null;
    }
    @property @safe @nogc pure nothrow
    bool isPrimitive() const
    {
        return _type != Type.Object;
    }

// deprecated
//     @trusted
//     bool isArrayIndex(ref CallContext cc, out uint index)
//     {
//         switch(_type)
//         {
//         case Type.Number:
//             index = toUint32(cc);
//             return true;
//         case Type.String:
//             return StringToIndex(_text, index);
//         default:
//             index = 0;
//             return false;
//         }
//         assert(0);
//     }

    @disable
    bool isArray()
    {
        import dmdscript.darray : Darray;
        if (_type != Type.Object)
            return false;
        if (auto a = cast(Darray)_object)
            return true;
//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// implement about Proxy exotic object
        return false;
    }

    @disable
    bool isCallable() const
    {
        import dmdscript.dfunction : Dfunction;
        if (_type != Type.Object)
            return false;
        return (cast(Dfunction)_object) !is null;
    }

    @disable
    bool isConstructor() const
    {
        import dmdscript.dfunction : Dconstructor;
        if (_type != Type.Object)
            return false;
        return (cast(Dconstructor)_object) !is null;
    }

    @disable
    bool isExtensible() const
    {
        if (_type != Type.Object)
            return false;
        assert(_object !is null);
        return _object.IsExtensible;
    }

    @disable
    bool isInteger() const
    {
        import std.math : floor, isInfinity;
        if (_type != Type.Number)
            return false;
        if (_number.isInfinity)
            return false;
        return _number.floor == _number;
    }


    //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    @disable
    bool isPropertyKey() const
    {
        return _type == Type.String;
    }

    //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    @disable
    bool isRegExp() const
    {
        import dmdscript.dregexp : Dregexp;
        if (_type != Type.Object)
            return false;
        return (cast(Dregexp)_object) !is null;
    }

    //--------------------------------------------------------------------
    @disable
    bool SameValueZero(in ref Value r) const
    {
        import std.math : isNaN;
        if (_type != r._type)
            return false;
        if (_type == Type.Number)
        {
            if (_number.isNaN && r._number.isNaN)
                return true;
            return _number == r._number;
        }
        else return SameValueNonNumber(r);
    }

    //--------------------------------------------------------------------
    @disable
    bool SameValueNonNumber(in ref Value r) const
    {
        assert(_type == r._type);
        final switch(_type)
        {
        case Type.Undefined:
        case Type.Null:
            return true;
        case Type.String:
            return 0 == stringcmp(_text, r._text);
        case Type.Boolean:
            return _dbool == r._dbool;
        case Type.Symbol:
            return _hash == r._hash;
        case Type.Object:
            return _object is r._object;

        case Type.RefError, Type.Number, Type.Iter:
            assert(0);
        }
    }

    //--------------------------------------------------------------------
    @trusted
    size_t toHash()
    {
        import dmdscript.primitive : calcHash;

        final switch(_type)
        {
        case Type.RefError:
            throwRefError();
            assert(0);
        case Type.Undefined:
        case Type.Null:
            return 0;
        case Type.Boolean:
            return _dbool ? 1 : 0;
        case Type.Number:
            return calcHash(_number);
        case Type.String:
            // Since strings are immutable, if we've already
            // computed the hash, use previous value
            if(0 == _hash)
                _hash = calcHash(_text);
            return _hash;
        case Type.Symbol:
            return _hash;
        case Type.Object:
            /* Uses the address of the object as the hash.
             * Since the object never moves, it will work
             * as its hash.
             * BUG: shouldn't do this.
             */
            return cast(uint)cast(void*)_object;
        case Type.Iter:
            assert(0);
        }
    }

    //--------------------------------------------------------------------
    Value* Get(in PropertyKey PropertyName, ref CallContext cc)
    {
        import std.conv : to;

        if(_type == Type.Object)
            return _object.Get(PropertyName, cc);
        else
        {
            // Should we generate the error, or just return undefined?
            throw CannotGetFromPrimitiveError
                .toThrow(PropertyName.toString, _type.to!string,
                         toString(cc));
            //return &vundefined;
        }
    }

    //--------------------------------------------------------------------
    DError* Set(K, V)(in auto ref K name, auto ref V value, ref CallContext cc)
        if (canHave!V && PropertyKey.IsKey!K)

    {
        import std.conv : to;

        if(_type == Type.Object)
        {
            return _object.Set(name, value, Property.Attribute.None, cc);
        }
        else
        {
            static if      (is(K : PropertyKey))
            {
                return CannotPutToPrimitiveError(
                    name.toString, value.toString(cc), getTypeof);
            }
            else static if (is(K : uint))
            {
                return CannotPutIndexToPrimitiveError(
                    name, value.toString(cc), _type.to!string);
            }
            else
            {
                return CannotPutToPrimitiveError(name, value.toString(cc),
                                                 _type.to!string);
            }
        }
    }

    //--------------------------------------------------------------------
    Value* GetV(K)(in auto ref K PropertyName, ref CallContext cc)
        if (PropertyKey.IsKey!K)
    {
        if (auto obj = toObject)
            return obj.Get(PropertyName, cc);
        else
            return null;
    }

    //--------------------------------------------------------------------
    @disable
    Value* GetMethod(K)(in auto ref K PropertyName, ref CallContext cc)
        if (PropertyKey.IsKey!K)
    {
        import dmdscript.errmsgs;

        if (auto func = GetV(PropertyName, cc))
        {
            if (func.isCallable)
                return func;
            else
            {
                auto pk = PropertyKey(PropertyName);
                throw NotCallableError.toThrow(pk.toString);
            }
        }
        else
            return null;
    }


    //--------------------------------------------------------------------
    DError* Call(ref CallContext cc, Dobject othis, out Value ret,
                 Value[] arglist)
    {
        import std.conv : to;

        if(_type == Type.Object)
        {
            DError* a;

            a = _object.Call(cc, othis, ret, arglist);
            //if (a) writef("Vobject.Call() returned %x\n", a);
            return a;
        }
        else if(_type == Type.RefError)
        {
            throwRefError();
            assert(0);
        }
        else
        {
            //PRINTF("Call method not implemented for primitive %p (%s)\n", this, string_t_ptr(toString()));
            ret.putVundefined();
            return PrimitiveNoCallError(_type.to!string);
        }
    }

    //--------------------------------------------------------------------
    DError* Construct(ref CallContext cc, out Value ret, Value[] arglist)
    {
        import std.conv : to;
        if(_type == Type.Object)
            return _object.Construct(cc, ret, arglist);
        else if(_type == Type.RefError){
            throwRefError();
            assert(0);
        }
        else
        {
            ret.putVundefined();
            return PrimitiveNoConstructError(_type.to!string);
        }
    }

    //--------------------------------------------------------------------
    DError* putIterator(out Value v)
    {
        if(_type == Type.Object)
            return _object.putIterator(v);
        else
        {
            v.putVundefined();
            return ForInMustBeObjectError;
        }
    }

    //--------------------------------------------------------------------
    DError* Invoke(K)(in auto ref K key, ref CallContext cc,
                      out Value ret, Value[] args)
        if (PropertyKey.IsKey!K)
    {
        if (auto f = GetV(key, cc))
            return f.Call(cc, object, ret, args);
        else
            return null;
    }

    //====================================================================
private:
    size_t  _hash;               // cache 'hash' value
    Type _type = Type.Undefined;
    union
    {
        bool      _dbool;        // can be true or false
        double    _number;
        string   _text;
        Dobject   _object;
        int       _int32;
        uint      _uint32;
        ushort    _uint16;

        Iterator* _iter;         // V_ITER
    }

    //
    @trusted
    void throwRefError() const
    {
        throw UndefinedVarError.toThrow(_text);
    }

    //
    @trusted @nogc pure nothrow
    void putSignalingUndefined(string id)
    {
        _type = Type.RefError;
        _text = id;
    }
}
static if (size_t.sizeof == 4)
  static assert(Value.sizeof == 16);
else static if (size_t.sizeof == 8)
  static assert(Value.sizeof == 32); //fat string point 2*8 + type tag & hash
else static assert(0, "This machine is not supported.");

//------------------------------------------------------------------------------
enum vundefined = Value(Value.Type.Undefined);
//
enum vnull = Value(Value.Type.Null);

//------------------------------------------------------------------------------
@safe pure nothrow
Value* signalingUndefined(in string id)
{
    auto p = new Value;
    p.putSignalingUndefined(id);
    return p;
}

//------------------------------------------------------------------------------
//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// check this.
@disable
Value* CanonicalNumericIndexString(ref CallContext cc, in string str)
{
    import dmdscript.dglobal : undefined;
    import dmdscript.primitive : stringcmp;

    auto value = new Value;
    if (str == "-0")
    {
        value.put(-0.0);
    }
    else
    {
        Value v;
        v.put(str);
        auto number = v.toNumber(cc);
        debug
        {
            Value v2;
            v2.put(number);
            if(0 != stringcmp(v2.toString(cc), str))
                return &undefined;
        }
        value.put(number);
    }
    return value;
}


//------------------------------------------------------------------------------
/* DError contains the ending status of a function.
Mostly, this contains a ScriptException.
DError is needed for catch statements in the script.
 */
struct DError
{
    import dmdscript.opcodes : IR;
    import dmdscript.exception : ScriptException;
    import dmdscript.protoerror : D0base;
    import dmdscript.callcontext : CallContext;

    Value entity;
    alias entity this;

    ///
    this(ref CallContext cc, ref Value v,
         string file = __FILE__, size_t line = __LINE__)
    {
        import dmdscript.protoerror : typeerror;

        if (v.type == Value.Type.Object)
        {
            entity = v;
        }
        else
        {
            entity.put(new typeerror(
                           new ScriptException(typeerror.Text, v.toString(cc),
                                               file, line)));
        }
    }

    ///
    @safe @nogc pure nothrow
    this(D0base err)
    {
        entity.put(err);
    }


    ///
deprecated
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        import dmdscript.protoerror : typeerror;
        entity.put(new typeerror(new ScriptException(typeerror.Text, msg,
                                                     file, line)));
    }

    ///
    ScriptException toScriptException(ref CallContext cc)
    {
        import dmdscript.protoerror;

        if (auto d0 = cast(D0base)entity.toObject)
            return d0.exception;
        else
        {
            auto msg = entity.toString(cc);
            string name = typeerror.Text;
            auto pk = PropertyKey(Key.constructor);
            if (auto constructor = entity.Get(pk, cc))
                name = constructor.object.classname;
            return new ScriptException(name, msg);
        }
    }

    ///
    @safe @nogc pure nothrow
    void addTrace(string sourcename, string funcname, string srctext)
    {
        import dmdscript.protoerror;

        if (auto d0 = cast(D0base)entity.object)
        {
            assert(d0.exception);
            d0.exception.addTrace(sourcename, funcname, srctext);
        }
    }

    ///
    @safe pure
    void addTrace(const(IR)* base, const(IR)* code,
                  string f = __FILE__, size_t l = __LINE__)
    {
        import dmdscript.protoerror;
        if (auto d0 = cast(D0base)entity.object)
        {
            assert(d0.exception);
            d0.exception.addTrace(base, code, f, l);
        }
    }

    ///
    @safe pure
    void addMessage(string message)
    {
        import dmdscript.protoerror;

        if (auto d0 = cast(D0base)entity.object)
        {
            assert(d0.exception);
            d0.exception.addMessage(message);
        }
    }
}

//==============================================================================
package:

@trusted
DError* toDError(alias Proto = typeerror)(Throwable t)
{
    import dmdscript.exception : ScriptException;
    import dmdscript.protoerror : newD0, typeerror;

    assert(t !is null);
    ScriptException exception;

    if (auto se = cast(ScriptException)t)
        return new DError(newD0(se));
    else
    {
        exception = new ScriptException(Proto.Text,
                                        t.toString, t.file, t.line);
        assert(exception !is null);
        return new DError(new Proto(exception));
    }
}

