//
//  Image.swift
//  Binarization
//
//  Created by Alexander Danilyak on 06/12/2016.
//  Copyright © 2016 adanilyak. All rights reserved.
//

import Foundation
import AppKit
import CoreGraphics

class Pixel {
    var r, g, b: UInt8
    
    init() {
        r = 0
        g = 0
        b = 0
    }
    
    init(pixelData: [UInt8], hasAlpha: Bool) {
        let offset = hasAlpha ? 1 : 0
        r = pixelData[0 + offset]
        g = pixelData[1 + offset]
        b = pixelData[2 + offset]
    }
    
    func l() -> Double {
        return Double(r) + 4.5907 * Double(g) + 0.0601 * Double(b)
        //return (Double(r) + Double(g) + Double(b)) / 3.0
    }
    
    func asArray() -> [Int] {
        return [Int(r), Int(g), Int(b)]
    }
    
    func binarization(threshold: Double) {
        let y = _k * (l() - threshold) + threshold

        let nc = UInt8(min(max(y, 0.0), 255.0))
        let nnc = nc > _th ? UInt8(255) : UInt8(0)
        
        r = nnc
        g = nnc
        b = nnc
    }
}

//
//          Y
//     ----->
//    |
//    |  IMG
//  X V
//

struct Image {
    var width: Int
    var height: Int
    var pixels: [[Pixel]]
    var bitmapConfig: [String: Any]
    
    init(with layer: Binarization.Pyramid.Layer) {
        width = layer.width
        height = layer.height
        pixels = layer.pixels!
        bitmapConfig = Image.defaultConfig(width: width)
    }
    
    init(with threshold: Binarization.Thresholds.thresholdMap) {
        width = threshold.count
        height = threshold[0].count
        pixels = Image.getFilledPixels(threshold: threshold)
        bitmapConfig = Image.defaultConfig(width: width)
    }
    
    init(with image: Image) {
        self.width = image.width
        self.height = image.height
        self.pixels = image.pixels.map { $0 }
        self.bitmapConfig = image.bitmapConfig
    }
    
    init(with imageNamed: String) {
        let path = Bundle.main.pathForImageResource(imageNamed)!
        let image = NSImage(contentsOfFile: path)!
        
        let bitmap = image.representations.first as! NSBitmapImageRep
        
        bitmapConfig = ["bitsPerSample": bitmap.bitsPerSample,
                        "samplesPerPixel": bitmap.samplesPerPixel,
                        "hasAlpha": bitmap.hasAlpha,
                        "isPlanar": bitmap.isPlanar,
                        "colorSpaceName": bitmap.colorSpaceName,
                        "bytesPerRow": bitmap.bytesPerRow,
                        "bitsPerPixel": bitmap.bitsPerPixel]
        
        pixels = Image.convertToArrayOfPixels(bitmap: bitmap)
        width = bitmap.pixelsWide
        height = bitmap.pixelsHigh
    }
    
    static func convertToArrayOfPixels(bitmap: NSBitmapImageRep) -> [[Pixel]] {
        var pixels = Array(repeating: Array(repeating: Pixel(), count: bitmap.pixelsHigh), count: bitmap.pixelsWide)
        
        for i in 0..<bitmap.pixelsHigh {
            for j in 0..<bitmap.pixelsWide {
                let pixelDataArray = [0, 0, 0, 0]
                let pointer: UnsafeMutablePointer<Int> = UnsafeMutablePointer(mutating: pixelDataArray)
                bitmap.getPixel(pointer, atX: j, y: i)
                pixels[j][i] = Pixel(pixelData: pixelDataArray.map { (p) -> UInt8 in
                    UInt8(p)
                }, hasAlpha: bitmap.hasAlpha)
            }
        }
        
        return pixels
    }
    
    func save(to file: String) {
        let _bitmapConfig = Image.defaultConfig(width: width)
        
        let imageRep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                        pixelsWide: width,
                                        pixelsHigh: height,
                                        bitsPerSample: _bitmapConfig["bitsPerSample"] as! Int,
                                        samplesPerPixel: _bitmapConfig["samplesPerPixel"] as! Int,
                                        hasAlpha: _bitmapConfig["hasAlpha"] as! Bool,
                                        isPlanar: _bitmapConfig["isPlanar"] as! Bool,
                                        colorSpaceName: _bitmapConfig["colorSpaceName"] as! String,
                                        bytesPerRow: _bitmapConfig["bytesPerRow"] as! Int,
                                        bitsPerPixel: _bitmapConfig["bitsPerPixel"] as! Int)!
        
        for i in 0..<height {
            for j in 0..<width {
                let pixelPointer = UnsafeMutablePointer<Int>(mutating: pixels[j][i].asArray())
                imageRep.setPixel(pixelPointer, atX: j, y: i)
            }
        }
        
        let imageJPGData = imageRep.representation(using: NSJPEGFileType, properties: [:])!
        try? imageJPGData.write(to: URL(fileURLWithPath: file))
    }
    
    static func defaultConfig(width: Int) -> [String: Any] {
        return ["bitsPerSample": 8,
                "samplesPerPixel": 3,
                "hasAlpha": false,
                "isPlanar": false,
                "colorSpaceName": "NSCalibratedRGBColorSpace",
                "bytesPerRow": 3 * width,
                "bitsPerPixel": 24]
    }
    
    //MARK: Fill With Thresholds
    
    static func getFilledPixels(threshold: Binarization.Thresholds.thresholdMap) -> [[Pixel]] {
        let height = threshold[0].count
        let width = threshold.count
        
        var pixels = Array(repeating: Array(repeating: Pixel(), count: height), count: width)
        
        var maxInThreshold = 0.0
        for i in 0..<height {
            for j in 0..<width {
                if threshold[j][i] > maxInThreshold {
                    maxInThreshold = threshold[j][i]
                }
            }
        }
        
        for i in 0..<height {
            for j in 0..<width {
                let onePixelData = maxInThreshold == 0.0 ? 0 : UInt8((threshold[j][i] / maxInThreshold) * 255.0)
                let pixelDataArray = Array(repeating: onePixelData, count: 4)
                pixels[j][i] = Pixel(pixelData: pixelDataArray, hasAlpha: false)
            }
        }
        
        return pixels
    }
    
    //MARK: Contrast
    
    func increaseContrastRelativeToThreshold(threshold: Binarization.Thresholds.thresholdMap, layerIndex: Int) {
        for i in 0..<height {
            for j in 0..<width {
                let divider = Int(pow(2.0, Double(layerIndex)))
                let thresholdValue = threshold[j / divider][i / divider]
                
                pixels[j][i].binarization(threshold: thresholdValue)
            }
        }
    }
}

extension NSBitmapImageRep {
    func _print(x: Int, y: Int) {
        let pixelDataArray = [0, 0, 0, 0]
        let pointer: UnsafeMutablePointer<Int> = UnsafeMutablePointer(mutating: pixelDataArray)
        self.getPixel(pointer, atX: x, y: y)
        print(pixelDataArray)
    }
}



