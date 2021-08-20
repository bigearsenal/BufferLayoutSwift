//
//  BufferLayout.swift
//  BufferLayoutSwift
//
//  Created by Chung Tran on 05/08/2021.
//

import Foundation
import Runtime

// MARK: - BufferLayout
public protocol BufferLayout: BufferLayoutProperty {
    static func injectOtherProperties(typeInfo: TypeInfo, currentInstance: inout Self) throws
    static var excludedPropertyNames: [String] {get}
}

public extension BufferLayout {
    init(buffer data: Data) throws {
        let info = try typeInfo(of: Self.self)
        var selfInstance: Self = try createInstance()
        
        var pointer: Int = 0
        for property in info.properties {
            if Self.excludedPropertyNames.contains(property.name) {continue}
            
            let instanceInfo = try typeInfo(of: property.type)
            
            if let t = instanceInfo.type as? BufferLayoutProperty.Type
            {
                let numberOfBytes = try t.getNumberOfBytes()
                guard pointer+numberOfBytes <= data.bytes.count else {
                    throw Error.bytesLengthIsNotValid
                }
                let newValue = try t.init(
                    buffer: Data(data[pointer..<pointer+numberOfBytes])
                )
                
                let newProperty = try info.property(named: property.name)
                try newProperty.set(value: newValue, on: &selfInstance)
                
                pointer += numberOfBytes
            } else if let t = instanceInfo.type as? BufferLayoutVectorType.Type
            {
                // get length
                let lengthSpan = t.numberOfBytesToStoreLength
                
                guard lengthSpan > 0 else {
                    throw Error.bytesLengthIsNotValid
                }
                
                let lengthBytes = data
                    .bytes[pointer..<pointer+lengthSpan]
                    .toArray()
                let length = lengthBytes.toInt()
                
                guard pointer + lengthSpan + length <= data.bytes.count else {
                    throw Error.bytesLengthIsNotValid
                }
                
                let newValue = try t.fromBytes(
                    bytes: data
                        .bytes[pointer+lengthSpan..<pointer+lengthSpan+length]
                        .toArray(),
                    length: length
                )
                
                let newProperty = try info.property(named: property.name)
                try newProperty.set(value: newValue, on: &selfInstance)
                
                pointer += lengthSpan + length
            }
        }
        try Self.injectOtherProperties(typeInfo: info, currentInstance: &selfInstance)
        self = selfInstance
    }
    
    func encode() throws -> Data {
        let info = try typeInfo(of: Self.self)
        var data = Data()
        for property in info.properties {
            if Self.excludedPropertyNames.contains(property.name) {continue}
            let instance = try property.get(from: self)
            if let instance = instance as? BufferLayoutProperty
            {
                data.append(try instance.encode())
            } else if let instance = instance as? BufferLayoutVectorType
            {
                data.append(try instance.encode())
            }
        }
        return data
    }
    
    static func injectOtherProperties(typeInfo: TypeInfo, currentInstance: inout Self) throws {}
    static var excludedPropertyNames: [String] {[]}
    
    @available(*, deprecated, message: "Not work with vectors", renamed: "getNumberOfBytes")
    static func getBufferLength() throws -> Int {
        try getNumberOfBytes()
    }
    
    static func getNumberOfBytes() throws -> Int {
        let info = try typeInfo(of: Self.self)
        var numberOfBytes = 0
        for property in info.properties {
            guard let instanceInfo = try? typeInfo(of: property.type) else {return 0}
            if let t = instanceInfo.type as? BufferLayoutProperty.Type,
               !Self.excludedPropertyNames.contains(property.name)
            {
                numberOfBytes += (try t.getNumberOfBytes())
            } else if instanceInfo.type is BufferLayoutVectorType.Type
            {
                throw Error.layoutContainsAVectorWhoseLengthCanNotBePredefined
            }
        }
        return numberOfBytes
    }
}

// MARK: - Helpers
private extension Data {
    var bytes: Array<UInt8> {
        Array(self)
    }
}

private extension ArraySlice {
    func toArray() -> [Element] {
        Array(self)
    }
}
