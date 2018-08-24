# criterion.nim

A statistics-driven micro-benchmarking framework heavily inspired by the
wonderful [criterion](https://github.com/bos/criterion) library for Haskell.

## Status

Mostly working

## Example

```nim
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
```

Gives the following (colored) output:

```
Benchmark: fib5()
Time
  Mean:  2.8019us (2.7797us .. 2.8266us)
  Std:   167.8612ns (106.8034ns .. 230.3764ns)
  Slope: 2.7577us (2.7499us .. 2.7689us)
  r^2:   0.9996 (0.9992 .. 0.9999)
Cycles
  Mean:  960044cycles (952725cycles .. 968942cycles)
  Std:   2249cycles (2198cycles .. 2306cycles)

Benchmark: fibN(x = 15)
Time
  Mean:  2.9217us (2.8829us .. 2.9595us)
  Std:   264.9737ns (245.1058ns .. 289.2494ns)
  Slope: 2.7671us (2.7423us .. 2.8032us)
  r^2:   0.9985 (0.9973 .. 0.9993)
Cycles
  Mean:  1001156cycles (987796cycles .. 1014500cycles)
  Std:   2371cycles (2307cycles .. 2438cycles)

Benchmark: fibN1(x = 15)
Time
  Mean:  2.7408us (2.7270us .. 2.7591us)
  Std:   116.1330ns (29.1107ns .. 180.0350ns)
  Slope: 2.7286us (2.7224us .. 2.7363us)
  r^2:   0.9998 (0.9994 .. 1.0000)
Cycles
  Mean:  944312cycles (939793cycles .. 950675cycles)
  Std:   2191cycles (2159cycles .. 2236cycles)
```

A bit too much info? Just set `cfg.brief = true` and the results will be output
in a condensed format:

```
Benchmark: fib5()
  Time: 3.2189us ± 911.1064ns
  Cycles: 1108521cycles ± 3032cycles

Benchmark: fibN(x = 15)
  Time: 2.7346us ± 80.7051ns
  Cycles: 942230cycles ± 2182cycles

Benchmark: fibN1(x = 15)
  Time: 2.7298us ± 35.4231ns
  Cycles: 940538cycles ± 2175cycles
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
