//
//  OnvifImagingParser.swift
//  TestMacUI
//
//  Created by Philip Bishop on 04/01/2022.
//

import Foundation
import SwiftUI

class ImagingType : Hashable{
    
    var id: Int = 0
    var name: String
    var xmlName: String
    
    init(name: String,xmlName: String){
        self.name = name
        self.xmlName = xmlName
    }
    func dump(){
        preconditionFailure("ImagingType:dump must be overridden")
    }
  
    func xmlRep(indent: String) -> String{
        preconditionFailure("ImagingType:dump must be overridden")
    }
    
    static func == (lhs: ImagingType, rhs: ImagingType) -> Bool {
        return lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(xmlName)
  
    }
}

class MinMaxImagingType : ImagingType{
    var min: Double = 0.0
    var max: Double = 0.0
    var value: Double = 0.0
    
    
    override func dump(){
        print(id,xmlName,name,min,max,value)
    }
    
    override func xmlRep(indent: String) -> String {
        let val = Int(round(value))
        return String(format: "<%@ xmlns=\"http://www.onvif.org/ver10/schema\">%@</%@>", name,String(val),name)
    }
}

class ModeImagingType : ImagingType{
    var modes = [String]()
    var mode: String = ""
    
    override func dump(){
        print(id,xmlName,name,modes,mode)
    }
    override func xmlRep(indent: String) -> String {
        return String(format: "<%@ xmlns=\"http://www.onvif.org/ver10/schema\"><Mode>%@</Mode></%@>", name,mode,name)
    }
}
class FocusImagingType : ModeImagingType{
    
    static var TypeName = "Focus"
    
    //required defaults for switching modes
    var defaultSpeed = "1"
    var nearLimit = "0"
    var farLimit = "0"
  
    var defaultSpeedMin = ""
    var defaultSpeedMax = ""
    var nearLimitMin = ""
    var nearLimitMax = ""
    var farLimitMin = ""
    var farLimitMax = ""
    
    func consume(path: [String]) -> Bool{
       
        
        /*
         tt:Focus/tt:AutoFocusMode/AUTO
         tt:Focus/tt:NearLimit/0
         tt:Focus/tt:FarLimit/0
         tt:Focus/tt:AutoFocusMode/MANUAL
         tt:Focus/tt:DefaultSpeed/1.000000
         */
        if path.count == 3{
            if path[1].contains(":AutoFocusMode"){
                modes.append(path[2])
            }
        }else{
           comsumeRnage(path: path)
        }
        return true
    }
    func consumeSetting(path: [String]){
        
        if path[1].contains(":AutoFocusMode"){
            mode = path[2]
        }else if path[1].contains(":DefaultSpeed"){
            defaultSpeed  = path[2]
        }else if path[1].contains(":NearLimit"){
            nearLimit  = path[2]
        }else if path[1].contains(":FarLimit"){
            farLimit  = path[2]
        }
    }
    private func comsumeRnage(path: [String]){
        /*
         tt:Focus/tt:AutoFocusModes/AUTO
         tt:Focus/tt:AutoFocusModes/MANUAL
         tt:Focus/tt:DefaultSpeed/tt:Min/1
         tt:Focus/tt:DefaultSpeed/tt:Max/1
         tt:Focus/tt:NearLimit/tt:Min/0
         tt:Focus/tt:NearLimit/tt:Max/0
         tt:Focus/tt:FarLimit/tt:Min/0
         tt:Focus/tt:FarLimit/tt:Max/0
         */
        
        if path[1].contains(":DefaultSpeed"){
            
            if path[2].contains("Min"){
                defaultSpeedMin  = path[3]
            }else if path[2].contains("Max"){
                defaultSpeedMax  = path[3]
            }
        }else if path[1].contains(":NearLimit"){
            if path[2].contains("Min"){
                nearLimitMin  = path[3]
            }else if path[2].contains("Max"){
                nearLimitMax  = path[3]
            }
        }else if path[1].contains(":FarLimit"){
            if path[2].contains("Min"){
                farLimitMin  = path[3]
            }else if path[2].contains("Max"){
                farLimitMax  = path[3]
            }
        }
    
    }
    override func dump(){
        print(id,xmlName,name,mode,defaultSpeed,nearLimit,farLimit)
        
    }
    override func xmlRep(indent: String) -> String {
        if mode.isEmpty{
            return ""
        }
        /*
         <Focus>
               <AutoFocusMode>       MANUAL
                                     </AutoFocusMode>
                                 <DefaultSpeed>
                                     1
                                     </DefaultSpeed>
                                 <NearLimit>
                                     1
                                     </NearLimit>
                                 <FarLimit>
                                     1
                                     </FarLimit>
                                 </Focus>
         */
        
        var buf = ""
        
        buf.append(String(format: "<%@ xmlns=\"http://www.onvif.org/ver10/schema\">", name))
        
        buf.append("\n")

        var keys = ["AutoFocusMode","DefaultSpeed","NearLimit","FarLimit"]
        var vals = [mode,defaultSpeed,nearLimit,farLimit]
        
        if mode == "AUTO"{
            keys = ["AutoFocusMode","DefaultSpeed"]
            vals = [mode,defaultSpeed]
        }
        
        for i in 0...keys.count-1{
            buf.append(indent)
            buf.append(String(format: "<%@>%@</%@>", keys[i], String(vals[i]),keys[i]))
            buf.append("\n")
        }
        
        //last line
        buf.append(indent)
        buf.append(String(format: "</%@>", name))
        
        return buf
    }
    
}
class IrCutFilterModeImagingType : ModeImagingType{
    static var TypeName = "IrCutFilterModes"
    static var ValueName = "IrCutFilter"
    
