const
  NS_IN_S* = 1e9'f64

when defined(windows):
  proc QueryPerformanceCounter(res: var int64) {.
    importc: "QueryPerformanceCounter", stdcall, dynlib: "kernel32".}
  proc QueryPerformanceFrequency(res: var int64) {.
    importc: "QueryPerformanceFrequency", stdcall, dynlib: "kernel32".}

  var base, frequency: int64
  QueryPerformanceCounter(base)
  QueryPerformanceFrequency(frequency)
  let scaleFactor = NS_IN_S / frequency.float64

  proc getMonotonicTime*(): float64 {.inline.} =
    var now: int64
    QueryPerformanceCounter(now)
    result = (now - base).float64 * scaleFactor
elif defined(macosx):
  type
    MachTimebaseInfoData {.pure, final,
        importc: "mach_timebase_info_data_t",
        header: "<mach/mach_time.h>".} = object
      numer, denom: uint32

  proc mach_absolute_time(): uint64 {.importc, header: "<mach/mach_time.h>".}
  proc mach_timebase_info(info: var MachTimebaseInfoData) {.importc,
    header: "<mach/mach_time.h>".}

  var timeBaseInfo: MachTimebaseInfoData
  mach_timebase_info(timeBaseInfo)

  let scaleFactor = timeBaseInfo.numer.float64 / timeBaseInfo.denom.float64

  proc getMonotonicTime*(): float64 {.inline.} =
    return mach_absolute_time().float64 * scaleFactor
elif defined(posix):
  import posix

  proc getMonotonicTime*(): float64 {.inline.} =
    var spc: Timespec
    discard clock_gettime(CLOCK_MONOTONIC, spc)
    return spc.tv_sec.float64 * NS_IN_S + spc.tv_nsec.float64
else:
  {.error: "Unsupported platform".}
