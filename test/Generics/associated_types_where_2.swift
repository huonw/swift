// RUN: %target-parse-verify-swift

protocol Base {}

/*protocol UndeclaredAssociatedType {
    associatedtype T where T: Base, T.X: Base // expected-error{{TODO}}
    associatedtype U where U: Base, U.X == Int // expected-error{{TODO}}
}*/

struct Conform1: Base {
    func method() {
        print("hello")
    }
}
struct Conform2: Base {}
struct Nonconform {}

protocol SimpleWhere {
    associatedtype T where T: Base
    var t: T { get }
}

protocol Bounded {
    associatedtype X where X: SimpleWhere, X.T == Conform1
    var x: X { get }
}
/*
struct Foo: SimpleWhere {
    typealias T = Conform1
    var t = Conform1()
}
struct Bar: Bounded {
    typealias X = Foo
    var x = Foo()
}
*/

struct Foo2: SimpleWhere {
    typealias T = Conform2
    var t = Conform2()
}
struct Bar2: Bounded {
    typealias X = Foo2 // expected-error{{X}}
    var x = Foo2()
}

// FIXME: this compiles and prints Conform1() !?!
func foo<Y: Bounded>(y: Y) {
    print(y.x.t)
}
foo(y: Bar2())




