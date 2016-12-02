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

module dmdscript.ddate;

debug import std.stdio;

import dmdscript.script;
import dmdscript.dobject;
import dmdscript.value;
import dmdscript.dfunction;
import dmdscript.dnative;
import dmdscript.property;
import dmdscript.text;
import dmdscript.errmsgs;


version = DATETOSTRING;                 // use DateToString

enum TIMEFORMAT
{
    String,
    DateString,
    TimeString,
    LocaleString,
    LocaleDateString,
    LocaleTimeString,
    UTCString,
}

d_time parseDateString(ref CallContext cc, d_string s)
{
    return s.parse;
}

d_string dateToString(ref CallContext cc, d_time t, TIMEFORMAT tf)
{
    d_string p;

    if(t == d_time_nan)
        p = "Invalid Date";
    else
    {
        switch(tf)
        {
        case TIMEFORMAT.String:
            t = localTimetoUTC(t);
            p = UTCtoString(t);
            break;

        case TIMEFORMAT.DateString:
            t = localTimetoUTC(t);
            p = toDateString(t);
            break;

        case TIMEFORMAT.TimeString:
            t = localTimetoUTC(t);
            p = toTimeString(t);
            break;

        case TIMEFORMAT.LocaleString:
            //p = toLocaleString(t);
            p = UTCtoString(t);
            break;

        case TIMEFORMAT.LocaleDateString:
            //p = toLocaleDateString(t);
            p = toDateString(t);
            break;

        case TIMEFORMAT.LocaleTimeString:
            //p = toLocaleTimeString(t);
            p = toTimeString(t);
            break;

        case TIMEFORMAT.UTCString:
            p = toUTCString(t);
            //p = toString(t);
            break;

        default:
            assert(0);
        }
    }
    return p;
}


/* ===================== Ddate.constructor functions ==================== */

DError* Ddate_parse(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.4.2
    d_string s;
    d_time n;

    if(arglist.length == 0)
        n = d_time_nan;
    else
    {
        s = arglist[0].toString();
        n = parseDateString(cc, s);
    }

    ret.putVtime(n);
    return null;
}

DError* Ddate_UTC(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.4.3 - 15.9.4.10

    d_time n;

    d_time year;
    d_time month = 0;
    d_time date = 0;
    d_time hours = 0;
    d_time minutes = 0;
    d_time seconds = 0;
    d_time ms = 0;

    d_time day;
    d_time time = 0;

    switch(arglist.length)
    {
    default:
    case 7:
        ms = arglist[6].toDtime(cc);
        goto case;
    case 6:
        seconds = arglist[5].toDtime(cc);
        goto case;
    case 5:
        minutes = arglist[4].toDtime(cc);
        goto case;
    case 4:
        hours = arglist[3].toDtime(cc);
        time = makeTime(hours, minutes, seconds, ms);
        goto case;
    case 3:
        date = arglist[2].toDtime(cc);
        goto case;
    case 2:
        month = arglist[1].toDtime(cc);
        goto case;
    case 1:
        year = arglist[0].toDtime(cc);

        if(year != d_time_nan && year >= 0 && year <= 99)
            year += 1900;
        day = makeDay(year, month, date);
        n = timeClip(makeDate(day, time));
        break;

    case 0:
        n = getUTCtime();
        break;
    }
    ret.putVtime(n);
    return null;
}

/* ===================== Ddate_constructor ==================== */

class DdateConstructor : Dconstructor
{
    this()
    {
        super(Text.Date, 7, Dfunction.getPrototype);

        static enum NativeFunctionData[] nfd =
        [
            { Text.parse, &Ddate_parse, 1 },
            { Text.UTC, &Ddate_UTC, 7 },
        ];

        DnativeFunction.initialize(this, nfd, Property.Attribute.DontEnum);
    }

    override DError* Construct(ref CallContext cc, out Value ret,
                               Value[] arglist)
    {
        // ECMA 15.9.3
        Dobject o;
        d_time n;

        d_time year;
        d_time month;
        d_time date = 0;
        d_time hours = 0;
        d_time minutes = 0;
        d_time seconds = 0;
        d_time ms = 0;

        d_time day;
        d_time time = 0;
        //generate NaN check boilerplate code
        static d_string breakOnNan(d_string var)
        {
            return "if(" ~ var ~ " == d_time_nan){
			n = d_time_nan;
			break;
		}";
        }
        //writefln("Ddate_constructor.Construct()");
        switch(arglist.length)
        {
        default:
        case 7:
            ms = arglist[6].toDtime(cc);
            mixin (breakOnNan("ms"));
            goto case;
        case 6:
            seconds = arglist[5].toDtime(cc);
            mixin (breakOnNan("seconds"));
            goto case;
        case 5:
            minutes = arglist[4].toDtime(cc);
            mixin (breakOnNan("minutes"));
            goto case;
        case 4:
            hours = arglist[3].toDtime(cc);
            mixin (breakOnNan("hours"));
            time = makeTime(hours, minutes, seconds, ms);
            goto case;
        case 3:
            date = arglist[2].toDtime(cc);
            goto case;
        case 2:
            month = arglist[1].toDtime(cc);
            year = arglist[0].toDtime(cc);

            if(year != d_time_nan && year >= 0 && year <= 99)
                year += 1900;
            day = makeDay(year, month, date);
            n = timeClip(localTimetoUTC(makeDate(day, time)));
            break;

        case 1:
            arglist[0].toPrimitive(cc, ret, null);
            if(ret.getType() == Value.TypeName.String)
            {
                n = parseDateString(cc, ret.text);
            }
            else
            {
                n = ret.toDtime(cc);
                n = timeClip(n);
            }
            break;

        case 0:
            n = getUTCtime();
            break;
        }
        //writefln("\tn = %s", n);
        o = new Ddate(n);
        ret.put(o);
        return null;
    }

    override DError* Call(ref CallContext cc, Dobject othis, out Value ret,
                          Value[] arglist)
    {
        // ECMA 15.9.2
        // return string as if (new Date()).toString()
        immutable(char)[] s;
        d_time t;

        version(DATETOSTRING)
        {
            t = getUTCtime();
            t = UTCtoLocalTime(t);
            s = dateToString(cc, t, TIMEFORMAT.String);
        }
        else
        {
            t = time();
            s = toString(t);
        }
        ret.put(s);
        return null;
    }
}


/* ===================== Ddate.prototype functions =============== */

DError* checkdate(out Value ret, d_string name, Dobject othis)
{
    ret.putVundefined();
    return FunctionWantsDateError(name, othis.classname);
}

int getThisTime(out Value ret, Dobject othis, out d_time n)
{
    d_number x;

    n = cast(d_time)othis.value.number;
    ret.putVtime(n);
    return (n == d_time_nan) ? 1 : 0;
}

int getThisLocalTime(out Value ret, Dobject othis, out d_time n)
{
    int isn = 1;

    n = cast(d_time)othis.value.number;
    if(n != d_time_nan)
    {
        isn = 0;
        n = UTCtoLocalTime(n);
    }
    ret.putVtime(n);
    return isn;
}

DError* Ddate_prototype_toString(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.5.2
    d_time n;
    immutable(char)[] s;

    //writefln("Ddate_prototype_toString()");
    if(!othis.isDdate())
        return checkdate(ret, Text.toString, othis);

    version(DATETOSTRING)
    {
        getThisLocalTime(ret, othis, n);
        s = dateToString(cc, n, TIMEFORMAT.String);
    }
    else
    {
        getThisTime(ret, othis, n);
        s = toString(n);
    }
    ret.put(s);
    return null;
}

DError* Ddate_prototype_toDateString(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.5.3
    d_time n;
    immutable(char)[] s;

    if(!othis.isDdate())
        return checkdate(ret, Text.toDateString, othis);

    version(DATETOSTRING)
    {
        getThisLocalTime(ret, othis, n);
        s = dateToString(cc, n, TIMEFORMAT.DateString);
    }
    else
    {
        getThisTime(ret, othis, n);
        s = toDateString(n);
    }
    ret.put(s);
    return null;
}

