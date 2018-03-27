// RUN: %target-typecheck-verify-swift
// RUN: %target-typecheck-verify-swift -debug-generic-signatures > %t.dump 2>&1
// RUN: %FileCheck %s < %t.dump

// SR-6569

protocol P {
    associatedtype A: P
}

struct Generically<Param> {}
extension Generically: P where Param: P, Param.A == Generically<Param> {
    typealias A = X
}

struct X: P {
    typealias A = X
}
struct Concretely<Param> {}
extension Concretely: P where Param: P, Param.A == Concretely<X> {
    typealias A = X
}
