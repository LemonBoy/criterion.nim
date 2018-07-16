# https://blog.janestreet.com/core_bench-micro-benchmarking-for-ocaml/
# http://datapigtechnologies.com/blog/index.php/highlighting-outliers-in-your-data-with-the-tukey-method/
# http://influentialpoints.com/Training/bootstrap_confidence_intervals-principles-properties-assumptions.htm#efrons
# https://www.itl.nist.gov/div898/handbook/prc/section1/prc16.htm
import math
import posix
import strformat
import random
import algorithm
import sequtils

type
  Config* = object
    budget*: int
    resamples*: int
    brief*: bool

  Conf* = object
    val, lo, hi: float64

type
  Measure* = object
    iters:int
    wall: float64

type
  Outliers* = object
    mild*: int
    severe*: int

proc getMonotonicTime(): float64 =
  var spc: Timespec
  assert clock_gettime(CLOCK_MONOTONIC, spc) >= 0
  return spc.tv_sec.float64 * 1e9 + spc.tv_nsec.float64

proc formatTime*(v: float64): string =
  let (unit, fact) =
    if v <= 1e3: ("ns", 1.0)
    elif v <= 1e6: ("us", 1e3)
    elif v <= 1e9: ("ms", 1e6)
    elif v <= 1e12: ("s", 1e9)
    else: ("ns", 1.0)

  &"{v / fact:.4f}{unit}"

proc `$`(x: Conf): string =
  x.val.formatTime & " (" & x.lo.formatTime & " .. " & x.hi.formatTime & ")"

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

proc resample[T](x: openArray[T], resamples: int, est: proc (x: openArray[T]): float): seq[float] =
  result = newSeq[float](resamples)
  var buffer = newSeq[T](x.len)

  for i in 0..<resamples:
    for j in 0..buffer.high: buffer[j] = x.rand
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

proc classifyOutliers[T:SomeReal](x: openArray[T]): Outliers =
  let (q25, q75) = (percentile(x, 0.25), percentile(x, 0.75))
  let iqr = q75 - q25

  # lof < lif < uif < uof
  let lif = q25 - 1.5 * iqr
  let lof = q25 - 3.0 * iqr
  let uif = q75 + 1.5 * iqr
  let uof = q75 + 3.0 * iqr

  # Classify the outliers using the boxplot technique
  for v in x:
    if v < lof or v > uof: inc result.severe
    elif v > lof and v < lif: inc result.mild
    elif v > uif and v < uof: inc result.mild

proc bootstrap[T](x: openArray[T], resamples: int, est: proc (x: openArray[T]): float): Conf =
  let pEst = est(x)
  let resampled = resample(x, resamples, est)
  let lo = percentile(resampled, 0.025) # n*0.05/2
  let hi = percentile(resampled, 0.975) # n*(1-0.05/2)

  result.val = pEst
  result.lo = lo
  result.hi = hi

proc generatePlot*(series: seq[Measure]) =
  var f: File

  assert open(f, "data.dat", fmWrite)
  for s in series:
    f.writeLine(&"{s.iters}\t{s.wall}")
  f.close()

proc mean1[T:SomeReal](x: openArray[T]): float =
  x.sum / x.len.T

proc std1[T:SomeReal](x: openArray[T]): float =
  let m = x.mean1
  var s: T

  for i in 0..x.high:
    s += (x[i] - m) * (x[i] - m)

  result = sqrt(s / (x.len - 1).T)

# Public

proc newDefaultConfig*(): Config =
  result.budget = 5
  result.resamples = 1000

proc bench*(cfg: Config, x: proc()): seq[Measure] =
  let budget = 1e9 * cfg.budget.float64
  var elapsed = 0.0
  var iterDone = 0

  result = @[]

  randomize()

  for iterCount in 1.geometricProgression(2):
    GC_fullCollect()

    let mono_start = getMonotonicTime()

    for _ in 0..<iterCount:
      x()

    let mono_end = getMonotonicTime()

    result.add(Measure(iters: iterCount, wall:  mono_end - mono_start))

    elapsed += mono_end - mono_start
    iterDone += iterCount

    if elapsed >= budget and iterDone > 10:
      break

proc analyse*(cfg: Config, data: seq[Measure]) =
  let outl = classifyOutliers(data.mapIt(it.wall))
  let totalOutl = outl.severe + outl.mild

  echo &"Collected {data.len} sample(s)"

  if totalOutl > 0:
    echo &"Found {totalOutl} outlier(s) ({totalOutl.float / data.len.float * 100:3.1f}%)"

  let slope = bootstrap(data.mapIt((it.iters.float64, it.wall)), cfg.resamples, olsRegress)

  let norm = data.mapIt(it.wall / it.iters.float64)

  let mean = bootstrap(norm, cfg.resamples, mean1)
  let std = bootstrap(norm, cfg.resamples, std1)

  echo "Slope:  ", slope
  if not cfg.brief:
    echo "Mean:   ", mean
    echo "StdDev: ", std