DError* Ddate_prototype_toTimeString(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.5.4
    d_time n;
    immutable(char)[] s;

    if(!othis.isDdate())
        return checkdate(ret, Text.toTimeString, othis);

    version(DATETOSTRING)
    {
        getThisLocalTime(ret, othis, n);
        s = dateToString(cc, n, TIMEFORMAT.TimeString);
    }
    else
    {
        getThisTime(ret, othis, n);
        s = toTimeString(n);
    }
    //s = toTimeString(n);
    ret.put(s);
    return null;
}

DError* Ddate_prototype_valueOf(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.5.3
    d_time n;

    if(!othis.isDdate())
        return checkdate(ret, Text.valueOf, othis);
    getThisTime(ret, othis, n);
    return null;
}

DError* Ddate_prototype_getTime(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.5.4
    d_time n;

    if(!othis.isDdate())
        return checkdate(ret, Text.getTime, othis);
    getThisTime(ret, othis, n);
    return null;
}

DError* Ddate_prototype_getYear(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.5.5
    d_time n;

    if(!othis.isDdate())
        return checkdate(ret, Text.getYear, othis);

    if(getThisLocalTime(ret, othis, n) == 0)
    {
        n = yearFromTime(n);
        if(n != d_time_nan)
        {
            n -= 1900;
            version(all)  // emulate jscript bug
            {
                if(n < 0 || n >= 100)
                    n += 1900;
            }
        }
        ret.putVtime(n);
    }
    return null;
}

DError* Ddate_prototype_getFullYear(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.5.6
    d_time n;

    if(!othis.isDdate())
        return checkdate(ret, Text.getFullYear, othis);

    if(getThisLocalTime(ret, othis, n) == 0)
    {
        n = yearFromTime(n);
        ret.putVtime(n);
    }
    return null;
}

DError* Ddate_prototype_getUTCFullYear(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.5.7
    d_time n;

    if(!othis.isDdate())
        return checkdate(ret, Text.getUTCFullYear, othis);
    if(getThisTime(ret, othis, n) == 0)
    {
        n = yearFromTime(n);
        ret.putVtime(n);
    }
    return null;
}

DError* Ddate_prototype_getMonth(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.5.8
    d_time n;

    if(!othis.isDdate())
        return checkdate(ret, Text.getMonth, othis);

    if(getThisLocalTime(ret, othis, n) == 0)
    {
        n = monthFromTime(n);
        ret.putVtime(n);
    }
    return null;
}

DError* Ddate_prototype_getUTCMonth(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.5.9
    d_time n;

    if(!othis.isDdate())
        return checkdate(ret, Text.getUTCMonth, othis);

    if(getThisTime(ret, othis, n) == 0)
    {
        n = monthFromTime(n);
        ret.putVtime(n);
    }
    return null;
}

DError* Ddate_prototype_getDate(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.5.10
    d_time n;

    if(!othis.isDdate())
        return checkdate(ret, Text.getDate, othis);

    if(getThisLocalTime(ret, othis, n) == 0)
    {
        //printf("LocalTime = %.16g\n", n);
        //printf("DaylightSavingTA(n) = %d\n", daylightSavingTA(n));
        n = dateFromTime(n);
        ret.putVtime(n);
    }
    return null;
}

DError* Ddate_prototype_getUTCDate(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.5.11
    d_time n;

    if(!othis.isDdate())
        return checkdate(ret, Text.getUTCDate, othis);

    if(getThisTime(ret, othis, n) == 0)
    {
        n = dateFromTime(n);
        ret.putVtime(n);
    }
    return null;
}

DError* Ddate_prototype_getDay(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.5.12
    d_time n;

    if(!othis.isDdate())
        return checkdate(ret, Text.getDay, othis);

    if(getThisLocalTime(ret, othis, n) == 0)
    {
        n = weekDay(n);
        ret.putVtime(n);
    }
    return null;
}

DError* Ddate_prototype_getUTCDay(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.5.13
    d_time n;

    if(!othis.isDdate())
        return checkdate(ret, Text.getUTCDay, othis);

    if(getThisTime(ret, othis, n) == 0)
    {
        n = weekDay(n);
        ret.putVtime(n);
    }
    return null;
}

DError* Ddate_prototype_getHours(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.5.14
    d_time n;

    if(!othis.isDdate())
        return checkdate(ret, Text.getHours, othis);

    if(getThisLocalTime(ret, othis, n) == 0)
    {
        n = hourFromTime(n);
        ret.putVtime(n);
    }
    return null;
}

DError* Ddate_prototype_getUTCHours(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.5.15
    d_time n;

    if(!othis.isDdate())
        return checkdate(ret, Text.getUTCHours, othis);

    if(getThisTime(ret, othis, n) == 0)
    {
        n = hourFromTime(n);
        ret.putVtime(n);
    }
    return null;
}

DError* Ddate_prototype_getMinutes(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.5.16
    d_time n;

    if(!othis.isDdate())
        return checkdate(ret, Text.getMinutes, othis);

    if(getThisLocalTime(ret, othis, n) == 0)
    {
        n = minFromTime(n);
        ret.putVtime(n);
    }
    return null;
}

DError* Ddate_prototype_getUTCMinutes(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.5.17
    d_time n;

    if(!othis.isDdate())
        return checkdate(ret, Text.getUTCMinutes, othis);

    if(getThisTime(ret, othis, n) == 0)
    {
        n = minFromTime(n);
        ret.putVtime(n);
    }
    return null;
}

DError* Ddate_prototype_getSeconds(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.5.18
    d_time n;

    if(!othis.isDdate())
        return checkdate(ret, Text.getSeconds, othis);

    if(getThisLocalTime(ret, othis, n) == 0)
    {
        n = secFromTime(n);
        ret.putVtime(n);
    }
    return null;
}

DError* Ddate_prototype_getUTCSeconds(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.5.19
    d_time n;

    if(!othis.isDdate())
        return checkdate(ret, Text.getUTCSeconds, othis);

    if(getThisTime(ret, othis, n) == 0)
    {
        n = secFromTime(n);
        ret.putVtime(n);
    }
    return null;
}

DError* Ddate_prototype_getMilliseconds(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.5.20
    d_time n;

    if(!othis.isDdate())
        return checkdate(ret, Text.getMilliseconds, othis);

    if(getThisLocalTime(ret, othis, n) == 0)
    {
        n = msFromTime(n);
        ret.putVtime(n);
    }
    return null;
}

DError* Ddate_prototype_getUTCMilliseconds(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.5.21
    d_time n;

    if(!othis.isDdate())
        return checkdate(ret, Text.getUTCMilliseconds, othis);

    if(getThisTime(ret, othis, n) == 0)
    {
        n = msFromTime(n);
        ret.putVtime(n);
    }
    return null;
}

DError* Ddate_prototype_getTimezoneOffset(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.5.22
    d_time n;

    if(!othis.isDdate())
        return checkdate(ret, Text.getTimezoneOffset, othis);

    if(getThisTime(ret, othis, n) == 0)
    {
        n = (n - UTCtoLocalTime(n)) / (60 * 1000);
        ret.putVtime(n);
    }
    return null;
}

DError* Ddate_prototype_setTime(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.5.23
    d_time n;

    if(!othis.isDdate())
        return checkdate(ret, Text.setTime, othis);

    if(!arglist.length)
        n = d_time_nan;
    else
        n = arglist[0].toDtime(cc);
    n = timeClip(n);
    othis.value.putVtime(n);
    ret.putVtime(n);
    return null;
}

DError* Ddate_prototype_setMilliseconds(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.5.24

    d_time ms;
    d_time t;
    d_time time;
    d_time n;

    if(!othis.isDdate())
        return checkdate(ret, Text.setMilliseconds, othis);

    if(getThisLocalTime(ret, othis, t) == 0)
    {
        if(!arglist.length)
            ms = d_time_nan;
        else
            ms = arglist[0].toDtime(cc);
        time = makeTime(hourFromTime(t), minFromTime(t), secFromTime(t), ms);
        n = timeClip(localTimetoUTC(makeDate(day(t), time)));
        othis.value.putVtime(n);
        ret.putVtime(n);
    }
    return null;
}

