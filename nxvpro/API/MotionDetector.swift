//
//  MotionDetector.swift
//  NX-V
//
//  Created by Philip Bishop on 31/05/2021.
//

import Foundation
import SwiftUI

/*
extension NSBitmapImageRep {
    var png: Data? { representation(using: .png, properties: [:]) }
}
extension Data {
    var bitmap: NSBitmapImageRep? { NSBitmapImageRep(data: self) }
}
extension UIImage {
    var png: Data? { tiffRepresentation?.bitmap?.png }
}
*/
struct VmdColor{
    var red: UInt8
    var green: UInt8
    var blue: UInt8
    //var alpha: UInt8
    
}

protocol MotionDetectionListener {
    func onMotionEvent(camera: Camera,start: Bool,time: Date)
    func onLevelChanged(camera: Camera,level: Int)
}
class MotionDetector{
    
    var previousPixels: [VmdColor]?
    var busy = false
    
    public var enabled: Bool = false
    public var listener: MotionDetectionListener?
    public var maxThreshold = 300
    public var name: String?
    public var vmdStorageRoot: URL?
    
    var threshold = 250
    var fullSizeImagePath: URL?
    var absMax = 1200
    var frameCount = 0
    var lastEventAt = Date()
    var ignoreFor = 10.0
    let useGrayScale = true
    
    var theCamera: Camera?
    func startNewSession(camera: Camera){
        theCamera = camera
        ignoreFor = 5.0
        lastEventAt = Date()
        busy = false
    }
    
    func setCurrentPath(imagePath: URL) -> Bool{
        
        if imagePath.path.isEmpty{
            return false
        }
        
        fullSizeImagePath = imagePath
        if let nsImage = UIImage(contentsOfFile: imagePath.path){
            if useGrayScale == false {
                return setCurrent(imageRef: nsImage)
            }
            if let bwi = ImageHelper.toBlackAndWhite(uiImage: nsImage) {
               return setCurrent(imageRef: bwi)
                
            }else{
                return setCurrent(imageRef: nsImage)
            }
        }
        return false
    }
    
    func setCurrent(imageRef: UIImage) -> Bool{
        if busy || enabled == false {
            return false
        }
        
        if maxThreshold <= 0 {
            return false;
        }
        
        let ti = Date().timeIntervalSince(lastEventAt)
        if ti < ignoreFor {
            previousPixels = nil
            listener?.onLevelChanged(camera: theCamera!,level: 0)
            AppLog.write("VMD: ignore for",Int(ti))
            return false
        }
        
        busy = true
        frameCount += 1
        var isEvent = false
        
        let currentPixels = getRGBAsFromImage(imageRef: imageRef)
        
        if previousPixels == nil {
            previousPixels = currentPixels
            busy = false
            
            return isEvent
        }
        listener?.onMotionEvent(camera: theCamera!,start: false,time: Date())
        let prev = previousPixels!
        
        if prev.count != currentPixels.count {
            busy = false
            return false
        }
        
     
        
        var totaldiff = 0
        
        
        for pixelIndex in 0...prev.count-1 {
            
            let pColor = prev[pixelIndex]
            let cColor = currentPixels[pixelIndex]

            var diff = comparePixels(prev: pColor.red,cur: cColor.red)
            if useGrayScale == false {
                diff += comparePixels(prev: pColor.green,cur: cColor.green)
            }
            diff += comparePixels(prev: pColor.blue,cur: cColor.blue)
            
            if( diff > threshold){
                totaldiff = totaldiff + 1
            }
        }
        
        if frameCount % 60 == 0 {
            AppLog.write("VMD:totalDiff",totaldiff,maxThreshold)
        }
        
        listener?.onLevelChanged(camera: theCamera!,level: totaldiff)
        
        if(totaldiff > maxThreshold){
            
            if totaldiff < absMax {
                lastEventAt = Date()
                listener?.onMotionEvent(camera: theCamera!,start: true,time: Date())
                //createMotionEvent()
                
                isEvent = true
                AppLog.write("VMD:Alert",totaldiff,maxThreshold)
            }else{
                AppLog.write("VMD:absMax exceeded",totaldiff,absMax)
            }
        }
        
        previousPixels = currentPixels
        busy = false
        
        return isEvent
    }
    func createMotionEvent(){
        do{
            let fname = name!+" "+FileHelper.getDateStr(date: Date())+".png"
            let eventFilePath = vmdStorageRoot!.appendingPathComponent(fname)
            let srcImage = fullSizeImagePath!
            try FileManager.default.moveItem(at: srcImage,to: eventFilePath)
        
            //to test correct resize (OK)
            /*
            let png = "raw-frame.png".replacingOccurrences(of: " ", with: "_")
            let vmdFrame = FileHelper.getPathForFilename(name: png)
            try rawFrame!.png?.write(to: vmdFrame)
             */
        }
        catch{
            AppLog.write("Failed to create motion event",error)
        }
        
        
    }
    func comparePixels(prev: UInt8, cur: UInt8) -> Int
    {
        var pix = (0xff & cur)

        var otherPix = (0xff & prev)

        // Catch any pixels that are out of range
        
        if (pix > 255) {
            pix = 255
        }
        
        if (otherPix > 255) {
            otherPix = 255
        }

        var diff: Int = Int(pix) - Int(otherPix)
        if diff < 0 {
            diff = diff * -1
        }

        return diff;
    }
    
    func getRGBAsFromImage(imageRef: UIImage) -> [VmdColor]{
        var rawData = [VmdColor]()
        
        
        let width = Int(imageRef.size.width)
        let height = Int(imageRef.size.height)
        let count = (width*height) * 4
        
        let  cgImage = imageRef.cgImage!//(forProposedRect: nil, context: nil, hints: nil
        
        guard let pixelData = cgImage.dataProvider?.data,
              let data = CFDataGetBytePtr(pixelData) else { return rawData }
        

        for pixelInfo in 0...count-1 {
            let r = UInt8(data[pixelInfo])
            let g = UInt8(data[(pixelInfo + 1)])
            let b = UInt8(data[pixelInfo + 2])
            
            let col = VmdColor(red: r,green: g,blue: b)
            rawData.append(col)
        }

        return rawData
    }
        
}
