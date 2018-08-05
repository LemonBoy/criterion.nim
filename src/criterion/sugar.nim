import impl
import config
import display

import macros

macro measureArgs*(args: typed, stmt: typed): typed {.used.} =
  expectKind stmt, nnkProcDef

  # The first param is the return type of the procedure
  if params(stmt).len != 2:
    error("the procedure must accept a single argument", stmt)

  var isIterator = false

  case getType(args).typeKind():
  of ntyProc:
    # Assume this is an iterator
    isIterator = true
  of ntyArray, ntySequence:
    discard
  else:
    # echo getType(args).typeKind()
    error("invalid arguments", args)

  let procName = stmt.name

  let forArg = if isIterator: newCall(args) else: args
  let forVar = genSym(nskForVar)

  # XXX Using `$` is not so wise
  result = newStmtList(stmt,
    nnkForStmt.newTree(forVar, forArg,
      newCall(ident("add"), ident("collectedVar"),
        newCall(ident("bench"), ident("cfg"),
          newCall(ident("&"), newStrLitNode(repr(procName) & "/"),
            newCall(ident("$"), forVar)),
          newProc(body = newCall(procName, forVar))))))

macro measure*(stmt: typed): typed {.used.} =
  expectKind stmt, nnkProcDef

  # The first param is the return type of the procedure
  if params(stmt).len != 1:
    error("the procedure must accept zero arguments", stmt)

  let procName = stmt.name

  result = newStmtList(stmt,
    newCall(ident("add"), ident("collectedVar"),
      newCall(ident("bench"), ident("cfg"), toStrLit(procName),
        newProc(body = newCall(procName)))))

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
