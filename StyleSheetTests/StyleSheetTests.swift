//
//  StyleSheetTests.swift
//  StyleSheetTests
//
//  Created by Cristian Filipov on 9/28/18.
//  Copyright © 2018 Cristian Filipov. All rights reserved.
//

import XCTest
import UIKit
@testable import StyleSheet

@objc protocol P1 {}
@objc protocol P2: P1 {}

class A: NSObject { var tag: String = "" }
class B: A { }
class C: B, P1 {}
class D: C, P2 {}
class Z: NSObject {}

class StyleSheetTests: XCTestCase {

    func testOrderOfStyles() {
        let stylesheet = StyleSheet(styles: [
            Style(A.self) { $0.tag = "A" },
            Style(B.self) { $0.tag = "B" }
        ])
        let a = B()
        stylesheet.apply(to: a)
        XCTAssertEqual(a.tag, "B")
    }

    // This test used to fail, now with sorting it passes
    func testOrderOfStylesRev() {
        let stylesheet = StyleSheet(styles: [
            Style(B.self) { $0.tag = "B" },
            Style(A.self) { $0.tag = "A" }
        ])
        let b = B()
        stylesheet.apply(to: b)
        XCTAssertEqual(b.tag, "B")
    }

    func testOrderOfStylesMarkerRev() {
        let stylesheet = StyleSheet(styles: [
            Style(D.self, P2.self) { $0.tag = "D_P2" },
            Style(D.self, P1.self) { $0.tag = "D_P1" },
            Style(C.self, P1.self) { $0.tag = "C_P1" }
        ])

        print("stylesheet: \(stylesheet.styles)")

        let d = D()
        stylesheet.apply(to: d)
        XCTAssertEqual(d.tag, "D_P2")

        let a = A()
        stylesheet.apply(to: a)
        XCTAssertEqual(a.tag, "")

        let c = C()
        stylesheet.apply(to: c)
        XCTAssert(class_conformsToProtocol(object_getClass(c), P1.self))
        XCTAssert(class_conformsToProtocol(object_getClass(c), stylesheet.styles[0].marker))
        XCTAssertEqual(c.tag, "C_P1")
    }

    func testOperator() {
        let stylesheet = StyleSheet(styles: [
            (C.self) => { $0.tag = "C" },
            (D.self) => { $0.tag = "D" },
            (C.self, P1.self) => { $0.tag = "C_P1" },
            (D.self, P2.self) => { $0.tag = "D_P2" },
        ])

        let c = C()
        stylesheet.apply(to: c)
        XCTAssertEqual(c.tag, "C_P1")

        let d = D()
        stylesheet.apply(to: d)
        XCTAssertEqual(d.tag, "D_P2")
    }

    func test_class_getAllSuperclasses() {
        let classes = class_getAllSuperclasses(D.self)

        XCTAssertTrue(classes.count == 4)
        XCTAssertTrue(classes[0] == C.self)
        XCTAssertTrue(classes[1] == B.self)
        XCTAssertTrue(classes[2] == A.self)
        XCTAssertTrue(classes[3] == NSObject.self)
    }

    func test_class_isSubclass() {
        XCTAssertTrue(class_isSubclass(D.self, C.self))
        XCTAssertTrue(class_isSubclass(C.self, B.self))
        XCTAssertTrue(class_isSubclass(B.self, A.self))
        XCTAssertTrue(class_isSubclass(A.self, NSObject.self))

        XCTAssertFalse(class_isSubclass(NSObject.self, A.self))
        XCTAssertFalse(class_isSubclass(A.self, B.self))
        XCTAssertFalse(class_isSubclass(B.self, C.self))
        XCTAssertFalse(class_isSubclass(C.self, D.self))
    }

    func test_compareTarget() {
        let styles: [AnyStyle] = [
            Style(C.self) { _ in },
            Style(B.self) { _ in },
            Style(A.self) { _ in }
        ]

        let sorted = styles.sorted(by: compareTarget).map { $0.target }
        let expected: [AnyClass] = [A.self, B.self, C.self]
        XCTAssertTrue(sorted.count == expected.count)
        XCTAssertTrue(zip(sorted, expected).filter { $0 != $1 }.isEmpty)
    }

    func test_compareMarker() {
        let styles: [AnyStyle] = [
            Style(AnyObject.self, P2.self) { _ in },
            Style(AnyObject.self, P1.self) { _ in },
        ]

        let sorted = styles.sorted(by: compareMarker).map { $0.marker }
        let expected: [Protocol] = [P1.self, P2.self]
        XCTAssertTrue(sorted.count == expected.count)
        let compacted = sorted.compactMap { $0 }
        XCTAssertTrue(compacted.count == expected.count)
        XCTAssertTrue(zip(compacted, expected).filter { !protocol_isEqual($0.0, $0.1) }.isEmpty)
    }

    func test_compareStyle() {
        let styles: [AnyStyle] = [
            Style(B.self, P2.self) { _ in },
            Style(B.self, P1.self) { _ in },
            Style(NSObject.self, P2.self) { _ in },
            Style(NSObject.self, P1.self) { _ in },
            Style(A.self, P2.self) { _ in },
            Style(A.self, P1.self) { _ in },
        ]

        let sorted = styles.sorted(by: compareStyle).map {
            (target: $0.target,
             marker: $0.marker)
        }
        let expected: [(target: AnyClass, marker: Protocol?)] = [
            (target: NSObject.self, marker: P1.self),
            (target: NSObject.self, marker: P2.self),
            (target: A.self, marker: P1.self),
            (target: A.self, marker: P2.self),
            (target: B.self, marker: P1.self),
            (target: B.self, marker: P2.self),
        ]

        XCTAssertTrue(sorted.count == expected.count)
        XCTAssertTrue(zip(sorted, expected).filter {
            let (a, b) = $0
            return a.target != b.target || !protocol_isEqual(a.marker, b.marker)
        }.isEmpty)
    }

    func test_stylesheetOrder() {
        let stylesheet = StyleSheet(styles: [
            Style(B.self, P2.self) { _ in },
            Style(B.self, P1.self) { _ in },
            Style(NSObject.self, P2.self) { _ in },
            Style(NSObject.self, P1.self) { _ in },
            Style(A.self, P2.self) { _ in },
            Style(A.self, P1.self) { _ in },
        ])

        let sorted = stylesheet.styles

        let expected: [(target: AnyClass, marker: Protocol?)] = [
            (target: NSObject.self, marker: P1.self),
            (target: NSObject.self, marker: P2.self),
            (target: A.self, marker: P1.self),
            (target: A.self, marker: P2.self),
            (target: B.self, marker: P1.self),
            (target: B.self, marker: P2.self),
        ]

        XCTAssertTrue(sorted.count == expected.count)
        XCTAssertTrue(zip(sorted, expected).filter {
            let (a, b) = $0
            return a.target != b.target || !protocol_isEqual(a.marker, b.marker)
        }.isEmpty)
    }

    func test_stylesheetOrder2() {
        let stylesheet = StyleSheet(styles: [
            Style(B.self) { $0.tag = "B" },
            Style(A.self) { $0.tag = "A" }
        ])

        let sorted = stylesheet.styles.map { $0.target }

        let expected: [AnyClass] = [
            A.self,
            B.self,
        ]

        XCTAssertTrue(sorted.count == expected.count)
        XCTAssertTrue(zip(sorted, expected).filter { $0.0 != $0.1 }.isEmpty)

        let b = B()
        stylesheet.apply(to: b)
        XCTAssertEqual(b.tag, "B")
    }

}