    func consume(path: [String]) -> Bool{
        if name == IrCutFilterModeImagingType.TypeName{
        
            /*
             tt:IrCutFilterModes/ON
             tt:IrCutFilterModes/OFF
             tt:IrCutFilterModes/AUTO
             */
            
            if path.count == 2{
                modes.append(path[1])
            }
            
            return true
        }
        
        return false
    }
    override func xmlRep(indent: String) -> String {
        return String(format: "<%@ xmlns=\"http://www.onvif.org/ver10/schema\">%@</%@>", name,mode,name)
    }
    func consumeSetting(path: [String]){
        /*
         t:IrCutFilter/AUTO
         */
        if path[0].contains(IrCutFilterModeImagingType.ValueName){
            mode = path[1]
        }
    }
    
}

class ExposureImagingType : ImagingType{
    static var TypeName = "Exposure"
    
    var modes = [String]()
    var mode: String = ""
    var minExposureTimeMin = 0.0
    var minExposureTimeMax = 0.0
    
    var maxExposureTimeMin = 0.0
    var maxExposureTimeMax = 0.0
   
    var minGainMin = 0.0
    var minGainMax = 0.0
    
    var maxGainMin = 0.0
    var maxGainMax = 0.0
    
    var minExposureTime = 0.0
    var maxExposureTime = 0.0
    var minGain = 0.0
    var maxGain = 0.0

    var minIris = 0.0
    var maxIris = 0.0
    
    //MARK: Exposure display factor
    var exposureDivider = 1.0
    var irisOffset = 0.0
    
    func calcExposureAndIrisForUi(){
       
        /*
        if maxExposureTime > 1000000{
            exposureDivider = 1000000
        }else if maxExposureTime > 100000{
            exposureDivider = 100000
        }else if maxExposureTime > 10000{
            exposureDivider = 10000
        }else if maxExposureTime > 1000{
            exposureDivider = 1000
        }
        
        minExposureTime /= exposureDivider
        maxExposureTime /= exposureDivider
        exposureTime /= exposureDivider
         */
       /*
        if minIris < 0{
            irisOffset = abs(minIris)
            
            maxIris += irisOffset
            minIris += irisOffset
            iris += irisOffset
        }
        */
    }
    //MARK: actual values
    var exposureTime = 0.0
    var gain = 0.0
    var iris = 0.0
    
