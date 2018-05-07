/** test262-harness-d.
Version:    ALPHA(dmd2.080.0)
Date:       2018-May-07 16:56:01
Authors:    KUMA
License:    CC0
 */
import std.stdio;

enum applicationName = "test262-harness-d";
enum _VERSION_ = "ALPHA(dmd2.080.0)";
enum copyrightMessage = q"EOS
Licensed under CC0 2018. Some rights reserved written by KUMA.
EOS";
enum helpMessage = q"EOS
Usage:
>./harness.exe [init|run|rerun|full|status]

Show more help:
>./harness.exe [init|run|rerun|full|status] --help
EOS";

enum helpAboutInit = q"EOS
About init command:
Initialize test262 database. And output to test262.json in cwd.

Usage:
>./harness.exe init (-j test262.json) (-r test) (-t ../test262)
EOS";

enum helpAboutRun = q"EOS
About run comand:
Do tests until first failure.

Usage:
>./harness.exe run (-p 'a part of path of targeted tests.') (-j test262.json)
EOS";

enum helpAboutRerun = q"EOS
About rerun command:

EOS";

enum helpAboutFull = q"EOS
About full command:

EOS";

enum helpAboutStatus = q"EOS
Show current progress.
EOS";

enum DEFAULT_ENGINE = ".\\dmdscript.exe";
enum DEFAULT_TEST262_PATH = "..\\test262";
enum DEFAULT_TEST262_ROOT = "test";
enum DEFAULT_DATABASE_FILE = "test262.json";
enum DEFAULT_HARNESS = "harness";
enum DEFAULT_INCLUDES = ["sta.js", "assert.js"];

enum RunType
{
    none = "",
    init = "init",
    untilFirstFailure = "run",
    allPassedAndGoOn = "rerun",
    full = "full",
    status = "status",
}

struct ArgsInfo
{
    bool needsHelp;
    RunType type;
    bool newEngine = false;
    string engine = DEFAULT_ENGINE;
    string database = DEFAULT_DATABASE_FILE;
    string test262path = DEFAULT_TEST262_PATH;
    string test262root = DEFAULT_TEST262_ROOT;
    string test262harness = DEFAULT_HARNESS;
    string[] includeNames = DEFAULT_INCLUDES;
    string[] includes;
    string test262;
    string harness;
    string pattern;
    bool ignoreComplain;
}

//==============================================================================
void main(string[] args)
{
    import std.file : exists, isDir, isFile;
    import std.path : buildPath;

    auto info = args.getInfo;

    if (info.needsHelp)
    {
        showHelp(info.type);
        return;
    }

    if (!info.test262path.exists || !info.test262path.isDir)
        throw new Exception (info.test262path ~ " is not found.");

    info.test262 = info.test262path.buildPath(info.test262root);
    if (!info.test262.exists || !info.test262path.isDir)
        throw new Exception (info.test262 ~ " is not found.");

    if (!info.engine.exists || !info.engine.isFile)
        throw new Exception (info.engine ~ " is not found.");

    info.harness = info.test262path.buildPath(info.test262harness);
    if (!info.harness.exists || !info.harness.isDir)
        throw new Exception (info.harness ~ " is not found.");
    info.includes = new string[info.includeNames.length];
    for (size_t i = 0; i < info.includeNames.length; ++i)
    {
        info.includes[i] = info.harness.buildPath(info.includeNames[i]);
        if (!info.includes[i].exists || !info.includes[i].isFile)
            throw new Exception (info.includes[i] ~ " is not found.");
    }

    if      (info.type == RunType.init)
        doInit(info);
    else if (info.type == RunType.status)
        showStatus(info);
    else
        runTest(info);
}

