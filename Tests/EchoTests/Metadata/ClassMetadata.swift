import XCTest
import Echo

class Boat {
  let name: String
  let designDate: Int
  
  init(name: String, designDate: Int) {
    self.name = name
    self.designDate = designDate
  }
  public func printName() -> String {
    print(name)
    return name
  }
  
  public func printDesignDate() -> String {
    print(designDate)
    return "\(designDate)"
  }
}

class Boat2<T, U> {
  let name: T
  let designDate: U
  
  init(name: T, designDate: U) {
    self.name = name
    self.designDate = designDate
  }
}

class Boat3<T>: JSONEncoder {
  let name: T
  
  init(name: T) {
    self.name = name
  }
}

enum ClassMetadataTests {
  static func testClass() throws {
    let maybeMetadata = reflectClass(Boat.self)
    XCTAssertNotNil(maybeMetadata)
    
    let metadata = maybeMetadata!
    
    XCTAssertEqual(metadata.classAddressPoint, 16)
    XCTAssertEqual(metadata.classSize, 120)
    XCTAssertEqual(metadata.instanceAddressPoint, 0)
    XCTAssertEqual(metadata.instanceAlignmentMask, 7)
    XCTAssertEqual(metadata.instanceSize, 40)
    XCTAssertEqual(metadata.flags.bits, 2)
    XCTAssertEqual(metadata.fieldOffsets, [16, 32])
    XCTAssertEqual(metadata.isSwiftClass, true)
    #if canImport(ObjectiveC)
    XCTAssertNotNil(metadata.isaPointer)
    XCTAssertNotNil(metadata.superclassType)
    #else
    XCTAssertNil(metadata.isaPointer)
    XCTAssertNil(metadata.superclassType)
    #endif
    XCTAssert(typeArraysEquals(metadata.genericTypes, []))
    XCTAssertEqual(metadata.kind, .class)
    XCTAssert(metadata.type == Boat.self)
    
    // VWT
    
    var extraInhabitantCount = 2147483647
    #if os(Linux)
    extraInhabitantCount = 4096
    #endif
    
    XCTAssertEqual(metadata.vwt.extraInhabitantCount, extraInhabitantCount)
    XCTAssertEqual(metadata.vwt.size, 8)
    XCTAssertEqual(metadata.vwt.stride, 8)
    XCTAssertEqual(metadata.vwt.flags.bits, 65543)
  }
  
  static func testGenericClass() throws {
    let maybeMetadata = reflectClass(Boat2<String, Int>.self)
    XCTAssertNotNil(maybeMetadata)
    
    let metadata = maybeMetadata!
    
    XCTAssertEqual(metadata.classAddressPoint, 16)
    XCTAssertEqual(metadata.classSize, 136)
    XCTAssertEqual(metadata.instanceAddressPoint, 0)
    XCTAssertEqual(metadata.instanceAlignmentMask, 7)
    XCTAssertEqual(metadata.instanceSize, 40)
    XCTAssertEqual(metadata.flags.bits, 2)
    XCTAssertEqual(metadata.fieldOffsets, [16, 32])
    XCTAssertEqual(metadata.isSwiftClass, true)
    #if canImport(ObjectiveC)
    XCTAssertNotNil(metadata.isaPointer)
    XCTAssertNotNil(metadata.superclassType)
    #else
    XCTAssertNil(metadata.isaPointer)
    XCTAssertNil(metadata.superclassType)
    #endif
    XCTAssert(typeArraysEquals(metadata.genericTypes, [String.self, Int.self]))
    XCTAssertEqual(metadata.kind, .class)
    XCTAssert(metadata.type == Boat2<String, Int>.self)
    
    // VWT
    
    var extraInhabitantCount = 2147483647
    #if os(Linux)
    extraInhabitantCount = 4096
    #endif
    
    XCTAssertEqual(metadata.vwt.extraInhabitantCount, extraInhabitantCount)
    XCTAssertEqual(metadata.vwt.size, 8)
    XCTAssertEqual(metadata.vwt.stride, 8)
    XCTAssertEqual(metadata.vwt.flags.bits, 65543)
    
    // Resilient Superclass Generic Types
    
    let resilientMetadata = reflectClass(Boat3<String>.self)!
    XCTAssert(typeArraysEquals(resilientMetadata.genericTypes, [String.self]))
    XCTAssertNotNil(resilientMetadata.superclassType)
    XCTAssert(resilientMetadata.superclassType! == JSONEncoder.self)
  }
  
  #if canImport(ObjectiveC)
  static func testObjCClass() throws {
    let maybeMetadata = reflectClass(NSObject.self)
    XCTAssertNotNil(maybeMetadata)
    
    let metadata = maybeMetadata!
    
    XCTAssertEqual(metadata.classAddressPoint, 32767)
    XCTAssertEqual(metadata.instanceAddressPoint, 32767)
    XCTAssertEqual(metadata.instanceAlignmentMask, 32767)
    XCTAssertEqual(metadata.isSwiftClass, false)
  }
  #endif
  static func testVtable() {
    let boat = Boat(name: "hello", designDate: 5)
    let maybeMetadata = reflectClass(Boat.self)
    XCTAssertNotNil(maybeMetadata)
  
    var printName: UnsafeMutablePointer<ClassMetadata.SIMP?>?
    var printDesignDate:  UnsafeMutablePointer<ClassMetadata.SIMP?>?
  
    XCTAssertEqual(boat.printName(), "hello")
  
    let metadata = maybeMetadata!
    for entry in metadata.vtable {
      var info = Dl_info()
      if dladdr(unsafeBitCast(entry.pointee, to: UnsafeRawPointer.self), &info) != 0,
          let snameC = info.dli_sname {
          let sname = String(cString: snameC)
          if sname.contains("printName") { printName = entry }
          if sname.contains("printDesignDate") { printDesignDate = entry }
      }
    }
  
    if let printDesignDate {
      printName?.pointee = printDesignDate.pointee
    }
  
    XCTAssertEqual(boat.printName(), "5")
  }
}

extension EchoTests {
  func testClassMetadata() throws {
    try ClassMetadataTests.testClass()
    try ClassMetadataTests.testGenericClass()
    #if canImport(ObjectiveC)
    try ClassMetadataTests.testObjCClass()
    #endif
    ClassMetadataTests.testVtable()
  }
}
