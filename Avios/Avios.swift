//
//  Avios.swift
//  Avios
//
//  Created by Josh Baker on 7/5/15.
//  Copyright © 2015 ONcast, LLC. All rights reserved.
//

import Foundation

public class AviosImage {
    public var width: Int = 0
    public var height: Int = 0
    public var stride: Int = 0
    public var yStride: Int = 0
    public var uvStride: Int = 0
    public var rgba : UnsafeBufferPointer<UInt8>
    public var y : UnsafeBufferPointer<UInt8>
    public var u : UnsafeBufferPointer<UInt8>
    public var v : UnsafeBufferPointer<UInt8>
    internal init() {
        rgba = UnsafeBufferPointer<UInt8>(start: UnsafePointer<UInt8>(bitPattern: 0), count: 0)
        y = UnsafeBufferPointer<UInt8>(start: UnsafePointer<UInt8>(bitPattern: 0), count: 0)
        u = UnsafeBufferPointer<UInt8>(start: UnsafePointer<UInt8>(bitPattern: 0), count: 0)
        v = UnsafeBufferPointer<UInt8>(start: UnsafePointer<UInt8>(bitPattern: 0), count: 0)
    }
}

public enum AviosError : ErrorType {
    case NoImage
}