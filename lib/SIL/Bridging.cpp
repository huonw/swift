//===--- Bridging.cpp - Bridging imported Clang types to Swift ------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//
// This file defines routines relating to bridging Swift types to C types,
// working in concert with the Clang importer.
//
//===----------------------------------------------------------------------===//

#define DEBUG_TYPE "libsil"
#include "swift/SIL/SILType.h"
#include "swift/SIL/SILModule.h"
#include "swift/AST/Decl.h"
#include "swift/AST/DiagnosticsSIL.h"
#include "swift/AST/ProtocolConformance.h"
#include "clang/AST/DeclObjC.h"
#include "llvm/Support/Debug.h"
#include "llvm/Support/ErrorHandling.h"
using namespace swift;
using namespace swift::Lowering;


SILType TypeConverter::getLoweredTypeOfGlobal(VarDecl *var) {
  AbstractionPattern origType = getAbstractionPattern(var);
  assert(!origType.isTypeParameter());
  return getLoweredType(origType, origType.getType()).getObjectType();
}

AnyFunctionType::CanParamArrayRef
TypeConverter::getBridgedInputParams(SILFunctionTypeRepresentation rep,
                                     AbstractionPattern pattern,
                                     AnyFunctionType::CanParamArrayRef params) {
  SmallVector<AnyFunctionType::Param, 4> bridgedParams;
  bool changed = false;
  for (unsigned i : indices(params)) {
    const auto &param = params[i];
    auto type = CanType(param.getType());
    Type bridged = getLoweredBridgedType(pattern.getTupleElementType(i), type,
                                         rep, TypeConverter::ForArgument);
    if (!bridged) {
      Context.Diags.diagnose(SourceLoc(), diag::could_not_find_bridge_type,
                             type);

      llvm::report_fatal_error("unable to set up the ObjC bridge!");
    }

    CanType canBridged = bridged->getCanonicalType();
    if (canBridged != type) {
      changed = true;
      bridgedParams.push_back(AnyFunctionType::Param(
          canBridged, param.getLabel(), param.getParameterFlags()));
    } else {
      bridgedParams.push_back(param);
    }
  }
  if (!changed)
    return params;
  return Context.AllocateCopy(bridgedParams);
}

/// Bridge a result type.
CanType TypeConverter::getBridgedResultType(SILFunctionTypeRepresentation rep,
                                            AbstractionPattern pattern,
                                            CanType result,
                                            bool suppressOptional) {
  auto loweredType =
    getLoweredBridgedType(pattern, result, rep,
                          suppressOptional
                            ? TypeConverter::ForNonOptionalResult
                            : TypeConverter::ForResult);

  if (!loweredType) {
    Context.Diags.diagnose(SourceLoc(), diag::could_not_find_bridge_type,
                           result);

    llvm::report_fatal_error("unable to set up the ObjC bridge!");
  }

  return loweredType->getCanonicalType();
}

Type TypeConverter::getLoweredBridgedType(AbstractionPattern pattern,
                                          Type t,
                                          SILFunctionTypeRepresentation rep,
                                          BridgedTypePurpose purpose) {
  switch (rep) {
  case SILFunctionTypeRepresentation::Thick:
  case SILFunctionTypeRepresentation::Thin:
  case SILFunctionTypeRepresentation::Method:
  case SILFunctionTypeRepresentation::WitnessMethod:
  case SILFunctionTypeRepresentation::Closure:
    // No bridging needed for native CCs.
    return t;
  case SILFunctionTypeRepresentation::CFunctionPointer:
  case SILFunctionTypeRepresentation::ObjCMethod:
  case SILFunctionTypeRepresentation::Block:
    // Map native types back to bridged types.

    bool canBridgeBool = (rep == SILFunctionTypeRepresentation::ObjCMethod);

    // Look through optional types.
    if (auto valueTy = t->getOptionalObjectType()) {
      pattern = pattern.transformType([](CanType patternTy) {
        return CanType(patternTy->getOptionalObjectType());
      });
      auto ty = getLoweredCBridgedType(pattern, valueTy, canBridgeBool, false);
      return ty ? OptionalType::get(ty) : ty;
    }
    return getLoweredCBridgedType(pattern, t, canBridgeBool,
                                  purpose == ForResult);
  }

  llvm_unreachable("Unhandled SILFunctionTypeRepresentation in switch.");
};

