import random
import sequtils
import math
import algorithm

import config
import timer

type
  CI*[T:SomeFloat] = object
    value*: T
    lower*, upper*: T

  Statistics* = object
    label*: string
    samples*: seq[float64]
    mean*: CI[float64]
    stddev*: CI[float64]
    slope*: CI[float64]
    rsquare*: CI[float64]
    q25*, q75*: float64
    cmean*: CI[float64]
    cstddev*: CI[float64]

converter toOrdinal*[T](v: CI[T]): T = v.value

iterator exceptOutliers(st: Statistics): float64 =
  let iqr = st.q75 - st.q25
  let lowerBound = st.q25 - 1.5 * iqr
  let upperBound = st.q75 + 1.5 * iqr
  for val in st.samples:
    if val in lowerBound..upperBound:
      yield val

proc percentile[T:SomeFloat](x: openArray[T], p: T): T =
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

proc bootstrap[T,V](cfg: Config, rng: var Rand, y: openArray[V], fn: proc (y: openArray[V]): T): CI[float64] =
  var values = newSeq[T](cfg.resamples)

  var bufferY = newSeq[V](y.len)

  for i in 0..<cfg.resamples:
    for j in 0..bufferY.high:
      bufferY[j] = rng.rand(y)

    values[i] = fn(bufferY)

  # Needed because the `percentile` procedure doesn't use a selection algorithm
  sort(values, system.cmp[T])

  result.value = fn(y)
  # Approximated 95% confidence interval
  result.lower = percentile(values, 0.025) # n(= 0.95)*0.05/2
  result.upper = percentile(values, 0.975) # n(= 0.95)*(1-0.05/2)

proc bootstrap[T,U,V](cfg: Config, rng: var Rand, x: openArray[U], y: openArray[V], fn: proc (x: openArray[U], y: openArray[V]): T): CI[float64] =
  var values = newSeq[T](cfg.resamples)

  var bufferX = newSeq[U](x.len)
  var bufferY = newSeq[V](y.len)

  for i in 0..<cfg.resamples:
    for j in 0..bufferX.high:
      let idx = rng.rand(bufferX.high)

      bufferX[j] = x[idx]
      bufferY[j] = y[idx]

    values[i] = fn(bufferX, bufferY)

  # Needed because the `percentile` procedure doesn't use a selection algorithm
  sort(values, system.cmp[T])

  result.value = fn(x, y)
  # Approximated 95% confidence interval
  result.lower = percentile(values, 0.025) # n(= 0.95)*0.05/2
  result.upper = percentile(values, 0.975) # n(= 0.95)*(1-0.05/2)

iterator linspace[T](a,b: T, points: Positive = 1): T =
  assert a < b
  let step = (b - a) / points.T
  var x = a
  while x <= b:
    yield x
    x += step

proc newStatistics*(cfg: Config, label: string, iterations: seq[int], samples: seq[float64], cycleSamples: seq[float64]): Statistics =
  result.label = label
  result.samples = newSeq[float64](samples.len)

  # Normalize the data first, we only need the "raw" (x,y) pairs to perform the
  # linear regression
  for i in 0..samples.high:
    result.samples[i] = samples[i] / iterations[i].float64

  sort(result.samples, system.cmp[float64])

  result.q25 = percentile(result.samples, 0.25)
  result.q75 = percentile(result.samples, 0.75)

  # Get our own rng state in order not to mess with the user code
  var rng = initRand(getMonotonicTime().int64)

  let mean = bootstrap(cfg, rng, result.samples,
    proc (y: openArray[float64]): float64 = y.sum / y.len.float64)

  let stddev = bootstrap(cfg, rng, result.samples,
    proc (y: openArray[float64]): float64 =
      sqrt(y.foldl(a + pow(b - mean, 2.0), 0.0) / (y.len.float64 - 1.0)))

  let slope = bootstrap(cfg, rng, iterations, samples,
    proc (x: openArray[int], y: openArray[float64]): float64 =
      var n, d: float64

      for i in 0..x.high:
        n += (x[i].float64 * y[i])
        d += pow(x[i].float64, 2)

      result = n / d)

  let rsquare = bootstrap(cfg, rng, iterations, samples,
    proc (x:openArray[int], y: openArray[float64]): float =
      # Total sum of squares
      let sTot = y.foldl(a + pow(b - mean, 2.0), 0.0)
      # Residual sum of squares
      let sRes = (0..x.high).foldl(a + pow(y[b] - slope*x[b].float64, 2.0), 0.0)

      result = 1 - (sRes / sTot))

  let cmean = bootstrap(cfg, rng, iterations, cycleSamples,
    proc (x: openArray[int], y: openArray[float64]): float64 =
      (0..x.high).foldl(a + (y[b] / x[b].float64), 0.0))

  let cstddev = bootstrap(cfg, rng, iterations, cycleSamples,
    proc (x: openArray[int], y: openArray[float64]): float64 =
      sqrt((0..x.high).foldl(a + pow((y[b] / x[b].float64) - mean, 2.0), 0.0) / (y.len.float64 - 1.0)))

  let iqr = result.q75 - result.q25
  let lowerBound = result.q25 - 1.5 * iqr
  let upperBound = result.q75 + 1.5 * iqr

  result.mean = mean
  result.stddev = stddev
  result.slope = slope
  result.rsquare = rsquare
  result.cmean = cmean
  result.cstddev = cstddev
