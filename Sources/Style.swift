import Foundation

public protocol StyleApplicator {
    func apply(to some: AnyObject, marker override: Protocol?)
}

public protocol AnyStyle: StyleApplicator {
    var marker: Protocol? { get }
    var target: AnyClass { get }
}

public struct Style<Target: AnyObject>: StyleApplicator, AnyStyle {
    private let body: (Target) -> ()
    public let marker: Protocol?
    public let target: AnyClass

    public func apply(to some: AnyObject, marker override: Protocol? = nil) {
        guard
            let some = some as? Target
            else {
                return
        }
        if let override = override {
            guard
                protocol_isEqual(marker, override)
                else {
                    return
            }
        } else if let marker = marker {
            guard
                let c = object_getClass(some),
                class_conformsToProtocol(c, marker)
                else {
                    return
            }
        }
        body(some)
    }

    public init(
        _ target: Target.Type,
        _ marker: Protocol? = nil,
        _ body: @escaping (Target) -> ()
        ) {
        self.body = body
        self.marker = marker
        self.target = Target.self
    }

    public static func == (lhs: Style<Target>, rhs: Style<Target>) -> Bool {
        return protocol_isEqual(lhs.marker, rhs.marker) && lhs.target == rhs.target
    }
}

extension AnyStyle {
    var styleId: String {
        if let marker = marker {
            return NSStringFromClass(target) +  " " + NSStringFromProtocol(marker)
        } else {
            return NSStringFromClass(target)
        }
    }
}

public struct StyleSheet: StyleApplicator {
    let styles: [AnyStyle]

    public func apply(to some: AnyObject, marker override: Protocol? = nil) {
        styles.forEach { $0.apply(to: some, marker: override) }
    }

    public init(styles: [AnyStyle]) throws {
        self.styles = try styles.sorted(by: compareStyle).throwIfNotDistinct()
    }
}

extension Array where Element == AnyStyle {
    func throwIfNotDistinct() throws -> [Element] {
        var ids = [String: Void]()
        try forEach {
            let styleId = $0.styleId
            if let _ = ids[styleId] {
                throw NSError(domain: "FerrumError", code: 0, userInfo: nil)
            }
            ids[styleId] = ()
        }
        return self
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

infix operator => : AssignmentPrecedence

public func => <Target: AnyObject>(left: (Target.Type, Protocol?), right: @escaping (Target) -> ()) -> Style<Target> {
    let (target, marker) = left
    return Style(target, marker, right)
}

public func => <Target: AnyObject>(left: (Target.Type), right: @escaping (Target) -> ()) -> Style<Target> {
    return Style(left, nil, right)
}
