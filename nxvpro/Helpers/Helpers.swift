//
//  Helpers.swift
//  NX-V
//
//  Created by Philip Bishop on 31/05/2021.
//
import AVFoundation
import Foundation
import SwiftUI

class Helpers{
    static func playAudioAlert(){
        if(UserDefaults.standard.object(forKey: Camera.VMD_AUDIO_KEY) != nil){
            let soundId = UserDefaults.standard.integer(forKey: Camera.VMD_AUDIO_KEY)
            if soundId > 0{
                DispatchQueue.main.async{
                    //AudioServicesPlayAlertSound(SystemSoundID(soundId))
                    AudioServicesPlaySystemSoundWithCompletion(UInt32(soundId)) {
                        print("AudioAlert complete")
                    }
                }
            }
        }
    }
    static func truncateIfTooLong(inStr: String,length: Int) -> String{
        if inStr.count > length + 1{
            return truncateString(inStr: inStr, length: length)
        }
        return inStr
    }
    static func truncateString(inStr: String,length: Int) -> String{
        let subStr = inStr.prefix(length)
        return String(subStr)
    }
    
    static func hasExceed(interval: TimeInterval,maxMinutes: Int) -> Bool{
        let ti = NSInteger(interval)
        
        return ti > maxMinutes * 60
    }
    static func timeString(time: TimeInterval) -> String {
        let hour = Int(time) / 3600
        let minute = Int(time) / 60 % 60
        let second = Int(time) % 60

        // return formated string
        return String(format: "%02i:%02i:%02i", hour, minute, second)
    }
    static func stringFromTimeInterval(interval: TimeInterval) -> NSString {
        
        let ti = NSInteger(interval)
        
        let ms = Int(interval) * 1000
        
        let seconds = ti % 60
        let minutes = (ti / 60) % 60
        let hours = (ti / 3600)
        
        return NSString(format: "%0.2d:%0.2d",minutes,seconds)
    }
    static func nowUTC() -> Date?{
        let utcDateFormatter = DateFormatter()
        utcDateFormatter.dateStyle = .medium
        utcDateFormatter.timeStyle = .medium

        // The default timeZone on DateFormatter is the device’s
        // local time zone. Set timeZone to UTC to get UTC time.
        utcDateFormatter.timeZone = TimeZone(abbreviation: "UTC")

        // Printing a Date
        let date = Date()
        let dateString = utcDateFormatter.string(from: date)

        let utcDate = utcDateFormatter.date(from: dateString)
        return utcDate
    }
    static func resizeImage(image:UIImage, w: Int,h: Int) -> UIImage{
            return resizeImage(image: image, newSize: CGSize(width: w, height: h))
    }
    static func resizeImage(image:UIImage, newSize:CGSize) -> UIImage{
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0);
        image.draw(in: CGRect(x: 0,y: 0,width: newSize.width,height: newSize.height))
        let newImage:UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }
    
    //MARK: Object detection box
    static func addBoxToImageAndSave(path: URL,box: CGRect){
        if let frame = UIImage(contentsOfFile: path.path){
            if let boxedFrame = addRectToImage(uiImage: frame, rect: box){
               
                let target = path
                if FileManager.default.fileExists(atPath: target.path){
                    FileHelper.deleteFile(theFile: target)
                }
                boxedFrame.pngWrite(target)
            
            }
        }
    }
    static func addRectToImage(uiImage: UIImage,rect: CGRect) -> UIImage?{
        
        let size = uiImage.size
        
        AppLog.write("ImageHelper:addRectToImage",size,rect)
        
        // Create a context of the starting image size and set it as the current one
        UIGraphicsBeginImageContext(uiImage.size)
        
        // Draw the starting image in the current context as background
        uiImage.draw(at: CGPoint.zero)

        // Get the current context
        let cgx = UIGraphicsGetCurrentContext()!

        
        //origina lower left corner
        let x = rect.origin.x
        //Different on OSX
        //let y = rect.origin.y
        //tvOS adjust
        let y = rect.origin.y - rect.size.height
        let x2 = x + rect.size.width
        let y2 = y + rect.size.height
        
        let topLeft = CGPoint(x: x, y: y)
        let bottomLeft = CGPoint(x: x, y: y2)
        
        let topRight = CGPoint(x: x2, y: y)
        let bottomRight = CGPoint(x: x2, y: y2)
        
        
        cgx.setStrokeColor(UIColor.cyan.cgColor)
        cgx.setLineWidth(3.5)
        
        cgx.move(to: topLeft)
        cgx.addLine(to: topRight)
        cgx.move(to: topRight)
        cgx.addLine(to: bottomRight)
        cgx.move(to: bottomRight)
        cgx.addLine(to: bottomLeft)
        cgx.addLine(to: topLeft)
        
        cgx.strokePath()
        
        let myImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // Return modified image
        return myImage
       
    }
}
extension String {
    var htmlDecoded: String {
        
        let decoded = self.replacingOccurrences(of: "%20", with: " ")
        
        return decoded
    }
}
extension String {
    func isIPv4() -> Bool {
        var sin = sockaddr_in()
        return self.withCString({ cstring in inet_pton(AF_INET, cstring, &sin.sin_addr) }) == 1
    }
    
