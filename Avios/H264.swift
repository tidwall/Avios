//
//  H264.swift
//  Avios
//
//  Created by Josh Baker on 6/29/15.
//  Copyright © 2015 ONcast, LLC. All rights reserved.
//

import Foundation
import AVFoundation
import VideoToolbox


public enum H264Error : ErrorType, CustomStringConvertible {
    case InvalidDecoderData
    case InvalidDecoderImage
    case InvalidNALUType
    case VideoSessionNotReady
    case Memory
    case CMBlockBufferCreateWithMemoryBlock(OSStatus)
    case CMBlockBufferAppendBufferReference(OSStatus)
    case CMSampleBufferCreateReady(OSStatus)
    case VTDecompressionSessionDecodeFrame(OSStatus)
    case CMVideoFormatDescriptionCreateFromH264ParameterSets(OSStatus)
    case VTDecompressionSessionCreate(OSStatus)
    case InvalidCVImageBuffer
    case InvalidCVPixelBufferFormat
    public var description : String {
        switch self {
        case .InvalidDecoderData: return "H264Error.InvalidDecoderData"
        case .InvalidDecoderImage: return "H264Error.InvalidDecoderImage"
        case .InvalidNALUType: return "H264Error.InvalidNALUType"
        case .VideoSessionNotReady: return "H264Error.VideoSessionNotReady"
        case .Memory: return "H264Error.Memory"
        case let .CMBlockBufferCreateWithMemoryBlock(status): return "H264Error.CMBlockBufferCreateWithMemoryBlock(\(status))"
        case let .CMBlockBufferAppendBufferReference(status): return "H264Error.CMBlockBufferAppendBufferReference(\(status))"
        case let .CMSampleBufferCreateReady(status): return "H264Error.CMSampleBufferCreateReady(\(status))"
        case let .VTDecompressionSessionDecodeFrame(status): return "H264Error.VTDecompressionSessionDecodeFrame(\(status))"
        case let .CMVideoFormatDescriptionCreateFromH264ParameterSets(status): return "H264Error.CMVideoFormatDescriptionCreateFromH264ParameterSets(\(status))"
        case let .VTDecompressionSessionCreate(status): return "H264Error.VTDecompressionSessionCreate(\(status))"
        case .InvalidCVImageBuffer: return "H264Error.InvalidCVImageBuffer"
        case .InvalidCVPixelBufferFormat: return "H264Error.InvalidCVPixelBufferFormat"
        }
    }


}

public class H264Decoder {
    private var dirtySPS : NALU?
    private var dirtyPPS : NALU?
    private var sps : NALU?
    private var pps : NALU?
    private var videoSession : VTDecompressionSession!
    private var formatDescription : CMVideoFormatDescription!
    private var mutex = pthread_mutex_t()
    private var cond = pthread_cond_t()
    private var processing = false
    private var processingError : ErrorType?
    private var processingImage : AviosImage?
    private var buffer : UnsafeMutablePointer<UInt8> = nil
    private var bufsize : Int = 0
    public init() throws{
        pthread_mutex_init(&mutex, nil)
        pthread_cond_init(&cond, nil)
        bufsize = 1024 * 16
        buffer = UnsafeMutablePointer<UInt8>(malloc(bufsize))
    }
    deinit{
        invalidateVideo()
        pthread_cond_destroy(&cond)
        pthread_mutex_destroy(&mutex)
        free(buffer)
    }
    
    public func decode(data: UnsafePointer<UInt8>, length: Int) throws -> AviosImage {
        let nalu = NALU(data, length: length)
        if nalu.type == .Undefined {
            throw H264Error.InvalidNALUType
        }
        if nalu.type == .SPS || nalu.type == .PPS {
            if nalu.type == .SPS {
                dirtySPS = nalu.copy()
            } else if nalu.type == .PPS {
                dirtyPPS = nalu.copy()
            }
            if dirtySPS != nil && dirtyPPS != nil {
                if sps == nil || pps == nil || sps!.equals(dirtySPS!) || pps!.equals(dirtyPPS!) {
                    invalidateVideo()
                    sps = dirtySPS!.copy()
                    pps = dirtyPPS!.copy()
                    do {
                        try initVideoSession()
                    } catch {
                        sps = nil
                        pps = nil
                        throw error
                    }
                }
                dirtySPS = nil
                dirtyPPS = nil
            }
            throw AviosError.NoImage
        }
        if videoSession == nil {
            throw H264Error.VideoSessionNotReady
        }
        if nalu.type == .SEI {
            throw AviosError.NoImage
        }
        if nalu.type != .IDR && nalu.type != .CodedSlice {
            throw H264Error.InvalidNALUType
        }
        let sampleBuffer = try nalu.sampleBuffer(formatDescription)
        defer {
            CMSampleBufferInvalidate(sampleBuffer)
        }
        
        var infoFlags = VTDecodeInfoFlags(rawValue: 0)
        pthread_mutex_lock(&mutex)
        processing = true
        processingImage = nil
        processingError = nil
        pthread_mutex_unlock(&mutex)
        let status = VTDecompressionSessionDecodeFrame(videoSession, sampleBuffer, [._EnableAsynchronousDecompression], nil, &infoFlags)
        if status != noErr {
            throw H264Error.VTDecompressionSessionDecodeFrame(status)
        }
        
        pthread_mutex_lock(&mutex)
        while processing {
            pthread_cond_wait(&cond, &mutex)
        }
        let error = processingError
        let image = processingImage
        pthread_mutex_unlock(&mutex)
        if error != nil {
            throw error!
        }
        if let image = image {
            return image
        }
        throw AviosError.NoImage
    }
    
