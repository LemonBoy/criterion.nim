import strformat
import terminal except styledWriteLine
import sequtils
import strutils
import streams
import macros
from os import existsEnv

import exporter
import statistics
import config

proc formatNum(v: float64): string =
  &"{v:.4f}"

proc formatCycles(v: float64): string =
  let s = insertSep($v.int64, '\'')
  &"{s}cycles"

proc formatTime(v: float64): string =
  let (unit, fact) =
    if v <= 1e3: ("ns", 1.0)
    elif v <= 1e6: ("us", 1e3)
    elif v <= 1e9: ("ms", 1e6)
    elif v <= 1e12: ("s", 1e9)
    else: ("ns", 1.0)

  &"{v / fact:.4f}{unit}"

proc formatConf[T](v: CI[T], fmt: proc(x: T): string): string =
  &"{v.value.fmt} ({v.lower.fmt} .. {v.upper.fmt})"

macro boringWrite*(f: File, m: varargs[typed]): untyped =
  ## Similar to termina.styledWrite but strip everything that's not a string.
  result = newNimNode(nnkStmtList)

  for arg in m:
    if arg.kind in {nnkStrLit..nnkTripleStrLit} or
      getTypeImpl(arg).typeKind in {ntyString}:
      result.add(newCall(bindSym"write", f, arg))

template styledWriteLine*(f: File, args: varargs[untyped]) =
  ## Similar to terminal.styledWriteLine but don't show colors if not
  ## needed/requested.
  if isatty(f) and not existsEnv("NO_COLOR"):
    styledWrite(f, args)
  else:
    boringWrite(f, args)
  write(f, "\n")

proc toDisplay*(cfg: Config, strm: Stream, r: BenchmarkResult) =
  let title = r.label & '(' &
    r.params.mapIt(it[0] & " = " & it[1]).join(", ") & ')'

  styledWriteLine(stdout, styleBright, fgGreen, "Benchmark: ", resetStyle, title)
  strm.writeLine "Collected ", r.stats.samples.len, " samples"

  if not r.stats.outliers.isZero:
    styledWriteLine(stdout, styleBright, fgYellow, "Warning: ", resetStyle,
      &"Found {r.stats.outliers.mild} mild and {r.stats.outliers.extreme} extreme outliers in the time measurements")
  if not r.stats.cycleOutliers.isZero:
    styledWriteLine(stdout, styleBright, fgYellow, "Warning: ", resetStyle,
      &"Found {r.stats.cycleOutliers.mild} mild and {r.stats.cycleOutliers.extreme} extreme outliers in the cycles measurements")

  if cfg.brief:
    strm.writeLine "  Time: ", formatTime(r.stats.samplesEst.mean.value) & " ± " &
      formatTime(r.stats.samplesEst.stddev)
    strm.writeLine "  Cycles: ", formatCycles(r.stats.cycleSamplesEst.mean.value) & " ± " &
      formatCycles(r.stats.cycleSamplesEst.stddev.value)
  else:
    styledWriteLine(stdout, styleBright, fgBlue, "Time", resetStyle)
    block:
      let est = r.stats.samplesEst
      strm.writeLine "  Time: ", formatConf(est.slope, formatTime)
      strm.writeLine "  R²:   ", formatConf(est.rsquare, formatNum)
      strm.writeLine "  Mean: ", formatConf(est.mean, formatTime)
      strm.writeLine "  Std:  ", formatConf(est.stddev, formatTime)
    styledWriteLine(stdout, styleBright, fgBlue, "Cycles", resetStyle)
    block:
      let est = r.stats.cycleSamplesEst
      strm.writeLine "  Cycles: ", formatConf(est.slope, formatCycles)
      strm.writeLine "  R²:     ", formatConf(est.rsquare, formatNum)
      strm.writeLine "  Mean:   ", formatConf(est.mean, formatCycles)
      strm.writeLine "  Std:    ", formatConf(est.stddev, formatCycles)

proc toDisplay*(cfg: Config, strm: Stream, r: seq[BenchmarkResult]) =
  for x in r:
    toDisplay(cfg, strm, x)
    strm.write '\n'