//------------------------------------------------------------------------------
ArgsInfo getInfo(string[] args)
{
    import std.getopt : getopt;

    ArgsInfo info;
    auto result = getopt (
        args,
        "json|j", "A path to database file.", &info.database,
        "test|t", "A path to test262.", &info.test262path,
        "root|r", "A name of root directory in test262.", &info.test262root,
        "engine|e", "An ECMAScript interpreter to test.",
        (string opt, string value)
        {
            info.newEngine = true;
            info.engine = value;
        },
        "pattern|p", "A pattern to filter tests.", &info.pattern,
        "harness", "A root directory of harnesses.", &info.test262harness,
        "include|i", "File names to include.", &info.includeNames,
        "ignore", "Ignore the ignore mark.", &info.ignoreComplain,
        );

    info.needsHelp = result.helpWanted;

    for (size_t i = 1; i < args.length; ++i)
    {
        switch (args[i])
        {
        case RunType.init:
            info.type = RunType.init;
            break;
        case RunType.untilFirstFailure:
            info.type = RunType.untilFirstFailure;
            break;
        case RunType.allPassedAndGoOn:
            info.type = RunType.allPassedAndGoOn;
            break;
        case RunType.full:
            info.type = RunType.full;
            break;
        case RunType.status:
            info.type = RunType.status;
            break;
        default:
            info.needsHelp = true;
        }
    }

    if (info.type == RunType.none)
        info.needsHelp = true;

    return info;
}

//==============================================================================
void showHelp(RunType about)
{
    switch (about)
    {
    case RunType.init:
        helpAboutInit.writeln;
        break;
    case RunType.untilFirstFailure:
        helpAboutRun.writeln;
        break;
    case RunType.allPassedAndGoOn:
        helpAboutRerun.writeln;
        break;
    case RunType.full:
        helpAboutFull.writeln;
        break;
    case RunType.status:
        helpAboutStatus.writeln;
        break;
    default:
        applicationName.writeln(" v", _VERSION_);
        copyrightMessage.writeln;
        helpMessage.writeln;
    }
}

//==============================================================================
void doInit(in ref ArgsInfo info)
{
    import std.array : array;
    import std.algorithm : filter, endsWith, map, sort, fold, startsWith;
    import std.file : dirEntries, SpanMode, DirEntry, write;
    import std.json : toJSON, JSONValue;

    auto data = info.test262.dirEntries(SpanMode.depth)
        .filter!(f=>f.name.endsWith(".js"))
        .map!(a=>a.name.toMetaData)
        .map!(a=>a.toJSONValue).array.JSONValue;

    JSONValue[string] table;
    table["engine"] = info.engine.JSONValue;
    table["includes"] = info.includes.JSONValue;
    table["tests"] = data;
    auto cont = table.JSONValue;

    info.database.write(cont.toJSON(true));
}

//------------------------------------------------------------------------------
struct MetaData
{
    import std.json : JSONValue;

    struct NegativeInfo
    {
        enum Phase
        {
            parse,
            early,
            resolution,
            runtime,
        }
        bool yes;
        Phase phase;
        string type;
    }

    struct FlagsInfo
    {
        bool onlyStrict;
        bool noStrict;
        bool moduleCode;
        bool raw;
        bool async;
        bool generated;
    }

    struct ESID
    {
        string className;
        float section = 0;
    }

    enum Result
    {
        none,
        failed,
        passed,
    }

    string path;
    NegativeInfo negative;
    string[] includes;
    FlagsInfo flags;
    string esid;
    string es5id;
    string es6id;
    string[] features;
    Result result;
    bool ignore;
    string complaint;

    JSONValue toJSONValue() const
    {
        import std.conv : to;
        JSONValue[string] v;
        v["path"] = JSONValue(path);
        if (negative.yes)
        {
            v["negative"] = JSONValue(
                [
                    "phase": JSONValue(negative.phase.to!string),
                    "type": JSONValue(negative.type),
                ]);
        }
        if (0 < includes.length)
            v["includes"] = JSONValue(includes);
        if (flags.onlyStrict)
            v["onlyStrict"] = JSONValue(true);
        if (flags.noStrict)
            v["noStrict"] = JSONValue(true);
        if (flags.moduleCode)
            v["module"] = JSONValue(true);
        if (flags.raw)
            v["raw"] = JSONValue(true);
        if (flags.async)
            v["async"] = JSONValue(true);
        if (flags.generated)
            v["generated"] = JSONValue(true);
        if (0 < esid.length)
            v["esid"] = JSONValue(esid);
        if (0 < es5id.length)
            v["es5id"] = JSONValue(es5id);
        if (0 < es6id.length)
            v["es6id"] = JSONValue(es6id);
        if (0 < features.length)
            v["features"] = JSONValue(features);
        if (Result.none != result)
            v["result"] = JSONValue(result == Result.passed);
        if (0 < complaint.length)
            v["complaint"] = complaint.JSONValue;

        return JSONValue(v);
    }

