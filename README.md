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
Collected 272 samples
Warning: Found 12 mild and 22 extreme outliers in the time measurements
Warning: Found 10 mild and 19 extreme outliers in the cycles measurements
Time
  Time: 53.7128ns (52.4716ns .. 55.2787ns)
  R²:   0.9940 (0.9852 .. 0.9985)
  Mean: 58.0495ns (55.6828ns .. 60.9758ns)
  Std:  22.4115ns (12.7442ns .. 32.3705ns)
Cycles
  Cycles: 96cycles (94cycles .. 99cycles)
  R²:     0.9940 (0.9847 .. 0.9985)
  Mean:   100cycles (97cycles .. 104cycles)
  Std:    29cycles (16cycles .. 39cycles)

Benchmark: fibN(x = 5)
Collected 273 samples
Warning: Found 10 mild and 30 extreme outliers in the time measurements
Warning: Found 15 mild and 15 extreme outliers in the cycles measurements
Time
  Time: 52.9674ns (52.5014ns .. 53.5172ns)
  R²:   0.9993 (0.9985 .. 0.9998)
  Mean: 56.2079ns (54.4115ns .. 58.4663ns)
  Std:  18.1898ns (7.5266ns .. 27.7590ns)
Cycles
  Cycles: 95cycles (94cycles .. 96cycles)
  R²:     0.9993 (0.9985 .. 0.9998)
  Mean:   97cycles (95cycles .. 99cycles)
  Std:    15cycles (9cycles .. 21cycles)

Benchmark: fibN1(x = 5)
Collected 273 samples
Warning: Found 19 mild and 19 extreme outliers in the time measurements
Warning: Found 10 mild and 15 extreme outliers in the cycles measurements
Time
  Time: 52.6990ns (52.1246ns .. 53.4357ns)
  R²:   0.9989 (0.9978 .. 0.9997)
  Mean: 55.6604ns (53.5989ns .. 58.7450ns)
  Std:  22.4004ns (7.5389ns .. 38.6971ns)
Cycles
  Cycles: 94cycles (93cycles .. 95cycles)
  R²:     0.9989 (0.9977 .. 0.9997)
  Mean:   96cycles (94cycles .. 99cycles)
  Std:    20cycles (8cycles .. 31cycles)
```

A bit too much info? Just set `cfg.brief = true` and the results will be output
in a condensed format:

```
Benchmark: fib5()
Collected 272 samples
Warning: Found 11 mild and 18 extreme outliers in the time measurements
Warning: Found 12 mild and 8 extreme outliers in the cycles measurements
  Time: 55.2958ns ± 24.6988ns
  Cycles: 95cycles ± 25cycles

Benchmark: fibN(x = 5)
Collected 273 samples
Warning: Found 12 mild and 18 extreme outliers in the time measurements
Warning: Found 17 mild and 10 extreme outliers in the cycles measurements
  Time: 53.9200ns ± 23.0084ns
  Cycles: 92cycles ± 20cycles

Benchmark: fibN1(x = 5)
Collected 272 samples
Warning: Found 15 mild and 14 extreme outliers in the time measurements
Warning: Found 22 mild and 11 extreme outliers in the cycles measurements
  Time: 56.2005ns ± 18.2831ns
  Cycles: 97cycles ± 14cycles
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
