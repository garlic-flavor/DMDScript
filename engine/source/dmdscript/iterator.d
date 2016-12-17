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


module dmdscript.iterator;

import dmdscript.dobject : Dobject;

struct Iterator
{
    import dmdscript.property : PropertyKey;
    import dmdscript.callcontext : CallContext;
    import dmdscript.value : Value, DError;

    PropertyKey[] keys;
    size_t  keyindex;
    Dobject o;
    Dobject ostart;

    debug
    {
        enum uint ITERATOR_VALUE = 0x1992836;
        uint foo = ITERATOR_VALUE;
    }

    invariant()
    {
        debug assert(foo == ITERATOR_VALUE);
    }

    void ctor(Dobject o)
    {
        import std.algorithm.sorting : sort;

        debug foo = ITERATOR_VALUE;
        //writef("Iterator: o = %p, p = %p\n", o, p);
        ostart = o;
        this.o = o;
        keys = o.proptable.keys.sort().release;
        keyindex = 0;
    }

    PropertyKey* next()
    {
        import std.algorithm.sorting : sort;
        import dmdscript.property : Property;

        Property* p;

        //writef("Iterator::done() p = %p\n", p);

        for(;; keyindex++)
        {
            while(keyindex == keys.length)
            {
                delete keys;
                o = getPrototype(o);
                if(!o)
                    return null;
                keys = o.proptable.keys.sort().release;
                keyindex = 0;
            }
            dmdscript.property.PropertyKey* key = &keys[keyindex];
            p = *key in o.proptable;
            if(!p)                      // if no longer in property table
                continue;
            if(!p.enumerable)
                continue;
            else
            {
                // ECMA 12.6.3
                // Do not enumerate those properties in prototypes
                // that are overridden
                if(o != ostart)
                {
                    for(Dobject ot = ostart; ot != o; ot = getPrototype(ot))
                    {
                        // If property p is in t, don't enumerate
                        if(*key in ot.proptable)
                            goto Lcontinue;
                    }
                }
                keyindex++;
                return key; //&p.value;

                Lcontinue:
                ;
            }
        }
        assert(0);
    }

    // Ecma-262-v7/7.4.2
    @disable
    DError* IteratorNext(ref CallContext cc, out Value ret, Value[] args = null)
    {
        auto err = o.value.Invoke(Key.next, cc, ret, args);
        if (ret.type != Value.Type.Object)
//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
            // use errmsgs
            throw new Exception("");
        return err;
    }

    // Ecma-262-v7/7.4.3
    @disable
    bool IteratorComplete(ref CallContext cc)
    {
        if (auto ret = o.Get(Key.done, cc))
            return ret.toBoolean;
        return false;
    }

    // Ecma-262-v7/7.4.4
    @disable
    Value* IteratorValue(ref CallContext cc)
    {
        return o.Get(Key.value, cc);
    }

    // Ecma-262-v7/7.4.5
    @disable
    bool IteratorStep(ref CallContext cc, out Value ret)
    {
        auto err = IteratorNext(cc, ret);
        return IteratorComplete(cc);
    }

    // Ecma-262-v7/7.4.6
    @disable
    void IteratorClose(){}

static:

    @disable
    Dobject CreateIterResultObject(Value value, bool done)
    {
        auto obj = new Dobject;
        obj.CreateDataProperty(Key.value, value);
        obj.CreateDataProperty(Key.done, done);
        return obj;
    }

    @disable
    Dobject CreateListIterator(Value[] list)
    {
        return null;
    }
}

//==============================================================================
private:

import dmdscript.primitive : StringKey, PKey = Key;
private enum Key : StringKey
{
    value = PKey.value,

    done = StringKey("done"),
    next = StringKey("next"),
}

//
Dobject getPrototype(Dobject o)
{
    version(all)
    {
        return o.GetPrototypeOf;    // use internal [[Prototype]]
    }
    else
    {
        // use "prototype"
        Value* v;

        v = o.Get(Text.prototype);
        if(!v || v.isPrimitive())
            return null;
        o = v.toObject();
        return o;
    }
}
