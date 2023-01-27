//
//  ImageHelper.swift
//  NXV-IOS
//
//  Created by Philip Bishop on 01/08/2021.
//

import SwiftUI

class ImageHelper{
    static func toBlackAndWhite(uiImage: UIImage) -> UIImage?{
        guard let currentCGImage = uiImage.cgImage else { return nil }
        let currentCIImage = CIImage(cgImage: currentCGImage)

        let filter = CIFilter(name: "CIColorMonochrome")
        filter?.setValue(currentCIImage, forKey: "inputImage")

        // set a gray value for the tint color
        filter?.setValue(CIColor(red: 0.7, green: 0.7, blue: 0.7), forKey: "inputColor")

        filter?.setValue(1.0, forKey: "inputIntensity")
        guard let outputImage = filter?.outputImage else { return nil}

        let context = CIContext()

        if let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
            let processedImage = UIImage(cgImage: cgimg)
            AppLog.write(processedImage.size)
            return processedImage
        }
        
        return nil
    }
}
