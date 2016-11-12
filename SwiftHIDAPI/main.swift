//
//  main.swift
//  SwiftHIDAPI
//
//  Created by kyb on 12/11/16.
//  Copyright © 2016 Suborbital Softworks Ltd. All rights reserved.
//
//  Licensed under Affero GPL 3
//

/*
 ## INTRODUCTION
 This is a little sample project how to import and use HIDAPI in Swift 3 with the Griffin Power Mate.
 
 HIDAPI is a library that allows for direct acees to USB HID devices. you can learn more about it from http://www.signal11.us/oss/hidapi/
 
 This project essentially is a Swift 3 port of a toy C++ program I've written to access the Griffin Power Mate: https://github.com/kybernetyk/pm8/
 
 
 ## PREREQUISITES
 This project assumes you have installed HIDAPI via brew (brew install hidapi).
 
 The path to the header is hardcoded in hidapi/module.map and you'll need to change it to point to hidapi.h on your system.
 
 This project also comes addition linker flags which contain the location of where the hidabi libraries can be found. If you get linker errors fix those settings!
 
 You can usually find out where hidapi resides on your system by running:
 
 pkg-config hidapi --cflags
 pkg-config hidapi --libs
 
 */

import Foundation
import hidapi

//meh
extension String {
    init(wString: UnsafeMutablePointer<wchar_t>) {
        if let nsstr = NSString(bytes: wString,
                                length: wcslen(wString) * MemoryLayout<wchar_t>.size,
                                encoding: String.Encoding.utf32LittleEndian.rawValue) {
            self.init(nsstr)
        } else {
            self.init()
        }
    }
}

func enumerateDevices() {
    let devs = hid_enumerate(0x00, 0x00)
    var cur_devp = devs
    
    while cur_devp != nil {
        if let dev = cur_devp?.pointee {
            print("Device Found")
            print("  Type: \(String(format: "%04x", dev.vendor_id)) \(String(format: "%04x", dev.product_id))")
            print("  Path: \(String(cString: dev.path))")
            print("  Serial_number: \(String(wString: dev.serial_number))")
            print("  Manufacturer: \(String(wString: dev.manufacturer_string))")
            print("  Product: \(String(wString: dev.product_string))")
            cur_devp = dev.next
        }
    }
    hid_free_enumeration(devs)
}

enum GriffinEvent {
    case WheelLeft, WheelRight, ButtonDown, ButtonUp
}


//this is a very naive approach to parsing what the powermate sends us
//it's enough for what I want to do but this doesn't cover all events
//and event combinations
func parseByteStream(buf: [UInt8]) -> GriffinEvent? {
    if buf[0] == 0x01 && buf[1] == 0x00 {
        return .ButtonDown
    }
    
    if buf[0] == 0x00 && buf[1] == 0x00 {
        return .ButtonUp
    }
    
    if buf[1] == 0xff {
        return .WheelLeft
    }
    
    if buf[1] == 0x01 {
        return .WheelRight
    }
    
    return nil
}

func mainLoop() {
    guard let handle = hid_open(0x077d, 0x0410, nil) else {
        print("No griffin powermate found, m8! Make sure the official Griffin app isn't running!")
        return
    }
    
    let MAX_STR = 255
    var wstr = [wchar_t](repeating: 0, count: MAX_STR)
    
    print("Device Info:")
    if hid_get_manufacturer_string(handle, &wstr, MAX_STR) == -1 {
        print("Could not get manufacturer string!")
        return
    }
    print("  Manufacturer String: \(String(wString: &wstr))")
    
    if hid_get_product_string(handle, &wstr, MAX_STR) == -1 {
        print("Could not get product string!")
        return
    }
    print("  Product String: \(String(wString: &wstr))")
    

    let BUF_LEN = 64
    var buf = [UInt8](repeating: 0, count: BUF_LEN + 1)
    
    while true {
        let rcount = hid_read(handle, &buf, BUF_LEN)
        if (rcount < 0) {
            print("Could not read from device!")
            return
        }
        if rcount == 6 {
            let slice = Array(buf[0...5])
            if let ev = parseByteStream(buf: slice) {
                print("ev: \(ev)")
            } else {
                print("unknown data: ")
                for b in slice {
                    print(" \(String(format: "%02x", b))", terminator: "")
                }
                print("")
            }
        }
    }
}

//enumerateDevices()
mainLoop()
