import Foundation
import Observation

@MainActor
@Observable
final class UnitConverterViewModel {
    struct Row: Identifiable {
        let unit: MeasurementUnit
        let value: String

        var id: String { unit.id }
    }

    /// Water at ~4…20 °C; the field is editable for other media.
    static let defaultDensity = "1000"

    private(set) var category: UnitCategory = .pressure
    private(set) var unit: MeasurementUnit = UnitCategory.pressure.defaultUnit
    var valueText = "1"
    var densityText = defaultDensity

    var value: Double? { NumberParser.parse(valueText) }

    var density: Double? {
        guard let parsed = NumberParser.parse(densityText), parsed > 0 else { return nil }
        return parsed
    }

    var isValueInvalid: Bool { !valueText.allSatisfy(\.isWhitespace) && (value == nil || isBelowAbsoluteZero) }

    var isDensityInvalid: Bool { needsDensity && density == nil }

    var isBelowAbsoluteZero: Bool {
        guard category == .temperature, let value else { return false }
        return unit.toBase(value) < UnitConverter.absoluteZeroCelsius - 1e-9
    }

    /// Density only matters when the list mixes volume and mass flow.
    var needsDensity: Bool { category == .flow }

    func select(_ newCategory: UnitCategory) {
        guard newCategory != category else { return }
        category = newCategory
        unit = newCategory.defaultUnit
        valueText = newCategory == .temperature ? "20" : "1"
    }

    /// Picking another unit keeps the physical quantity: the field is rewritten in the new unit.
    func select(_ newUnit: MeasurementUnit) {
        guard newUnit != unit else { return }
        if let value, let converted = UnitConverter.convert(value, from: unit, to: newUnit, density: density) {
            valueText = UnitConverter.format(converted)
        }
        unit = newUnit
    }

    var rows: [Row] {
        guard let value, !isBelowAbsoluteZero else { return [] }
        return category.units.map { target in
            let converted = UnitConverter.convert(value, from: unit, to: target, density: density)
            return Row(unit: target, value: converted.map(UnitConverter.format) ?? "нужна плотность")
        }
    }

    var noteTitle: String { "\(category.title): \(valueText) \(unit.symbol)" }

    var summary: String? {
        let rows = rows
        guard !rows.isEmpty else { return nil }
        var lines = ["\(category.title): \(valueText) \(unit.symbol)"]
        if needsDensity, let density {
            lines.append("Плотность: \(UnitConverter.format(density)) кг/м³")
        }
        lines += rows.filter { $0.unit != unit }.map { "= \($0.value) \($0.unit.symbol)" }
        return lines.joined(separator: "\n")
    }
}
