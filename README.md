# criterion.nim

A statistics-driven micro-benchmarking framework heavily inspired by the
wonderful [criterion](https://github.com/bos/criterion) library for Haskell.

## Status

Mostly working

## Example

```nim
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
```

Gives the following output:

```
Results for: fib5
Mean: 633.0391ns (609.3131ns .. 656.0740ns)
Std: 178.9518ns (158.7979ns .. 199.6843ns)
Slope: 508.6990ns (506.8242ns .. 511.8218ns)
r^2: 0.9998 (0.9995 .. 1.0000)

Results for: fibN/5
Mean: 510.0214ns (507.4473ns .. 513.3158ns)
Std: 23.7082ns (9.8628ns .. 37.0326ns)
Slope: 507.3269ns (505.3856ns .. 509.8917ns)
r^2: 0.9998 (0.9996 .. 0.9999)

Results for: fibN1/5
Mean: 510.3315ns (507.3686ns .. 514.0403ns)
Std: 26.6482ns (12.6483ns .. 40.6832ns)
Slope: 508.6465ns (505.4450ns .. 512.0704ns)
r^2: 0.9997 (0.9996 .. 0.9999)
```

If you need to pass more than a single argument to your benchmark fixture just
use a tuple: they are automagically unpacked at compile-time.

```nim
import criterion

let cfg = newDefaultConfig()

benchmark cfg:
  proc foo(x: int, y: float) {.measureArgs: [(1,1.0),(2,2.0)].} =
    discard x.float + y
```
