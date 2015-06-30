//
//  Theora.swift
//  Avios
//
//  Created by Josh Baker on 6/27/15.
//  Copyright © 2015 ONcast, LLC. All rights reserved.
//

import Foundation

public class TheoraImage {
    public var width: Int = 0
    public var height: Int = 0
    public var yStride: Int = 0
    public var uvStride: Int = 0
    public var y : UnsafeBufferPointer<UInt8>
    public var u : UnsafeBufferPointer<UInt8>
    public var v : UnsafeBufferPointer<UInt8>
    private init() {
        y = UnsafeBufferPointer<UInt8>(start: UnsafePointer<UInt8>(bitPattern: 0), count: 0)
        u = UnsafeBufferPointer<UInt8>(start: UnsafePointer<UInt8>(bitPattern: 0), count: 0)
        v = UnsafeBufferPointer<UInt8>(start: UnsafePointer<UInt8>(bitPattern: 0), count: 0)
    }
}

public enum TheoraError : ErrorType {
    case InvalidHeaders
    case InvalidDecoderData
    case InvalidDecoderImage
}

public class TheoraDecoder {
    let theora : COpaquePointer
    let queue = dispatch_queue_create(nil, nil)
    private init(_ headers : UnsafePointer<UInt8>, length: Int) throws {
        theora = theora_decoder_new(headers, length)
        if theora == nil {
            throw TheoraError.InvalidHeaders
        }
    }
    public convenience init(_ headers : [UInt8]) throws {
        try self.init(headers, length: headers.count)
    }
    public convenience init(_ headers : UnsafeBufferPointer<UInt8>) throws {
        try self.init(headers.baseAddress, length: headers.count)
    }
    public convenience init(_ headers : NSData) throws {
        try self.init(UnsafePointer<UInt8>(headers.bytes), length: headers.length)
    }
    deinit{
        theora_decoder_delete(theora)
    }
    private func decode(data: UnsafePointer<UInt8>, length: Int) throws -> [TheoraImage] {
        var error : ErrorType?
        var image : TheoraImage!
        var done = false
        var mutex = pthread_mutex_t()
        var cond = pthread_cond_t()
        pthread_mutex_init(&mutex, nil)
        pthread_cond_init(&cond, nil)
        dispatch_async(queue) {
            defer {
                pthread_mutex_lock(&mutex)
                done = true
                pthread_cond_broadcast(&cond)
                pthread_mutex_unlock(&mutex)
            }
            if !theora_decoder_decode(self.theora, data, length){
                error = TheoraError.InvalidDecoderData
                return
            }
            let dimg = theora_decoder_get_image(self.theora)
            if dimg == nil {
                error = TheoraError.InvalidDecoderImage
                return
            }
            image = TheoraImage()
            image.width = Int(dimg.memory.y_width)
            image.height = Int(dimg.memory.y_height)
            image.yStride = Int(dimg.memory.y_stride)
            image.uvStride = Int(dimg.memory.uv_stride)
            image.y = UnsafeBufferPointer<UInt8>(start: dimg.memory.y, count: image.yStride*image.height)
            image.u = UnsafeBufferPointer<UInt8>(start: dimg.memory.u, count: image.uvStride*(image.height/2))
            image.v = UnsafeBufferPointer<UInt8>(start: dimg.memory.v, count: image.uvStride*(image.height/2))
        }

        pthread_mutex_lock(&mutex)
        while !done {
            pthread_cond_wait(&cond, &mutex)
        }
        pthread_mutex_unlock(&mutex)
        pthread_mutex_destroy(&mutex)
        pthread_cond_destroy(&cond)
        if error != nil{
            throw error!
        }
        return [image]
        
        
    }
    public func decode(data: [UInt8]) throws -> [TheoraImage] {
        return try decode(data, length: data.count)
    }
    public func decode(data: UnsafeBufferPointer<UInt8>) throws -> [TheoraImage] {
        return try decode(data.baseAddress, length: data.count)
    }
    public func decode(data: NSData) throws -> [TheoraImage] {
        return try decode(UnsafePointer<UInt8>(data.bytes), length: data.length)
    }
    
}