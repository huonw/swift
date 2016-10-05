// RUN: %target-parse-verify-swift

protocol Base {}

// check protocol declarations are handled

protocol UndeclaredParameter {
    associatedtype T where X: Base // expected-error{{use of undeclared type 'X'}}
}

protocol NonGenericSameType1 {
    associatedtype T where T == Int // expected-error{{same-type requirement makes associated type 'T' non-generic}}
}
protocol NonGenericSameType2 {
    associatedtype T
    associatedtype U where T == Int // expected-error{{same-type requirement makes associated type 'T' non-generic}}
}

// protocol conformances are handled sensibly too

struct Conform1: Base {}
struct Conform2: Base {}
struct Nonconform {}

protocol SimpleWhere1 {
    associatedtype T where T: Base
}
struct Foo: SimpleWhere1 {
    typealias T = Conform1
}

protocol SimpleWhere2 {
    associatedtype T where T: Base // expected-note{{protocol requires nested type 'T'}}
}
struct Bar: SimpleWhere2 { // expected-error{{type 'Bar' does not conform to protocol 'SimpleWhere2'}}
    typealias T = Nonconform // expected-note{{possibly intended match 'Bar.T' (aka 'Nonconform') does not conform to 'Base'}}
}
