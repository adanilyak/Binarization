//
//  Pyramid.swift
//  Binarization
//
//  Created by Alexander Danilyak on 09/12/2016.
//  Copyright © 2016 adanilyak. All rights reserved.
//

import Foundation

class Binarization {
    var image: Image
    
    var pyramids: [Pyramid.PyramidType : Pyramid]?
    var thresholds: Thresholds?
    var constNoiseThreshold: Double
    
    init(image: Image, constNoiseThreshold: Double) {
        self.image = image
        self.constNoiseThreshold = constNoiseThreshold
    }
    
    func createPyramidsAndThresholds() {
        createPyramids()
        createThreshold()
    }
    
    func makeBinarization(index: Int = 3) -> Image {
        createPyramidsAndThresholds()
        return increaseContrastReltiveToThresholdMap(index: index)
    }
    
    func createPyramids() {
        let minPyramid = Pyramid(with: image, type: .min)
        minPyramid.debugPrint()
        let maxPyramid = Pyramid(with: image, type: .max)
        maxPyramid.debugPrint()
        let averagePyramid = Pyramid(with: image, type: .average)
        averagePyramid.debugPrint()
        pyramids = [.min : minPyramid, .max : maxPyramid, .average : averagePyramid]
    }
    
    func createThreshold() {
        thresholds = Thresholds.init(hypothesis: .localAverage, pyramids: pyramids!, constNoiseThreshold: constNoiseThreshold)
        thresholds?.buildLastThesholdMap()
        thresholds?.buildAllOtherMaps()
        thresholds?.debugPrint()
    }
    
    func increaseContrastReltiveToThresholdMap(index: Int = 0) -> Image {
        image.increaseContrastRelativeToThreshold(threshold: thresholds!.thresholds[index], layerIndex: index)
        return image
    }
    
    //
    // --------------------------------------
    //
    
    class Thresholds {
        typealias thresholdMap = [[Double]]
        
        enum ThresholdInitHypothesis {
            case localAverage
            case averageBetweenMinAndMax
        }
        
        //MARK: Thresholds Properties
        
        var hypothesis: ThresholdInitHypothesis
        var thresholds: [thresholdMap]
        var constNoiseThreshold: Double
        var pyramids: [Pyramid.PyramidType : Pyramid]
        
        //MARK: Thresholds Body
        
        init(hypothesis: ThresholdInitHypothesis, pyramids: [Pyramid.PyramidType : Pyramid], constNoiseThreshold: Double) {
            self.pyramids = pyramids
            self.hypothesis = hypothesis
            self.constNoiseThreshold = constNoiseThreshold
            
            thresholds = Thresholds.createAllThresholdMapLayersWithFakeData(pyramid: pyramids[.min]!)
        }
        
        static func createAllThresholdMapLayersWithFakeData(pyramid: Pyramid) -> [thresholdMap] {
            var thresholds: [thresholdMap] = []
            for layer in pyramid.layers! {
                let map = Array(repeating: Array(repeating: 0.0, count: layer.height), count: layer.width)
                thresholds.append(map)
            }
            return thresholds
        }
        
        func buildLastThesholdMap() {
            let lastIndex = thresholds.count - 1
            let height = thresholds[lastIndex][0].count
            let width = thresholds[lastIndex].count
            
            for i in 0..<height {
                for j in 0..<width {
                    switch hypothesis {
                    case .localAverage:
                        thresholds[lastIndex][j][i] = pyramids[.average]!.layers!.last!.pixels![j][i].l()
                    case .averageBetweenMinAndMax:
                        thresholds[lastIndex][j][i] = (pyramids[.min]!.layers!.last!.pixels![j][i].l() + pyramids[.max]!.layers!.last!.pixels![j][i].l()) / 2.0
                    }
                }
            }
        }
        
        func buildAllOtherMaps() {
            let lastIndex = thresholds.count - 1
            let height = thresholds[lastIndex][0].count
            let width = thresholds[lastIndex].count
            
            for i in 0..<height {
                for j in 0..<width {
                    recursiveConvolution(layerIndex: lastIndex, w: j, h: i)
                }
            }
        }
        
