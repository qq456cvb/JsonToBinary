//
//  main.swift
//  JsonToBinary
//
//  Created by Neil on 14/11/2016.
//  Copyright © 2016 Neil. All rights reserved.
//

import Foundation
import CoreFoundation

func loadJson(dic: Any) -> Void {
    if dic is NSDictionary {
        print("{")
        for (key, value) in (dic as! NSDictionary) {
            print("\"\(key as! String)\":")
            loadJson(dic: value)
            print(",")
        }
        print("}")
    } else if dic is NSArray {
        print("[")
        var sum:Float = 0.0
        for value in (dic as! NSArray) {
            if let f = value as? Float {
                sum += f
            }
            loadJson(dic: value)
        }
        print(sum)
        print("]")
    } else {
//        print("0")
    }
}

func readArr(stream: inout InputStream) -> Any {
    let intBuf = UnsafeMutablePointer<UInt8>.allocate(capacity: 4)
    let byteBuf = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)

    stream.read(byteBuf, maxLength: 1)
    stream.read(intBuf, maxLength: 4)
    let byte = byteBuf[0]
    let cnt = Int(intBuf.deinitialize().assumingMemoryBound(to: UInt32.self)[0])
    if byte == 0 { // value
        let arrBuf = UnsafeMutablePointer<UInt8>.allocate(capacity: cnt * 4)
        stream.read(arrBuf, maxLength: cnt * 4)
        let floatArrBuf = arrBuf.deinitialize().assumingMemoryBound(to: Float.self)
        var arr = Array(repeating: 0.0, count: cnt) as! [Float]
        for i in 0...(cnt-1) {
            if cnt == 128 && abs(floatArrBuf[i] - 0) < 1e-10 {
//                arr[i] = -0.25;
                print("FOUND!")
            } else {
                arr[i] = floatArrBuf[i]
            }
        }
        arrBuf.deinitialize().deallocate(bytes: cnt * 4, alignedTo: 1)
        intBuf.deallocate(capacity: 4)
        byteBuf.deallocate(capacity: 1)
        return arr
    } else if byte == 1 { // dictionary
        var arr = [Any].init()
        for _ in 0...(cnt-1) {
            arr.append(readDic(stream: &stream))
        }
        intBuf.deallocate(capacity: 4)
        byteBuf.deallocate(capacity: 1)
        return arr
    } else if byte == 3 { // string
        var arr = [String].init()
        for _ in 0...(cnt-1) {
            stream.read(intBuf, maxLength: 4)
            let strLen = Int(intBuf.deinitialize().assumingMemoryBound(to: UInt32.self)[0])
            
            // read string
            let strBuf = UnsafeMutablePointer<UInt8>.allocate(capacity: strLen)
            stream.read(strBuf, maxLength: strLen)
            let data = Data(bytes: strBuf, count: strLen)
            let valStr = String(data: data, encoding: String.Encoding.ascii)
            arr.append(valStr!)
            strBuf.deallocate(capacity: strLen)
            
        }
        intBuf.deallocate(capacity: 4)
        byteBuf.deallocate(capacity: 1)
        return arr
    } else { // never get here
        assert(false)
    }
    assert(false)
    return [Any].init()
}

func readDic(stream: inout InputStream) -> Dictionary<String, Any> {
    var dic = Dictionary<String, Any>.init()
    let intBuf = UnsafeMutablePointer<UInt8>.allocate(capacity: 4)
    let byteBuf = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
    
    stream.read(intBuf, maxLength: 4)
    let num = intBuf.deinitialize().assumingMemoryBound(to: UInt32.self)[0]
    for _ in 0...(num-1) {
        stream.read(intBuf, maxLength: 4)
        let strLen = Int(intBuf.deinitialize().assumingMemoryBound(to: UInt32.self)[0])
        let strBuf = UnsafeMutablePointer<UInt8>.allocate(capacity: strLen)
        stream.read(strBuf, maxLength: strLen)
        
        var data = Data(bytes: strBuf, count: strLen)
        let str = String(data: data, encoding: String.Encoding.ascii)
        
        stream.read(byteBuf, maxLength: 1)
        let byte = byteBuf[0]
        if byte == 0 { // value
            stream.read(intBuf, maxLength: 4)
            let f = intBuf.deinitialize().assumingMemoryBound(to: Float.self)[0]
            dic[str!] = f
        } else if byte == 1 { // dictionary
            dic[str!] = readDic(stream: &stream)
        } else if byte == 2 { // array
            dic[str!] = readArr(stream: &stream)
        } else if byte == 3 { // string
            // read string length
            stream.read(intBuf, maxLength: 4)
            let innerStrLen = Int(intBuf.deinitialize().assumingMemoryBound(to: UInt32.self)[0])
            
            // read string
            let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: innerStrLen)
            stream.read(buf, maxLength: innerStrLen)
            data = Data(bytes: buf, count: innerStrLen)
            let valStr = String(data: data, encoding: String.Encoding.ascii)
            
            dic[str!] = valStr
            buf.deallocate(capacity: innerStrLen)
        } else {
            assert(false) // cannot get in
        }
        strBuf.deallocate(capacity: strLen)
    }
    intBuf.deallocate(capacity: 4)
    byteBuf.deallocate(capacity: 1)
    return dic
}



