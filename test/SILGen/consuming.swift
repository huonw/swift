// RUN: %target-swift-frontend -Xllvm -sil-full-demangle -emit-silgen %s -disable-objc-attr-requires-foundation-module -enable-sil-ownership -enable-guaranteed-normal-arguments | %FileCheck %s

import Swift

class RefAggregate {}
struct ValueAggregate { let x = RefAggregate() }

struct ConsumingTrivial {
    // CHECK-LABEL: sil hidden @$S9consuming16ConsumingTrivialV0A6NoArgsyyF : $@convention(method) (ConsumingTrivial) -> () {
    __consuming func consumingNoArgs() {
        let s = self
    }
    // CHECK-LABEL: sil hidden @$S9consuming16ConsumingTrivialV0A4Args7trivial5value3refySin_AA14ValueAggregateVnAA03RefI0CntF : $@convention(method) (Int, @owned ValueAggregate, @owned RefAggregate, ConsumingTrivial) -> () {
    __consuming func consumingArgs(trivial : __owned Int, value : __owned ValueAggregate, ref : __owned RefAggregate) {
        let s = self
        let t = trivial
        let v = value
        let r = ref
    }
}

enum ConsumingEnum {
    case a, b(RefAggregate), c(ValueAggregate)

    // Make sure we can call borrowing functions from consuming ones and vice versa.

    // CHECK-LABEL: sil hidden @$S9consuming13ConsumingEnumO9borrowingyyF : $@convention(method) (@guaranteed ConsumingEnum) -> () {
    func borrowing() {
        // CHECK: bb0([[SELF:%.*]] : @guaranteed $ConsumingEnum):
        // CHECK:   [[COPIED:%.*]] = copy_value [[SELF]] : $ConsumingEnum
        // CHECK:   [[CONSUMING_NO_ARGS:%.*]] = function_ref @$S9consuming13ConsumingEnumO0A6NoArgsyyF : $@convention(method) (@owned ConsumingEnum) -> ()
        // CHECK:   {{%.*}} = apply [[CONSUMING_NO_ARGS]]([[COPIED]])
        // CHECK: } // end sil function '$S9consuming13ConsumingEnumO9borrowingyyF'
        self.consumingNoArgs()
    }

    // CHECK-LABEL: sil hidden @$S9consuming13ConsumingEnumO0A6NoArgsyyF : $@convention(method) (@owned ConsumingEnum) -> () {
    __consuming func consumingNoArgs() {
        // CHECK: bb0([[SELF:%.*]] : @owned $ConsumingEnum):
        // CHECK:   [[BORROWED:%.*]] = begin_borrow [[SELF]] : $ConsumingEnum
        // CHECK:   [[BORROWING:%.*]] = function_ref @$S9consuming13ConsumingEnumO9borrowingyyF : $@convention(method) (@guaranteed ConsumingEnum) -> ()
        // CHECK:   {{%.*}} = apply [[BORROWING]]([[BORROWED]]) : $@convention(method) (@guaranteed ConsumingEnum) -> ()
        // CHECK:   end_borrow [[BORROWED]] from [[SELF]] : $ConsumingEnum, $ConsumingEnum
        // CHECK:   destroy_value [[SELF]] : $ConsumingEnum
        // CHECK: } // end sil function '$S9consuming13ConsumingEnumO0A6NoArgsyyF'
        self.borrowing()
    }

    // CHECK-LABEL: sil hidden @$S9consuming13ConsumingEnumO0A4Args7trivial5value3refySin_AA14ValueAggregateVnAA03RefI0CntF : $@convention(method) (Int, @owned ValueAggregate, @owned RefAggregate, @owned ConsumingEnum) -> () {
    __consuming func consumingArgs(trivial : __owned Int, value : __owned ValueAggregate, ref : __owned RefAggregate) {
        let s = self
        let t = trivial
        let v = value
        let r = ref
    }
}