        private func recursiveConvolution(layerIndex: Int, w: Int, h: Int) {
            if layerIndex <= 0 { return }
            
            var result = Array(repeating: 0.0, count: 4)
            
            let sidePart = 0.25
            let mainPart = 0.75
            
            let layerHeight = thresholds[layerIndex][0].count
            let layerWidth = thresholds[layerIndex].count
            
            // Convolution Line
            let hasLeftNeighbor = w - 1 >= 0
            let hasRightNeighbor = w + 1 < layerWidth
            
            if hasLeftNeighbor {
                result[0] = mainPart * thresholds[layerIndex][w][h] + sidePart * thresholds[layerIndex][w - 1][h]
                result[2] = mainPart * thresholds[layerIndex][w][h] + sidePart * thresholds[layerIndex][w - 1][h]
            } else {
                result[0] = thresholds[layerIndex][w][h]
                result[2] = thresholds[layerIndex][w][h]
            }
            
            if hasRightNeighbor {
                result[1] = mainPart * thresholds[layerIndex][w][h] + sidePart * thresholds[layerIndex][w + 1][h]
                result[3] = mainPart * thresholds[layerIndex][w][h] + sidePart * thresholds[layerIndex][w + 1][h]
            } else {
                result[1] = thresholds[layerIndex][w][h]
                result[3] = thresholds[layerIndex][w][h]
            }
            
            // Convolution Row
            let hasTopNeighbor = h - 1 >= 0
            let hasBottomNeighbor = h + 1 < layerHeight
            
            if hasTopNeighbor {
                result[0] += mainPart * thresholds[layerIndex][w][h] + sidePart * thresholds[layerIndex][w][h - 1]
                result[1] += mainPart * thresholds[layerIndex][w][h] + sidePart * thresholds[layerIndex][w][h - 1]
            } else {
                result[0] += thresholds[layerIndex][w][h]
                result[1] += thresholds[layerIndex][w][h]
            }
            
            if hasBottomNeighbor {
                result[2] += mainPart * thresholds[layerIndex][w][h] + sidePart * thresholds[layerIndex][w][h + 1]
                result[3] += mainPart * thresholds[layerIndex][w][h] + sidePart * thresholds[layerIndex][w][h + 1]
            } else {
                result[2] += thresholds[layerIndex][w][h]
                result[3] += thresholds[layerIndex][w][h]
            }
            
            result = result.map { (value) -> Double in
                return value / 2.0
            }
            
            let previousLayerIndex = layerIndex - 1
            
            let safeWidth = 2 * w + 1 >= thresholds[previousLayerIndex].count ? 2 * w : 2 * w + 1
            let safeHeight = 2 * h + 1 >= thresholds[previousLayerIndex][0].count ? 2 * h : 2 * h + 1
            
            thresholds[previousLayerIndex][2 * w][2 * h] = result[0]
            thresholds[previousLayerIndex][safeWidth][2 * h] = result[1]
            thresholds[previousLayerIndex][2 * w][safeHeight] = result[2]
            thresholds[previousLayerIndex][safeWidth][safeHeight] = result[3]
            
            func compareWithNoiseThesholdAndDoRecursion(_index: Int, _w: Int, _h: Int) {
                if abs(pyramids[.max]!.layers![_index].pixels![_w][_h].l() - pyramids[.min]!.layers![_index].pixels![_w][_h].l()) > constNoiseThreshold {
                    switch hypothesis {
                    case .localAverage:
                        thresholds[_index][_w][_h] = pyramids[.average]!.layers![_index].pixels![_w][_h].l()
                    case .averageBetweenMinAndMax:
                        thresholds[_index][_w][_h] = (pyramids[.min]!.layers![_index].pixels![_w][_h].l() + pyramids[.max]!.layers![_index].pixels![_w][_h].l()) / 2.0
                    }
                }
                
                recursiveConvolution(layerIndex: previousLayerIndex, w: _w, h: _h)
            }
            
            compareWithNoiseThesholdAndDoRecursion(_index: previousLayerIndex, _w: 2 * w, _h: 2 * h)
            compareWithNoiseThesholdAndDoRecursion(_index: previousLayerIndex, _w: safeWidth, _h: 2 * h)
            compareWithNoiseThesholdAndDoRecursion(_index: previousLayerIndex, _w: 2 * w, _h: safeHeight)
            compareWithNoiseThesholdAndDoRecursion(_index: previousLayerIndex, _w: safeWidth, _h: safeHeight)
        }
        