    func isIPv6() -> Bool {
        var sin6 = sockaddr_in6()
        return self.withCString({ cstring in inet_pton(AF_INET6, cstring, &sin6.sin6_addr) }) == 1
    }
    
    func isIpAddress() -> Bool { return self.isIPv6() || self.isIPv4() }
}

enum Regex {
    static let ipAddress = "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$"
    static let hostname = "^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\\-]*[a-zA-Z0-9])\\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\\-]*[A-Za-z0-9])$"
}

extension String {
    
    var isValidIpAddressOrHost: Bool{
        return isValidHostname || isValidIpAddress
    }
    
    var isValidIpAddress: Bool {
        return self.matches(pattern: Regex.ipAddress)
    }
    
    var isValidHostname: Bool {
        return self.matches(pattern: Regex.hostname)
    }
    
    private func matches(pattern: String) -> Bool {
        return self.range(of: pattern,
                          options: .regularExpression,
                          range: nil,
                          locale: nil) != nil
    }
}
extension String {
    
    func camelCaseToWords() -> String {
        return unicodeScalars.reduce("") {
            if CharacterSet.uppercaseLetters.contains($1) {
                if $0.count > 0 {
                    return ($0 + " " + String($1))
                }
            }
            return $0 + String($1)
        }
    }
}
extension String {
    func index(from: Int) -> Index {
        return self.index(startIndex, offsetBy: from)
    }

    func substring(from: Int) -> String {
        let fromIndex = index(from: from)
        return String(self[fromIndex...])
    }

    func substring(to: Int) -> String {
        let toIndex = index(from: to)
        return String(self[..<toIndex])
    }

    func substring(with r: Range<Int>) -> String {
        let startIndex = index(from: r.lowerBound)
        let endIndex = index(from: r.upperBound)
        return String(self[startIndex..<endIndex])
    }
    
}
extension Date {
    func localDate() -> Date {
        let nowUTC = Date()
        let timeZoneOffset = Double(TimeZone.current.secondsFromGMT(for: nowUTC))
        guard let localDate = Calendar.current.date(byAdding: .second, value: Int(timeZoneOffset), to: nowUTC) else {return Date()}

        return localDate
    }
    func toUTC() -> Date{
        let timeZoneOffset = Double(TimeZone.current.secondsFromGMT(for: self))
        guard let utcDate = Calendar.current.date(byAdding: .second, value: Int(timeZoneOffset * -1), to: self) else {
            return self
            
        }

        return utcDate
    }
    func withAddedMinutes(minutes: Double) -> Date {
        addingTimeInterval(minutes * 60)
    }

    func withAddedHours(hours: Double) -> Date {
         withAddedMinutes(minutes: hours * 60)
    }
    
}
extension UIImage {
    /// Save PNG in the Documents directory
    func pngWrite(_ url: URL) {
        if let pngData = self.pngData(){
            do{
                
                try pngData.write(to: url)
                AppLog.write("pngWrite",url)
            }catch{
                AppLog.write("pngWrite at failed",error)
            }
        }
    }
}
extension UIImage {
    func scalePreservingAspectRatio(targetSize: CGSize) -> UIImage {
        // Determine the scale factor that preserves aspect ratio
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        
        let scaleFactor = min(widthRatio, heightRatio)
        
        // Compute the new image size that preserves aspect ratio
        let scaledImageSize = CGSize(
            width: size.width * scaleFactor,
            height: size.height * scaleFactor
        )

        // Draw and return the resized UIImage
        let renderer = UIGraphicsImageRenderer(
            size: scaledImageSize
        )

        let scaledImage = renderer.image { _ in
            self.draw(in: CGRect(
                origin: .zero,
                size: scaledImageSize
            ))
        }
        
        return scaledImage
    }
}
extension TimeInterval {
    
    var seconds: Int {
        return Int(self.rounded())
    }
    
    var milliseconds: Int {
        return Int(self * 1_000)
    }
}
extension Data {
    var hexString: String {
        let hexString = map { String(format: "%02.2hhx", $0) }.joined()
        return hexString
    }
}