// Check the various other data types work:
struct ConsumingStructRef {
    var x: RefAggregate
    // CHECK-LABEL: sil hidden @$S9consuming18ConsumingStructRefV0A6NoArgsyyF : $@convention(method) (@owned ConsumingStructRef) -> () {
    __consuming func consumingNoArgs() {
        let s = self
    }
    // CHECK-LABEL: sil hidden @$S9consuming18ConsumingStructRefV0A4Args7trivial5value3refySin_AA14ValueAggregateVnAA0dJ0CntF : $@convention(method) (Int, @owned ValueAggregate, @owned RefAggregate, @owned ConsumingStructRef) -> () {
    __consuming func consumingArgs(trivial : __owned Int, value : __owned ValueAggregate, ref : __owned RefAggregate) {
        let s = self
        let t = trivial
        let v = value
        let r = ref
    }
}

struct ConsumingStructValue {
    var x: ValueAggregate
    // CHECK-LABEL: sil hidden @$S9consuming20ConsumingStructValueV0A6NoArgsyyF : $@convention(method) (@owned ConsumingStructValue) -> () {
    __consuming func consumingNoArgs() {
        let s = self
    }
    // CHECK-LABEL: sil hidden @$S9consuming20ConsumingStructValueV0A4Args7trivial5value3refySin_AA0D9AggregateVnAA03RefI0CntF : $@convention(method) (Int, @owned ValueAggregate, @owned RefAggregate, @owned ConsumingStructValue) -> () {
    __consuming func consumingArgs(trivial : __owned Int, value : __owned ValueAggregate, ref : __owned RefAggregate) {
        let s = self
        let t = trivial
        let v = value
        let r = ref
    }
}

class ConsumingClass {
    var x: ValueAggregate = ValueAggregate()
    // CHECK-LABEL: sil hidden @$S9consuming14ConsumingClassC0A6NoArgsyyF : $@convention(method) (@owned ConsumingClass) -> () {
    __consuming func consumingNoArgs() {
        let s = self
    }
    // CHECK-LABEL: sil hidden @$S9consuming14ConsumingClassC0A4Args7trivial5value3refySin_AA14ValueAggregateVnAA03RefI0CntF : $@convention(method) (Int, @owned ValueAggregate, @owned RefAggregate, @owned ConsumingClass) -> () {
    __consuming func consumingArgs(trivial : __owned Int, value : __owned ValueAggregate, ref : __owned RefAggregate) {
        let s = self
        let t = trivial
        let v = value
        let r = ref
    }
}

// CHECK-LABEL: sil hidden @$S9consuming22guaranteedPartialThunk1xyycAA13ConsumingEnumO_tF : $@convention(thin) (@guaranteed ConsumingEnum) -> @owned @callee_guaranteed () -> () {
func guaranteedPartialThunk(x: ConsumingEnum) -> () -> () {
    // CHECK:      bb0([[X:%.*]] : @guaranteed $ConsumingEnum):
    // CHECK-NEXT:   debug_value [[X]]
    // CHECK-NEXT:   [[COPY:%.*]] = copy_value [[X]] : $ConsumingEnum
    // CHECK-NEXT:   // function_ref curry thunk of consuming.ConsumingEnum.consumingNoArgs() -> ()
    // CHECK-NEXT:   [[CURRY_THUNK:%.*]] = function_ref @$S9consuming13ConsumingEnumO0A6NoArgsyyFTc : $@convention(thin) (@owned ConsumingEnum) -> @owned @callee_guaranteed () -> ()
    // CHECK-NEXT:   [[RET:%.*]] = apply [[CURRY_THUNK]]([[COPY]]) : $@convention(thin) (@owned ConsumingEnum) -> @owned @callee_guaranteed () -> ()
    // CHECK-NEXT:   return [[RET]]
    // CHECK-NEXT: } // end sil function '$S9consuming22guaranteedPartialThunk1xyycAA13ConsumingEnumO_tF'
    return x.consumingNoArgs
}
// CHECK-LABEL: sil shared [thunk] @$S9consuming13ConsumingEnumO0A6NoArgsyyFTc : $@convention(thin) (@owned ConsumingEnum) -> @owned @callee_guaranteed () -> () {
// CHECK:      bb0(%0 : @owned $ConsumingEnum):
// CHECK-NEXT:   // function_ref consuming.ConsumingEnum.consumingNoArgs() -> ()
// CHECK-NEXT:   [[METHOD:%.*]] = function_ref @$S9consuming13ConsumingEnumO0A6NoArgsyyF : $@convention(method) (@owned ConsumingEnum) -> ()
// CHECK-NEXT:   [[RET:%.*]] = partial_apply [callee_guaranteed] [[METHOD]](%0)
// CHECK-NEXT:   return [[RET]] : $@callee_guaranteed () -> ()
// CHECK-NEXT: } // end sil function '$S9consuming13ConsumingEnumO0A6NoArgsyyFTc'

