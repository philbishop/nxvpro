//
//  SystemDateTimeParse.swift
//  NX-V PRO
//
//  Created by Philip Bishop on 25/03/2022.
//

import Foundation

class SystemDateTimeParser{
    
    var type = "Manual"
    var daylighSaving = false
    var tz = "GMT+0:00:00"
    let keys = ["Year", "Month", "Day", "Hour", "Minute", "Second"]
    var vals = ["","","","","",""]
    var sysDateTime = Date()
    var hasDateTime = false
    
    func parseRespose(xml: Data){
        let separator = "!"
        let xmlParser = XmlPathsParser(tag: ":GetSystemDateAndTimeResponse",separator: separator)
        xmlParser.parseRespose(xml: xml)
        for path in xmlParser.itemPaths{
            let parts = path.components(separatedBy: separator)
            if parts.count == 3{
                let p1 = parts[1]
                if p1.hasSuffix(":DateTimeType"){
                    type = parts[2]
                }else if p1.hasSuffix(":DaylightSavings"){
                    daylighSaving = parts[2] == "true"
                }
            }else if parts.count == 4{
                if parts[2].hasSuffix(":TZ"){
                    tz = parts[3].replacingOccurrences(of: "\n", with: "")
                }
            }else if parts.count == 5{
                let p3 = parts[3]
                for i in 0...keys.count-1{
                    if p3.hasSuffix(":"+keys[i]){
                        vals[i] = parts[4].trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    }
                }
            }
        }
        hasDateTime = vals[0].isEmpty == false
        if hasDateTime{
            //create date and assign to camera
            var components = DateComponents()
            components.year = Int(vals[0])
            components.month = Int(vals[1])
            components.day = Int(vals[2])
            components.hour = Int(vals[3])
            components.minute = Int(vals[4])
            components.second = Int(vals[5])
            
            sysDateTime = Calendar.current.date(from: components)!
            
        }
    }
    
    /*
     tds:SystemDateAndTime/tt:DateTimeType/Manual
     tds:SystemDateAndTime/tt:DaylightSavings/false
     tds:SystemDateAndTime/tt:TimeZone/tt:TZ/GMT+0:00:00
     tds:SystemDateAndTime/tt:UTCDateTime/tt:Time/tt:Hour/7
     tds:SystemDateAndTime/tt:UTCDateTime/tt:Time/tt:Minute/17
     tds:SystemDateAndTime/tt:UTCDateTime/tt:Time/tt:Second/20
     tds:SystemDateAndTime/tt:UTCDateTime/tt:Date/tt:Year/2022
     tds:SystemDateAndTime/tt:UTCDateTime/tt:Date/tt:Month/3
     tds:SystemDateAndTime/tt:UTCDateTime/tt:Date/tt:Day/25
     tds:SystemDateAndTime/tt:LocalDateTime/tt:Time/tt:Hour/7
     tds:SystemDateAndTime/tt:LocalDateTime/tt:Time/tt:Minute/17
     tds:SystemDateAndTime/tt:LocalDateTime/tt:Time/tt:Second/20
     tds:SystemDateAndTime/tt:LocalDateTime/tt:Date/tt:Year/2022
     tds:SystemDateAndTime/tt:LocalDateTime/tt:Date/tt:Month/3
     tds:SystemDateAndTime/tt:LocalDateTime/tt:Date/tt:Day/25
     */
}