Type TypeConverter::getLoweredCBridgedType(AbstractionPattern pattern,
                                           Type t,
                                           bool canBridgeBool,
                                           bool bridgedCollectionsAreOptional) {
  auto clangTy = pattern.isClangType() ? pattern.getClangType() : nullptr;

  // Bridge Bool back to ObjC bool, unless the original Clang type was _Bool
  // or the Darwin Boolean type.
  auto nativeBoolTy = getBoolType();
  if (nativeBoolTy && t->isEqual(nativeBoolTy)) {
    if (clangTy) {
      if (clangTy->isBooleanType())
        return t;
      if (clangTy->isSpecificBuiltinType(clang::BuiltinType::UChar))
        return getDarwinBooleanType();
    }
    if (clangTy || canBridgeBool)
      return getObjCBoolType();
    return t;
  }

  // Class metatypes bridge to ObjC metatypes.
  if (auto metaTy = t->getAs<MetatypeType>()) {
    if (metaTy->getInstanceType()->getClassOrBoundGenericClass()) {
      return MetatypeType::get(metaTy->getInstanceType(),
                               MetatypeRepresentation::ObjC);
    }
  }

  // ObjC-compatible existential metatypes.
  if (auto metaTy = t->getAs<ExistentialMetatypeType>()) {
    if (metaTy->getInstanceType()->isObjCExistentialType()) {
      return ExistentialMetatypeType::get(metaTy->getInstanceType(),
                                          MetatypeRepresentation::ObjC);
    }
  }
  
  // `Any` can bridge to `AnyObject` (`id` in ObjC).
  if (t->isAny())
    return Context.getAnyObjectType();
  
  if (auto funTy = t->getAs<FunctionType>()) {
    switch (funTy->getExtInfo().getSILRepresentation()) {
    // Functions that are already represented as blocks or C function pointers
    // don't need bridging.
    case SILFunctionType::Representation::Block:
    case SILFunctionType::Representation::CFunctionPointer:
    case SILFunctionType::Representation::Thin:
    case SILFunctionType::Representation::Method:
    case SILFunctionType::Representation::ObjCMethod:
    case SILFunctionType::Representation::WitnessMethod:
    case SILFunctionType::Representation::Closure:
      return t;
    case SILFunctionType::Representation::Thick: {
      // Thick functions (TODO: conditionally) get bridged to blocks.
      // This bridging is more powerful than usual block bridging, however,
      // so we use the ObjCMethod representation.
      auto newInput = getBridgedInputParams(
          SILFunctionType::Representation::ObjCMethod,
          pattern.getFunctionInputType(), funTy->getParams());
      Type newResult =
          getBridgedResultType(SILFunctionType::Representation::ObjCMethod,
                               pattern.getFunctionResultType(),
                               funTy->getResult()->getCanonicalType(),
                               /*non-optional*/false);

      return FunctionType::get(newInput.getOriginalArray(), newResult,
                               funTy->getExtInfo().withSILRepresentation(
                                   SILFunctionType::Representation::Block));
    }
    }
  }

  auto foreignRepresentation =
    t->getForeignRepresentableIn(ForeignLanguage::ObjectiveC, M.TheSwiftModule);
  switch (foreignRepresentation.first) {
  case ForeignRepresentableKind::None:
  case ForeignRepresentableKind::Trivial:
  case ForeignRepresentableKind::Object:
    return t;

  case ForeignRepresentableKind::Bridged:
  case ForeignRepresentableKind::StaticBridged: {
    auto conformance = foreignRepresentation.second;
    assert(conformance && "Missing conformance?");
    Type bridgedTy =
      ProtocolConformanceRef::getTypeWitnessByName(
        t, ProtocolConformanceRef(conformance),
        M.getASTContext().Id_ObjectiveCType,
        nullptr);
    assert(bridgedTy && "Missing _ObjectiveCType witness?");
    if (bridgedCollectionsAreOptional && clangTy)
      bridgedTy = OptionalType::get(bridgedTy);
    return bridgedTy;
  }

  case ForeignRepresentableKind::BridgedError: {
    auto nsErrorDecl = M.getASTContext().getNSErrorDecl();
    assert(nsErrorDecl && "Cannot bridge when NSError isn't available");
    return nsErrorDecl->getDeclaredInterfaceType();
  }
  }

  return t;
}