// CHECK-LABEL: sil hidden @$S9consuming17ownedPartialThunk1xyycAA13ConsumingEnumOn_tF : $@convention(thin) (@owned ConsumingEnum) -> @owned @callee_guaranteed () -> () {
func ownedPartialThunk(x: __owned ConsumingEnum) -> () -> () {
    // CHECK:      bb0([[X:%.*]] : @owned $ConsumingEnum):
    // CHECK-NEXT:   debug_value [[X]]
    // CHECK-NEXT:   [[BORROW:%.*]] = begin_borrow [[X]] : $ConsumingEnum
    // CHECK-NEXT:   [[COPY:%.*]] = copy_value [[BORROW]] : $ConsumingEnum
    // CHECK-NEXT:   // function_ref curry thunk of consuming.ConsumingEnum.consumingNoArgs() -> ()
    // CHECK-NEXT:   [[CURRY_THUNK:%.*]] = function_ref @$S9consuming13ConsumingEnumO0A6NoArgsyyFTc : $@convention(thin) (@owned ConsumingEnum) -> @owned @callee_guaranteed () -> ()
    // CHECK-NEXT:   [[RET:%.*]] = apply [[CURRY_THUNK]]([[COPY]])
    // CHECK-NEXT:   end_borrow [[BORROW]] from [[X]] : $ConsumingEnum, $ConsumingEnum
    // CHECK-NEXT:   destroy_value [[X]] : $ConsumingEnum
    // CHECK-NEXT:   return [[RET]] : $@callee_guaranteed () -> ()
    // CHECK-NEXT: } // end sil function '$S9consuming17ownedPartialThunk1xyycAA13ConsumingEnumOn_tF'
    return x.consumingNoArgs
}

