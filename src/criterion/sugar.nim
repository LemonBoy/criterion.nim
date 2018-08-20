import sequtils
import macros

import impl
import config
import display
import statistics

const
  ELLIPSIZE_THRESHOLD = 15

proc ellipsize(s: string): string =
  if s.len < ELLIPSIZE_THRESHOLD:
    return s
  result = s[0..5] & "..." & s[^6..^1]

proc dissectType(t: NimNode): int =
  let ty = getType(t)
  case ty.typeKind():
    of ntyProc:
      result = dissectType(ty[^1])
    of ntyArray:
      result = dissectType(ty[1]) * dissectType(ty[2])
    of ntyRange:
      result = dissectType(ty[2])
    of ntyInt:
      result = 1
    of ntyTuple:
      result = ty.len - 1
    of ntyEmpty:
      result = 0
    else:
      doAssert false, "unhandled type in dissectType " & $ty.typeKind()

proc countArguments(n: NimNode, req, max: var int) =
  case n.kind
  of nnkIdentDefs:
    # <ident1> ... <identN>, <type>, <default>
    max += n.len - 2
    if n[^1].kind == nnkEmpty:
      req += n.len - 2
  of nnkFormalParams:
    # <return>, <args> ... <args>
    for i in 1..<n.len:
      countArguments(n[i], req, max)
  else:
    doAssert false, "unhandled node kind " & $n.kind

template returnsVoid(params: NimNode): bool =
  params[0].kind == nnkEmpty or getType(params[0]).typeKind == ntyVoid

macro measureArgs*(args: typed, stmt: typed): untyped {.used.} =
  expectKind stmt, {nnkProcDef, nnkFuncDef}

  let params = params(stmt)

  var reqArgs, maxArgs = 0
  countArguments(params, reqArgs, maxArgs)

  if reqArgs != maxArgs:
    error("procedures with default arguments are not supported")

  let procName = stmt.name
  let procNameStr = newStrLitNode($procName & "/")

  let arg = genSym(nskForVar)

  # Try to figure out if `args` returns a n-element tuple and pass'em all as
  # distinct arguments
  let typeCardinality = dissectType(args)

  if typeCardinality != maxArgs:
    error("expected " & $maxArgs & " argument(s) but got " & $typeCardinality)

  var innerBody = newCall(procName)

  case typeCardinality:
  of 0:
    discard
  of 1:
    innerBody.add(arg)
  else:
    for i in 0..<typeCardinality:
      innerBody.add(newNimNode(nnkBracketExpr).add(arg, newIntLitNode(i)))

  if not returnsVoid(params):
    innerBody = newNimNode(nnkDiscardStmt).add(innerBody)

  let arg0 = if getType(args).typeKind() == ntyProc:
    newCall(args)
  else:
    args

  # Workaround, if `bench` is used directly then the compiler gets confused
  # between the same symbol (???)
  let bench = bindSym"bench"
  let ellipsize = bindSym"ellipsize"

  result = quote do:
    when not compiles((for _ in `arg0`: discard)):
      {.error: "the argument must be an iterable object".}
    else:
      for `arg` in `arg0`:
        collectedVar.add(`bench`(cfg, `procNameStr` & `ellipsize`($`arg`),
          proc () = `innerBody`))

macro measure*(stmt: typed): typed {.used.} =
  expectKind stmt, {nnkProcDef, nnkFuncDef}

  let params = params(stmt)

  var reqArgs, maxArgs = 0
  countArguments(params, reqArgs, maxArgs)

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
    collectedVar.add(`bench`(cfg, `procNameStr`, proc () = `innerBody`))

template benchmark*(cfg: Config, body: untyped): untyped =
  var collected: seq[Statistics] = @[]

  # This template is only needed to let the macros access the instantiated
  # template variable
  template collectedVar(): untyped = collected

  # This is where the user-provided code is injected
  block:
    body

  # Once all the benchmarks have been run print the results
  for r in collected:
    toShow(r)
