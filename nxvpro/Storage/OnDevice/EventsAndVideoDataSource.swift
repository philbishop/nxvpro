//
//  EventsAndVideoDataSource.swift
//  NXV-IOS
//
//  Created by Philip Bishop on 30/06/2021.
//

import SwiftUI
import AVKit

class EventsAndVideosDataSource {
    
    
    let validVideoExt = ["mp4","avi","mov","webm","mjpg"]
    //var camera: Camera?
    var cameras: [Camera]?
    var recordRange = RecordProfileToken()
    var recordTokens = [RecordToken]()
    
    func setCameras(cameras: [Camera]){
        self.cameras = cameras
    }
    
    func setCamera(camera: Camera){
        cameras = [Camera]()
        cameras!.append(camera)
        //self.camera = camera
    }
    
    func getTokensFor(day: Date) -> [RecordToken]{
        var tokens = [RecordToken]()
        for rt in recordTokens{
            if let date = rt.fileDate{
                if Calendar.current.isDate(date, inSameDayAs: day){
                    tokens.append(rt)
                }
            }
        }
        return tokens
    }
    
    private var emodel: EventsAndVideosModel?
    
    func getCardsForDay(day: Date) -> [CardData]{
        var cards = [CardData]()
        if let eventsModel = emodel{
            for d in eventsModel.daysWithVideos {
                print("Events day with video",d)
                if let cdat = eventsModel.daysToVideoData[d]{
                    for card in cdat{
                        if card.date != nil{
                            if Calendar.current.isDate(day, inSameDayAs: card.date){
                                cards.append(card)
                            }
                        }
                    }
                }
            }
        }
        return cards
    }
    func refresh(){
        if let eventsModel = emodel{
            populateVideos(model: eventsModel)
        }
    }
    func populateVideos(model: EventsAndVideosModel) -> Int {
        self.emodel=model;
        model.daysToVideoData = [Date: [CardData]]()
        
        let videoRoot = FileHelper.getVideoStorageRoot()
        print("VIDEO",videoRoot.path)
        
        var firstDate: Date?
        var lastDate: Date?
        
        recordRange = RecordProfileToken()
        recordTokens.removeAll()
        
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
                
                var camera: Camera?
               
                if validVideoExt.contains(ext) {
                    
                    let fileParts = file.components(separatedBy: "_")
                    guard fileParts.count > 1 else{
                        continue
                    }
                    
                    if let cams = cameras{
                        for cam in cams{
                            if file.hasPrefix(cam.getStringUid()){
                                camera = cam
                                break
                            }
                        }
                    }
                    
                    if camera == nil{
                        continue
                    }
                    
                    let dateStr = fileParts[fileParts.count-1].replacingOccurrences(of: "."+ext, with: "")
                    let cdate = dateTimeFromFileString(dateStr: dateStr)
                    
                    
                    if cdate == nil {
                        continue
                    }
                    
                    let eventTime = cdate!
                    let eventDay = dayFromFileString(dateStr: dateStr)!
                    
                    let cal = Calendar.current
                    if let fdate = cdate{
                        if firstDate == nil{
                            firstDate = cdate
                            lastDate = cdate
                        }else if fdate<firstDate!{
                            firstDate = fdate
                        }else if fdate > lastDate!{
                            lastDate = fdate
                        }
                    }
                    
                    
                    if model.daysWithVideos.contains(eventDay) == false {
                        model.daysWithVideos.append(eventDay)
                    }
                    
                    
                    let nameParts = file.components(separatedBy: "_")
                    let srcPath = videoRoot.appendingPathComponent(file)
                    
                    var nsImage = ""
                    
                    //let nsi = srcPath.generateThumbnail()
                    let thumbPath = srcPath.path.replacingOccurrences(of: "."+ext, with: ".png")
                    
                    if FileManager.default.fileExists(atPath: thumbPath) {
                        nsImage = thumbPath
                        
                    }
                    
                    var name = nameParts[0]
                    if let cam = camera{
                        name = cam.getDisplayName()
                    }
                    
                    //print("EventDataSrc:matched",file,camera!.getStringUid(),camera!.name,name)
                   
                    
                    var cardData = CardData(image: nsImage, name: name, date: eventTime,filePath: srcPath)
                    
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
            if firstDate != nil{
                
                //sort each day with videos
                for d in model.daysWithVideos {
                    print("Events day with video",d)
                    if let cdat = model.daysToVideoData[d]{
                    
                        model.daysToVideoData[d] =  cdat.sorted {
                        $0.date.timeIntervalSince1970 < $1.date.timeIntervalSince1970
                     }
                    }
                }
                
                model.daysWithVideos.sort{
                    $0.timeIntervalSince1970 > $1.timeIntervalSince1970
                }
           
                print("Events date range",firstDate,lastDate)
                
                recordRange.setLocalRange(firstDate!, lastDate!)
                
                for (date,data) in model.daysToVideoData {
                    for card in data{
                        var rt = RecordToken()
                        //set values to map card to recordToken
                        rt.card = card
                        rt.cameraName = card.name//camera!.getDisplayName()
                        rt.Token = "LOCAL"
                        rt.fileDate = card.date
                        rt.localFilePath = card.filePath.path
                        rt.ReplayUri = rt.localFilePath
                        recordTokens.append(rt)
                    }
                }
                
                print("EventsAndVideoDataSource range",firstDate,lastDate)
            }else{
                print("EventsAndVideoDataSource nothing found")
            }
            
        }catch{
            print("\(error)")
        }
        print("EventsAndVideoDataSource count",model.daysToVideoData.count)
        
        return model.daysToVideoData.count
    }
    func dateTimeFromFileString(dateStr: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        dateFormatter.timeZone = NSTimeZone.default
        return dateFormatter.date(from: dateStr)
    }
    func dayFromFileString(dateStr: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        
        let dateOnly = dateStr.substring(to: 8)
        
        return dateFormatter.date(from: dateOnly)
        
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