    this(in ref JSONValue jv)
    {
        import std.conv : to;
        import std.algorithm : map;
        import std.array : array;
        import std.json : JSON_TYPE;

        foreach (key, val; jv.object)
        {
            switch (key)
            {
            case "path":
                path = val.str;
                break;
            case "negative":
                auto table = val.object;
                negative.yes = true;
                foreach (k, v; table)
                {
                    switch (k)
                    {
                    case "phase":
                        negative.phase = v.str.to!(NegativeInfo.Phase);
                        break;
                    case "type":
                        negative.type = v.str;
                        break;
                    default:
                        throw new Exception (key ~ " is not expected.");
                    }
                }
                break;
            case "includes":
                includes = val.array.map!(a=>a.str).array;
                break;
            case "onlyStrict":
                flags.onlyStrict = true;
                break;
            case "noStrict":
                flags.noStrict = true;
                break;
            case "module":
                flags.moduleCode = true;
                break;
            case "raw":
                flags.raw = true;
                break;
            case "async":
                flags.async = true;
                break;
            case "generated":
                flags.generated = true;
                break;
            case "esid":
                esid = val.str;
                break;
            case "es5id":
                es5id = val.str;
                break;
            case "es6id":
                es6id = val.str;
                break;
            case "features":
                features = val.array.map!(a=>a.str).array;
                break;
            case "result":
                result = val.type == JSON_TYPE.TRUE ?
                    Result.passed : Result.failed;
                break;
            case "ignore":
                ignore = true;
                break;
            case "complaint":
                complaint = val.str;
                break;
            default:
                throw new Exception(key ~ " is not expected.");
            }
        }
    }
}

//------------------------------------------------------------------------------
MetaData toMetaData(string path)
{
    import std.conv : to;
    import std.file : exists, isFile, read;

    assert (path.exists && path.isFile);

    MetaData meta;
    meta.path = path;

    try
    {
        path.read.to!string.takeMetaSection.parseYAML.toMetaData(meta);
    }
    catch (Throwable t)
    {
        throw new Exception ("An error occured about " ~ path, t);
    }
    return meta;
}

auto takeMetaSection(string script)
{
    import std.algorithm : findSplit;
    import std.array : Appender;
    import std.typecons : tuple;

    Appender!string buf;
    for (auto result = tuple("", "", script);;)
    {
        result = result[2].findSplit("/*---");
        if (result[2].length == 0)
            break;

        result = result[2].findSplit("---*/");
        buf.put(result[0]);
        if (result[2].length == 0)
            break;
    }

    return buf.data;
}

struct YAML
{
    import std.variant : Algebraic;
    alias Value = Algebraic!(string, string[], YAML[]);

    string key;
    Value value;
}

auto parseYAML(string metaSection)
{
    import std.string : splitLines;

    size_t i;
    return metaSection.splitLines.parseYAML(-1, i);
}

