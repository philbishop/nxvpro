//
//  EventsAndVideoDataSource.swift
//  NXV-IOS
//
//  Created by Philip Bishop on 30/06/2021.
//

import SwiftUI
import AVKit

class EventsAndVideosDataSource {
    
    /*
    static func populateModel(camera: Camera) -> Bool{
        let model = EventsAndVideosModel()
        let ds = EventsAndVideosDataSource(camera: camera)
        ds.populateVideos(model: model)
        
        return model.daysWithVideos.count > 0
    }
    */
    let validVideoExt = ["mp4","avi","mov","webm","mjpg"]
    var camera: Camera?
    
    
    func setCamera(camera: Camera?){
        self.camera = camera
    }
    func populateVideos(model: EventsAndVideosModel) -> Int {
        model.daysToVideoData = [Date: [CardData]]()
        
        let videoRoot = FileHelper.getVideoStorageRoot()
        print("VIDEO",videoRoot.path)
        
        
        do {
             let files = try FileManager.default.contentsOfDirectory(atPath: videoRoot.path)
            
            if files.count == 0 {
                return 0
            }
            //iterate and find most recent video
            for i in 0...files.count-1 {
                let file = files[i]
               
                //TP-IPC_1920x1080_20210609124237.mp4
                
                let parts = file.components(separatedBy: ".")
                
                let ext = parts[parts.count-1]
                
                
                if validVideoExt.contains(ext) {
                    
                    let fileParts = file.components(separatedBy: "_")
                    guard fileParts.count > 1 else{
                        continue
                    }
                    if let cam = camera{
                        if file.hasPrefix(cam.getStringUid())==false{
                            continue
                        }
                    }
                    let dateStr = fileParts[fileParts.count-1].replacingOccurrences(of: "."+ext, with: "")
                    let cdate = dateFromFileString(dateStr: dateStr)
                    
                    if cdate == nil {
                        continue
                    }
                    let created = cdate!
                    let calendar = Calendar.current
                    let dcomp = DateComponents(year:
                                                calendar.component(.year, from: created)
                                               ,month:
                    calendar.component(.month, from: created)
                                               ,day:
                    calendar.component(.day, from: created))
                    
                    let eventDay = calendar.date(from: dcomp)!
                    
                    if model.daysWithVideos.contains(eventDay) == false {
                        model.daysWithVideos.append(eventDay)
                    }
                    
                    print("file atts",eventDay)
                    
                    let ecomp = DateComponents(year:
                                                calendar.component(.year, from: created)
                                               ,month:
                    calendar.component(.month, from: created)
                                               ,day:
                    calendar.component(.day, from: created),
                                               hour:
                    calendar.component(.hour, from: created),
                                               minute:
                    calendar.component(.minute, from: created),
                                               second:
                    calendar.component(.second, from: created))
                    
                    let eventTime = calendar.date(from: ecomp)!
                    
                    
                    let nameParts = file.components(separatedBy: "_")
                    let srcPath = videoRoot.appendingPathComponent(file)
                    var nsImage = UIImage(named: "no_video_thumb")
                    
                    let nsi = srcPath.generateThumbnail()
                    let thumbPath = srcPath.path.replacingOccurrences(of: "."+ext, with: ".png")
                    
                    if FileManager.default.fileExists(atPath: thumbPath) {
                        nsImage = UIImage(contentsOfFile: thumbPath)
                        
                    }
                    else if nsi != nil {
                        nsImage = nsi
                    }
                    
                    var name = nameParts[0]
                    if let cam = camera{
                        name = cam.getDisplayName()
                    }
                    
                    let cardData = CardData(image: nsImage!, name: name, date: eventTime,filePath: srcPath)
                    
                    //check if this is an event
                    let eventImg = "_" + file.replacingOccurrences(of: "."+ext, with: ".png")
                    let eventImgPath = videoRoot.appendingPathComponent(eventImg)
                    
                    print(eventImgPath.path)
                    
                    cardData.isEvent = FileManager.default.fileExists(atPath: eventImgPath.path)
                    
                    if cardData.isEvent {
                        cardData.fullsizeImagePath = eventImgPath
                        print("Matching event (fullsize) found",eventImg)
                    }
                    
                    let dataForDay = model.daysToVideoData[eventDay]
                    if dataForDay == nil {
                        model.daysToVideoData[eventDay] = [CardData]()
            
                    }
                    model.daysToVideoData[eventDay]!.append(cardData)
                    
                    print("Events daysWithVideo",eventDay,model.daysToVideoData[eventDay]!.count)
                }
                
            }
            
            //sort each day with videos
            for d in model.daysWithVideos {
                let cdat = model.daysToVideoData[d]
                model.daysToVideoData[d] =  cdat!.sorted {
                    $0.date.timeIntervalSince1970 > $1.date.timeIntervalSince1970
                 }
            }
            
            model.daysWithVideos.sort{
                $0.timeIntervalSince1970 > $1.timeIntervalSince1970
            }
        }catch{
            print("\(error)")
        }

        return model.daysToVideoData.count
    }
    func dateFromFileString(dateStr: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        return dateFormatter.date(from: dateStr)
    }
}

class EventsAndVideosModel : ObservableObject{
    @Published var daysWithEvents: [Date]
    @Published var daysWithVideos: [Date]
    @Published var daysToData: [Date: [CardData]]
    @Published var daysToVideoData: [Date: [CardData]]
    
    @Published var videoPlaceholderText: String = "Loading video..."
    @Published var videoPlayerHidden: Bool = true
    
    init(){
        daysWithEvents = [Date]()
        daysWithVideos = [Date]()
        daysToData = [Date: [CardData]]()
        daysToVideoData = [Date: [CardData]]()
       
    }
    
    func sortAll(){
        for d in daysWithEvents {
            let cdat = daysToData[d]
            daysToData[d] =  cdat!.sorted {
                $0.date.timeIntervalSince1970 < $1.date.timeIntervalSince1970
             }
        }
        for d in daysWithVideos {
            let cdat = daysToVideoData[d]
            daysToVideoData[d] =  cdat!.sorted {
                $0.date.timeIntervalSince1970 < $1.date.timeIntervalSince1970
             }
        }
    }
    
    func reset(){
        daysWithEvents = [Date]()
        daysWithVideos = [Date]()
        daysToData = [Date: [CardData]]()
        daysToVideoData = [Date: [CardData]]()
       
    }
    
    func getVideoCard(atPath: URL) -> CardData? {
        for day in daysWithVideos {
            let vcards = daysToVideoData[day]
            
            for vc in vcards! {
                if vc.filePath == atPath {
                    return vc
                }
            }
        }
        return nil
    }
    
    func getDayForVideo(filePath: URL) -> Date? {
        for day in daysWithVideos {
            let vcards = daysToVideoData[day]
            
            for vc in vcards! {
                if vc.filePath == filePath {
                    return day
                }
            }
        }
        return nil
    }
    
    
    func dayToString(date: Date) -> String{
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM dd yyyy"
        return fmt.string(from: date)
    }
    
    func getPreviousVideoDay(day: Date) -> Date?{
        if daysToVideoData.count == 0 {
            return nil
        }
        var prevItem: Date?
        for (date,data) in daysToVideoData {
            
            if date == day {
                return prevItem
            }
            prevItem = date
            
        }
        return nil
    }
    func getNextVideoDay(day: Date) -> Date?{
        if daysToVideoData.count == 0 {
            return nil
        }
        var returnNext = false
        for (date,data) in daysToVideoData {
            
            if date == day {
                returnNext = true
                continue
            }
            if returnNext {
                return date
            }
        }
        return nil
    }
    
}
