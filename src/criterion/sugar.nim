import sequtils
import strutils
import macros
import typetraits

import impl
import config
import display
import statistics

type
  BenchmarkResult = tuple
    stats: Statistics
    label: string
    params: seq[(string, string)]

const
  ELLIPSIZE_THRESHOLD = 15

proc ellipsize[T](obj: T): string =
  when T is object|tuple|array|seq:
    return $T
  else:
    var s = $obj

    if s.len < ELLIPSIZE_THRESHOLD:
      return s

    result = s[0..5] & "..." & s[^6..^1] & "[" & $s.len & "]"

proc dissectType(t: NimNode): int =
  let ty = getType(t)
  case ty.typeKind():
    of ntyProc:
      result = dissectType(ty[^1])
    of ntyArray:
      result = dissectType(ty[1]) * dissectType(ty[2])
    of ntyRange:
      result = dissectType(ty[2])
    of ntyBool, ntyChar, ntyString, ntyInt..ntyUInt64, ntySet, ntyObject:
      result = 1
    of ntyTuple:
      result = ty.len - 1
    of ntyEmpty:
      result = 0
    else:
      doAssert false, "unhandled type in dissectType " & $ty.typeKind()

proc countArguments(n: NimNode, req, max: var int, idents: var seq[string]) =
  case n.kind
  of nnkIdentDefs:
    # <ident1> ... <identN>, <type>, <default>
    for i in 0..<n.len - 2:
      idents.add($n[i])
    max += n.len - 2
    if n[^1].kind == nnkEmpty:
      req += n.len - 2
  of nnkFormalParams:
    # <return>, <args> ... <args>
    for i in 1..<n.len:
      countArguments(n[i], req, max, idents)
  else:
    doAssert false, "unhandled node kind " & $n.kind

template returnsVoid(params: NimNode): bool =
  params[0].kind == nnkEmpty or getType(params[0]).typeKind == ntyVoid

macro measureArgs*(args: typed, stmt: typed): untyped {.used.} =
  expectKind stmt, {nnkProcDef, nnkFuncDef}

  let params = params(stmt)

  var reqArgs, maxArgs = 0
  var argNames: seq[string] = @[]
  countArguments(params, reqArgs, maxArgs, argNames)

  if reqArgs != maxArgs:
    error("procedures with default arguments are not supported")

  let procName = stmt.name
  let procNameStr = newStrLitNode($procName)

  let arg = genSym(nskForVar)
  var argsVar = genSym(nskVar)

  # Try to figure out if `args` returns a n-element tuple and pass'em all as
  # distinct arguments
  let typeCardinality = dissectType(args)

  if typeCardinality != maxArgs:
    error("expected " & $maxArgs & " argument(s) but got " & $typeCardinality)

  var innerBody = newCall(procName)
  var collectArgsLoop = newStmtList()

  # Unpack `arg` if necessary and record the param <-> value assignment
  case typeCardinality:
  of 0:
    discard
  of 1:
    # Single argument only, pass as-is
    innerBody.add(arg)
    collectArgsLoop.add(newCall("add", argsVar,
      newTree(nnkTupleConstr,
        newStrLitNode(argNames[0]), newCall(bindSym"ellipsize", arg))))
  else:
    for i in 0..<typeCardinality:
      let argN = newNimNode(nnkBracketExpr).add(arg, newIntLitNode(i))
      innerBody.add(argN)
      collectArgsLoop.add(newCall("add", argsVar,
        newTree(nnkTupleConstr,
          newStrLitNode(argNames[i]), newCall(bindSym"ellipsize", argN))))

  if not returnsVoid(params):
    innerBody = newNimNode(nnkDiscardStmt).add(innerBody)

  let arg0 = if getType(args).typeKind() == ntyProc:
    newCall(args)
  else:
    args

  # Workaround, if `bench` is used directly then the compiler gets confused
  # between the same symbol (???)
  let bench = bindSym"bench"

  result = quote do:
    when not compiles((for _ in `arg0`: discard)):
      {.error: "the argument must be an iterable object".}
    else:
      for `arg` in `arg0`:
        var `argsVar` = newSeqOfCap[(string, string)](`typeCardinality`)
        `collectArgsLoop`
        let stats = `bench`(cfg, `procNameStr`, proc () = `innerBody`)
        collectedVar.add((stats, `procNameStr`, `argsVar`))

macro measure*(stmt: typed): typed {.used.} =
  expectKind stmt, {nnkProcDef, nnkFuncDef}

  let params = params(stmt)

  var reqArgs, maxArgs = 0
  var argNames: seq[string] = @[]
  countArguments(params, reqArgs, maxArgs, argNames)

  if reqArgs != 0:
    error("the procedure must accept zero arguments")

  let procName = stmt.name
  let procNameStr = newStrLitNode($procName)

  let innerBody = if not returnsVoid(params):
    newNimNode(nnkDiscardStmt).add(newCall(procName))
  else:
    newCall(procName)

  # Workaround, if `bench` is used directly then the compiler gets confused
  # between the same symbol (???)
  let bench = bindSym"bench"

  result = quote do:
    let stats = `bench`(cfg, `procNameStr`, proc () = `innerBody`)
    collectedVar.add((stats, `procNameStr`, @[]))

template benchmark*(cfg: Config, body: untyped): untyped =
  var collected: seq[BenchmarkResult] = @[]

  # This template is only needed to let the macros access the instantiated
  # template variable
  template collectedVar(): untyped = collected

  # This is where the user-provided code is injected
  block:
    body

  # Once all the benchmarks have been run print the results
  for r in collected:
    let argsStr = "(" & join(r.params.mapIt(it[0] & " = " & it[1]), ", ") & ")"
    echo "Benchmark: " & r.label & argsStr
    toShow(r.stats, cfg.brief)
    echo ""