YAML[] parseYAML(string[] lines, in int baseIndent, ref size_t i)
{
    import std.ascii : isWhite;
    import std.string : splitLines, strip, stripRight, stripLeft;
    import std.algorithm : until, findSplit, countUntil, joiner,
        startsWith, endsWith, splitter, map;
    import std.array : Appender, array;
    import std.range : drop;
    import std.conv : to;

    Appender!(string[]) buf;
    Appender!(YAML[]) yamls;

    for (; i < lines.length;)
    {
        if (0 == lines[i].stripRight.length)
        {
            ++i;
            continue;
        }
        auto indent = lines[i].countUntil!(a=>!a.isWhite);
        if (indent <= baseIndent)
            break;

        auto result = lines[i].until("#").findSplit(":");
        if (result[1].empty)
        {
            ++i;
            continue;
        }

        auto key = result[0].to!string.strip;
        auto value = result[2].to!string.strip;
        if      (value == ">" || value == "|")
        {
            buf.shrinkTo(0);

            for (++i; i < lines.length; ++i)
            {
                auto idt = lines[i].countUntil!(a=>!a.isWhite);
                if (idt <= indent)
                    break;

                if (value == ">")
                    buf.put(lines[i].strip);
                else
                    buf.put(lines[i].drop(indent));
            }
            if (value == ">")
                yamls.put(YAML(key,
                               YAML.Value(buf.data.joiner(" ").to!string)));
            else
                yamls.put(YAML(key,
                               YAML.Value(buf.data.joiner("\n").to!string)));
        }
        else if (value == "")
        {
            ++i;
            if (i < lines.length && lines[i].stripLeft.startsWith('-'))
            {
                buf.shrinkTo(0);
                for (; i < lines.length; ++i)
                {
                    auto idt = lines[i].countUntil!(a=>!a.isWhite);
                    if (idt <= indent)
                        break;
                    auto l = lines[i][idt..$];
                    if (!l.startsWith('-'))
                        break;

                    buf.put(l[1..$].strip);
                }
                yamls.put(YAML(key, YAML.Value(buf.data)));
            }
            else
                yamls.put(YAML(key, YAML.Value(parseYAML(lines, indent, i))));
        }
        else
        {
            if (value.startsWith('[') && value.endsWith(']'))
            {
                yamls.put(YAML(key, YAML.Value(value[1..$-1]
                                               .splitter(',')
                                               .map!(a=>a.strip).array)));
            }
            else
                yamls.put(YAML(key, YAML.Value(value)));
            ++i;
        }
    }

    return yamls.data;
}


void toMetaData(YAML[] yamls, ref MetaData meta)
{
    foreach (yaml; yamls)
    {
        switch (yaml.key)
        {
        case "esid":
            meta.esid = yaml.value.get!string;
            break;
        case "es5id":
            meta.es5id = yaml.value.get!string;
            break;
        case "es6id":
            meta.es6id = yaml.value.get!string;
            break;
        case "negative":
            meta.negative.yes = true;
            foreach (sub; yaml.value.get!(YAML[]))
            {
                switch (sub.key)
                {
                case "phase":
                    alias P = MetaData.NegativeInfo.Phase;
                    switch (sub.value.get!string)
                    {
                    case "parse":
                        meta.negative.phase = P.parse;
                        break;
                    case "early":
                        meta.negative.phase = P.early;
                        break;
                    case "resolution":
                        meta.negative.phase = P.resolution;
                        break;
                    case "runtime":
                        meta.negative.phase = P.runtime;
                        break;
                    default:
                        throw new Exception (sub.value.get!string ~
                                             " is Unknown phase.");
                    }
                    break;
                case "type":
                    meta.negative.type = sub.value.get!string;
                    break;
                default:
                }
            }
            break;
        case "flags":
            foreach (one; yaml.value.get!(string[]))
            {
                switch (one)
                {
                case "onlyStrict":
                    meta.flags.onlyStrict = true;
                    break;
                case "noStrict":
                    meta.flags.noStrict = true;
                    break;
                case "module":
                    meta.flags.moduleCode = true;
                    break;
                case "raw":
                    meta.flags.raw = true;
                    break;
                case "async":
                    meta.flags.async = true;
                    break;
                case "generated":
                    meta.flags.generated = true;
                    break;
                case "CanBlockIsFalse": /// what's this?
                    break;
                default:
                    throw new Exception (one ~ " is an unknown flag.");
                }
            }
            break;
        case "features":
            meta.features = yaml.value.get!(string[]);
            break;
        default:
        }
    }
}