DError* Ddate_prototype_setUTCMilliseconds(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.5.25
    d_time ms;
    d_time t;
    d_time time;
    d_time n;

    if(!othis.isDdate())
        return checkdate(ret, Text.setUTCMilliseconds, othis);

    if(getThisTime(ret, othis, t) == 0)
    {
        if(!arglist.length)
            ms = d_time_nan;
        else
            ms = arglist[0].toDtime(cc);
        time = makeTime(hourFromTime(t), minFromTime(t), secFromTime(t), ms);
        n = timeClip(makeDate(day(t), time));
        othis.value.putVtime(n);
        ret.putVtime(n);
    }
    return null;
}

DError* Ddate_prototype_setSeconds(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.5.26
    d_time ms;
    d_time seconds;
    d_time t;
    d_time time;
    d_time n;

    if(!othis.isDdate())
        return checkdate(ret, Text.setSeconds, othis);

    if(getThisLocalTime(ret, othis, t) == 0)
    {
        switch(arglist.length)
        {
        default:
        case 2:
            ms = arglist[1].toDtime(cc);
            seconds = arglist[0].toDtime(cc);
            break;

        case 1:
            ms = msFromTime(t);
            seconds = arglist[0].toDtime(cc);
            break;

        case 0:
            ms = msFromTime(t);
            seconds = d_time_nan;
            break;
        }
        time = makeTime(hourFromTime(t), minFromTime(t), seconds, ms);
        n = timeClip(localTimetoUTC(makeDate(day(t), time)));
        othis.value.putVtime(n);
        ret.putVtime(n);
    }
    return null;
}

DError* Ddate_prototype_setUTCSeconds(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.5.27
    d_time ms;
    d_time seconds;
    d_time t;
    d_time time;
    d_time n;

    if(!othis.isDdate())
        return checkdate(ret, Text.setUTCSeconds, othis);

    if(getThisTime(ret, othis, t) == 0)
    {
        switch(arglist.length)
        {
        default:
        case 2:
            ms = arglist[1].toDtime(cc);
            seconds = arglist[0].toDtime(cc);
            break;

        case 1:
            ms = msFromTime(t);
            seconds = arglist[0].toDtime(cc);
            break;

        case 0:
            ms = msFromTime(t);
            seconds = d_time_nan;
            break;
        }
        time = makeTime(hourFromTime(t), minFromTime(t), seconds, ms);
        n = timeClip(makeDate(day(t), time));
        othis.value.putVtime(n);
        ret.putVtime(n);
    }
    return null;
}

DError* Ddate_prototype_setMinutes(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.5.28
    d_time ms;
    d_time seconds;
    d_time minutes;
    d_time t;
    d_time time;
    d_time n;

    if(!othis.isDdate())
        return checkdate(ret, Text.setMinutes, othis);

    if(getThisLocalTime(ret, othis, t) == 0)
    {
        switch(arglist.length)
        {
        default:
        case 3:
            ms = arglist[2].toDtime(cc);
            seconds = arglist[1].toDtime(cc);
            minutes = arglist[0].toDtime(cc);
            break;

        case 2:
            ms = msFromTime(t);
            seconds = arglist[1].toDtime(cc);
            minutes = arglist[0].toDtime(cc);
            break;

        case 1:
            ms = msFromTime(t);
            seconds = secFromTime(t);
            minutes = arglist[0].toDtime(cc);
            break;

        case 0:
            ms = msFromTime(t);
            seconds = secFromTime(t);
            minutes = d_time_nan;
            break;
        }
        time = makeTime(hourFromTime(t), minutes, seconds, ms);
        n = timeClip(localTimetoUTC(makeDate(day(t), time)));
        othis.value.putVtime(n);
        ret.putVtime(n);
    }
    return null;
}

DError* Ddate_prototype_setUTCMinutes(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.5.29
    d_time ms;
    d_time seconds;
    d_time minutes;
    d_time t;
    d_time time;
    d_time n;

    if(!othis.isDdate())
        return checkdate(ret, Text.setUTCMinutes, othis);

    if(getThisTime(ret, othis, t) == 0)
    {
        switch(arglist.length)
        {
        default:
        case 3:
            ms = arglist[2].toDtime(cc);
            seconds = arglist[1].toDtime(cc);
            minutes = arglist[0].toDtime(cc);
            break;

        case 2:
            ms = msFromTime(t);
            seconds = arglist[1].toDtime(cc);
            minutes = arglist[0].toDtime(cc);
            break;

        case 1:
            ms = msFromTime(t);
            seconds = secFromTime(t);
            minutes = arglist[0].toDtime(cc);
            break;

        case 0:
            ms = msFromTime(t);
            seconds = secFromTime(t);
            minutes = d_time_nan;
            break;
        }
        time = makeTime(hourFromTime(t), minutes, seconds, ms);
        n = timeClip(makeDate(day(t), time));
        othis.value.putVtime(n);
        ret.putVtime(n);
    }
    return null;
}

DError* Ddate_prototype_setHours(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.5.30
    d_time ms;
    d_time seconds;
    d_time minutes;
    d_time hours;
    d_time t;
    d_time time;
    d_time n;

    if(!othis.isDdate())
        return checkdate(ret, Text.setHours, othis);

    if(getThisLocalTime(ret, othis, t) == 0)
    {
        switch(arglist.length)
        {
        default:
        case 4:
            ms = arglist[3].toDtime(cc);
            seconds = arglist[2].toDtime(cc);
            minutes = arglist[1].toDtime(cc);
            hours = arglist[0].toDtime(cc);
            break;

        case 3:
            ms = msFromTime(t);
            seconds = arglist[2].toDtime(cc);
            minutes = arglist[1].toDtime(cc);
            hours = arglist[0].toDtime(cc);
            break;

        case 2:
            ms = msFromTime(t);
            seconds = secFromTime(t);
            minutes = arglist[1].toDtime(cc);
            hours = arglist[0].toDtime(cc);
            break;

        case 1:
            ms = msFromTime(t);
            seconds = secFromTime(t);
            minutes = minFromTime(t);
            hours = arglist[0].toDtime(cc);
            break;

        case 0:
            ms = msFromTime(t);
            seconds = secFromTime(t);
            minutes = minFromTime(t);
            hours = d_time_nan;
            break;
        }
        time = makeTime(hours, minutes, seconds, ms);
        n = timeClip(localTimetoUTC(makeDate(day(t), time)));
        othis.value.putVtime(n);
        ret.putVtime(n);
    }
    return null;
}

DError* Ddate_prototype_setUTCHours(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.5.31
    d_time ms;
    d_time seconds;
    d_time minutes;
    d_time hours;
    d_time t;
    d_time time;
    d_time n;

    if(!othis.isDdate())
        return checkdate(ret, Text.setUTCHours, othis);

    if(getThisTime(ret, othis, t) == 0)
    {
        switch(arglist.length)
        {
        default:
        case 4:
            ms = arglist[3].toDtime(cc);
            seconds = arglist[2].toDtime(cc);
            minutes = arglist[1].toDtime(cc);
            hours = arglist[0].toDtime(cc);
            break;

        case 3:
            ms = msFromTime(t);
            seconds = arglist[2].toDtime(cc);
            minutes = arglist[1].toDtime(cc);
            hours = arglist[0].toDtime(cc);
            break;

        case 2:
            ms = msFromTime(t);
            seconds = secFromTime(t);
            minutes = arglist[1].toDtime(cc);
            hours = arglist[0].toDtime(cc);
            break;

        case 1:
            ms = msFromTime(t);
            seconds = secFromTime(t);
            minutes = minFromTime(t);
            hours = arglist[0].toDtime(cc);
            break;

        case 0:
            ms = msFromTime(t);
            seconds = secFromTime(t);
            minutes = minFromTime(t);
            hours = d_time_nan;
            break;
        }
        time = makeTime(hours, minutes, seconds, ms);
        n = timeClip(makeDate(day(t), time));
        othis.value.putVtime(n);
        ret.putVtime(n);
    }
    return null;
}

DError* Ddate_prototype_setDate(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.5.32
    d_time date;
    d_time t;
    d_time day;
    d_time n;

    if(!othis.isDdate())
        return checkdate(ret, Text.setDate, othis);

    if(getThisLocalTime(ret, othis, t) == 0)
    {
        if(!arglist.length)
            date = d_time_nan;
        else
            date = arglist[0].toDtime(cc);
        day = makeDay(yearFromTime(t), monthFromTime(t), date);
        n = timeClip(localTimetoUTC(makeDate(day, timeWithinDay(t))));
        othis.value.putVtime(n);
        ret.putVtime(n);
    }
    return null;
}

