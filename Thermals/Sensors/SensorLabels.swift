/// Board labels for raw IOKit sensor names. A table of names seen on real chips, never a guess: unknown names stay raw.
enum SensorLabels {
    private static let exact = [
        "gas gauge battery": "BATTERY",
        "NAND CH0 temp": "SSD",
    ]

    /// Numbered families: `prefix`, a number, then `suffix` becomes `label` and the same number.
    private static let numbered: [(prefix: String, suffix: String, label: String)] = [
        ("PMU tdie", "", "CPU DIE"),
        ("PMU tdev", "", "PMU DEV"),
        ("NAND CH", " temp", "SSD CH"),
        ("SOC MTR Temp Sensor", "", "SOC"),
        ("PMGR SOC Die Temp Sensor", "", "SOC DIE"),
        ("pACC MTR Temp Sensor", "", "P-CORES"),
        ("eACC MTR Temp Sensor", "", "E-CORES"),
        ("GPU MTR Temp Sensor", "", "GPU"),
        ("ANE MTR Temp Sensor", "", "NEURAL ENGINE"),
        ("ISP MTR Temp Sensor", "", "CAMERA ISP"),
    ]

    static func label(for name: String) -> String {
        if let label = exact[name] { return label }
        for family in numbered where name.count > family.prefix.count + family.suffix.count
            && name.hasPrefix(family.prefix) && name.hasSuffix(family.suffix) {
            let number = name.dropFirst(family.prefix.count).dropLast(family.suffix.count)
            if number.allSatisfy({ $0.isASCII && $0.isNumber }) { return "\(family.label) \(number)" }
        }
        return name
    }
}