    func supportsExposure() -> Bool{
        if modes.count < 2{
            return false
        }
        return (maxExposureTime - minExposureTime) != 0
    }
    func supportsGain() -> Bool{
        return (maxGain - minGain) != 0
    }
    func supportsIris() -> Bool{
        return (maxIris - minIris) != 0
    }
    override func xmlRep(indent: String) -> String {
        var buf = ""
        
        //first line indented by caller
        buf.append(String(format: "<%@ xmlns=\"http://www.onvif.org/ver10/schema\"><Mode>%@</Mode>", name, mode,name))
        buf.append("\n")

        let keys = ["MinExposureTime","MaxExposureTime","MinGain","MaxGain","ExposureTime","Gain","Iris"]
        let vals = [minExposureTime * exposureDivider,maxExposureTime * exposureDivider,minGain,maxGain,exposureTime * exposureDivider,gain,iris + (irisOffset * -1)]
        
        for i in 0...keys.count-1{
            buf.append(indent)
            buf.append(String(format: "<%@>%@</%@>", keys[i], String(vals[i]),keys[i]))
            buf.append("\n")
        }

        //last line
        buf.append(indent)
        buf.append(String(format: "</%@>", name))
        return buf
    }
    
    func consume(path: [String]) -> Bool{
        if name == ExposureImagingType.TypeName{
        /*
         tt:Exposure/tt:Mode/AUTO
         tt:Exposure/tt:MinExposureTime/tt:Min/10
         tt:Exposure/tt:MinExposureTime/tt:Max/10
         tt:Exposure/tt:MaxExposureTime/tt:Min/10
         tt:Exposure/tt:MaxExposureTime/tt:Max/320000
         tt:Exposure/tt:MinGain/tt:Min/0
         tt:Exposure/tt:MinGain/tt:Max/0
         tt:Exposure/tt:MaxGain/tt:Min/0
         tt:Exposure/tt:MaxGain/tt:Max/100
         tt:Exposure/tt:Mode/MANUAL
         
         tt:Exposure/tt:Iris/tt:Min/-1
         tt:Exposure/tt:Iris/tt:Max/1
        tt:Exposure/tt:Iris/1.000000
         
         */
            if path[1].contains("Mode"){
                modes.append(path[2])
            }else if path[1].contains("MinExposureTime"){
                if path[2].contains("Min"){
                    minExposureTimeMin = Double(path[3])!
                }else{
                    minExposureTimeMax = Double(path[3])!
                }
            }else if path[1].contains("MaxExposureTime"){
                if path[2].contains("Min"){
                    maxExposureTimeMin = Double(path[3])!
                }else{
                    maxExposureTimeMax = Double(path[3])!
                }
            }else if path[1].contains("MinGain"){
                if path[2].contains("Min"){
                    minGainMin = Double(path[3])!
                }else{
                    minGainMax = Double(path[3])!
                }
            }else if path[1].contains("MaxGain"){
                if path[2].contains("Min"){
                    maxGainMin = Double(path[3])!
                }else{
                    maxGainMax = Double(path[3])!
                }
            }else if path[1].contains("Iris"){
                if path[2].contains("Min"){
                    minIris = Double(path[3])!
                }else if path[2].contains("Max"){
                    maxIris = Double(path[3])!
                }
            }
            
            return true
        }
        
        return false
    }
    func consumeSetting(path: [String]){
        /*
         tt:Exposure/tt:Mode/AUTO
         tt:Exposure/tt:MinExposureTime/10
         tt:Exposure/tt:MaxExposureTime/32998
         tt:Exposure/tt:MinGain/0
         tt:Exposure/tt:MaxGain/49
         gain
         expoureTime
         iris
         */
        let val = path[2]
        if path[1].contains("Mode"){
            mode = val
        }else if path[1].contains("MinExposureTime"){
            minExposureTime = Double(val)!
        }else if path[1].contains("MaxExposureTime"){
            maxExposureTime = Double(val)!
        }else if path[1].contains("MinGain"){
            minGain = Double(val)!
        }else if path[1].contains("MaxGain"){
            maxGain = Double(val)!
        }else if path[1].contains("ExposureTime"){
            exposureTime = Double(val)!
        }else if path[1].contains("Gain"){
            gain = Double(val)!
        }else if path[1].contains("Iris"){
            iris = Double(val)!
        }
    }
    