DError* Ddate_prototype_setUTCDate(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.5.33
    d_time date;
    d_time t;
    d_time day;
    d_time n;

    if(!othis.isDdate())
        return checkdate(ret, Text.setUTCDate, othis);

    if(getThisTime(ret, othis, t) == 0)
    {
        if(!arglist.length)
            date = d_time_nan;
        else
            date = arglist[0].toDtime(cc);
        day = makeDay(yearFromTime(t), monthFromTime(t), date);
        n = timeClip(makeDate(day, timeWithinDay(t)));
        othis.value.putVtime(n);
        ret.putVtime(n);
    }
    return null;
}

DError* Ddate_prototype_setMonth(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.5.34
    d_time date;
    d_time month;
    d_time t;
    d_time day;
    d_time n;

    if(!othis.isDdate())
        return checkdate(ret, Text.setMonth, othis);

    if(getThisLocalTime(ret, othis, t) == 0)
    {
        switch(arglist.length)
        {
        default:
        case 2:
            month = arglist[0].toDtime(cc);
            date = arglist[1].toDtime(cc);
            break;

        case 1:
            month = arglist[0].toDtime(cc);
            date = dateFromTime(t);
            break;

        case 0:
            month = d_time_nan;
            date = dateFromTime(t);
            break;
        }
        day = makeDay(yearFromTime(t), month, date);
        n = timeClip(localTimetoUTC(makeDate(day, timeWithinDay(t))));
        othis.value.putVtime(n);
        ret.putVtime(n);
    }
    return null;
}

DError* Ddate_prototype_setUTCMonth(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.5.35
    d_time date;
    d_time month;
    d_time t;
    d_time day;
    d_time n;

    if(!othis.isDdate())
        return checkdate(ret, Text.setUTCMonth, othis);

    if(getThisTime(ret, othis, t) == 0)
    {
        switch(arglist.length)
        {
        default:
        case 2:
            month = arglist[0].toDtime(cc);
            date = arglist[1].toDtime(cc);
            break;

        case 1:
            month = arglist[0].toDtime(cc);
            date = dateFromTime(t);
            break;

        case 0:
            month = d_time_nan;
            date = dateFromTime(t);
            break;
        }
        day = makeDay(yearFromTime(t), month, date);
        n = timeClip(makeDate(day, timeWithinDay(t)));
        othis.value.putVtime(n);
        ret.putVtime(n);
    }
    return null;
}

DError* Ddate_prototype_setFullYear(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.5.36
    d_time date;
    d_time month;
    d_time year;
    d_time t;
    d_time day;
    d_time n;

    if(!othis.isDdate())
        return checkdate(ret, Text.setFullYear, othis);

    if(getThisLocalTime(ret, othis, t))
        t = 0;

    switch(arglist.length)
    {
    default:
    case 3:
        date = arglist[2].toDtime(cc);
        month = arglist[1].toDtime(cc);
        year = arglist[0].toDtime(cc);
        break;

    case 2:
        date = dateFromTime(t);
        month = arglist[1].toDtime(cc);
        year = arglist[0].toDtime(cc);
        break;

    case 1:
        date = dateFromTime(t);
        month = monthFromTime(t);
        year = arglist[0].toDtime(cc);
        break;

    case 0:
        date = dateFromTime(t);
        month = monthFromTime(t);
        year = d_time_nan;
        break;
    }
    day = makeDay(year, month, date);
    n = timeClip(localTimetoUTC(makeDate(day, timeWithinDay(t))));
    othis.value.putVtime(n);
    ret.putVtime(n);
    return null;
}

DError* Ddate_prototype_setUTCFullYear(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.5.37
    d_time date;
    d_time month;
    d_time year;
    d_time t;
    d_time day;
    d_time n;

    if(!othis.isDdate())
        return checkdate(ret, Text.setUTCFullYear, othis);

    getThisTime(ret, othis, t);
    if(t == d_time_nan)
        t = 0;
    switch(arglist.length)
    {
    default:
    case 3:
        month = arglist[2].toDtime(cc);
        date = arglist[1].toDtime(cc);
        year = arglist[0].toDtime(cc);
        break;

    case 2:
        month = monthFromTime(t);
        date = arglist[1].toDtime(cc);
        year = arglist[0].toDtime(cc);
        break;

    case 1:
        month = monthFromTime(t);
        date = dateFromTime(t);
        year = arglist[0].toDtime(cc);
        break;

    case 0:
        month = monthFromTime(t);
        date = dateFromTime(t);
        year = d_time_nan;
        break;
    }
    day = makeDay(year, month, date);
    n = timeClip(makeDate(day, timeWithinDay(t)));
    othis.value.putVtime(n);
    ret.putVtime(n);
    return null;
}

DError* Ddate_prototype_setYear(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.5.38
    d_time date;
    d_time month;
    d_time year;
    d_time t;
    d_time day;
    d_time n;

    if(!othis.isDdate())
        return checkdate(ret, Text.setYear, othis);

    if(getThisLocalTime(ret, othis, t))
        t = 0;
    switch(arglist.length)
    {
    default:
    case 1:
        month = monthFromTime(t);
        date = dateFromTime(t);
        year = arglist[0].toDtime(cc);
        if(0 <= year && year <= 99)
            year += 1900;
        day = makeDay(year, month, date);
        n = timeClip(localTimetoUTC(makeDate(day, timeWithinDay(t))));
        break;

    case 0:
        n = d_time_nan;
        break;
    }
    othis.value.putVtime(n);
    ret.putVtime(n);
    return null;
}

DError* Ddate_prototype_toLocaleString(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.5.39
    immutable(char)[] s;
    d_time t;

    if(!othis.isDdate())
        return checkdate(ret, Text.toLocaleString, othis);

    if(getThisLocalTime(ret, othis, t))
        t = 0;

    s = dateToString(cc, t, TIMEFORMAT.LocaleString);
    ret.put(s);
    return null;
}

DError* Ddate_prototype_toLocaleDateString(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.5.6
    immutable(char)[] s;
    d_time t;

    if(!othis.isDdate())
        return checkdate(ret, Text.toLocaleDateString, othis);

    if(getThisLocalTime(ret, othis, t))
        t = 0;

    s = dateToString(cc, t, TIMEFORMAT.LocaleDateString);
    ret.put(s);
    return null;
}

DError* Ddate_prototype_toLocaleTimeString(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.5.7
    immutable(char)[] s;
    d_time t;

    if(!othis.isDdate())
        return checkdate(ret, Text.toLocaleTimeString, othis);

    if(getThisLocalTime(ret, othis, t))
        t = 0;
    s = dateToString(cc, t, TIMEFORMAT.LocaleTimeString);
    ret.put(s);
    return null;
}

DError* Ddate_prototype_toUTCString(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.9.5.40
    immutable(char)[] s;
    d_time t;

    if(!othis.isDdate())
        return checkdate(ret, Text.toUTCString, othis);

    if(getThisTime(ret, othis, t))
        t = 0;
    s = dateToString(cc, t, TIMEFORMAT.UTCString);
    ret.put(s);
    return null;
}

/* ===================== Ddate_prototype ==================== */

