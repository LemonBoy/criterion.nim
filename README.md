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
Benchmark: fib5()
Mean:  48.3079ns (45.1520ns .. 52.8269ns)
Std:   33.3215ns (15.0746ns .. 53.0642ns)
Slope: 32.0345ns (31.8805ns .. 32.2599ns)
r^2:   0.9998 (0.9994 .. 1.0000)

Benchmark: fibN(x = 5)
Mean:  33.6282ns (32.5132ns .. 35.7919ns)
Std:   13.5899ns (2.2646ns .. 23.0743ns)
Slope: 32.1599ns (31.9847ns .. 32.3936ns)
r^2:   0.9996 (0.9994 .. 0.9998)

Benchmark: fibN1(x = 5)
Mean:  33.8858ns (32.7428ns .. 35.6385ns)
Std:   13.7220ns (2.8405ns .. 23.2511ns)
Slope: 32.6684ns (32.2661ns .. 33.2929ns)
r^2:   0.9978 (0.9951 .. 0.9992)
```

A bit too much info? Just set `cfg.brief = true` and the results will be output
in a condensed format:

```
Benchmark: fib5()
Mean: 45.7193ns ± 31.5409ns

Benchmark: fibN(x = 5)
Mean: 33.3713ns ± 9.3118ns

Benchmark: fibN1(x = 5)
Mean: 33.6369ns ± 10.8619ns
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
