import Foundation

/// Statistical helpers for collections of `Double` values.
///
/// All computations are pure and dependency-free. Empty arrays are handled
/// safely by returning `nil` rather than trapping.
extension Array where Element == Double {
    /// The arithmetic mean of the elements, or `nil` when the array is empty.
    var mean: Double? {
        guard !isEmpty else { return nil }
        return reduce(0, +) / Double(count)
    }

    /// The sample standard deviation (using Bessel's correction, `n - 1`).
    ///
    /// Returns `nil` when there are fewer than two elements, since the sample
    /// standard deviation is undefined for a single value or an empty array.
    var standardDeviation: Double? {
        guard count >= 2, let mean else { return nil }
        let sumOfSquaredDeviations = reduce(0) { partial, value in
            let deviation = value - mean
            return partial + deviation * deviation
        }
        return (sumOfSquaredDeviations / Double(count - 1)).squareRoot()
    }
}
