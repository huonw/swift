// RUN: %target-parse-verify-swift

protocol Base {}

protocol UndeclaredAssociatedType {
    associatedtype T where T: Base, T.X: Base // expected-error{{TODO}}
    associatedtype U where U: Base, U.X == Int // expected-error{{TODO}}
}

// check for requirements on associated types that are not satisfied
struct Conform1: Base {
    func method() {
        print("hello")
    }
}
struct Conform2: Base {}
struct Nonconform {}

protocol SimpleWhere {
    associatedtype T where T: Base
}

protocol SameType {
    associatedtype X where X: SimpleWhere, X.T == Conform1 // expected-note{{note the types 'Conform2' (aka 'Self.X.T') and 'Conform1' (aka 'Conform1') are required to be equivalent}}
}

struct Foo: SimpleWhere {
    typealias T = Conform1
}
struct Bar: SameType {
    typealias X = Foo
}

struct Foo2: SimpleWhere {
    typealias T = Conform2
}
struct Bar2: SameType { // expected-error{{type 'Bar2' does not conform to protocol 'SameType'}}
    typealias X = Foo2 // expected-note{{possibly intended match does not satisfy same-type requirement}}
}

protocol Extra {}
extension Conform1: Extra {}

protocol Conformance {
    associatedtype X where X: SimpleWhere, X.T: Extra // expected-note{{note the type 'Conform2' (aka 'Self.X.T') is required to conform to 'Extra'
}

struct Baz: Conformance {
    typealias X = Foo
}

struct Baz2: Conformance { // expected-error{{type 'Baz2' does not conform to protocol 'Conformance'}}
    typealias X = Foo2 // expected-note{{possibly intended match does not satisfy conformance requirement}}
}
