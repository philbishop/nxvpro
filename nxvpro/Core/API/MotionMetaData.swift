//
//  MotionMetaData.swift
//  NX-V PRO
//
//  Created by Philip Bishop on 13/04/2023.
//

import Foundation

class MotionMetaData: Codable {
    var box: CGRect
    var confidence: Float
    var info: String?
    
    init(){
        self.box = CGRect()
        self.confidence = 0
        self.info = ""
    }
    
    init(box: CGRect, confidence: Float,info: String) {
        self.box = box
        self.confidence = confidence
        self.info = info
    }
    
    enum CodingKeys: String, CodingKey {
        case box = "box"
        case confidence = " confidence"
        case info = "info"
    }
    
    func save(toFile: URL){
        let encoder = JSONEncoder()
        
        if let encodedData = try? encoder.encode(self) {
            
            do {
                try encodedData.write(to: toFile)
            }
            catch {
                AppLog.write("Failed to write JSON data: \(error.localizedDescription)")
            }
            
        }
    }
    func load(fromFile: URL){
        do {
            let jsonData = try Data(contentsOf: fromFile)
            let meta = try JSONDecoder().decode(MotionMetaData.self, from: jsonData)
            
            self.box = meta.box
            self.confidence = meta.confidence
            
            if let mi = meta.info{
                self.info = mi
            }
        }
        catch {
            AppLog.write("Failed to load JSON data: \(error.localizedDescription)")
        }
    }
    func load(fromString: String){
        if let jsonData = fromString.data(using: .utf8){
            do{
                let meta = try JSONDecoder().decode(MotionMetaData.self, from: jsonData)
                
                self.box = meta.box
                self.confidence = meta.confidence
                
                if let mi = meta.info{
                    self.info = mi
                }
            }catch{
                AppLog.write("Failed to load JSON data from string: \(error.localizedDescription)")
            }
        }
    }
    func confidenceString() -> String{
        let rc = round(confidence*100)
        let cs = String(format: "%.0f",rc)
        var objectTitle = ""
        if let mi = info{
            objectTitle = mi + " "
        }
        return objectTitle +  cs + "%"
    }
}