class DdatePrototype : Ddate
{
    this()
    {
        super(Dobject.getPrototype);

        Dobject f = Dfunction.getPrototype;

        DefineOwnProperty(Text.constructor, Ddate.getConstructor,
               Property.Attribute.DontEnum);

        static enum NativeFunctionData[] nfd =
        [
            { Text.toString, &Ddate_prototype_toString, 0 },
            { Text.toDateString, &Ddate_prototype_toDateString, 0 },
            { Text.toTimeString, &Ddate_prototype_toTimeString, 0 },
            { Text.valueOf, &Ddate_prototype_valueOf, 0 },
            { Text.getTime, &Ddate_prototype_getTime, 0 },
            //{	Text.getVarDate, &Ddate_prototype_getVarDate, 0 },
            { Text.getYear, &Ddate_prototype_getYear, 0 },
            { Text.getFullYear, &Ddate_prototype_getFullYear, 0 },
            { Text.getUTCFullYear, &Ddate_prototype_getUTCFullYear, 0 },
            { Text.getMonth, &Ddate_prototype_getMonth, 0 },
            { Text.getUTCMonth, &Ddate_prototype_getUTCMonth, 0 },
            { Text.getDate, &Ddate_prototype_getDate, 0 },
            { Text.getUTCDate, &Ddate_prototype_getUTCDate, 0 },
            { Text.getDay, &Ddate_prototype_getDay, 0 },
            { Text.getUTCDay, &Ddate_prototype_getUTCDay, 0 },
            { Text.getHours, &Ddate_prototype_getHours, 0 },
            { Text.getUTCHours, &Ddate_prototype_getUTCHours, 0 },
            { Text.getMinutes, &Ddate_prototype_getMinutes, 0 },
            { Text.getUTCMinutes, &Ddate_prototype_getUTCMinutes, 0 },
            { Text.getSeconds, &Ddate_prototype_getSeconds, 0 },
            { Text.getUTCSeconds, &Ddate_prototype_getUTCSeconds, 0 },
            { Text.getMilliseconds, &Ddate_prototype_getMilliseconds, 0 },
            { Text.getUTCMilliseconds, &Ddate_prototype_getUTCMilliseconds, 0 },
            { Text.getTimezoneOffset, &Ddate_prototype_getTimezoneOffset, 0 },
            { Text.setTime, &Ddate_prototype_setTime, 1 },
            { Text.setMilliseconds, &Ddate_prototype_setMilliseconds, 1 },
            { Text.setUTCMilliseconds, &Ddate_prototype_setUTCMilliseconds, 1 },
            { Text.setSeconds, &Ddate_prototype_setSeconds, 2 },
            { Text.setUTCSeconds, &Ddate_prototype_setUTCSeconds, 2 },
            { Text.setMinutes, &Ddate_prototype_setMinutes, 3 },
            { Text.setUTCMinutes, &Ddate_prototype_setUTCMinutes, 3 },
            { Text.setHours, &Ddate_prototype_setHours, 4 },
            { Text.setUTCHours, &Ddate_prototype_setUTCHours, 4 },
            { Text.setDate, &Ddate_prototype_setDate, 1 },
            { Text.setUTCDate, &Ddate_prototype_setUTCDate, 1 },
            { Text.setMonth, &Ddate_prototype_setMonth, 2 },
            { Text.setUTCMonth, &Ddate_prototype_setUTCMonth, 2 },
            { Text.setFullYear, &Ddate_prototype_setFullYear, 3 },
            { Text.setUTCFullYear, &Ddate_prototype_setUTCFullYear, 3 },
            { Text.setYear, &Ddate_prototype_setYear, 1 },
            { Text.toLocaleString, &Ddate_prototype_toLocaleString, 0 },
            { Text.toLocaleDateString, &Ddate_prototype_toLocaleDateString, 0 },
            { Text.toLocaleTimeString, &Ddate_prototype_toLocaleTimeString, 0 },
            { Text.toUTCString, &Ddate_prototype_toUTCString, 0 },

            // Map toGMTString() onto toUTCString(), per ECMA 15.9.5.41
            { Text.toGMTString, &Ddate_prototype_toUTCString, 0 },
        ];

        DnativeFunction.initialize(this, nfd, Property.Attribute.DontEnum);

        debug
        {
            CallContext cc;
            auto key = PropertyKey(Text.toString);
            assert(proptable.get(key, cc, null));
        }
    }
}


/* ===================== Ddate ==================== */

class Ddate : Dobject
{
    this(d_number n)
    {
        super(_prototype);
        classname = Text.Date;
        value.put(n);
    }

    this(d_time n)
    {
        super(_prototype);
        classname = Text.Date;
        value.putVtime(n);
    }

    this(Dobject prototype)
    {
        super(prototype);
        classname = Text.Date;
        value.put(d_number.nan);
    }

static:
    void initialize()
    {
        _constructor = new DdateConstructor();
        _prototype = new DdatePrototype();

        _constructor.DefineOwnProperty(Text.prototype, _prototype,
                            Property.Attribute.DontEnum |
                            Property.Attribute.DontDelete |
                            Property.Attribute.ReadOnly);

        assert(_prototype.proptable.length != 0);
    }

    Dfunction getConstructor()
    {
        return _constructor;
    }

    Dobject getPrototype()
    {
        return _prototype;
    }

private:
    Dfunction _constructor;
    Dobject _prototype;
}


