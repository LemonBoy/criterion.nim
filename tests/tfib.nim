import criterion

var cfg = newDefaultConfig()

cfg.brief = true

benchmark cfg:
  func fib(n: int): int =
    case n
    of 0: 1
    of 1: 1
    else: fib(n-1) + fib(n-2)

  proc fib5() {.measure.} =
    var n = 15
    doAssert fib(n) > 1

  # ... equivalent to ...

  iterator argFactory(): int =
    for x in [15]:
      yield x

  proc fibN(x: int) {.measureArgs: argFactory.} =
    doAssert fib(x) > 1

  # ... equivalent to ...

  proc fibN1(x: int) {.measureArgs: [15].} =
    doAssert fib(x) > 1