func readBson(file: String) -> Dictionary<String, Any> {
    var stream = InputStream(fileAtPath: file)
    stream?.open()
    let dic = readDic(stream: &stream!)
    stream?.close()
    return dic
}

func writeDic(dic: Dictionary<String, Any>, stream: inout OutputStream) {
    // write entry num
    var buffer: UnsafeMutablePointer<UInt8> = UnsafeMutablePointer(mutating: [dic.count]).deinitialize().assumingMemoryBound(to: UInt8.self)
    stream.write(buffer, maxLength: 4)
    
    for (key, value) in dic {
        var str = key
        
        // write key length
        var strLen = str.lengthOfBytes(using: String.Encoding.ascii)
        buffer = UnsafeMutablePointer(mutating: [strLen]).deinitialize().assumingMemoryBound(to: UInt8.self)
        stream.write(buffer, maxLength: 4)
        
        // write key
        buffer = UnsafeMutablePointer(mutating: str.cString(using: String.Encoding.ascii)! as [Int8]).deinitialize().assumingMemoryBound(to: UInt8.self)
        stream.write(buffer, maxLength: strLen)
        
        // write value
        if value is Dictionary<String, Any> {
            buffer = UnsafeMutablePointer(mutating: [UInt8(1)]).deinitialize().assumingMemoryBound(to: UInt8.self)
            stream.write(buffer, maxLength: 1)
            writeDic(dic: value as! Dictionary<String, Any>, stream: &stream)
        } else if (value is Array<Any>) {
            buffer = UnsafeMutablePointer(mutating: [UInt8(2)]).deinitialize().assumingMemoryBound(to: UInt8.self)
            stream.write(buffer, maxLength: 1)
            writeArr(arr: value as! Array<Any>, stream: &stream)
        } else {
            if value is String { // value is string
                // indicate it is string by 3
                buffer = UnsafeMutablePointer(mutating: [UInt8(3)]).deinitialize().assumingMemoryBound(to: UInt8.self)
                stream.write(buffer, maxLength: 1)
                // write length
                str = value as! String
                strLen = str.lengthOfBytes(using: String.Encoding.ascii)
                buffer = UnsafeMutablePointer(mutating: [strLen]).deinitialize().assumingMemoryBound(to: UInt8.self)
                stream.write(buffer, maxLength: 4)
                
                // write string
                buffer = UnsafeMutablePointer(mutating: str.cString(using: String.Encoding.ascii)! as [Int8]).deinitialize().assumingMemoryBound(to: UInt8.self)
                stream.write(buffer, maxLength: strLen)
            } else {
                // indicate it is float by 0
                buffer = UnsafeMutablePointer(mutating: [UInt8(0)]).deinitialize().assumingMemoryBound(to: UInt8.self)
                stream.write(buffer, maxLength: 1)
                
                // write the single float
                buffer = UnsafeMutablePointer(mutating: [value as! Float]).deinitialize().assumingMemoryBound(to: UInt8.self)
                stream.write(buffer, maxLength: 4)
            }
        }
    }
}

