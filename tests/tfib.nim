import criterion

let cfg = newDefaultConfig()

benchmark cfg:
  proc fib(n: int): int =
    case n
    of 0: 1
    of 1: 1
    else: fib(n-1) + fib(n-2)

  proc fib5() {.measure.} =
    discard fib(5)

  # ... equivalent to ...

  iterator argFactory(): int =
    for x in [5]:
      yield x

  proc fibN(x: int) {.measureArgs: argFactory.} =
    discard fib(x)

  # ... equivalent to ...

  proc fibN1(x: int) {.measureArgs: [5].} =
    discard fib(x)
