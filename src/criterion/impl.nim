import math
import strformat
import random
import algorithm
import sequtils
import stats

import timer

# XXX Evaluate if and how much the outliers affect the results (eg trim and
# recalculate)
# XXX Tabular results ?

type
  Config* = object
    budget*: Positive
    resamples*: Positive
    brief*: bool
    minIters*: Positive

type
  Conf = object
    ## Point estimate and upper/lower 95% confidence interval
    val, lo, hi: float64

  Sample = object
    iterations: int
    realTime: float64

  Samples = seq[Sample]

  Context = object
    cfg: Config
    rng: ref Rand

proc formatTime(v: float64): string =
  let (unit, fact) =
    if v <= 1e3: ("ns", 1.0)
    elif v <= 1e6: ("us", 1e3)
    elif v <= 1e9: ("ms", 1e6)
    elif v <= 1e12: ("s", 1e9)
    else: ("ns", 1.0)

  &"{v / fact:.4f}{unit}"

proc formatConf(v: Conf, fmt: proc(x: float64): string): string =
  &"{v.val.fmt} ({v.lo.fmt} .. {v.hi.fmt})"

proc olsRegress[T:SomeReal](x: openArray[(T,T)]): float =
  var n: T
  var d: T

  for i in 0..x.high:
    n += (x[i][0] * x[i][1])
    d += (x[i][0] * x[i][0])

  result = n / d

iterator geometricProgression(base: int, N: int): int =
  var v = base
  while true:
    yield v
    v *= N

proc resample[T](rng: var Rand, x: openArray[T], resamples: int, est: proc (x: openArray[T]): float): seq[float] =
  result = newSeq[float](resamples)
  var buffer = newSeq[T](x.len)

  for i in 0..<resamples:
    for j in 0..buffer.high: buffer[j] = rng.rand(x)
    result[i] = est(buffer)

  sort(result, system.cmp[float])

proc percentile[T:SomeReal](x: openArray[T], p: T): T =
  # The array _must_ be sorted
  # assert p >= 0 and p <= 1
  assert p in 0.T..1.T
  # Fast path
  if p == 0: return x[0]
  elif p == 1: return x[^1]
  # Note: The N-1 basis is used for the interpolation
  let (idx, d) = splitDecimal(p * (x.len - 1).T)
  assert idx.int < x.high

  result = x[idx.int] + (x[idx.int + 1] - x[idx.int]) * d

proc fences[T:SomeReal](x: openArray[T]): (float,float,float,float) =
  let (q25, q75) = (percentile(x, 0.25), percentile(x, 0.75))
  let iqr = q75 - q25

  # lof < lif < uif < uof
  let lof = q25 - 3.0 * iqr
  let lif = q25 - 1.5 * iqr
  let uif = q75 + 1.5 * iqr
  let uof = q75 + 3.0 * iqr

  return (lof, lif, uif, uof)

proc bootstrap[T](rng: var Rand, x: openArray[T], resamples: int, est: proc (x: openArray[T]): float): Conf =
  let pEst = est(x)
  let resampled = resample(rng, x, resamples, est)
  let lo = percentile(resampled, 0.025) # n*0.05/2
  let hi = percentile(resampled, 0.975) # n*(1-0.05/2)

  result.val = pEst
  result.lo = lo
  result.hi = hi

proc rSquare[T:SomeReal](slope: T, data: openArray[(T,T)]): T =
  var sTot = 0.0
  var sRes = 0.0
  var mean = 0.0

  for v in data: mean += v[1]
  mean /= data.len.float64

  for v in data:
    sTot += (v[1] - mean) * (v[1] - mean)
    sRes += (v[1] - slope*v[0]) * (v[1] - slope*v[0])

  result = 1 - (sRes / sTot)

# Public

proc newDefaultConfig*(): Config =
  result.budget = 5
  result.resamples = 1000
  result.minIters = 4

proc newContext*(cfg: Config): Context =
  result.cfg = cfg
  new(result.rng)
  result.rng[] = initRand(getMonotonicTime().int64)

proc bench*(ctx: Context, body: proc (): void): Samples =
  var collected: Samples = @[]
  let budget = 1e9'f64 * ctx.cfg.budget.float64
  var elapsed = 0.0
  var iterDone = 0

  for iterCount in geometricProgression(1, 2):
    GC_fullCollect()

    let rtBegin = getMonotonicTime()

    for _ in 0..<iterCount:
      try:
        body()
      except:
        echo "The procedure raised an exception, aborting."
        return @[]

    let rtFinish = getMonotonicTime()

    collected.add(Sample(iterations: iterCount, realTime: rtFinish - rtBegin))

    elapsed += rtFinish - rtBegin
    iterDone += iterCount

    # Make sure we collected enough samples to have meaningful results
    if elapsed >= budget and iterDone >= ctx.cfg.minIters:
      break

  return collected

proc exportCSV*(ctx: Context, path: string, label: string, data: Samples, append: bool = false): bool =
  var fp: File

  if not open(fp, path, [fmWrite, fmAppend][append.int]):
    echo &"Could not write to '{path}'"
    return false

  if not append:
    # Write the headers
    fp.writeLine("label", ',', "iterations", ',', "elapsed time [ns]")

  for sample in data:
    fp.writeLine(label, ',', sample.iterations, ',', sample.realTime)

  fp.close()

  return true

proc analyse*(ctx: Context, data: Samples) =
  echo &"Collected {data.len} sample(s)"

  # Outliers may influence the resulting mean and standard deviation
  block:
    let (_, lif, uif, _) = fences(data.mapIt(it.realTime))
    # Roughly estimate both the severe/mild outliers here
    let total = data.foldl(a + (b.realTime notin lif..uif).int, 0)

    if total > 0:
      echo &"Found {total} outlier(s) in the dataset " &
        &"({100.0 * total.float / data.len.float:.2f}%)"

  # Perform a linear regression on the measured realTime
  let points = data.mapIt((it.iterations.float64, it.realTime))

  let slope = bootstrap(ctx.rng[], points, ctx.cfg.resamples, olsRegress)
  let rs = bootstrap(ctx.rng[], points, ctx.cfg.resamples,
    proc (x: openArray[(float,float)]): float = rSquare(slope.val, x))

  # Evaluate the estimators on the averages
  let avg = data.mapIt(it.realTime / it.iterations.float64)
  let mean = bootstrap(ctx.rng[], avg, ctx.cfg.resamples, mean)
  let std = bootstrap(ctx.rng[], avg, ctx.cfg.resamples, standardDeviation)

  if ctx.cfg.brief:
    echo &"Time:    {mean.val.formatTime} ± {std.val.formatTime}"
  else:
    echo "Slope:  ", formatConf(slope, formatTime)
    echo "R^2:    ", formatConf(rs, proc (x: float64): string = &"{x:.4f}")
    echo "Mean:   ", formatConf(mean, formatTime)
    echo "StdDev: ", formatConf(std, formatTime)