    private func decompressionOutputCallback(sourceFrameRefCon: UnsafeMutablePointer<Void>, status: OSStatus, infoFlags: VTDecodeInfoFlags, imageBuffer: CVImageBuffer?, presentationTimeStamp: CMTime, presentationDuration: CMTime){
        pthread_mutex_lock(&mutex)
        defer {
            processing = false
            pthread_cond_broadcast(&cond)
            pthread_mutex_unlock(&mutex)
        }
        if status != noErr {
            processingError = H264Error.VTDecompressionSessionDecodeFrame(status)
            return
        }
        if imageBuffer == nil {
            processingError = H264Error.InvalidCVImageBuffer
            return
        }
        let pixelBuffer = unsafeBitCast(unsafeAddressOf(imageBuffer!), CVPixelBuffer.self)
        CVPixelBufferLockBaseAddress(pixelBuffer, 0)
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, 0)
        }

        if CVPixelBufferGetPixelFormatType(pixelBuffer) != kCVPixelFormatType_32BGRA {
            processingError = H264Error.InvalidCVPixelBufferFormat
            return
        }
        
        let image = AviosImage()
        image.width = CVPixelBufferGetWidth(pixelBuffer)
        image.height = CVPixelBufferGetHeight(pixelBuffer)
        image.stride = CVPixelBufferGetBytesPerRow(pixelBuffer)
        if image.stride * image.height > bufsize {
            while image.stride * image.height > bufsize {
                bufsize *= 2
            }
            free(buffer)
            buffer = UnsafeMutablePointer<UInt8>(malloc(bufsize))
        }
        memcpy(buffer, CVPixelBufferGetBaseAddress(pixelBuffer), image.stride * image.height)
        image.rgba = UnsafeBufferPointer<UInt8>(start: buffer, count: image.stride * image.height)
        processingImage = image
    }
    
    private func invalidateVideo() {
        formatDescription = nil
        if videoSession != nil {
            VTDecompressionSessionInvalidate(videoSession)
            videoSession = nil
        }
        sps = nil
        pps = nil
    }
    private func initVideoSession() throws {
        formatDescription = nil
        var _formatDescription : CMFormatDescription?
        let parameterSetPointers : [UnsafePointer<UInt8>] = [ pps!.buffer.baseAddress, sps!.buffer.baseAddress ]
        let parameterSetSizes : [Int] = [ pps!.buffer.count, sps!.buffer.count ]
        var status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault, 2, parameterSetPointers, parameterSetSizes, 4, &_formatDescription);
        if status != noErr {
            throw H264Error.CMVideoFormatDescriptionCreateFromH264ParameterSets(status)
        }
        formatDescription = _formatDescription!

        if videoSession != nil {
            VTDecompressionSessionInvalidate(videoSession)
            videoSession = nil
        }
        var videoSessionM : VTDecompressionSession?

        let decoderParameters = NSMutableDictionary()
        let destinationPixelBufferAttributes = NSMutableDictionary()
        destinationPixelBufferAttributes.setValue(NSNumber(unsignedInt: kCVPixelFormatType_32BGRA), forKey: kCVPixelBufferPixelFormatTypeKey as String)

        var outputCallback = VTDecompressionOutputCallbackRecord()
        outputCallback.decompressionOutputCallback = callback
        outputCallback.decompressionOutputRefCon = UnsafeMutablePointer<Void>(unsafeAddressOf(self))
       
        status = VTDecompressionSessionCreate(nil, formatDescription, decoderParameters, destinationPixelBufferAttributes, &outputCallback, &videoSessionM)
        if status != noErr {
            throw H264Error.VTDecompressionSessionCreate(status)
        }
        self.videoSession = videoSessionM;
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

private func callback(decompressionOutputRefCon: UnsafeMutablePointer<Void>, sourceFrameRefCon: UnsafeMutablePointer<Void>, status: OSStatus, infoFlags: VTDecodeInfoFlags, imageBuffer: CVImageBuffer?, presentationTimeStamp: CMTime, presentationDuration: CMTime){
    unsafeBitCast(decompressionOutputRefCon, H264Decoder.self).decompressionOutputCallback(sourceFrameRefCon, status: status, infoFlags: infoFlags, imageBuffer: imageBuffer, presentationTimeStamp: presentationTimeStamp, presentationDuration: presentationDuration)
}

