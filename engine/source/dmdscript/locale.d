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
module dmdscript.locale;

//------------------------------------------------------------------------------
///
struct Locale
{
    import core.stdc.locale : lconv;

public static:

    //--------------------------------------------------------------------
    ///
    @property @safe @nogc nothrow
    string list_separator()
    {
        return _list_separator;
    }

    //--------------------------------------------------------------------
    ///
    const(lconv)* locale()
    {
        import core.stdc.locale : localeconv;

        if (_lconv is null)
            _lconv = localeconv();

        assert (_lconv !is null);
        return _lconv;
    }

private static:
    string _list_separator = ",";
    lconv* _lconv;
}
