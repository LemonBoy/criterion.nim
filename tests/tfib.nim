import criterion

var cfg = newDefaultConfig()

# cfg.brief = true
# cfg.outputPath = "tfib.json"

benchmark cfg:
  func fib(n: int): int =
    case n
    of 0: 1
    of 1: 1
    else: fib(n-1) + fib(n-2)

  proc fib5() {.measure.} =
    # blackBox fib(5)
    # var n = 5
    var tmp = fib(5)
    blackBox tmp

  # ... equivalent to ...

  iterator argFactory(): int =
    for x in [5]:
      yield x

  proc fibN(x: int) {.measure: argFactory.} =
    var tmp = fib(x)
    blackBox tmp

  # ... equivalent to ...

  proc fibN1(x: int) {.measure: [5].} =
    var tmp = fib(x)
    blackBox tmp
