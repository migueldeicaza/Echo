//
//  TypeMetadata.swift
//  Echo
//
//  Created by Alejandro Alonso
//  Copyright © 2019 - 2021 Alejandro Alonso. All rights reserved.
//

#if os(Linux)
import CEcho
#endif
import Foundation

/// Type metadata refers to those metadata records who declare a new type in
/// Swift. Said metadata records only refer to structs, classes, and enums.
///
/// ABI Stability: Stable since the following
///
///     | macOS | iOS/tvOS | watchOS | Linux | Windows |
///     |-------|----------|---------|-------|---------|
///     | 10.14 | 12.2     | 5.2     | NA    | NA      |
///
public protocol TypeMetadata: Metadata {}

extension TypeMetadata {
  /// The list of conformances defined for this type metadata.
  ///
  /// NOTE: This list is populated once before the program starts with all of
  ///       the conformances that are statically know at compile time. If you
  ///       are attempting to load libraries dynamically at runtime, this list
  ///       will update automatically, so make sure if you need up to date
  ///       information on a type's conformances, fetch this often. Example:
  ///
  ///       let metadata = ...
  ///       var conformances = metadata.conformances
  ///       loadPlugin(...)
  ///       // conformances is now outdated! Refresh it by calling this again.
  ///       conformances = metadata.conformances
  public var conformances: [ConformanceDescriptor] {
    #if os(Linux)
    iterateSharedObjects()
    #endif
    
    guard let contextDescriptorPtr = contextDescriptor?.ptr else {
        return []
    }
    
    return conformanceLock.withLock {
      Echo.conformances[contextDescriptorPtr, default: []]
    }
  }
  
  /// The base type context descriptor for this type metadata record.
  public var contextDescriptor: TypeContextDescriptor? {
    switch self {
    case let structMetadata as StructMetadata:
      return structMetadata.descriptor
    case let enumMetadata as EnumMetadata:
      return enumMetadata.descriptor
    case let classMetadata as ClassMetadata:
      return classMetadata.descriptor
    default:
      fatalError("Unknown TypeMetadata conformance")
    }
  }
  
  /// An array of field offsets for this type's stored representation.
  public var fieldOffsets: [Int] {
    switch self {
    case let structMetadata as StructMetadata:
      return structMetadata.fieldOffsets
    case let classMetadata as ClassMetadata:
      return classMetadata.fieldOffsets
    case is EnumMetadata:
      return []
    default:
      fatalError("Unknown TypeMetadata conformance")
    }
  }
  
  var genericArgumentPtr: UnsafeRawPointer? {
    switch self {
    case is StructMetadata:
      return ptr + MemoryLayout<_StructMetadata>.size
      
    case is EnumMetadata:
      return ptr + MemoryLayout<_EnumMetadata>.size
      
    case let classMetadata as ClassMetadata:
      guard let descriptor = classMetadata.descriptor else {
        return nil
      }
      return ptr.offset(of: descriptor.genericArgumentOffset)
      
    default:
      fatalError("Unknown TypeMetadata conformance")
    }
  }
  
  /// An array of types that represent the generic arguments that make up this
  /// type.
  public var genericTypes: [Any.Type] {
    guard let contextDescriptor = contextDescriptor,
          contextDescriptor.flags.isGeneric,
          // Explicitly only call this once because class metadata could require
          // computation, so only do it once if needed.
          let gap = genericArgumentPtr else {
      return []
    }
    
    let numParams = contextDescriptor.genericContext!.numParams
    
    return Array(unsafeUninitializedCapacity: numParams) {
      for i in 0 ..< numParams {
        let type = gap.load(
          fromByteOffset: i * MemoryLayout<Any.Type>.stride,
          as: Any.Type.self
        )
        
        $0[i] = type
      }
      
      $1 = numParams
    }
  }
  
  /// An array of metadata records for the types that represent the generic
  /// arguments that make up this type.
  public var genericMetadata: [Metadata] {
    genericTypes.map { reflect($0) }
  }
  
  /// Given a mangled type name to some field, superclass, etc., return the
  /// type. Using this is the preferred way to interact with mangled type names
  /// because this uses the metadata's generic context and arguments and such to
  /// fill in generic types along with caching the mangled name for future use.
  /// - Parameter mangledName: The mangled type name pointer to some type in
  ///                          this metadata's reach.
  /// - Returns: The type that the mangled type name refers to, if we're able
  ///            to demangle it.
  public func type(
    of mangledName: UnsafeRawPointer
  ) -> Any.Type? {
    let entry = mangledNameLock.withLock {
      mangledNames[mangledName]
    }
    
    if entry != nil {
      return entry!
    }
    
    guard let contextDescriptor = contextDescriptor else {
      return nil
    }
    
    let length = getSymbolicMangledNameLength(mangledName)
    let name = mangledName.assumingMemoryBound(to: UInt8.self)
    let type = _getTypeByMangledNameInContext(
      name,
      UInt(length),
      genericContext: contextDescriptor.ptr,
      genericArguments: genericArgumentPtr
    )
    
    mangledNameLock.withLock {
      mangledNames[mangledName] = type
    }
    
    return type
  }
}

let mangledNameLock = NSLock()
var mangledNames = [UnsafeRawPointer: Any.Type?]()