// CHECK-LABEL: sil hidden @$S9consuming19guaranteedFullThunkyycAA13ConsumingEnumOhcyF : $@convention(thin) () -> @owned @callee_guaranteed (@guaranteed ConsumingEnum) -> @owned @callee_guaranteed () -> () {
func guaranteedFullThunk() -> (__shared ConsumingEnum) -> () -> () {
    // CHECK-NEXT: bb0:
    // CHECK-NEXT:   {{%.*}} = metatype
    // CHECK-NEXT:   // function_ref curry thunk of consuming.ConsumingEnum.consumingNoArgs() -> ()
    // CHECK-NEXT:   [[CURRY_THUNK:%.*]] = function_ref @$S9consuming13ConsumingEnumO0A6NoArgsyyFTc : $@convention(thin) (@owned ConsumingEnum) -> @owned @callee_guaranteed () -> ()
    // CHECK-NEXT:   [[THICK_CURRY_THUNK:%.*]] = thin_to_thick_function [[CURRY_THUNK]] : ${{.*}} to $@callee_guaranteed (@owned ConsumingEnum) -> @owned @callee_guaranteed () -> ()
    // CHECK-NEXT:   // function_ref reabstraction thunk helper
    // CHECK-NEXT:   [[REABSTRACTION_THUNK:%.*]] = function_ref @$S9consuming13ConsumingEnumOIeg_Iegxo_ACIeg_Ieggo_TR : $@convention(thin) (@guaranteed ConsumingEnum, @guaranteed @callee_guaranteed (@owned ConsumingEnum) -> @owned @callee_guaranteed () -> ()) -> @owned @callee_guaranteed () -> ()
    // CHECK-NEXT:   [[RET:%.*]] = partial_apply [callee_guaranteed] [[REABSTRACTION_THUNK]]([[THICK_CURRY_THUNK]])
    // CHECK-NEXT:   return [[RET]] : $@callee_guaranteed (@guaranteed ConsumingEnum) -> @owned @callee_guaranteed () -> ()
    // CHECK-NEXT: } // end sil function '$S9consuming19guaranteedFullThunkyycAA13ConsumingEnumOhcyF'
    return ConsumingEnum.consumingNoArgs
}

// Reabstraction thunk for converting the @owned self parameter to a @guaranteed one.

// CHECK-LABEL: sil shared [transparent] [serializable] [reabstraction_thunk] @$S9consuming13ConsumingEnumOIeg_Iegxo_ACIeg_Ieggo_TR : $@convention(thin) (@guaranteed ConsumingEnum, @guaranteed @callee_guaranteed (@owned ConsumingEnum) -> @owned @callee_guaranteed () -> ()) -> @owned @callee_guaranteed () -> () {
// CHECK:      bb0(%0 : @guaranteed $ConsumingEnum, %1 : @guaranteed $@callee_guaranteed (@owned ConsumingEnum) -> @owned @callee_guaranteed () -> ()):
// CHECK-NEXT:   [[COPY:%.*]] = copy_value %0 : $ConsumingEnum
// CHECK-NEXT:   [[RET:%.*]] = apply %1([[COPY]]) : $@callee_guaranteed (@owned ConsumingEnum) -> @owned @callee_guaranteed () -> ()
// CHECK-NEXT:   return [[RET]] : $@callee_guaranteed () -> ()
// CHECK-NEXT: } // end sil function '$S9consuming13ConsumingEnumOIeg_Iegxo_ACIeg_Ieggo_TR'

// CHECK-LABEL: sil hidden @$S9consuming14ownedFullThunkyycAA13ConsumingEnumOncyF : $@convention(thin) () -> @owned @callee_guaranteed (@owned ConsumingEnum) -> @owned @callee_guaranteed () -> () {
func ownedFullThunk() -> (__owned ConsumingEnum) -> () -> () {
    // CHECK-NEXT: bb0:
    // CHECK-NEXT:   {{%.*}} = metatype
    // CHECK-NEXT:   // function_ref curry thunk of consuming.ConsumingEnum.consumingNoArgs() -> ()
    // CHECK-NEXT:   [[CURRY_THUNK:%.*]] = function_ref @$S9consuming13ConsumingEnumO0A6NoArgsyyFTc : $@convention(thin) (@owned ConsumingEnum) -> @owned @callee_guaranteed () -> ()
    // CHECK-NEXT:   [[THICK_CURRY_THUNK:%.*]] = thin_to_thick_function [[CURRY_THUNK]] : ${{.*}} to $@callee_guaranteed (@owned ConsumingEnum) -> @owned @callee_guaranteed () -> ()
    // CHECK-NEXT:   return [[THICK_CURRY_THUNK]] : $@callee_guaranteed (@owned ConsumingEnum) -> @owned @callee_guaranteed () -> ()
    // CHECK-NEXT: } // end sil function '$S9consuming14ownedFullThunkyycAA13ConsumingEnumOncyF'
    return ConsumingEnum.consumingNoArgs
}