        func debugPrint() {
            if debugOutput {
                print("-----------------------------------")
                print("THRESHOLDS DONE")
                for (index, map) in thresholds.enumerated() {
                    Image(with: map).save(to: outputFolder + "thresholds_\(index).jpg")
                }
                print("-----------------------------------")

            }
        }
    }
    
    //
    // --------------------------------------
    //
    
    class Pyramid {
        enum PyramidType: String {
            case min
            case max
            case average
            case notset
        }
        
        class Layer {
            var index: Int = 0
            var width: Int = 0
            var height: Int = 0
            var pixels: [[Pixel]]?
            
            //MARK: Build
            
            static func buildInitialLayer(image: Image) -> Layer {
                let layer = Layer()
                layer.index = 0
                layer.width = image.width
                layer.height = image.height
                layer.pixels = image.pixels
                return layer
            }
            
            static func buildFromPrevious(layer: Layer, convolution: @escaping ([Pixel]) -> Pixel) -> Layer? {
                if layer.width < 4 || layer.height < 4 { return nil }
                
                let nextLayer = Layer()
                
                nextLayer.index = layer.index + 1
                nextLayer.width =  layer.width / 2 + layer.width % 2
                nextLayer.height = layer.height / 2 + layer.height % 2
                
                nextLayer.pixels = Array(repeating: Array(repeating: Pixel(), count: nextLayer.height), count: nextLayer.width)
                
                for i in 0..<nextLayer.height {
                    for j in 0..<nextLayer.width {
                        let safeWidth = 2 * j + 1 >= layer.width ? 2 * j : 2 * j + 1
                        let safeHeight = 2 * i + 1 >= layer.height ? 2 * i : 2 * i + 1
                        let square = [layer.pixels![2 * j][2 * i],
                                      layer.pixels![safeWidth][2 * i],
                                      layer.pixels![2 * j][safeHeight],
                                      layer.pixels![safeWidth][safeHeight]]
                        nextLayer.pixels![j][i] = convolution(square)
                    }
                }
                
                return nextLayer
            }
            
            //MARK: Convolutions
            
            static func max(pixels: [Pixel]) -> Pixel {
                let pixel = pixels.max { (p1, p2) -> Bool in
                    return p1.l() < p2.l()
                }
                return pixel!
            }
            
            static func min(pixels: [Pixel]) -> Pixel {
                let pixel = pixels.min { (p1, p2) -> Bool in
                    return p1.l() < p2.l()
                }
                return pixel!
            }
            
            static func average(pixels: [Pixel]) -> Pixel {
                var r = 0, g = 0, b = 0
                for pixel in pixels {
                    r += Int(pixel.r)
                    g += Int(pixel.g)
                    b += Int(pixel.b)
                }
                let count = pixels.count
                return Pixel(pixelData: [UInt8(r / count), UInt8(g / count), UInt8(b / count), 0], hasAlpha: false)
            }
        }
        
        //MARK: Pyramid Body
        
        var layers: [Layer]?
        var type: PyramidType
        
        init(with image: Image, type: PyramidType) {
            self.type = type
            buildAllLayers(image: image)
        }
        
        func buildAllLayers(image: Image) {
            layers = []
            layers!.append(Layer.buildInitialLayer(image: image))
            
            var nextLayer: Layer?
            repeat {
                nextLayer = Layer.buildFromPrevious(layer: layers!.last!, convolution: convolution())
                if nextLayer != nil { layers!.append(nextLayer!) }
            } while nextLayer != nil
        }
        
        func convolution() -> (([Pixel]) -> Pixel) {
            switch type {
            case .max: return Layer.max
            case .min: return Layer.min
            case .average: return Layer.average
            case .notset: assert(false, "convolution not set")
            }
            return Layer.max
        }
        
        func height(at layerIndex: Int) -> Int {
            return layers![layerIndex].height
        }
        
        func width(at layerIndex: Int) -> Int {
            return layers![layerIndex].width
        }
        
        func debugPrint() {
            if debugOutput {
                print("-----------------------------------")
                print("TYEPE: \(type.rawValue.uppercased())")
                print("LAYERS: \(layers?.count)")
                if layers != nil {
                    for (index, layer) in layers!.enumerated() {
                        print("INDEX: \(index), WIDTH: \(layer.width), HEIGHT: \(layer.height)")
                        Image(with: layer).save(to: outputFolder + "\(type.rawValue.uppercased())_\(index).jpg")
                    }
                }
                print("-----------------------------------")
            }
        }
    }
}
