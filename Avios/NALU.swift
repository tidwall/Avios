//
//  NALU.swift
//  Avios
//
//  Created by Josh Baker on 6/29/15.
//  Copyright © 2015 ONcast, LLC. All rights reserved.
//

import CoreMedia

public enum NALUType : UInt8, CustomStringConvertible {
    case Undefined = 0
    case CodedSlice = 1
    case DataPartitionA = 2
    case DataPartitionB = 3
    case DataPartitionC = 4
    case IDR = 5 // (Instantaneous Decoding Refresh) Picture
    case SEI = 6 // (Supplemental Enhancement Information)
    case SPS = 7 // (Sequence Parameter Set)
    case PPS = 8 // (Picture Parameter Set)
    case AccessUnitDelimiter = 9
    case EndOfSequence = 10
    case EndOfStream = 11
    case FilterData = 12
    // 13-23 [extended]
    // 24-31 [unspecified]
    
    public var description : String {
        switch self {
        case .CodedSlice: return "CodedSlice"
        case .DataPartitionA: return "DataPartitionA"
        case .DataPartitionB: return "DataPartitionB"
        case .DataPartitionC: return "DataPartitionC"
        case .IDR: return "IDR"
        case .SEI: return "SEI"
        case .SPS: return "SPS"
        case .PPS: return "PPS"
        case .AccessUnitDelimiter: return "AccessUnitDelimiter"
        case .EndOfSequence: return "EndOfSequence"
        case .EndOfStream: return "EndOfStream"
        case .FilterData: return "FilterData"
        default: return "Undefined"
        }
    }
}

public class NALU {
    private var bbuffer : CMBlockBuffer!
    private var bbdata : UnsafeMutablePointer<UInt8> = nil
    private var bblen  = [UInt8](count: 8, repeatedValue: 0)

    private var copied = false
    public let buffer : UnsafeBufferPointer<UInt8>
    public let type : NALUType
    public let priority : Int
    public init(_ buffer: UnsafeBufferPointer<UInt8>) {
        var type : NALUType?
        var priority : Int?
        self.buffer = buffer
        if buffer.count > 0 {
            let hb = buffer[0]
            if (((hb >> 7) & 0x01) == 0){ // zerobit
                type = NALUType(rawValue: (hb >> 0) & 0x1F) // type
                priority = Int((hb >> 5) & 0x03) // priority
            }
        }
        self.type = type == nil ? .Undefined : type!
        self.priority = priority == nil ? 0 : priority!
    }
    deinit {
        if copied {
            free(UnsafeMutablePointer<UInt8>(buffer.baseAddress))
        }
        if bbdata != nil {
            free(bbdata)
        }
    }
    public convenience init(){
        self.init(UnsafeBufferPointer<UInt8>(start: UnsafePointer<UInt8>(bitPattern: 0), count: 0))
    }
    public convenience init(_ bytes: UnsafePointer<UInt8>, length: Int) {
        self.init(UnsafeBufferPointer<UInt8>(start: bytes, count: length))
    }
    public var naluTypeName : String {
        return type.description
    }
    public func copy() -> NALU {
        let baseAddress = UnsafeMutablePointer<UInt8>(malloc(buffer.count))
        memcpy(baseAddress, buffer.baseAddress, buffer.count)
        let nalu = NALU(baseAddress, length: buffer.count)
        nalu.copied = true
        return nalu
    }
    public func equals(nalu: NALU) -> Bool {
        if nalu.buffer.count != buffer.count {
            return false
        }
        return memcmp(nalu.buffer.baseAddress, buffer.baseAddress, buffer.count) == 0
    }
    public var nsdata : NSData {
        return NSData(bytesNoCopy: UnsafeMutablePointer<Void>(buffer.baseAddress), length: buffer.count, freeWhenDone: false)
    }
    
    // returns a non-contiguous CMBlockBuffer.
    public func blockBuffer() throws -> CMBlockBuffer {
        if bbuffer != nil {
            return bbuffer
        }

        var biglen = CFSwapInt32HostToBig(UInt32(buffer.count))
        memcpy(&bblen, &biglen, 4)
        var _buffer : CMBlockBuffer?
        var status = CMBlockBufferCreateWithMemoryBlock(nil, &bblen, 4, kCFAllocatorNull, nil, 0, 4, 0, &_buffer)
        if status != noErr {
            throw H264Error.CMBlockBufferCreateWithMemoryBlock(status)
        }
        var bufferData : CMBlockBuffer?
        status = CMBlockBufferCreateWithMemoryBlock(nil, UnsafeMutablePointer<UInt8>(buffer.baseAddress), buffer.count, kCFAllocatorNull, nil, 0, buffer.count, 0, &bufferData)
        if status != noErr {
            throw H264Error.CMBlockBufferCreateWithMemoryBlock(status)
        }

        status = CMBlockBufferAppendBufferReference(_buffer!, bufferData!, 0, buffer.count, 0)
        if status != noErr {
            throw H264Error.CMBlockBufferAppendBufferReference(status)
        }
        bbuffer = _buffer
        
        return bbuffer
    }
    
    public func sampleBuffer(fd : CMVideoFormatDescription) throws -> CMSampleBuffer {
        var sampleBuffer : CMSampleBuffer?
        var timingInfo = CMSampleTimingInfo()
        timingInfo.decodeTimeStamp = kCMTimeInvalid
        timingInfo.presentationTimeStamp = kCMTimeZero // pts
        timingInfo.duration = kCMTimeInvalid
        let status = CMSampleBufferCreateReady(kCFAllocatorDefault, try blockBuffer(), fd, 1, 1, &timingInfo, 0, nil, &sampleBuffer)
        if status != noErr {
            throw H264Error.CMSampleBufferCreateReady(status)
        }
        return sampleBuffer!
    }
}
