//
//  SDcardStatsFactory.swift
//  TestMacUI
//
//  Created by Philip Bishop on 07/01/2022.
//

import Foundation

struct DayStat{
    var hourOfDay = 0
    var count = 0
    var percentOfMax = 0.0
    var percentOfDay = 0.0
}

class EventDayStat{
    var count = 0
    var percentOfMax = 0.0
    var percentOfAllDays = 0.0
    var label = ""
}

class SDCardStatsFactory{
    
    var cachedItems = [RecordToken]()
    var dayStats = [DayStat]()
    var itemsPerDay = [Date:[RecordToken]]()
    var eventDayStats = [EventDayStat]()
    var storageType = StorageType.onboard
    
    func analyzeCache(cameraUid: String,profileToken: String,storageType: StorageType){
        self.storageType = storageType
        cachedItems.removeAll()
        loadFromCache(cameraUid: cameraUid,profileToken: profileToken)
        calculatByHourStats()
        calculateEventDayStats()
        
    }
    private func calculateEventDayStats(){
       
        let frmt = DateFormatter()
        frmt.dateFormat="yyyy-MM-dd"
        
        var totalEvents =  cachedItems.count
        var maxOnDay = 0.0
        
        for (date,events) in itemsPerDay{
            maxOnDay = max(maxOnDay,Double(events.count))
            
            let es = EventDayStat()
            es.count =  events.count
            es.label = frmt.string(from: date)
            eventDayStats.append(es)
        }
        
        //now set the percent and relative
        
        for es in eventDayStats{
            es.percentOfMax = ( Double(es.count) / maxOnDay ) * 100
            es.percentOfAllDays = ( Double(es.count) / Double(totalEvents) ) * 100
        }
        
        
    }
    private func calculatByHourStats(){
        var counts = [Int]()
        for i in 0...23{
            counts.append(0)
        }
       
        for rt in cachedItems{
            
            let dt = rt.getTime()
            let sd = Calendar.current.startOfDay(for: dt!)
            if itemsPerDay[sd] == nil{
                itemsPerDay[sd] = [RecordToken]()
            }
            itemsPerDay[sd]!.append(rt)
            
            let hod = Calendar.current.component(.hour, from: dt!)
            counts[hod] = counts[hod] + 1
            
        }
        
        var maxCount = 0.0
        var totalCount = 0.0
        for count in counts{
            totalCount = totalCount + Double(count)
            maxCount = max(maxCount,Double(count))
        }
        
        var barLevels = [Double]()
        var dayLevels = [Double]()
        for i in 0...23{
            let relVal = (Double(counts[i]) / maxCount ) * 100
            barLevels.append(relVal)
            
            let dayLevel = (Double(counts[i]) / totalCount ) * 100
            dayLevels.append(dayLevel)
        }
       
        dayStats.removeAll()
        for i in 0...23{
            let dayStat = DayStat(hourOfDay: i, count: counts[i],percentOfMax: barLevels[i],percentOfDay: dayLevels[i])
            dayStats.append(dayStat)
        }
    }
    private func loadFromCache(cameraUid: String,profileToken: String){
        let sdCache = FileHelper.getSdCardStorageRoot()
        do {
             let files = try FileManager.default.contentsOfDirectory(atPath: sdCache.path)
            if  files.count == 0 {
                return
            }
            //iterate and find most recent video
            for i in 0...files.count-1 {
                let file = files[i]
                //get file ext, might not be MP4
                let parts = file.components(separatedBy: ".")
                let ext = parts[parts.count-1]
                
                if ext != "csv"{
                    continue
                }
                if file.hasPrefix(cameraUid) == false{
                    continue
                }
                
                let isFtp = file.contains("_ftp")
                
                if storageType == .ftp && isFtp == false{
                    continue
                }
                if storageType == .onboard && isFtp{
                    continue
                }
                
                let fparts = file.components(separatedBy: "_")
                let dstr = fparts[fparts.count-1].replacingOccurrences(of: ".csv", with: "")
                
                print("Found cache item",cameraUid,dstr)
                
                let filePath = sdCache.appendingPathComponent(file)
                do{
                    
                    let csvData = try Data(contentsOf: filePath)
                    let allLines = String(data: csvData, encoding: .utf8)!
                    let lines = allLines.components(separatedBy: "\n")
                    for line in lines{
                        if line.isEmpty{
                            continue
                        }
                        let rt = RecordToken()
                        if storageType != .onboard{
                            rt.fromFtpCsv(line: line)
                            let localFile = StorageHelper.getLocalFilePath(remotePath: rt.ReplayUri)
                            if localFile.1{
                                rt.localFilePath = localFile.0.path
                            }
                        }else{
                            rt.fromCsv(line: line)
                        
                            if profileToken.isEmpty == false && rt.Token != profileToken{
                                continue
                            }
                        }
                        cachedItems.append(rt)
                    }
                }catch{
                    print("Failed to load recording events CSV",filePath)
                }
            }
        }catch{
            print("SDCardStatsFactory:analyzeCache FAILED")
        }
    }
    
}
