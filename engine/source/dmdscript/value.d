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

import dmdscript.primitive: Key, PropertyKey;
import dmdscript.dobject: Dobject;
import dmdscript.property: Property;
import dmdscript.errmsgs;
import dmdscript.callcontext: CallContext;
import dmdscript.protoerror: cTypeError = TypeError;
import dmdscript.derror: Derror, onError;
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
    import std.bigint: BigInt;

    // NEVER import dmdscript.dfunction : Dfunction at here.
    import dmdscript.iterator : Iterator;
    import dmdscript.primitive;
    import dmdscript.property : PropTable;
    import dmdscript.drealm: Drealm;


    //--------------------------------------------------------------------
    enum Type : ubyte
    {
        RefError,//triggers ReferenceError expcetion when accessed

        Undefined,
        Null,
        Boolean,
        Number,
        BigInt,
        String,
        Object,

        Iter,
        Symbol,
    }

    static @safe @nogc pure nothrow
    string toString(in Type t)
    {
        final switch (t)
        {
        case Type.RefError:  return Type.RefError.stringof;
        case Type.Undefined: return Type.Undefined.stringof;
        case Type.Null:      return Type.Undefined.stringof;
        case Type.Boolean:   return Type.Boolean.stringof;
        case Type.Number:    return Type.Number.stringof;
        case Type.BigInt:    return Type.BigInt.stringof;
        case Type.String:    return Type.String.stringof;
        case Type.Object:    return Type.Object.stringof;
        case Type.Iter:      return Type.Iter.stringof;
        case Type.Symbol:    return Type.Symbol.stringof;
        }
        assert (0);
    }

    //--------------------------------------------------------------------
    template canHave(T)
    {
        enum canHave = is(T == bool) || is(T == const(bool)) ||
            is(T : Type) || is(T : PropertyKey) || is(T : double) ||
            is(T : string) || is(T : Dobject) || is(T == Iterator*) ||
            is(T : Value) || is(T : BigInt*);
    }

    //--------------------------------------------------------------------
    @safe @nogc pure nothrow
    this(T)(auto ref T arg) if (canHave!T)
    {
        put(arg);
    }

    //--------------------------------------------------------------------
    @safe @nogc pure nothrow
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

        inout(BigInt)* bigInt() inout
        {
            assert (_type == Type.BigInt);
            return _bi;
        }

        string text() const
        {
            assert (_type == Type.String || _type == Type.Symbol ||
                    _type == Type.RefError);
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
    nothrow
    Derror checkReference(CallContext* cc) const
    {
        if(_type == Type.RefError)
        {
            return UndefinedVarError(cc, _text);
        }
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
    @trusted @nogc pure nothrow
    void putVsymbol()(in auto ref PropertyKey s)
    {
        assert (s.isSymbol);
        _type = Type.Symbol;
        _text = s.text;
        _hash = s.hash;
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
        else static if (is(T == BigInt*))
        {
            assert (t !is null);
            _type = Type.BigInt;
            _bi = t;
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
        else static if (is(T : BigInt*))
        {
            assert (t !is null);
            _type = Type.BigInt;
            _bi = t;
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
    /*
      the parameter v may equal to this.
      so you should not qualify v with 'out'.
     */
    nothrow
    Derror toPrimitive(ref Value v, CallContext* cc,
                        in Type PreferredType = Type.RefError)
    {
        Derror err;

        if     (_type == Type.Object)
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
            if (_object.DefaultValue(v, cc, PreferredType).onError(err))
                return err;

            if(!v.isPrimitive)
            {
                v.putVundefined;
                return ObjectCannotBePrimitiveError(cc);
            }
        }
        else if (_type == Type.RefError)
            return UndefinedVarError(cc, _text);
        else
        {
            v = this;
        }
        return null;
    }

    //--------------------------------------------------------------------
    @trusted nothrow
    Derror to(T : bool)(out T b, CallContext* cc) const
    {
        import std.math : isNaN;

        final switch(_type)
        {
        case Type.RefError:
            b = false;
            return UndefinedVarError(cc, _text);
        case Type.Undefined, Type.Null, Type.Iter:
            b = false;
            break;
        case Type.Boolean:
            b = _dbool;
            break;
        case Type.Number:
            b = !(_number == 0.0 || isNaN(_number));
            break;
        case Type.String:
            b = 0 < _text.length;
            break;
        case Type.Symbol:
            b = true;
            break;
        case Type.Object:
            b =true;
            break;
        case Type.BigInt:
            b = (*_bi) != 0;
            break;
        }
        return null;
    }

    //--------------------------------------------------------------------
    @trusted nothrow
    Derror to(T : double)(out T n, CallContext* cc)
    {
        import std.uni : isWhite;

        final switch(_type)
        {
        case Type.RefError:
            n = double.nan;
            return UndefinedVarError(cc, _text);
        case Type.Undefined, Type.Iter:
            n = double.nan;
            break;
        case Type.Null:
            n = 0;
            break;
        case Type.Boolean:
            n = _dbool ? 1 : 0;
            break;
        case Type.Number:
            n = _number;
            break;
        case Type.BigInt:
            n = double.nan; // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
            break;
        case Type.String, Type.Symbol:
        {
            size_t len;
            size_t endidx;

            len = _text.length;
            n = StringNumericLiteral(_text, endidx, 0);

            // Consume trailing whitespace
            for (auto c = _text.ptr + endidx; c < _text.ptr + _text.length;
                 ++c)
            {
                if(!(*c).isWhite)
                {
                    n = double.nan;
                    break;
                }
            }

            break;
        }
        case Type.Object:
        {
            Value val;
            Value* v;
            // void* a;

            v = &val;
            toPrimitive(*v, cc, Type.Number);
            /*a = toPrimitive(v, TypeNumber);
              if(a)//rerr
              return double.nan;*/
            if(v.isPrimitive)
                return v.to(n, cc);
            else
                n = double.nan;
            break;
        }
        }
        return null;
    }

    //--------------------------------------------------------------------
    @trusted nothrow
    Derror toDtime(out d_time t, CallContext* cc)
    {
        double d;
        Derror err;
        if (!to(d, cc).onError(err))
            t = cast(d_time)d;
        return err;
    }

    //--------------------------------------------------------------------
    @trusted nothrow
    Derror toInteger(out double number, CallContext* cc)
    {
        import std.math : floor, isInfinity, isNaN;

        Derror err;

        final switch(_type)
        {
        case Type.RefError:
            number = double.nan;
            err = UndefinedVarError(cc, _text);
            break;
        case Type.Undefined:
            number =  double.nan;
            break;
        case Type.Null:
            number = 0;
            break;
        case Type.Boolean:
            number = _dbool ? 1 : 0;
            break;

        case Type.Number, Type.String, Type.Object, Type.Iter, Type.Symbol,
            Type.BigInt:
        {
            if (to(number, cc).onError(err))
                break;
            if(number.isNaN)
                number = 0;
            else if(number == 0 || isInfinity(number))
            {
            }
            else if(number > 0)
                number = floor(number);
            else
                number = -floor(-number);
            break;
        }
        }
        return err;
    }

    //--------------------------------------------------------------------
    @trusted nothrow
    Derror to(T : int)(out T i, CallContext* cc)
    {
        import std.math : floor, isInfinity, isNaN;

        Derror err;

        final switch(_type)
        {
        case Type.RefError:
            i = 0;
            err = UndefinedVarError(cc, _text);
            break;
        case Type.Undefined, Type.Null:
            i = 0;
            break;
        case Type.Boolean:
            i = _dbool ? 1 : 0;
            break;

        case Type.Number, Type.String, Type.Object, Type.Iter, Type.Symbol,
            Type.BigInt:
        {
            double n;
            long ll;

            if (to(n, cc).onError(err))
                break;
            if(isNaN(n))
                i = 0;
            else if(n == 0 || isInfinity(n))
                i = 0;
            else
            {
                if(n > 0)
                    n = floor(n);
                else
                    n = -floor(-n);

                ll = cast(long)n;
                i = cast(T)ll;
            }
            break;
        }
        }
        return err;
    }


    // //--------------------------------------------------------------------
    // @safe
    // ubyte toUint8Clamp(CallContext* cc)
    // {
    //     import std.math : lrint, isInfinity, isNaN;

    //     final switch(_type)
    //     {
    //     case Type.RefError:
    //         throwRefError();
    //         assert(0);
    //     case Type.Undefined, Type.Null:
    //         return 0;
    //     case Type.Boolean:
    //         return cast(ubyte)(_dbool ? 1 : 0);

    //     case Type.Number, Type.String, Type.Object, Type.Iter, Type.Symbol,
    //         Type.BigInt:
    //     {
    //         ubyte uint8;
    //         double number;

    //         number = toNumber(cc);
    //         if      (isNaN(number))
    //             uint8 = 0;
    //         else if (number <= 0)
    //             uint8 = 0;
    //         else if (255 <= number)
    //             uint8 = 255;
    //         else if (isInfinity(number))
    //             uint8 = ubyte.max;
    //         else
    //             uint8 = cast(ubyte)lrint(number);
    //         return uint8;
    //     }
    //     }
    //     assert(0);
    // }

    //--------------------------------------------------------------------
    nothrow
    Derror to(T : PropertyKey)(out T pk, CallContext* cc)
    {
        import std.format: format;

        Derror err;
        final switch(_type)
        {
        case Type.RefError:
            err = UndefinedVarError(cc, _text);
            break;
        case Type.Undefined:
            pk = Key.undefined;
            break;
        case Type.Null:
            pk = Key._null;
            break;
        case Type.Boolean:
            pk = _dbool ? Key._true : Key._false;
            break;
        case Type.Number:
            if (0 <= _number)
            {
                auto i32 = cast(size_t)_number;
                if (_number == cast(double)i32)
                {
                    pk = PropertyKey(i32);
                    break;
                }
            }
            pk = PropertyKey(NumberToString(_number));
            break;
        case Type.BigInt:
            if (0 <= (*_bi))
            {
                auto i32 = _bi.uintLength;
                if ((*_bi) == i32)
                {
                    pk = PropertyKey(i32);
                    break;
                }
            }
            try pk = PropertyKey("%d".format(*_bi));
            catch (Throwable) pk = Key.BigInt;
            break;

        case Type.String:
        {
            size_t i32;
            if      (StringToIndex(_text, i32))
                pk = PropertyKey(i32);
            else if (0 < _hash)
                pk = PropertyKey(_text, _hash);
            else
            {
                _hash = calcHash(_text);
                pk = PropertyKey(_text, _hash);
            }
            break;
        }
        case Type.Symbol:
            if (0 < _hash)
                pk = PropertyKey(_text, _hash);
            else
            {
                _hash = ~calcHash(_text);
                pk = PropertyKey(_text, _hash);
            }
            break;
        case Type.Object:
        {
            string s;
            if (to(s, cc).onError(err))
                break;
            pk = PropertyKey(s);
            break;
        }
        case Type.Iter:
            assert(0);
        }

        return err;
    }

    //--------------------------------------------------------------------
    nothrow
    Derror to(T : string)(out T s, CallContext* cc)
    {
        import std.format: format;

        Derror err;
        final switch(_type)
        {
        case Type.RefError:
            err = UndefinedVarError(cc, _text);
            break;
        case Type.Undefined:
            s = Key.undefined;
            break;
        case Type.Null:
            s = Key._null;
            break;
        case Type.Boolean:
            s = _dbool ? Key._true : Key._false;
            break;
        case Type.Number:
            s = NumberToString(_number);
            break;
        case Type.BigInt:
            try s = "%d".format(*_bi);
            catch(Throwable) s = "BigInt";
            break;
        case Type.String, Type.Symbol:
            s = _text;
            break;
        case Type.Object:
        {
            Value val;
            if (toPrimitive(val, cc, Type.String).onError(err))
                break;
            if(val.isPrimitive)
            {
                return val.to(s, cc);
            }
            else
            {
                Dobject o;
                if      (!val.to(o, cc).onError(err) && o !is null)
                    s = o.classname;
                else
                    s = "Object";
            }
            break;
        }
        case Type.Iter:
            assert(0);
        }
        return err;
    }

//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    // needs more implementation.
    nothrow
    Derror toLocaleString(out string s, CallContext* cc)
    {
        Derror err;
        to(s, cc).onError(err);
        return err;
    }

    //--------------------------------------------------------------------
    nothrow
    Derror to(T : string)(out T s, in int radix, CallContext* cc)
    {
        import std.math : isFinite;
        import std.conv : sto = to;

        Derror err;
        if(_type == Type.Number)
        {
            assert(2 <= radix && radix <= 36);
            if(!isFinite(_number))
            {
                to(s, cc).onError(err);
            }
            else
            {
                try s = _number >= 0.0 ?
                        sto!string(cast(long)_number, radix) :
                        "-" ~ sto!string(cast(long) - _number, radix);
                catch (Throwable) s = "number";
            }
        }
        else if (_type == Type.BigInt)
        {
            assert(2 <= radix && radix <= 36);
            try s = 0 <= (*_bi) ?
                    sto!string(_bi.toLong, radix) :
                    "-" ~ sto!string(_bi.toLong, radix);
            catch (Throwable) s = "BigInt";
        }
        else
        {
            to(s, cc).onError(err);
        }
        return err;
    }

    //--------------------------------------------------------------------
    nothrow
    Derror toSource(out string s, CallContext* cc)
    {
        import std.format: format;

        Derror err;
        switch(_type)
        {
        case Type.String:
        {
            s = "\"" ~ _text ~ "\"";
            break;
        }
        case Type.BigInt:
            try s = "%dn".format(*_bi);
            catch (Throwable) s = "BigInt";
            break;
        case Type.Symbol:
            s = _text;
            break;
        case Type.Object:
        {
            Value v;

            auto pk = PropertyKey(Key.toSource);
            if (Get(pk, v, cc).onError(err))
                break;
            if(v.isEmpty)
                v.putVundefined;
            if(v.isPrimitive)
            {
                if (v.toSource(s, cc).onError(err))
                    break;
            }
            else          // it's an Object
            {
                Dobject o;
                Value val;

                o = v._object;
                if (o.Call(cc, this._object, val, null).onError(err))
                    break;
                // if(a)                             // if exception was thrown
                // {
                //     a.addTrace(cc, f, l);
                //     return a;
                //    // debug writef("Vobject.toSource() failed with %x\n", a);
                // }
                else if(val.isPrimitive)
                {
                    if (val.to(s, cc).onError(err))
                        break;
                }
            }
            s = Key.undefined;
            break;
        }
        default:
            to(s, cc).onError(err);
        }
        return err;
    }

    //--------------------------------------------------------------------
    @trusted nothrow
    Derror to(T : Dobject)(out T o, CallContext* cc)
    {
        import dmdscript.dstring : Dstring;
        import dmdscript.dnumber : Dnumber;
        import dmdscript.dboolean : Dboolean;
        import dmdscript.dsymbol : Dsymbol;

        Derror err;
        final switch(_type)
        {
        case Type.RefError:
            err = UndefinedVarError(cc, _text);
            break;
        case Type.Undefined:
            err = CannotConvertToObject2Error(cc, "undefined", _text);
            break;
            //RuntimeErrorx("cannot convert undefined to Object");
        case Type.Null:
            //RuntimeErrorx("cannot convert null to Object");
            err = CannotConvertToObject2Error(cc, "Null", _text);
            break;
        case Type.Boolean:
            o = cc.realm.dBoolean(_dbool);
            break;
        case Type.Number:
            o = cc.realm.dNumber(_number);
            break;
        case Type.BigInt:
            o = cc.realm.dBigInt(_bi);
            break;
        case Type.String:
            o = cc.realm.dString(_text);
            break;
        case Type.Symbol:
            o = cc.realm.dSymbol(this);
            break;
        case Type.Object:
            o =_object;
            break;
        case Type.Iter:
            assert(0);
        }
        return err;
    }

    //--------------------------------------------------------------------
    @disable nothrow
    Derror ToLength(out double n, CallContext* cc)
    {
        import std.math : isInfinity;
        enum MAX_LENGTH = (2UL ^^ 53) - 1;

        Derror err;
        if (toInteger(n, cc).onError(err)){}
        else if (n < 0) n = 0;
        else if (n.isInfinity) n = MAX_LENGTH;
        else if (MAX_LENGTH < n) n = MAX_LENGTH;
        return err;
    }

    //--------------------------------------------------------------------
    @trusted nothrow
    string toString() const
    {
        import std.format: format;

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
        case Type.BigInt:
            try return "%d".format(*_bi);
            catch (Throwable) return "BigInt";
        case Type.String, Type.Symbol:
            return _text;
        case Type.Object:
            return Key.Object;
        case Type.Iter:
            assert(0);
        }
        assert(0);
    }

    // use equals()
    @disable
    bool opEquals(in ref Value v) const{ return true;}
    // use cmp();
    @disable
    int opCmp(in ref Value v) const { return 0; }

    //--------------------------------------------------------------------
    @trusted nothrow
    Derror equals(in ref Value v, out bool b, CallContext* cc) const
    {
        import std.math : isNaN;
        import dmdscript.primitive : stringcmp;

        Derror err;
        final switch(_type)
        {
        case Type.RefError:
            err = UndefinedVarError(cc, _text);
            break;

        case Type.Undefined, Type.Null:
            b =  _type == v._type;
            break;

        case Type.Boolean:
            b = Type.Boolean == v._type && v._dbool == _dbool;
            break;

        case Type.Number:
            if(v._type == Type.Number)
            {
                b = _number == v._number ||
                    isNaN(_number) && isNaN(v._number);
            }
            else if(v._type == Type.String)
            {
                b = 0 == stringcmp(NumberToString(_number), v._text);
            }
            break;

        case Type.BigInt:
            b =  v._type == Type.BigInt && (*_bi) == (*v._bi);
            break;

        case Type.String:
            if(v._type == Type.String)
            {
                b = 0 == stringcmp(_text, v._text);
            }
            else if(v._type == Type.Number)
            {
                b = 0 == stringcmp(_text, NumberToString(v._number));
            }
            break;

        case Type.Symbol:
            b = v._type == Type.Symbol && _hash == v._hash;
            break;

        case Type.Object:
            b = v._type == Type.Object && v._object is _object;
            break;

        case Type.Iter:
            assert(0);
        }
        return null;
    }

    //--------------------------------------------------------------------
    @trusted nothrow
    Derror cmp()(in auto ref Value v, out int i, CallContext* cc) const
    {
        import std.math : isNaN;
        import dmdscript.primitive : stringcmp;

        Derror err;
        final switch(_type)
        {
        case Type.RefError:
            err = UndefinedVarError(cc, _text);
            break;
        case Type.Undefined:
            if(_type == v._type)
                i = 0;
            break;
        case Type.Null:
            if(_type == v._type)
                i = 0;
            break;
        case Type.Boolean:
            if(_type == v._type)
                i = v._dbool - _dbool;
            break;
        case Type.Number:
            if(v._type == Type.Number)
            {
                if(_number == v._number)
                    i = 0;
                if(isNaN(_number) && isNaN(v._number))
                    i = 0;
                if(_number > v._number)
                    i = 1;
            }
            else if(v._type == Type.String)
            {
                i = stringcmp(NumberToString(_number), v._text);
            }
            break;
        case Type.BigInt:
            if (v._type == Type.BigInt)
            {
                if      ((*_bi) == (*v._bi))
                    i = 0;
                else if ((*_bi) > (*v._bi))
                    i = 1;
            }
            break;
        case Type.String:
            if(v._type == Type.String)
            {
                i = stringcmp(_text, v._text);
            }
            else if(v._type == Type.Number)
            {
                i = stringcmp(_text, NumberToString(v._number));
            }
            break;
        case Type.Symbol:
            if (v._type == Type.Symbol)
                i = (_hash == v._hash) ? 0 : -1;
            else
                i = -1;
            break;
        case Type.Object:
            if(v._object == _object)
                i = 0;
            break;
        case Type.Iter:
            assert(0);
        }
        return null;
    }

    //--------------------------------------------------------------------
    @property @trusted @nogc pure nothrow
    string getTypeof() const
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
        case Type.BigInt:      return Key.BigInt;
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
        return _type != Type.Object && _type != Type.RefError;
    }

    @property @safe @nogc pure nothrow
    bool isBigInt() const
    {
        return _type == Type.BigInt;
    }

    @property @safe @nogc pure nothrow
    bool isSymbol() const
    {
        return _type == Type.Symbol;
    }

// deprecated
//     @trusted
//     bool isArrayIndex(CallContext cc, out uint index)
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

//     @disable
//     bool isArray()
//     {
//         import dmdscript.darray : Darray;
//         if (_type != Type.Object)
//             return false;
//         if (auto a = cast(Darray)_object)
//             return true;
// //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// // implement about Proxy exotic object
//         return false;
//     }

    @trusted @nogc pure nothrow
    bool isCallable() const
    {
        import dmdscript.dfunction : Dfunction;
        if (_type != Type.Object)
            return false;
        return (cast(Dfunction)_object) !is null;
    }

    // @disable
    // bool isConstructor() const
    // {
    //     import dmdscript.dfunction : Dconstructor;
    //     if (_type != Type.Object)
    //         return false;
    //     return (cast(Dconstructor)_object) !is null;
    // }

    // @disable
    // bool isExtensible() const
    // {
    //     if (_type != Type.Object)
    //         return false;
    //     assert(_object !is null);
    //     return _object.IsExtensible;
    // }

    // @disable
    // bool isInteger() const
    // {
    //     import std.math : floor, isInfinity;
    //     if (_type != Type.Number)
    //         return false;
    //     if (_number.isInfinity)
    //         return false;
    //     return _number.floor == _number;
    // }


    // //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    // @disable
    // bool isPropertyKey() const
    // {
    //     return _type == Type.String;
    // }

    // //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    // @disable
    // bool isRegExp() const
    // {
    //     import dmdscript.dregexp : Dregexp;
    //     if (_type != Type.Object)
    //         return false;
    //     return (cast(Dregexp)_object) !is null;
    // }

    // //--------------------------------------------------------------------
    // @disable
    // bool SameValueZero(in ref Value r) const
    // {
    //     import std.math : isNaN;
    //     if (_type != r._type)
    //         return false;
    //     if (_type == Type.Number)
    //     {
    //         if (_number.isNaN && r._number.isNaN)
    //             return true;
    //         return _number == r._number;
    //     }
    //     else return SameValueNonNumber(r);
    // }

    // //--------------------------------------------------------------------
    // @disable
    // bool SameValueNonNumber(in ref Value r) const
    // {
    //     assert(_type == r._type);
    //     final switch(_type)
    //     {
    //     case Type.Undefined:
    //     case Type.Null:
    //         return true;
    //     case Type.String:
    //         return 0 == stringcmp(_text, r._text);
    //     case Type.Boolean:
    //         return _dbool == r._dbool;
    //     case Type.Symbol:
    //         return _hash == r._hash;
    //     case Type.Object:
    //         return _object is r._object;

    //     case Type.RefError, Type.Number, Type.Iter, Type.BigInt:
    //         assert(0);
    //     }
    // }

    //--------------------------------------------------------------------
    @trusted nothrow
    Derror toHash(out size_t h, CallContext* cc)
    {
        import dmdscript.primitive : calcHash;

        Derror err;
        final switch(_type)
        {
        case Type.RefError:
            err = UndefinedVarError(cc, _text);
            break;
        case Type.Undefined:
        case Type.Null:
            h = 0;
            break;
        case Type.Boolean:
            h = _dbool ? 1 : 0;
            break;
        case Type.Number:
            h = calcHash(_number);
            break;
        case Type.String:
            // Since strings are immutable, if we've already
            // computed the hash, use previous value
            if(0 == _hash)
                _hash = calcHash(_text);
            h = _hash;
            break;
        case Type.Symbol:
            h = _hash;
            break;
        case Type.Object:
            /* Uses the address of the object as the hash.
             * Since the object never moves, it will work
             * as its hash.
             * BUG: shouldn't do this.
             */
            h = cast(uint)cast(void*)_object;
            break;
        case Type.Iter:
            assert(0);
        case Type.BigInt:
            if (0 == _hash)
                _hash = _bi.toHash;
            h = _hash;
            break;
        }
        return err;
    }

    //--------------------------------------------------------------------
    nothrow
    Derror Get(in PropertyKey PropertyName, out Value ret, CallContext* cc)
    {
        Derror err;
        if(_type == Type.Object)
        {
            _object.Get(PropertyName, ret, cc).onError(err);
        }
        else
        {
            // Should we generate the error, or just return undefined?
            string s;
            to(s, cc);
            err = CannotGetFromPrimitiveError
                (cc, PropertyName.toString, toString(_type), s);
            ret.putVundefined;
        }
        return err;
    }

    nothrow
    Derror GetProperty(
        in ref PropertyKey name, out Property* ret, out Dobject othis,
        CallContext* cc)
    {
        Derror err;
        if (_type == Type.Object)
        {
            ret = _object.GetProperty(name);
            othis = _object;
        }
        else
        {
            string s;
            to(s, cc);
            err = CannotGetFromPrimitiveError(
                cc, name.toString, toString(_type), s);
            ret = null;
        }
        return err;
    }

    //--------------------------------------------------------------------
    nothrow
    Derror Set(K, V)(in auto ref K name, auto ref V value, CallContext* cc)
        if (canHave!V && PropertyKey.IsKey!K)

    {
        import std.conv : to;

        Derror err;
        if(_type == Type.Object)
        {
            _object.Set(name, value, Property.Attribute.None, cc).onError(err);
        }
        else
        {
            string s;
            value.to(s, cc);
            static if      (is(K : PropertyKey))
            {
                err = CannotPutToPrimitiveError(cc,
                    name.toString, s, getTypeof);
            }
            else static if (is(K : uint))
            {
                err = CannotPutIndexToPrimitiveError(cc,
                    name, s, _type.to!string);
            }
            else
            {
                err = CannotPutToPrimitiveError(
                    cc, name, s, _type.to!string);
            }
        }
        return err;
    }

    //--------------------------------------------------------------------
    nothrow
    Derror GetV(K)(in auto ref K PropertyName, out Value* ret, CallContext* cc)
    if (PropertyKey.IsKey!K)
    {
        Derror err;
        Dobject o;
        if (!toObject(cc.realm, o).onError(err))
            o.Get(cc, PropertyName, ret).onError(err);
        return err;
    }

    // //--------------------------------------------------------------------
    // @disable
    // Value* GetMethod(K)(in auto ref K PropertyName, CallContext* cc)
    //     if (PropertyKey.IsKey!K)
    // {
    //     import dmdscript.errmsgs;

    //     if (auto func = GetV(PropertyName, cc))
    //     {
    //         if (func.isCallable)
    //             return func;
    //         else
    //         {
    //             auto pk = PropertyKey(PropertyName);
    //             throw NotCallableError.toThrow(pk.toString);
    //         }
    //     }
    //     else
    //         return null;
    // }


    //--------------------------------------------------------------------
    nothrow
    Derror Call(CallContext* cc, Dobject othis, out Value ret,
                 Value[] arglist)
    {
        import std.conv : to;

        Derror err;
        if(_type == Type.Object)
        {
            _object.Call(cc, othis, ret, arglist).onError(err);
            //if (a) writef("Vobject.Call() returned %x\n", a);
        }
        else if(_type == Type.RefError)
        {
            ret.putVundefined();
            err = UndefinedVarError(cc, _text);
        }
        else
        {
            //PRINTF("Call method not implemented for primitive %p (%s)\n", this, string_t_ptr(toString()));
            ret.putVundefined();
            err = PrimitiveNoCallError(cc, toString(_type));
        }
        return err;
    }

    //--------------------------------------------------------------------
    nothrow
    Derror Construct(CallContext* cc, out Value ret, Value[] arglist)
    {
        import std.conv : to;
        Derror err;
        if(_type == Type.Object)
            _object.Construct(cc, ret, arglist).onError(err);
        else if(_type == Type.RefError)
        {
            ret.putVundefined();
            err = UndefinedVarError(cc, _text);
        }
        else
        {
            ret.putVundefined();
            err = PrimitiveNoConstructError(cc, toString(_type));
        }
        return err;
    }

    //--------------------------------------------------------------------
    nothrow
    Derror putIterator(out Value v, CallContext* cc)
    {
        Derror err;
        if(_type == Type.Object)
            _object.putIterator(v, cc).onError(err);
        else
        {
            v.putVundefined();
            err = ForInMustBeObjectError(cc);
        }
        return err;
    }

    //--------------------------------------------------------------------
    nothrow
    Derror Invoke(K)(CallContext* cc, in auto ref K key,
                      out Value ret, Value[] args)
        if (PropertyKey.IsKey!K)
    {
        Derror err;
        Dfunction f;
        if (!GetV(cc, key).onError(err) && f !is null)
            f.Call(cc, object, ret, args).onError(err);
        return err;
    }

    //
    @trusted @nogc pure nothrow
    void putSignalingUndefined(string id)
    {
        _type = Type.RefError;
        _text = id;
    }

    @trusted @nogc pure nothrow
    void clear()
    {
        _type = Type.RefError;
        _hash = 0;
        _text = null;
    }

    //====================================================================
private:
    size_t  _hash;               // cache 'hash' value
    Type _type = Type.RefError;
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
        BigInt* _bi;
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
// @safe pure nothrow
// Value* signalingUndefined(in string id)
// {
//     auto p = new Value;
//     p.putSignalingUndefined(id);
//     return p;
// }

//------------------------------------------------------------------------------
//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// check this.
@disable
Value* CanonicalNumericIndexString(CallContext* cc, in string str)
{
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
        double number;
        v.to(number, cc);
        debug
        {
            Value v2;
            v2.put(number);
            string s;
            v2.to(s, cc);
            if(0 != stringcmp(s, str))
            {
                value.putVundefined;
                return value;
            }
        }
        value.put(number);
    }
    return value;
}
