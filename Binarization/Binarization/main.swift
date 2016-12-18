//
//  main.swift
//  Binarization
//
//  Created by Alexander Danilyak on 06/12/2016.
//  Copyright © 2016 adanilyak. All rights reserved.
//

import Foundation

let debugOutput = false
let outputFolder = "/Users/Alexander/Desktop/Binarization/Pyramid/NT1/"

let noiseThresholds = [10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 25.0, 10.0,  5.0  , 10.0, 10.0]

let arrNTH: [Double] = [10.0]//[5.0, 10.0, 15.0, 20.0]
let arrK: [Double] = [4.0, 6.0]//[3.0, 6.0, 9.0]
let arrTH: [UInt8] = [220]//[230, 240, 250]
let arrTHPL: [Int] = [2, 3]

var _k: Double = 6.0
var _th: UInt8 = 200

for i in 1...15 {
    for __nth in arrNTH {
        for __k in arrK {
            for __th in arrTH {
                for __l in arrTHPL {
                    _k = __k
                    _th = __th
                    
                    let start = Date()
                    let image = Image(with: String(i))
                    let binarization = Binarization(image: image, constNoiseThreshold:__nth)
                    let outImage = binarization.makeBinarization(index: __l)
                    outImage.save(to: outputFolder + "\(i)_out_\(__nth)_\(_k)_\(_th)_\(__l).jpg")
                    print("DONE \(i)_out_\(__nth)_\(_k)_\(_th)_\(__l) IN \(Int(-start.timeIntervalSinceNow))")
                }
            }
        }

    }
}

