# criterion.nim

A statistics-driven micro-benchmarking framework heavily inspired by the
wonderful [criterion](https://github.com/bos/criterion) library for Haskell.

## Status

WIP

## Example

```nim
import criterion

let cfg = newDefaultConfig()

let dataset = cfg.bench do:
  proc fib(n: int): int =
    case n
    of 0: 1
    of 1: 1
    else: fib(n-1) + fib(n-2)
  discard fib(25)

cfg.analyse(dataset)
```

Gives the following output:

```
Collected 10 sample(s)
Found 1 outlier(s) (10.0%)
Slope:  7.8005ms (7.7865ms .. 7.8538ms)
Mean:   8.2214ms (7.7718ms .. 9.0008ms)
StdDev: 1.1173ms (46.0506us .. 1.6979ms)
```
