# criterion.nim

A statistics-driven micro-benchmarking framework heavily inspired by the
wonderful [criterion](https://github.com/bos/criterion) library for Haskell.

## Status

WIP

## Example

```nim
import criterion

proc fib(n: int): int =
  case n
  of 0: 1
  of 1: 1
  else: fib(n-1) + fib(n-2)

let cfg = newDefaultConfig()
var ctx = newContext(cfg)

let dataset = cfg.bench do:
  discard fib(25)
# Alternatively one can use the sugar-free syntax
# let dataset = ctx.bench(proc () = discard fib(25))

cfg.analyse(dataset)
```

Gives the following output:

```
Collected 10 sample(s)
Found 1 outlier(s) in the dataset (10.00%)
Slope:  8.2113ms (8.2083ms .. 8.2736ms)
R^2:    1.0000 (0.9990 .. 1.0000)
Mean:   8.6745ms (8.2653ms .. 9.3380ms)
StdDev: 985.0854us (153.5764us .. 1.5006ms)
```
