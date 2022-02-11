//
//  CardData.swift
//  NXV-IOS
//
//  Created by Philip Bishop on 19/06/2021.
//
import SwiftUI
import AVFoundation

extension URL {
    func generateThumbnail() -> UIImage? {
        do {
            let asset = AVURLAsset(url: self)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            
            // Swift 5.3
            let cgImage = try imageGenerator.copyCGImage(at: .zero,
                                                         actualTime: nil)

            return UIImage(cgImage: cgImage)
        } catch {
            print(error.localizedDescription)

            return nil
        }
    }
}

class CardData : Hashable, ObservableObject{
    
    
    static var nextId = 0
    static var idLookup = [String: Int]()
    static func getPathId(path: String) -> Int {
        if idLookup[path] == nil {
            nextId = nextId + 1
            idLookup[path] = nextId
        }
        
        return idLookup[path]!
    }
    var id: Int
    @Published var nsImage: UIImage
    var name: String
    var date: Date
    var filePath: URL
    //motion events with video clip
    var fullsizeImagePath: URL?
    var fileSizeString: String
    var fileSize: UInt64
    var isEvent: Bool
    
    init(image: UIImage,name: String,date: Date,filePath: URL){
        self.id = CardData.getPathId(path: filePath.path)
        
        self.nsImage = image
        self.name = name
        self.date = date
        self.filePath = filePath
        self.fileSizeString = filePath.fileSizeString
        self.fileSize = filePath.fileSize
        self.isEvent = false
    }
    
    func dateString() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM dd HH:mm:ss"
        return fmt.string(from: date)
    }
    func shortDateString() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM dd HH:mm"
        return fmt.string(from: date)
    }
    func hasFullsizeImagePath() -> Bool {
        return fullsizeImagePath != nil
    }
    
    //MARK: hashable
    static func == (lhs: CardData, rhs: CardData) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(name)
        }
}



struct CardRow : Hashable{
    var rowId: Int
    var rowData: [CardData]
    
    init(rowId: Int,rowData: [CardData]){
        self.rowId = rowId
        self.rowData = rowData
    }
}
