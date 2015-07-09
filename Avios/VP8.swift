//
//  VP8.swift
//  Avios
//
//  Created by Josh Baker on 6/27/15.
//  Copyright © 2015 ONcast, LLC. All rights reserved.
//

import Foundation

public enum VP8Error : ErrorType {
    case InvalidHeaders
    case InvalidDecoderData
    case InvalidDecoderImage
}

public class VP8Decoder {
    let vp8 : COpaquePointer
    let queue = dispatch_queue_create(nil, nil)
    public init() throws {
        vp8 = vp8_decoder_new()
        if vp8 == nil {
            throw VP8Error.InvalidHeaders
        }
    }
    deinit{
        vp8_decoder_delete(vp8)
    }
    private func decode(data: UnsafePointer<UInt8>, length: Int) throws -> AviosImage {
        var error : ErrorType?
        var image : AviosImage!
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
            if !vp8_decoder_decode(self.vp8, data, length){
                error = VP8Error.InvalidDecoderData
                return
            }
            let dimg = vp8_decoder_get_image(self.vp8)
            if dimg == nil {
                error = VP8Error.InvalidDecoderImage
                return
            }
            image = AviosImage()
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
        return image
        
        
    }
    public func decode(data: [UInt8]) throws -> AviosImage {
        return try decode(data, length: data.count)
    }
    public func decode(data: UnsafeBufferPointer<UInt8>) throws -> AviosImage {
        return try decode(data.baseAddress, length: data.count)
    }
    public func decode(data: NSData) throws -> AviosImage {
        return try decode(UnsafePointer<UInt8>(data.bytes), length: data.length)
    }
    
}