//==============================================================================
void runTest(in ref ArgsInfo info)
{
    import std.file : exists, isFile, read, write;
    import std.conv : to;
    import std.json : JSONValue, parseJSON, toJSON;
    import std.algorithm : filter, map, find;
    import std.range : empty;
    import std.process : pipeProcess, Redirect, wait;
    import std.string : strip;
    import std.array : array;

    if (!info.database.exists || !info.database.isFile)
        throw new Exception (info.database ~ " is not found.");

    string engine = info.engine;
    auto table = info.database.read.to!string.parseJSON.object;
    if (!info.newEngine)
    {
        engine = table["engine"].str;
        if (!engine.exists || !engine.isFile)
            throw new Exception (engine ~ " is not found.");
    }

    auto baseCommand = [engine];
    foreach (one; info.includes)
        baseCommand ~= "-i" ~ one;

    size_t allCount;
    size_t passedCount;
    size_t failedCount;
    size_t ignoredCount;
    bool aborting = false;
    table["tests"] = table["tests"].array.map!(
        (jv){
            if (0 < info.pattern.length &&
                jv["path"].str.find(info.pattern).empty)
                return jv;

            auto meta = jv.MetaData;

            if (meta.result == MetaData.Result.passed &&
                info.type != RunType.allPassedAndGoOn)
                return jv;

            ++allCount;
            if (aborting)
                return jv;
            if (0 < meta.complaint.length && !info.ignoreComplain)
            {
                ++ignoredCount;
                return jv;
            }

            auto pipes = pipeProcess(baseCommand ~ meta.path, Redirect.stderr);
            auto exitcode = wait(pipes.pid);

            if ((exitcode != 0) == meta.negative.yes) // success
            {
                meta.result = MetaData.Result.passed;
                ++passedCount;
            }
            else // failure.
            {
                meta.result = MetaData.Result.failed;
                writeln(meta.path, " is failed.");
                foreach (line; pipes.stderr.byLine)
                    line.writeln;

                writeln;

                foreach (one; meta.path.read.to!string
                         .takeMetaSection.parseYAML)
                {
                    writeln("[", one.key, "]:");
                    writeln(one.value);
                }

                writeln;

                std.stdio.write("complain to this?>");
                meta.complaint = readln.to!string.strip;

                if (info.type != RunType.full)
                    aborting = true;
            }
            return meta.toJSONValue;
        }).array.JSONValue;

    auto cont = table.JSONValue;

    info.database.write(cont.toJSON(true));

    writeln("Run ", allCount, " tests.");
    writeln("Passed ", passedCount);
    writeln("Failed ", failedCount);
    writeln("Ignored ", ignoredCount);
}

//==============================================================================
void showStatus(in ref ArgsInfo info)
{
    import std.file : exists, isFile, read;
    import std.conv : to;
    import std.array : Appender;
    import std.json : parseJSON, JSON_TYPE;

    if (!info.database.exists || !info.database.isFile)
        throw new Exception (info.database ~ " is not found.");

    auto table = info.database.read.to!string.parseJSON.object;

    writeln("Target engine: ", table["engine"].str);
    writeln("Default includes: ", table["includes"].array);
    writeln;

    size_t allCount, passedCount, failedCount, ignoredCount;
    Appender!(string[]) buf;
    foreach (one; table["tests"].array)
    {
        ++allCount;

        auto t = one.object;
        if (auto p = "result" in t)
        {
            if      ((*p).type == JSON_TYPE.TRUE)
                ++passedCount;
            else if (auto p2 = "complaint" in t)
            {
                ++ignoredCount;
                buf.put(t["path"].str);
                buf.put("    " ~ (*p2).str);
            }
            else
                ++failedCount;
        }
    }

    writeln("In ", allCount, " tests, ");
    writeln(passedCount, " passed,");
    writeln(failedCount, " failed,");
    writeln(ignoredCount, " ignored.");
    writeln;

    foreach (one; buf.data)
        one.writeln;
}
