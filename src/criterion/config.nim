type
  Config* = object
    budget*: int
    resamples*: int
    minSamples*: int
    brief*: bool

proc newDefaultConfig*(): Config =
  result.budget = 5
  result.resamples = 1_000
  result.minSamples = 30
  result.brief = false
