/// A per-element value provider explicitly cached when passed to a cached force factory.
///
/// Closures are never reevaluated on ticks. Recreate the force after relevant graph metadata
/// changes. Duplicate stable IDs use the first cached value.
public struct CachedValueProvider<Input: Sendable>: Sendable {
  private let value: @Sendable (Input, Int) -> Double
  /// Creates a provider from a sendable closure receiving the value and its revision index.
  public init(_ value: @escaping @Sendable (Input, Int) -> Double) { self.value = value }
  /// Creates a provider that caches the same value for every element.
  public static func constant(_ value: Double) -> Self { Self { _, _ in value } }
  func values(for inputs: [Input]) -> [Double] {
    inputs.enumerated().map { value($0.element, $0.offset) }
  }
}

/// Selects exact reference calculation or Barnes-Hut approximation.
public enum ManyBodyAlgorithm: Sendable {
  /// Always evaluates every pair.
  case direct
  /// Uses direct evaluation below `directThreshold`, otherwise a deterministic orthant tree.
  /// Theta must be finite and positive; invalid theta disables the force. Negative thresholds
  /// clamp to zero.
  case barnesHut(theta: Double = 0.9, directThreshold: Int = 32)
}
