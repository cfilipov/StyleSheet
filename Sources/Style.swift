import Foundation

public protocol StyleApplicator {
    func apply(to some: AnyObject)
    func apply(to some: AnyObject, marker override: Protocol)
}

public protocol AnyStyle: StyleApplicator {
    var marker: Protocol? { get }
    var target: AnyClass { get }
}

public struct Style<Target: AnyObject>: StyleApplicator, AnyStyle {
    private let body: (Target) -> ()
    public let marker: Protocol?
    public let target: AnyClass

    public func apply(to some: AnyObject) {
        if let marker = marker {
            guard
                let c = object_getClass(some),
                class_conformsToProtocol(c, marker)
            else {
                return
            }
        }
        guard
            let some = some as? Target
        else {
            return
        }
        body(some)
    }

    public func apply(to some: AnyObject, marker override: Protocol) {
        guard
            protocol_isEqual(marker, override),
            let some = some as? Target
        else {
            return
        }
        body(some)
    }

    public init(
        _ target: Target.Type,
        _ marker: Protocol? = nil,
        body: @escaping (Target) -> ()
    ) {
        self.body = body
        self.marker = marker
        self.target = Target.self
    }
}

public struct StyleSheet: StyleApplicator {
    let styles: [AnyStyle]

    public func apply(to some: AnyObject) {
        styles.forEach { $0.apply(to: some) }
    }

    public func apply(to some: AnyObject, marker override: Protocol) {
        styles.forEach { $0.apply(to: some, marker: override) }
    }

    public init(styles: [AnyStyle]) {
        self.styles = styles.sorted(by: compareStyle)
    }
}

func class_getAllSuperclasses(_ c: AnyClass) -> [AnyClass] {
    var result = [AnyClass]()
    var sup: AnyClass? = class_getSuperclass(c)
    while let s = sup {
        result.append(s)
        sup = class_getSuperclass(s)
    }
    return result
}

func class_isSubclass(_ a: AnyClass, _ b: AnyClass) -> Bool {
    return class_getAllSuperclasses(a).contains(where: { $0 == b })
}

func compareStyle(_ a: AnyStyle, _ b: AnyStyle) -> Bool {
    if a.target == b.target {
        return compareMarker(a, b)
    } else {
        return compareTarget(a, b)
    }
}

func compareTarget(_ a: AnyStyle, _ b: AnyStyle) -> Bool {
    if a.target == b.target {
        return false
    }
    if a.target == AnyObject.self {
        return true
    }
    if class_isSubclass(b.target, a.target) {
        return true
    }
    return false
}

func compareMarker(_ a: AnyStyle, _ b: AnyStyle) -> Bool {
    switch (a.marker, b.marker) {
    case (.none, .some(_)):
        return true
    case (.some(let aMarker), .some(let bMarker))
        where protocol_conformsToProtocol(bMarker, aMarker):
        return true
    default: return false
    }
}
