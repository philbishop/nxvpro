//
//  CardDataEx.swift
//  nxvpro
//
//  Created by Philip Bishop on 26/01/2023.
//

import SwiftUI

extension CardData{
    func getThumb() -> UIImage{
        
        
        if imagePath.isEmpty==false && FileManager.default.fileExists(atPath: imagePath){
            if let nsi = UIImage(contentsOfFile: imagePath){
                return nsi
            }
        }
        
        return UIImage(named: "no_video_thumb")!
    }
}