    override func dump(){
        let props = [minExposureTimeMin,minExposureTimeMax,maxExposureTimeMin,maxExposureTimeMin,minGainMin,minGainMax,maxGainMin,maxGainMax]
        print(id,xmlName,name,modes,mode,props,minExposureTime,maxExposureTime,minGain,maxGain)
    }
}
class WhiteBalanceImagingType : ImagingType{
    
    static var TypeName = "WhiteBalance"
    
    var modes = [String]()
    var mode: String = ""
    var yrGainMin = 0.0
    var yrGainMax = 0.0
    var ybGainMin = 0.0
    var ybGainMax = 0.0
    
    var crGain = 0.0
    var cbGain = 0.0
    
    override func xmlRep(indent: String) -> String {
        var buf = ""
        
        //first line indented by caller
        buf.append(String(format: "<%@ xmlns=\"http://www.onvif.org/ver10/schema\">", name))
        buf.append("\n")
        buf.append(indent)
        buf.append(String(format: "<Mode>%@</Mode>",mode))
        buf.append("\n")
        
        let keys = ["CrGain","CbGain"]
        let vals = [crGain,cbGain]
        
        for i in 0...keys.count-1{
            buf.append(indent)
            buf.append(String(format: "<%@>%@</%@>", keys[i], String(vals[i]),keys[i]))
            buf.append("\n")
        }

        //last line
        buf.append(indent)
        buf.append(String(format: "</%@>", name))
        return buf
    }
    
    func consume(path: [String]) -> Bool{
        if name == "WhiteBalance"{
            /*
             tt:WhiteBalance/tt:Mode/AUTO
             tt:WhiteBalance/tt:Mode/MANUAL
             tt:WhiteBalance/tt:YrGain/tt:Min/0
             tt:WhiteBalance/tt:YrGain/tt:Max/100
             tt:WhiteBalance/tt:YbGain/tt:Min/0
             tt:WhiteBalance/tt:YbGain/tt:Max/100
             */
            if path[1].contains("Mode"){
                modes.append(path[2])
            }else if path[1].contains("YrGain"){
                if path[2].contains("Min"){
                    yrGainMin = Double(path[3])!
                }else if path[2].contains("Max"){
                    yrGainMax = Double(path[3])!
                }
            }else if path[1].contains("YbGain"){
                if path[2].contains("Min"){
                    ybGainMin = Double(path[3])!
                }else if path[2].contains("Max"){
                    ybGainMax = Double(path[3])!
                }
            }
            return true
        }
        
        return false
    }
    func consumeSetting(path: [String]){
        /*
         tt:WhiteBalance/tt:Mode/MANUAL
         tt:WhiteBalance/tt:CrGain/51
         tt:WhiteBalance/tt:CbGain/51
         */
        if path[1].contains("Mode"){
            mode = path[2]
        }else if path[1].contains("CrGain"){
            crGain = Double(path[2])!
        }else if path[1].contains("CbGain"){
            cbGain = Double(path[2])!
        }
    }
    
    override func dump(){
        print(id,xmlName,name,modes,mode,yrGainMin,yrGainMax,ybGainMin,ybGainMax,crGain,cbGain)
    }
}
class WideDynamicRangeImagingType : ImagingType{
    
    static var TypeName = "WideDynamicRange"
    
    var modes = [String]()
    var mode: String = ""
    var minLevel: Double = 0.0
    var maxLevel: Double = 0.0
    var level: Double = 0.0
    
    func hasRange() -> Bool{
        return maxLevel - minLevel != 0
    }
    
    override func xmlRep(indent: String) -> String {
        var buf = ""
        
        //first line indented by caller
        buf.append(String(format: "<%@ xmlns=\"http://www.onvif.org/ver10/schema\">", name))
        buf.append("\n")
        buf.append(indent)
        buf.append(indent)
        
        buf.append(String(format: "<Mode>%@</Mode>",mode))
        buf.append("\n")
        
        if level != 0{
        
            let keys = ["Level"]
            let vals = [level]
            
            for i in 0...keys.count-1{
                buf.append(indent)
                buf.append(indent)
                buf.append(String(format: "<%@>%@</%@>", keys[i], String(vals[i]),keys[i]))
                buf.append("\n")
            }
        }
        //last line
        buf.append(indent)
        buf.append(String(format: "</%@>", name))
        return buf
    }
    
