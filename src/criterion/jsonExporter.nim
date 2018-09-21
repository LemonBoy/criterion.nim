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
    , "data":
      [ { "iterations":   r.stats.iterations }
      , { "time_series":  r.stats.samples }
      , { "cycle_series": r.stats.cycleSamples }
      ]
    }

proc toJson*(cfg: Config, strm: Stream, r: BenchmarkResult) =
  let jsonObj = %r
  strm.writeLine $jsonObj

proc toJson*(cfg: Config, strm: Stream, r: seq[BenchmarkResult]) =
  let jsonObj = %r
  strm.writeLine $jsonObj
