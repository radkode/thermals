import Foundation

struct SensorSample: Sendable {
    let date: Date
    var sensors: [SensorReading] = []
    var thermalState = ProcessInfo.ThermalState.nominal
    var memory: MemoryReading?
    var fans: [FanReading]?
    var systemPower: Double?
    var powerSource: PowerSourceReading?
    var gpuPower: Double?
    var ticks: [CPUTicks]?
    var cores: [CoreInfo] = []
}

actor SensorCollector {
    private lazy var temperatures = HIDTemperatureReader()
    private lazy var smc = SMCReader()
    private lazy var gpu = GPUPowerReader()
    private lazy var cores = CoreLayout.read()
    private var gpuMeter = GPUPowerMeter()

    func sample() -> SensorSample {
        let date = Date.now
        let sensors = TemperatureSensors.byName(TemperatureSensors.usable(temperatures?.read() ?? []))
        let thermalState = ProcessInfo.processInfo.thermalState
        let memory = MemoryStats.read()
        let fans = smc?.fans()
        let systemPower = smc?.systemPower()
        let powerSource = PowerSourceReading.read()
        let gpuPower = gpu?.sample().flatMap { gpuMeter.watts($0) }
        return SensorSample(date: date, sensors: sensors, thermalState: thermalState, memory: memory,
                            fans: fans, systemPower: systemPower, powerSource: powerSource,
                            gpuPower: gpuPower, ticks: CPULoad.sample(), cores: cores)
    }
}