    func consume(path: [String]) -> Bool{
        if name == "WideDynamicRange" || name ==  "BacklightCompensation"{
            /*
             tt:WideDynamicRange/tt:Mode/ON
             tt:WideDynamicRange/tt:Mode/OFF
             tt:WideDynamicRange/tt:Level/tt:Min/0
             tt:WideDynamicRange/tt:Level/tt:Max/100
             */
            
            if path[1].contains("Mode"){
                modes.append(path[2])
            }else if path[1].contains("Level"){
                if path[2].contains("Min"){
                    minLevel = Double(path[3])!
                }else if path[2].contains("Max"){
                    maxLevel = Double(path[3])!
                }
            }
            return true
        }
        return false
    }
    func consumeSetting(path: [String]){
        /*
         tt:WideDynamicRange/tt:Mode/ON
         tt:WideDynamicRange/tt:Level/89
         */
        if path[1].contains("Mode"){
            mode = path[2]
        }else if path[1].contains("Level"){
            level = Double(path[2])!
        }
    }
    override func dump(){
        print(id,xmlName,name,modes,mode,minLevel,maxLevel,level)
    }
}
class BacklightCompensationImagingType : WideDynamicRangeImagingType{
    static var SubClassTypeName = "BacklightCompensation"
}

class OnvifImagingParser{
    var basicOpts = [ "Brightness", "ColorSaturation", "Contrast", "Sharpness" ]
   
    var optLookup = [String:MinMaxImagingType]()
    var modeLookup = [String:ModeImagingType]()
    
    var backlightCompensation: BacklightCompensationImagingType?
    var wideDynamicRange: WideDynamicRangeImagingType?
    var whiteBalance: WhiteBalanceImagingType?
    var irCutFilter: IrCutFilterModeImagingType?
    var focus: FocusImagingType?
    
    var exposure: ExposureImagingType?
    
    var imagingOpts = [ImagingType]()
    
    func getMinMaxTypeOpt(name: String,xmlName: String) -> MinMaxImagingType?{
        if let mmOpt = optLookup[name]{
            return mmOpt
        }
        for opt in basicOpts{
            if opt == name{
                let mmit = MinMaxImagingType(name: name,xmlName: xmlName)
                optLookup[name] = mmit
                return mmit
            }
        }
        return nil
    }
    
    func getModeTypeOpt(name: String,xmlName: String) -> ModeImagingType?{
        if let mmOpt = modeLookup[name]{
            return mmOpt
        }
        
        return nil
    }
    
    func parseOptions(xml: Data){
        let imagingParser = XmlPathsParser(tag: ":ImagingOptions")
         imagingParser.parseRespose(xml: xml)
         
        let flatXml = imagingParser.itemPaths
        
        for xmlPath in flatXml{
            let path = xmlPath.components(separatedBy: "/")
            let xmlName = path[0]
            let nParts =  xmlName.components(separatedBy: ":")
            let name = nParts[1]
            
            if let mmOpt = getMinMaxTypeOpt(name: name, xmlName: xmlName){
                if path[1].contains(":Min"){
                    let val =  path[2]
                    mmOpt.min = Double(val)!
                }else if path[1].contains(":Max"){
                    let val =  path[2]
                    mmOpt.max = Double(val)!
                }
            }else if let mmOpt = getModeTypeOpt(name: name, xmlName: xmlName){
                if path[1].contains(":Mode"){
                    let val =  path[2]
                    mmOpt.modes.append(val)
                }
            }else{
                if name == WideDynamicRangeImagingType.TypeName{
                    if wideDynamicRange == nil{
                        wideDynamicRange = WideDynamicRangeImagingType(name: name,xmlName: xmlName)
                    }
                    wideDynamicRange!.consume(path: path)
                }else if name == WhiteBalanceImagingType.TypeName{
                    if whiteBalance == nil{
                        whiteBalance = WhiteBalanceImagingType(name: name,xmlName: xmlName)
                    }
                    whiteBalance!.consume(path: path)
                }else if name == IrCutFilterModeImagingType.TypeName{
                    if irCutFilter == nil{
                        irCutFilter = IrCutFilterModeImagingType(name: name,xmlName: xmlName)
                    }
                    irCutFilter!.consume(path: path)
                }else if name == ExposureImagingType.TypeName{
                    if exposure == nil{
                        exposure = ExposureImagingType(name: name,xmlName: xmlName)
                    }
                    exposure?.consume(path: path)
                }else if name == BacklightCompensationImagingType.SubClassTypeName{
                    if backlightCompensation == nil{
                        backlightCompensation = BacklightCompensationImagingType(name: name,xmlName: xmlName)
                    }
                    backlightCompensation!.consume(path: path)
                }else if name ==  FocusImagingType.TypeName{
                    if focus == nil{
                        focus = FocusImagingType(name: name,xmlName: xmlName)
                    }
                    focus!.consume(path: path)
                }
            }
            
            //print(xmlPath)
        }
        
        /*
        print(">> MinMaxTypes:Options <<")
        for (key,mmType) in optLookup{
            mmType.dump()
        }
         */
    }
    
