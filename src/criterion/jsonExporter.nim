import json
import streams

import exporter
import statistics
import config

proc `%`(p: ParamTuple): JsonNode =
  %*{"name": p.name, "value": p.value}

proc `%`(r: BenchmarkResult): JsonNode =
  %*{ "label": r.label
    , "parameters": r.params
    , "raw_data":
      { "iterations":   r.stats.iterations
      , "time":  r.stats.samples
      , "cycles": r.stats.cycleSamples
      }
    , "estimates":
      { "time": r.stats.samplesEst
      , "cycles": r.stats.cycleSamplesEst
      }
    }

proc toJson*(cfg: Config, strm: Stream, r: BenchmarkResult) =
  let jsonObj = %r
  strm.writeLine $jsonObj

proc toJson*(cfg: Config, strm: Stream, r: seq[BenchmarkResult]) =
  let jsonObj = %r
  strm.writeLine $jsonObj