func writeArr(arr: [Any], stream: inout OutputStream) {
    let cnt = arr.count
    if arr[0] is Dictionary<String, Any> { // dictionary
        // indicate array of dictionary by 1
        var buffer: UnsafeMutablePointer<UInt8> = UnsafeMutablePointer(mutating: [UInt8(1)]).deinitialize().assumingMemoryBound(to: UInt8.self)
        stream.write(buffer, maxLength: 1)
//        buffer.deallocate(capacity: 1)
        
        // write length of array
        buffer = UnsafeMutablePointer(mutating: [cnt]).deinitialize().assumingMemoryBound(to: UInt8.self)
        stream.write(buffer, maxLength: 4)
//        buffer.deallocate(capacity: 4)
        
        for i in 0...(cnt-1) {
            writeDic(dic: arr[i] as! Dictionary, stream: &stream)
        }
    } else if arr[0] is Array<Any> {
        assert(false)
    } else if arr[0] is String { // array of String
        // indicate array of string by 3
        var buffer: UnsafeMutablePointer<UInt8> = UnsafeMutablePointer(mutating: [UInt8(3)]).deinitialize().assumingMemoryBound(to: UInt8.self)
        stream.write(buffer, maxLength: 1)
//        buffer.deallocate(capacity: 1)
        
        // write length of array
        buffer = UnsafeMutablePointer(mutating: [cnt]).deinitialize().assumingMemoryBound(to: UInt8.self)
        stream.write(buffer, maxLength: 4)
//        buffer.deallocate(capacity: 4)

        for str in (arr as! [String]) { // write every string
            // write string length
            let strLen = str.lengthOfBytes(using: String.Encoding.ascii)
            buffer = UnsafeMutablePointer(mutating: [strLen]).deinitialize().assumingMemoryBound(to: UInt8.self)
            stream.write(buffer, maxLength: 4)
//            buffer.deallocate(capacity: 4)
            
            // write string
            buffer = UnsafeMutablePointer(mutating: str.cString(using: String.Encoding.ascii)! as [Int8]).deinitialize().assumingMemoryBound(to: UInt8.self)
            stream.write(buffer, maxLength: strLen)
//            buffer.deallocate(capacity: strLen)
        }
    } else { // array of Float
        // indicate array of float by 0
        var buffer: UnsafeMutablePointer<UInt8> = UnsafeMutablePointer(mutating: [UInt8(0)]).deinitialize().assumingMemoryBound(to: UInt8.self)
        stream.write(buffer, maxLength: 1)
//        buffer.deallocate(capacity: 1)
        
        // write length of array
        buffer = UnsafeMutablePointer(mutating: [cnt]).deinitialize().assumingMemoryBound(to: UInt8.self)
        stream.write(buffer, maxLength: 4)
//        buffer.deallocate(capacity: 4)
        
        if cnt == 128 && arr[127] as? Float != nil {
            if abs(arr[127] as! Float - 1.12568796) < 0.01 {
                print("FOUND \(arr[127]) in write!")
//                arr[127] = 1.125688
                // write array
                let float_arr = arr as! [Float]
                
                let buf = UnsafeMutablePointer(mutating: float_arr).deinitialize().assumingMemoryBound(to: UInt8.self)
                print(buf[cnt*4-4])
                print(buf[cnt*4-3])
                print(buf[cnt*4-2])
                print(buf[cnt*4-1])
//                buffer = UnsafeMutablePointer(mutating: arr as! [Float]).deinitialize().assumingMemoryBound(to: UInt8.self)
                stream.write(buf, maxLength: cnt * 4)
//
//                buffer = UnsafeMutablePointer(mutating: [1.125688]).deinitialize().assumingMemoryBound(to: UInt8.self)
//                stream.write(buffer, maxLength: 4)
            } else {
                // write array
                buffer = UnsafeMutablePointer(mutating: arr as! [Float]).deinitialize().assumingMemoryBound(to: UInt8.self)
                stream.write(buffer, maxLength: cnt * 4)
            }
        } else {
            // write array
            buffer = UnsafeMutablePointer(mutating: arr as! [Float]).deinitialize().assumingMemoryBound(to: UInt8.self)
            stream.write(buffer, maxLength: cnt * 4)
        }
        
//        buffer.deallocate(capacity: cnt * 4)
    }
}

func writeBson(file: String, dic: Dictionary<String, Any>) -> Void {
    var stream = OutputStream(toFileAtPath: file, append: false)
    stream?.open()
    writeDic(dic: dic, stream: &stream!)
    stream?.close()
}


let path = "/Users/qq456cvb/Documents/Xcode projects/JsonToBinary/yolo_tiny.json"
let jsonData = try? Data(contentsOf: URL(fileURLWithPath: path))
let dic = try (JSONSerialization.jsonObject(with: jsonData!, options: .allowFragments) as! NSDictionary).mutableCopy() as! NSMutableDictionary



//let binaryDic = readBson(file: "/Users/qq456cvb/Documents/Xcode projects/JsonToBinary/yolo_tiny.bson")
//let cnt = 64000000
//let arr = Array(repeating: 0.0, count: cnt) as! [Float]

//let arrBuf = UnsafeMutablePointer<UInt8>.allocate(capacity: cnt * 4)
////stream.read(arrBuf, maxLength: cnt * 4)
//let arr = Array(UnsafeBufferPointer(start: arrBuf.deinitialize().assumingMemoryBound(to: Float.self), count: cnt))
////arrBuf.deinitialize().deallocate(bytes: cnt * 4, alignedTo: 1)
//arrBuf.deallocate(capacity: cnt)
//let i = 0

//loadJson(dic: dic!)

//loadJson(dic: binaryDic as NSDictionary)

//let a = 8

//for (key, value) in (dic!["layer"] as! NSDictionary?)! {
//    print("Property: \"\(key as! String)\"")
//}

//let os = OutputStream(toFileAtPath: "/Users/qq456cvb/Documents/Xcode projects/JsonToBinary/test.txt", append: false)!
//os.open()
//let buffer = [Float](repeating:1.12568796, count: 1)
//let inbuffer: UnsafeMutablePointer<UInt8> = UnsafeMutablePointer(mutating: buffer).deinitialize().assumingMemoryBound(to: UInt8.self)
//print(os.write(inbuffer, maxLength: 4) as Any)
//os.close()
////
//let pbuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4)
//let ins = InputStream(fileAtPath: "/Users/qq456cvb/Documents/Xcode projects/JsonToBinary/test.txt")!
//ins.open()
//ins.read(pbuffer, maxLength: 4)
//ins.close()
////
//let arrary = Array(UnsafeBufferPointer(start: pbuffer.deinitialize().assumingMemoryBound(to: Float.self), count: 4))
//
//let origin = pbuffer.deinitialize().assumingMemoryBound(to: Float.self)
//print(origin[0])

