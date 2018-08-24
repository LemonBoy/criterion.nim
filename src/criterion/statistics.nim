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

  Estimates* = object
    mean*: CI[float64]
    stddev*: CI[float64]
    slope*: CI[float64]
    rsquare*: CI[float64]

  Outliers* = tuple
    extreme: int
    mild: int

  Statistics* = object
    label*: string
    samples*: seq[float64]
    cycleSamples*: seq[float64]
    samplesEst*: Estimates
    cycleSamplesEst*: Estimates
    outliers*: Outliers
    cycleOutliers*: Outliers

converter toOrdinal*[T](v: CI[T]): T = v.value

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

proc classifyOutliers[T](x: openArray[T]): Outliers =
  let q25 = percentile(x, 0.25)
  let q75 = percentile(x, 0.75)
  let iqr = q75 - q25
  # Inner and outer fences
  let (ifLow, ifUpp) = (q25 - 1.5 * iqr, q75 + 1.5 * iqr)
  let (ofLow, ofUpp) = (q25 - 3.0 * iqr, q75 + 3.0 * iqr)
  for val in x:
    if val < ofLow or val > ofUpp: inc result.extreme
    elif val < ifLow or val > ifUpp: inc result.mild

proc isZero*(o: Outliers): bool =
  o.mild + o.extreme == 0

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

proc newEstimates*(cfg: Config, iterations: seq[int], rawSamples, samples: seq[float64]): Estimates =
  # Get our own RNG state in order not to mess with the user code
  var rng = initRand(getMonotonicTime().int64)

  let mean = bootstrap(cfg, rng, samples,
    proc (y: openArray[float64]): float64 = y.sum / y.len.float64)

  let stddev = bootstrap(cfg, rng, samples,
    proc (y: openArray[float64]): float64 =
      sqrt(y.foldl(a + pow(b - mean, 2.0), 0.0) / (y.len.float64 - 1.0)))

  let slope = bootstrap(cfg, rng, iterations, rawSamples,
    proc (x: openArray[int], y: openArray[float64]): float64 =
      var n, d: float64

      for i in 0..x.high:
        n += (x[i].float64 * y[i])
        d += pow(x[i].float64, 2)

      result = n / d)

  let rsquare = bootstrap(cfg, rng, iterations, rawSamples,
    proc (x:openArray[int], y: openArray[float64]): float =
      # Total sum of squares
      let sTot = y.foldl(a + pow(b - mean, 2.0), 0.0)
      # Residual sum of squares
      let sRes = (0..x.high).foldl(a + pow(y[b] - slope*x[b].float64, 2.0), 0.0)

      result = 1 - (sRes / sTot))

  Estimates(mean: mean, stddev: stddev, slope: slope, rsquare: rsquare)

proc newStatistics*(cfg: Config, label: string, iterations: seq[int], samples, cycleSamples: seq[float64]): Statistics =
  var normSamples = (0..samples.high).mapIt(samples[it] / iterations[it].float64)
  var normCycleSamples = (0..samples.high).mapIt(cycleSamples[it] / iterations[it].float64)

  result = Statistics(
    label: label,
    samples: normSamples,
    cycleSamples: normCycleSamples,
    samplesEst: newEstimates(cfg, iterations, samples, normSamples),
    cycleSamplesEst: newEstimates(cfg, iterations, cycleSamples, normCycleSamples)
  )

  # We have to sort the samples in order to evaluate the percentiles so let's
  # just do it now
  sort(normSamples, system.cmp[float64])
  sort(normCycleSamples, system.cmp[float64])

  result.outliers = classifyOutliers(normSamples)
  result.cycleOutliers = classifyOutliers(normCycleSamples)