    func psrseSetting(xml: Data){
        let imagingParser = XmlPathsParser(tag: ":ImagingSettings")
         imagingParser.parseRespose(xml: xml)
         
        let flatXml = imagingParser.itemPaths
        
        for xmlPath in flatXml{
            let path = xmlPath.components(separatedBy: "/")
            let xmlName = path[0]
            let nParts =  xmlName.components(separatedBy: ":")
            let name = nParts[1]
            
            if let mmOpt = optLookup[name]{
                
                let val =  path[1]
                mmOpt.value = Double(val)!
                
            }else if let mmOpt = modeLookup[name]{
                
                if path[1].contains(":Mode"){
                    mmOpt.mode = path[2]
                }
                
            }else{
                if name == WideDynamicRangeImagingType.TypeName && wideDynamicRange != nil{
                    wideDynamicRange!.consumeSetting(path: path)
                }else if name == WhiteBalanceImagingType.TypeName && whiteBalance != nil{

                    whiteBalance!.consumeSetting(path: path)
                }else if name == IrCutFilterModeImagingType.ValueName && irCutFilter != nil{
                     irCutFilter!.consumeSetting(path: path)
                }else if name == ExposureImagingType.TypeName && exposure != nil{
                    exposure!.consumeSetting(path: path)
                }else if name == BacklightCompensationImagingType.SubClassTypeName && backlightCompensation != nil{
                    backlightCompensation!.consumeSetting(path: path)
                }else if name == FocusImagingType.TypeName{
                    if focus == nil{
                        //optional focus may not be in options
                        print("OnvifImagingParser:focus has settings no options, creating instance")
                        focus = FocusImagingType(name: name,xmlName: xmlName)
                    }
                    focus?.consumeSetting(path: path)
                }
                
            }
            //print(xmlPath)
        }
        
        print(">> ImagingType;Settings <<")
        for (key,mmType) in optLookup{
            //mmType.dump()
            imagingOpts.append(mmType)
        }
        for (key,mmType) in modeLookup{
            //mmType.dump()
            imagingOpts.append(mmType)
        }
        if backlightCompensation != nil{
            imagingOpts.append(backlightCompensation!)
        }
        if wideDynamicRange != nil{
            imagingOpts.append(wideDynamicRange!)
            //wideDynamicRange!.dump()
            
        }
        if whiteBalance != nil{
            imagingOpts.append(whiteBalance!)
            //whiteBalance!.dump()
        }
        if( irCutFilter != nil){
            imagingOpts.append(irCutFilter!)
            //irCutFilter!.dump()
        }
        if exposure != nil{
            imagingOpts.append(exposure!)
            //exposure!.dump()
        }
        if focus != nil{
            imagingOpts.append(focus!)
        }
        var id = 0
        for iop in imagingOpts{
            iop.id = id
            id += 1
            iop.dump()
        }
    }
}
