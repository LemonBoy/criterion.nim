type
  Config* = object
    budget*: float
    warmupBudget*: float
    resamples*: int
    minSamples*: int
    brief*: bool
    verbose*: bool
    outputPath*: string

proc newDefaultConfig*(): Config =
  result.budget = 5.0
  result.warmupBudget = 3.0
  result.resamples = 1_000
  result.minSamples = 100
  result.brief = false
  result.verbose = false
  result.outputPath = ""
