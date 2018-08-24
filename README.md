# criterion.nim

A statistics-driven micro-benchmarking framework heavily inspired by the
wonderful [criterion](https://github.com/bos/criterion) library for Haskell.

## Status

Mostly working

## Example

```nim
import criterion

var cfg = newDefaultConfig()

benchmark cfg:
  func fib(n: int): int =
    case n
    of 0: 1
    of 1: 1
    else: fib(n-1) + fib(n-2)

  proc fib5() {.measure.} =
    var n = 5
    doAssert fib(n) > 1

  # ... equivalent to ...

  iterator argFactory(): int =
    for x in [5]:
      yield x

  proc fibN(x: int) {.measureArgs: argFactory.} =
    doAssert fib(x) > 1

  # ... equivalent to ...

  proc fibN1(x: int) {.measureArgs: [5].} =
    doAssert fib(x) > 1
```

Gives the following (colored) output:

```
Benchmark: fib5()
Time
  Mean:  33.2897ns (31.7797ns .. 35.4315ns)
  Std:   17.2337ns (3.0836ns .. 29.2159ns)
  Slope: 30.9751ns (30.8246ns .. 31.1627ns)
  r^2:   0.9997 (0.9993 .. 0.9999)
Cycles
  Mean:  16160cycles (15857cycles .. 16589cycles)
  Std:   26cycles (22cycles .. 30cycles)

Benchmark: fibN(x = 5)
Time
  Mean:  33.0711ns (31.8598ns .. 35.0677ns)
  Std:   13.4164ns (3.5756ns .. 22.2653ns)
  Slope: 30.8647ns (30.7889ns .. 30.9487ns)
  r^2:   0.9999 (0.9998 .. 1.0000)
Cycles
  Mean:  16288cycles (15929cycles .. 16765cycles)
  Std:   27cycles (23cycles .. 34cycles)

Benchmark: fibN1(x = 5)
Time
  Mean:  33.6754ns (32.4165ns .. 35.3637ns)
  Std:   12.8452ns (4.2435ns .. 20.3009ns)
  Slope: 32.3092ns (31.6511ns .. 33.3043ns)
  r^2:   0.9960 (0.9919 .. 0.9989)
Cycles
  Mean:  16505cycles (16178cycles .. 16946cycles)
  Std:   27cycles (24cycles .. 32cycles)
```

A bit too much info? Just set `cfg.brief = true` and the results will be output
in a condensed format:

```
Benchmark: fib5()
  Time: 33.8089ns ± 20.7207ns
  Cycles: 16523cycles ± 33cycles

Benchmark: fibN(x = 5)
  Time: 33.9886ns ± 24.4268ns
  Cycles: 16634cycles ± 38cycles

Benchmark: fibN1(x = 5)
  Time: 33.8866ns ± 17.0953ns
  Cycles: 16506cycles ± 29cycles
```

Much easier to parse, isn't it?

If you need to pass more than a single argument to your benchmark fixture just
use a tuple: they are automagically unpacked at compile-time.

```nim
import criterion

let cfg = newDefaultConfig()

benchmark cfg:
  proc foo(x: int, y: float) {.measureArgs: [(1,1.0),(2,2.0)].} =
    discard x.float + y
```