/* =========== ported from undead.date. =========== */
private
{
    import std.datetime;

    enum d_time_origin = SysTime(DateTime(1970, 1, 1), UTC());
    d_time toDtime(in ref SysTime t)
    {
        return (t.toUTC - d_time_origin).total!"msecs";
    }
    SysTime fromDtime(in d_time t)
    {
        return d_time_origin + dur!"msecs"(t);
    }

    d_time getUTCtime()
    {
        auto ct = Clock.currTime;
        return ct.toDtime;
    }

    d_time localTimetoUTC(in d_time t)
    {
        return t - LocalTime().utcOffsetAt(0).total!"msecs";
    }

    d_time UTCtoLocalTime(in d_time t)
    {
        return t + LocalTime().utcOffsetAt(0).total!"msecs";
    }

    string UTCtoString(in d_time t)
    {
        import std.format : sformat;
        import std.conv : to;
        import std.string : capitalize;
        import std.exception : assumeUnique;
        import std.math : abs;

        auto buf = new char[29 + 7 + 1];
        auto st = t.fromDtime.toLocalTime;
        auto offset = LocalTime().utcOffsetAt(0);
        int hours, minutes;
        offset.split!("hours", "minutes")(hours, minutes);

        return buf.sformat("%.3s %.3s %02d %02d:%02d:%02d GMT%c%02d%02d %d",
                           st.dayOfWeek.to!string.capitalize,
                           st.month.to!string.capitalize,
                           st.day, st.hour, st.minute, st.second,
                           Duration.zero < offset ? '+' : '-',
                           hours.abs, minutes, st.year).assumeUnique;
    }

    string toDateString(in d_time t)
    {
        import std.format : sformat;
        import std.conv : to;
        import std.string : capitalize;
        import std.exception : assumeUnique;

        auto buf = new char[29 + 7 + 1];
        auto st = t.fromDtime.toLocalTime;
        return buf.sformat("%.3s %.3s %02d %d",
                           st.dayOfWeek.to!string.capitalize,
                           st.month.to!string.capitalize,
                           st.day, st.year).assumeUnique;
    }

    string toTimeString(in d_time t)
    {
        import std.format : sformat;
        import std.exception : assumeUnique;
        import std.math : abs;

        auto buf = new char[17 + 1];
        auto st = t.fromDtime.toLocalTime;
        auto offset = LocalTime().utcOffsetAt(0);
        int hours, minutes;
        offset.split!("hours", "minutes")(hours, minutes);

        return buf.sformat("%02d:%02d:%02d GMT%c%02d%02d",
                           st.hour, st.minute, st.second,
                           Duration.zero < offset ? '+' : '-',
                           hours.abs, minutes).assumeUnique;
    }

    string toUTCString(in d_time t)
    {
        import std.format : sformat;
        import std.conv : to;
        import std.string : capitalize;
        import std.exception : assumeUnique;

        auto st = t.fromDtime;
        auto buf = new char[25 + 7 + 1];
        return buf.sformat("%.3s, %02d %.3s %d %02d:%02d:%02d UTC",
                           st.dayOfWeek.to!string.capitalize,
                           st.day,
                           st.month.to!string.capitalize,
                           st.year, st.hour, st.minute, st.second).assumeUnique;
    }

    d_time makeTime(d_time hour, d_time min, d_time sec, d_time ms)
    {
        return hour * (1000 * 60 * 60)
            + min * (1000 * 60)
            + sec * 1000
            + ms;
    }

    /*
     * Params:
     *        month = 0..11
     *        date = day of month, 1..31
     * Returns:
     *        number of days since start of epoch
     */
    d_time makeDay(d_time year, d_time month, d_time date)
    {
        return (SysTime(Date(cast(int)year,
                             cast(int)(month+1),
                             cast(int)date), UTC())
                - d_time_origin).total!"days";
    }

    d_time timeClip(d_time time)
    {
        return time;
    }

    d_time makeDate(d_time day, d_time time)
    {
        if (day == d_time_nan || time == d_time_nan)
            return d_time_nan;

        return day * (1000 * 60 * 60 * 24) + time;
    }

    d_time yearFromTime(d_time t)
    {
        return t.fromDtime.year;
    }
    d_time monthFromTime(d_time t)
    {
        return t.fromDtime.month - 1;
    }
    d_time dateFromTime(d_time t)
    {
        return t.fromDtime.day;
    }
    d_time hourFromTime(d_time t)
    {
        return (t / (1000 * 60 * 60)) % 24;
    }
    d_time minFromTime(d_time t)
    {
        return (t / (1000 * 60)) % 60;
    }
    d_time secFromTime(d_time t)
    {
        return (t / 1000) % 60;
    }
    d_time msFromTime(d_time t)
    {
        return t % 1000;
    }
    int day(in d_time t)
    {
        return cast(int)(t / (1000 * 60 * 60 * 24));
    }
    int timeWithinDay(d_time t)
    {
        return cast(int)(t % (1000 * 60 * 60 * 24));
    }

    int weekDay(d_time t)
    {
        return t.fromDtime.dayOfWeek;
    }

    d_time parse(string s)
    {
        try
        {
            DateParse dp;
            SysTime st;
            dp.parse(s, st);
            return st.toDtime;
        }
        catch(Throwable)
            return d_time_nan;
    }

    unittest
    {
        import undead.date;
        auto now = getUTCtime;
        assert(undead.date.toTimeString(now) == now.toTimeString);

        assert(undead.date.toUTCString(now) == now.toUTCString);

        assert(undead.date.makeTime(1, 2, 3, 4) == makeTime(1, 2, 3, 4));

        assert(undead.date.makeDay(2016, 8, 15) == makeDay(2016, 8, 15));

        assert(undead.date.timeClip(now) == now.timeClip);

        assert(undead.date.makeDate(1, 2) == makeDate(1, 2));

        assert((undead.date.getUTCtime / 100) == (getUTCtime / 100));

        assert(undead.date.localTimetoUTC(now) == localTimetoUTC(now));

        assert(undead.date.UTCtoLocalTime(now) == UTCtoLocalTime(now));

        assert(undead.date.UTCtoString(now) == now.UTCtoString);

        assert(undead.date.toDateString(now) == now.toDateString);

        assert(undead.date.yearFromTime(now) == now.yearFromTime);
        assert(undead.date.monthFromTime(now) == now.monthFromTime);
        assert(undead.date.dateFromTime(now) == now.dateFromTime);
        assert(undead.date.hourFromTime(now) == now.hourFromTime);
        assert(undead.date.minFromTime(now) == now.minFromTime);
        assert(undead.date.secFromTime(now) == now.secFromTime);
        assert(undead.date.msFromTime(now) == now.msFromTime);
        assert(undead.date.day(now) == now.day);
        assert(undead.date.timeWithinDay(now) == now.timeWithinDay);

        assert(undead.date.weekDay(now) == now.weekDay);

        auto today = "August 28, 2016 20:50 +900";
        assert(undead.date.parse(today) == today.parse);
    }

    struct DateParse
    {
        import core.stdc.stdlib : alloca;
        import std.string : cmp;

        void parse(string s, out SysTime st)
        {
            this = DateParse.init;

            //version (Win32)
            buffer = (cast(char *)alloca(s.length))[0 .. s.length];
            //else
            //buffer = new char[s.length];

            debug(dateparse) printf("DateParse.parse('%.*s')\n", s);
            if (!parseString(s))
            {
                goto Lerror;
            }

            /+
             if (year == year.init)
             year = 0;
             else
             +/
            debug(dateparse)
                printf("year = %d, month = %d, day = %d\n%02d:%02d:%02d.%03d\nweekday = %d, tzcorrection = %d\n",
                       year, month, day,
                       hours, minutes, seconds, ms,
                       weekday, tzcorrection);
            if (
                year == year.init ||
                (month < 1 || month > 12) ||
                (day < 1 || day > 31) ||
                (hours < 0 || hours > 23) ||
                (minutes < 0 || minutes > 59) ||
                (seconds < 0 || seconds > 59) ||
                (tzcorrection != int.min &&
                 ((tzcorrection < -2300 || tzcorrection > 2300) ||
                  (tzcorrection % 10)))
                )
            {
            Lerror:
                throw new Error("Invalid date string: " ~ s);
            }

            if (ampm)
            {   if (hours > 12)
                    goto Lerror;
                if (hours < 12)
                {
                    if (ampm == 2)  // if P.M.
                        hours += 12;
                }
                else if (ampm == 1) // if 12am
                {
                    hours = 0;              // which is midnight
                }
            }

//      if (tzcorrection != tzcorrection.init)
//          tzcorrection /= 100;

            if (year >= 0 && year <= 99)
                year += 1900;

            auto dt = DateTime(year, month, day, hours, minutes, seconds);
            st = SysTime(dt, ms.dur!"msecs",
                         tzcorrection == int.min || tzcorrection == 0 ? UTC() :
                         new immutable(SimpleTimeZone)(
                             (-tzcorrection / 100).dur!"hours" +
                             (-tzcorrection % 100).dur!"minutes"));
            if (0 <= weekday && st.dayOfWeek != weekday)
                throw new Error("The day of week is mismatched: " ~ s);
        }


    private:
        int year = int.min; // our "nan" Date value
        int month;          // 1..12
        int day;            // 1..31
        int hours;          // 0..23
        int minutes;        // 0..59
        int seconds;        // 0..59
        int ms;             // 0..999
        int weekday = -1;   // 0..7
        int ampm;           // 0: not specified
        // 1: AM
        // 2: PM
        int tzcorrection = int.min; // -1200..1200 correction in hours

        string s;
        int si;
        int number;
        char[] buffer;

        enum DP : byte
        {
            err,
            weekday,
            month,
            number,
            end,
            colon,
            minus,
            slash,
            ampm,
            plus,
            tz,
            dst,
            dsttz,
        }

        DP nextToken()
        {   int nest;
            uint c;
            int bi;
            DP result = DP.err;

            //printf("DateParse::nextToken()\n");
            for (;;)
            {
                assert(si <= s.length);
                if (si == s.length)
                {   result = DP.end;
                    goto Lret;
                }
                //printf("\ts[%d] = '%c'\n", si, s[si]);
                switch (s[si])
                {
                case ':':       result = DP.colon; goto ret_inc;
                case '+':       result = DP.plus;  goto ret_inc;
                case '-':       result = DP.minus; goto ret_inc;
                case '/':       result = DP.slash; goto ret_inc;
                case '.':
                    version(DATE_DOT_DELIM)
                    {
                        result = DP.slash;
                        goto ret_inc;
                    }
                    else
                    {
                        si++;
                        break;
                    }

                ret_inc:
                    si++;
                    goto Lret;

                case ' ':
                case '\n':
                case '\r':
                case '\t':
                case ',':
                    si++;
                    break;

                case '(':               // comment
                    nest = 1;
                    for (;;)
                    {
                        si++;
                        if (si == s.length)
                            goto Lret;          // error
                        switch (s[si])
                        {
                        case '(':
                            nest++;
                            break;

                        case ')':
                            if (--nest == 0)
                                goto Lendofcomment;
                            break;

                        default:
                            break;
                        }
                    }
                Lendofcomment:
                    si++;
                    break;

                default:
                    number = 0;
                    for (;;)
                    {
                        if (si == s.length)
                            // c cannot be undefined here
                            break;
                        c = s[si];
                        if (!(c >= '0' && c <= '9'))
                            break;
                        result = DP.number;
                        number = number * 10 + (c - '0');
                        si++;
                    }
                    if (result == DP.number)
                        goto Lret;

                    bi = 0;
                bufloop:
                    while (c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z')
                    {
                        if (c < 'a')            // if upper case
                            c += cast(uint)'a' - cast(uint)'A'; // to lower case
                        buffer[bi] = cast(char)c;
                        bi++;
                        do
                        {
                            si++;
                            if (si == s.length)
                                break bufloop;
                            c = s[si];
                        } while (c == '.');     // ignore embedded '.'s
                    }
                    result = classify(buffer[0 .. bi].idup);
                    goto Lret;
                }
            }
        Lret:
            //printf("-DateParse::nextToken()\n");
            return result;
        }

        DP classify(string buf)
        {
            struct DateID
            {
                string name;
                DP tok;
                short value;
            }

            static immutable DateID[] dateidtab =
            [
                {   "january",      DP.month,       1},
                {   "february",     DP.month,       2},
                {   "march",        DP.month,       3},
                {   "april",        DP.month,       4},
                {   "may",          DP.month,       5},
                {   "june",         DP.month,       6},
                {   "july",         DP.month,       7},
                {   "august",       DP.month,       8},
                {   "september",    DP.month,       9},
                {   "october",      DP.month,       10},
                {   "november",     DP.month,       11},
                {   "december",     DP.month,       12},
                {   "jan",          DP.month,       1},
                {   "feb",          DP.month,       2},
                {   "mar",          DP.month,       3},
                {   "apr",          DP.month,       4},
                {   "jun",          DP.month,       6},
                {   "jul",          DP.month,       7},
                {   "aug",          DP.month,       8},
                {   "sep",          DP.month,       9},
                {   "sept",         DP.month,       9},
                {   "oct",          DP.month,       10},
                {   "nov",          DP.month,       11},
                {   "dec",          DP.month,       12},

                {   "sunday",       DP.weekday,     0},
                {   "monday",       DP.weekday,     1},
                {   "tuesday",      DP.weekday,     2},
                {   "tues",         DP.weekday,     2},
                {   "wednesday",    DP.weekday,     3},
                {   "wednes",       DP.weekday,     3},
                {   "thursday",     DP.weekday,     4},
                {   "thur",         DP.weekday,     4},
                {   "thurs",        DP.weekday,     4},
                {   "friday",       DP.weekday,     5},
                {   "saturday",     DP.weekday,     6},

                {   "sun",          DP.weekday,     0},
                {   "mon",          DP.weekday,     1},
                {   "tue",          DP.weekday,     2},
                {   "wed",          DP.weekday,     3},
                {   "thu",          DP.weekday,     4},
                {   "fri",          DP.weekday,     5},
                {   "sat",          DP.weekday,     6},

                {   "am",           DP.ampm,                1},
                {   "pm",           DP.ampm,                2},

                {   "gmt",          DP.tz,          +000},
                {   "ut",           DP.tz,          +000},
                {   "utc",          DP.tz,          +000},
                {   "wet",          DP.tz,          +000},
                {   "z",            DP.tz,          +000},
                {   "wat",          DP.tz,          +100},
                {   "a",            DP.tz,          +100},
                {   "at",           DP.tz,          +200},
                {   "b",            DP.tz,          +200},
                {   "c",            DP.tz,          +300},
                {   "ast",          DP.tz,          +400},
                {   "d",            DP.tz,          +400},
                {   "est",          DP.tz,          +500},
                {   "e",            DP.tz,          +500},
                {   "cst",          DP.tz,          +600},
                {   "f",            DP.tz,          +600},
                {   "mst",          DP.tz,          +700},
                {   "g",            DP.tz,          +700},
                {   "pst",          DP.tz,          +800},
                {   "h",            DP.tz,          +800},
                {   "yst",          DP.tz,          +900},
                {   "i",            DP.tz,          +900},
                {   "ahst",         DP.tz,          +1000},
                {   "cat",          DP.tz,          +1000},
                {   "hst",          DP.tz,          +1000},
                {   "k",            DP.tz,          +1000},
                {   "nt",           DP.tz,          +1100},
                {   "l",            DP.tz,          +1100},
                {   "idlw",         DP.tz,          +1200},
                {   "m",            DP.tz,          +1200},

                {   "cet",          DP.tz,          -100},
                {   "fwt",          DP.tz,          -100},
                {   "met",          DP.tz,          -100},
                {   "mewt",         DP.tz,          -100},
                {   "swt",          DP.tz,          -100},
                {   "n",            DP.tz,          -100},
                {   "eet",          DP.tz,          -200},
                {   "o",            DP.tz,          -200},
                {   "bt",           DP.tz,          -300},
                {   "p",            DP.tz,          -300},
                {   "zp4",          DP.tz,          -400},
                {   "q",            DP.tz,          -400},
                {   "zp5",          DP.tz,          -500},
                {   "r",            DP.tz,          -500},
                {   "zp6",          DP.tz,          -600},
                {   "s",            DP.tz,          -600},
                {   "wast",         DP.tz,          -700},
                {   "t",            DP.tz,          -700},
                {   "cct",          DP.tz,          -800},
                {   "u",            DP.tz,          -800},
                {   "jst",          DP.tz,          -900},
                {   "v",            DP.tz,          -900},
                {   "east",         DP.tz,          -1000},
                {   "gst",          DP.tz,          -1000},
                {   "w",            DP.tz,          -1000},
                {   "x",            DP.tz,          -1100},
                {   "idle",         DP.tz,          -1200},
                {   "nzst",         DP.tz,          -1200},
                {   "nzt",          DP.tz,          -1200},
                {   "y",            DP.tz,          -1200},

                {   "bst",          DP.dsttz,       000},
                {   "adt",          DP.dsttz,       +400},
                {   "edt",          DP.dsttz,       +500},
                {   "cdt",          DP.dsttz,       +600},
                {   "mdt",          DP.dsttz,       +700},
                {   "pdt",          DP.dsttz,       +800},
                {   "ydt",          DP.dsttz,       +900},
                {   "hdt",          DP.dsttz,       +1000},
                {   "mest",         DP.dsttz,       -100},
                {   "mesz",         DP.dsttz,       -100},
                {   "sst",          DP.dsttz,       -100},
                {   "fst",          DP.dsttz,       -100},
                {   "wadt",         DP.dsttz,       -700},
                {   "eadt",         DP.dsttz,       -1000},
                {   "nzdt",         DP.dsttz,       -1200},

                {   "dst",          DP.dst,         0},
            ];

            //message(DTEXT("DateParse::classify('%s')\n"), buf);

            // Do a linear search. Yes, it would be faster with a binary
            // one.
            for (uint i = 0; i < dateidtab.length; i++)
            {
                if (cmp(dateidtab[i].name, buf) == 0)
                {
                    number = dateidtab[i].value;
                    return dateidtab[i].tok;
                }
            }
            return DP.err;
        }

        int parseString(string s)
        {
            int n1;
            int dp;
            int sisave;
            int result;

            //message(DTEXT("DateParse::parseString('%ls')\n"), s);
            this.s = s;
            si = 0;
            dp = nextToken();
            for (;;)
            {
                //message(DTEXT("\tdp = %d\n"), dp);
                switch (dp)
                {
                case DP.end:
                    result = 1;
                Lret:
                    return result;

                case DP.err:
                case_error:
                    //message(DTEXT("\terror\n"));
                default:
                    result = 0;
                    goto Lret;

                case DP.minus:
                    break;                  // ignore spurious '-'

                case DP.weekday:
                    weekday = number;
                    break;

                case DP.month:              // month day, [year]
                    month = number;
                    dp = nextToken();
                    if (dp == DP.number)
                    {
                        day = number;
                        sisave = si;
                        dp = nextToken();
                        if (dp == DP.number)
                        {
                            n1 = number;
                            dp = nextToken();
                            if (dp == DP.colon)
                            {   // back up, not a year
                                si = sisave;
                            }
                            else
                            {   year = n1;
                                continue;
                            }
                            break;
                        }
                    }
                    continue;

                case DP.number:
                    n1 = number;
                    dp = nextToken();
                    switch (dp)
                    {
                    case DP.end:
                        year = n1;
                        break;

                    case DP.minus:
                    case DP.slash:  // n1/ ? ? ?
                        dp = parseCalendarDate(n1);
                        if (dp == DP.err)
                            goto case_error;
                        break;

                    case DP.colon:  // hh:mm [:ss] [am | pm]
                        dp = parseTimeOfDay(n1);
                        if (dp == DP.err)
                            goto case_error;
                        break;

                    case DP.ampm:
                        hours = n1;
                        minutes = 0;
                        seconds = 0;
                        ampm = number;
                        break;

                    case DP.month:
                        day = n1;
                        month = number;
                        dp = nextToken();
                        if (dp == DP.number)
                        {   // day month year
                            year = number;
                            dp = nextToken();
                        }
                        break;

                    default:
                        year = n1;
                        break;
                    }
                    continue;
                }
                dp = nextToken();
            }
            // @@@ bug in the compiler: this is never reachable
            assert(0);
        }

        int parseCalendarDate(int n1)
        {
            int n2;
            int n3;
            int dp;

            debug(dateparse) printf("DateParse.parseCalendarDate(%d)\n", n1);
            dp = nextToken();
            if (dp == DP.month)     // day/month
            {
                day = n1;
                month = number;
                dp = nextToken();
                if (dp == DP.number)
                {   // day/month year
                    year = number;
                    dp = nextToken();
                }
                else if (dp == DP.minus || dp == DP.slash)
                {   // day/month/year
                    dp = nextToken();
                    if (dp != DP.number)
                        goto case_error;
                    year = number;
                    dp = nextToken();
                }
                return dp;
            }
            if (dp != DP.number)
                goto case_error;
            n2 = number;
            //message(DTEXT("\tn2 = %d\n"), n2);
            dp = nextToken();
            if (dp == DP.minus || dp == DP.slash)
            {
                dp = nextToken();
                if (dp != DP.number)
                    goto case_error;
                n3 = number;
                //message(DTEXT("\tn3 = %d\n"), n3);
                dp = nextToken();

                // case1: year/month/day
                // case2: month/day/year
                int case1, case2;

                case1 = (n1 > 12 ||
                         (n2 >= 1 && n2 <= 12) &&
                         (n3 >= 1 && n3 <= 31));
                case2 = ((n1 >= 1 && n1 <= 12) &&
                         (n2 >= 1 && n2 <= 31) ||
                         n3 > 31);
                if (case1 == case2)
                    goto case_error;
                if (case1)
                {
                    year = n1;
                    month = n2;
                    day = n3;
                }
                else
                {
                    month = n1;
                    day = n2;
                    year = n3;
                }
            }
            else
            {   // must be month/day
                month = n1;
                day = n2;
            }
            return dp;

        case_error:
            return DP.err;
        }

        int parseTimeOfDay(int n1)
        {
            int dp;
            int sign;

            // 12am is midnight
            // 12pm is noon

            //message(DTEXT("DateParse::parseTimeOfDay(%d)\n"), n1);
            hours = n1;
            dp = nextToken();
            if (dp != DP.number)
                goto case_error;
            minutes = number;
            dp = nextToken();
            if (dp == DP.colon)
            {
                dp = nextToken();
                if (dp != DP.number)
                    goto case_error;
                seconds = number;
                dp = nextToken();
            }
            else
                seconds = 0;

            if (dp == DP.ampm)
            {
                ampm = number;
                dp = nextToken();
            }
            else if (dp == DP.plus || dp == DP.minus)
            {
            Loffset:
                sign = (dp == DP.minus) ? -1 : 1;
                dp = nextToken();
                if (dp != DP.number)
                    goto case_error;
                tzcorrection = -sign * number;
                dp = nextToken();
            }
            else if (dp == DP.tz)
            {
                tzcorrection = number;
                dp = nextToken();
                if (number == 0 && (dp == DP.plus || dp == DP.minus))
                    goto Loffset;
                if (dp == DP.dst)
                {   tzcorrection += 100;
                    dp = nextToken();
                }
            }
            else if (dp == DP.dsttz)
            {
                tzcorrection = number;
                dp = nextToken();
            }

            return dp;

        case_error:
            return DP.err;
        }

    }


    unittest
    {
        DateParse dp;
        SysTime d;
        dp.parse("March 10, 1959 12:00 -800", d);
        assert(d.year         == 1959);
        assert(d.month        == 3);
        assert(d.day          == 10);
        assert(d.hour         == 12);
        assert(d.minute       == 0);
        assert(d.second       == 0);
        assert(d.fracSecs     == Duration.zero);
        assert(d.dayOfWeek    == DayOfWeek.tue);
        assert(d.timezone.utcOffsetAt(0) == -8.hours);

        dp.parse("Tue Apr 02 02:04:57 GMT-0800 1996", d);
        assert(d.year         == 1996);
        assert(d.month        == 4);
        assert(d.day          == 2);
        assert(d.hour         == 2);
        assert(d.minute       == 4);
        assert(d.second       == 57);
        assert(d.fracSecs     == Duration.zero);
        assert(d.dayOfWeek    == DayOfWeek.tue);
        assert(d.timezone.utcOffsetAt(0) == -8.hours);

        dp.parse("March 14, -1980 21:14:50", d);
        assert(d.year         == 1980);
        assert(d.month        == 3);
        assert(d.day          == 14);
        assert(d.hour         == 21);
        assert(d.minute       == 14);
        assert(d.second       == 50);
        assert(d.fracSecs     == Duration.zero);
        assert(d.dayOfWeek    == DayOfWeek.fri);
        assert(d.timezone     is UTC());

        dp.parse("Tue Apr 02 02:04:57 1996", d);
        assert(d.year         == 1996);
        assert(d.month        == 4);
        assert(d.day          == 2);
        assert(d.hour         == 2);
        assert(d.minute       == 4);
        assert(d.second       == 57);
        assert(d.fracSecs     == Duration.zero);
        assert(d.dayOfWeek    == DayOfWeek.tue);
        assert(d.timezone     is UTC());

        dp.parse("Tue, 02 Apr 1996 02:04:57 G.M.T.", d);
        assert(d.year         == 1996);
        assert(d.month        == 4);
        assert(d.day          == 2);
        assert(d.hour         == 2);
        assert(d.minute       == 4);
        assert(d.second       == 57);
        assert(d.fracSecs     == Duration.zero);
        assert(d.dayOfWeek    == DayOfWeek.tue);
        assert(d.timezone     is UTC());

        dp.parse("December 31, 3000", d);
        assert(d.year         == 3000);
        assert(d.month        == 12);
        assert(d.day          == 31);
        assert(d.hour         == 0);
        assert(d.minute       == 0);
        assert(d.second       == 0);
        assert(d.fracSecs     == Duration.zero);
        assert(d.dayOfWeek    == DayOfWeek.wed);
        assert(d.timezone     is UTC());

        dp.parse("Wed, 31 Dec 1969 16:00:00 GMT", d);
        assert(d.year         == 1969);
        assert(d.month        == 12);
        assert(d.day          == 31);
        assert(d.hour         == 16);
        assert(d.minute       == 0);
        assert(d.second       == 0);
        assert(d.fracSecs     == Duration.zero);
        assert(d.dayOfWeek    == DayOfWeek.wed);
        assert(d.timezone     == UTC());

        dp.parse("1/1/1999 12:30 AM", d);
        assert(d.year         == 1999);
        assert(d.month        == 1);
        assert(d.day          == 1);
        assert(d.hour         == 0);
        assert(d.minute       == 30);
        assert(d.second       == 0);
        assert(d.fracSecs     == Duration.zero);
        assert(d.dayOfWeek    == DayOfWeek.fri);
        assert(d.timezone     == UTC());

        dp.parse("Tue, 20 May 2003 15:38:58 +0530", d);
        assert(d.year         == 2003);
        assert(d.month        == 5);
        assert(d.day          == 20);
        assert(d.hour         == 15);
        assert(d.minute       == 38);
        assert(d.second       == 58);
        assert(d.fracSecs     == Duration.zero);
        assert(d.dayOfWeek    == DayOfWeek.tue);
        assert(d.timezone.utcOffsetAt(0) == 5.hours + 30.minutes);

/*
  debug(dateparse) printf("year = %d, month = %d, day = %d\n%02d:%02d:%02d.%03d\nweekday = %d, tzcorrection = %d\n",
  d.year, d.month, d.day,
  d.hour, d.minute, d.second, d.ms,
  d.weekday, d.tzcorrection);
*/
    }
}
