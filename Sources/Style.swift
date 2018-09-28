import Foundation

public protocol StyleApplicator {
    func apply(to some: Any)
    func apply<MarkerOverride>(to some: Any, marker: MarkerOverride.Type)
}

public struct Style<Marker: Protocol, Target>: StyleApplicator {
    private let body: (Target) -> ()

    public func apply(to some: Any) {
        if some is Marker, let some = some as? Target {
            body(some)
        }
    }

    public func apply<MarkerOverride>(to some: Any, marker: MarkerOverride.Type) {
        if marker == Marker.self, let some = some as? Target {
            body(some)
        }
    }

    public init(body: @escaping (Target) -> ()) { self.body = body }
}

public struct StyleSheet: StyleApplicator {
    private let styles: [StyleApplicator]

    public func apply(to some: Any) {
        styles.lazy.reversed().forEach { $0.apply(to: some) }
    }

    public func apply<MarkerOverride>(to some: Any, marker: MarkerOverride.Type) {
        styles.lazy.reversed().forEach { $0.apply(to: some, marker: marker) }
    }

    public init(styles: [StyleApplicator]) { self.styles = styles }
}
