//
//  ProfileXmlParser.swift
//  NX-V
//
//  Created by Philip Bishop on 25/05/2021.
//

import Foundation

//ptz
class ZoomRangeProfileXmlParser : NSObject, XMLParserDelegate{

    let firstTag = "tt:ZoomLimits"
    let tokenTags = ["tt:Min","tt:Max"]
    var tokenVals = ["",""]
    var tokenIndex = 0
    var isCollecting = false
    var currentStr = ""
    var foundFirst = false
    var isComplete = false
    
    func parseRespose(xml: Data){
        let parser = XMLParser(data: xml)
        parser.delegate = self
        parser.parse()
    }
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
    
        if isComplete {
            return
        }
        
        //find tokens
        if foundFirst && elementName == tokenTags[tokenIndex] {
            isCollecting = true
            currentStr = ""
        }
        if(elementName.contains(firstTag)){
            print("found",firstTag)
            foundFirst = true
           
        }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if(isCollecting){
            currentStr += string
        }
    }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        
        if(isCollecting){
            tokenVals[tokenIndex] = currentStr
            tokenIndex += 1
            if(tokenIndex == tokenTags.count){
                isComplete = true
                print("ZoomParser complete ")
            }
        }
        isCollecting = false
    }
}
class PtzProfileXmlParser : NSObject, XMLParserDelegate{
    
     var firstTag = ":DefaultPTZSpeed"
    var attsToken = ":PanTilt"
   
    //introduced for HkVision ref: andy.thorton
    var ptzTag = "tt:PTZConfiguration"
    var hasPtzConfig = false
    
    var foundFirst = false
    var ptzXSpeed = ""
    var ptzYSpeed = ""
    
    var hasPtzSpeeds = false
    
    func parseRespose(xml: Data){
        let parser = XMLParser(data: xml)
        parser.delegate = self
        parser.parse()
    }
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
    
        if(hasPtzSpeeds){
            return;
        }
        
        if elementName.hasSuffix(ptzTag){
            hasPtzConfig = true
            ptzXSpeed = "0.5"
            ptzYSpeed = "0.5"
        }
        
        if(foundFirst && elementName.contains(attsToken)){
            ptzXSpeed = attributeDict["x"]!
            ptzYSpeed = attributeDict["y"]!
            hasPtzSpeeds = true
        }
        if(elementName.contains(firstTag)){
            print("found",firstTag)
            foundFirst = true
           
        }
    }
}
class PtzZoomProfileXmlParser : NSObject, XMLParserDelegate{
    
    var firstTag = ":DefaultPTZSpeed"
    var attsToken = ":Zoom"

    //introduced for HkVision ref: andy.thorton
    var ptzTag = "tt:PTZConfiguration"
    var hasPtzConfig = false
    
    var foundFirst = false
    var zoomSpeed = ""
    var hasPtzSpeeds = false
    
    func parseRespose(xml: Data){
        let parser = XMLParser(data: xml)
        parser.delegate = self
        parser.parse()
    }
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
    
        
        if(hasPtzSpeeds){
            return;
        }
        if elementName.hasSuffix(ptzTag){
            hasPtzConfig = true
            zoomSpeed = "1"
        }
        if(foundFirst && elementName.contains(attsToken)){
            zoomSpeed = attributeDict["x"]!
            hasPtzSpeeds = true
        }
        if(elementName.contains(firstTag)){
            print("found",firstTag)
            foundFirst = true
           
        }
    }
}
/*
class ProfileXmlParser : NSObject, XMLParserDelegate{

    var isCollecting = false
    var currentStr = ""
    var profiles = [CameraProfile]()
    var profilesIds = [String]()
    var profilesEncoderIds = [String]()
    
    var videoEncoderConfTokens = [String]()
    
    var tokenIdex = 0
    var firstTag = "trt:Profiles"
    var configTag = "tt:VideoEncoderConfiguration"
    var tokenTags = ["tt:Name","tt:Width","tt:Height"]
    var tokenVals = ["","",""]
    var foundProfile = false;

    func parseRespose(xml: Data){
        //must do this first
        let xmlParser = XmlPathsParser(tag: ":VideoEncoderConfiguration")
        xmlParser.parseRespose(xml: xml)
        for xpath in xmlParser.itemPaths{
            let path = xpath.components(separatedBy: "/")
            if path.count == 2{
                let keyParts = path[0].components(separatedBy: ":")
                if keyParts.count > 1{
                    let key = keyParts[1]
                    let val = path[1]
                    if key == "Name"{
                        videoEncoderConfTokens.append(val)
                        
                    }
                }else{
                    print("Found out of bounds in VideoEncoderConfiguration",path)
                }
            }
        }
        
        let parser = XMLParser(data: xml)
        parser.delegate = self
        parser.parse()
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
        if(profiles.count > 0){
            for i in 0...profiles.count-1{
                
                profiles[i].token = profilesIds[i]
                profiles[i].encoderConfigToken = profilesEncoderIds[i]
                if i < videoEncoderConfTokens.count{
                    profiles[i].videoEncoderConfToken = videoEncoderConfTokens[i]
                }
            }
        }
    }
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
    
        
        if(foundProfile && elementName == tokenTags[tokenIdex]){
            isCollecting = true
        }
        if(elementName == firstTag){
            //print("found",firstTag)
            let id = attributeDict["token"]
            profilesIds.append(id!)
            foundProfile = true
           
        }else if elementName == configTag{
            let id = attributeDict["token"]
            profilesEncoderIds.append(id!)
            
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if(isCollecting){
            currentStr += string
        }
    }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        
        if(isCollecting){
            tokenVals[tokenIdex] = currentStr
            tokenIdex += 1
            if(tokenIdex == tokenTags.count){
                
                //print("Profile complete (phase1)")
                
                let cp = CameraProfile(name: tokenVals[0],resolution: tokenVals[1]+"x"+tokenVals[2]
                                                       ,url: "",snapshotUrl: "")
                profiles.append(cp)
                tokenIdex = 0
                tokenVals = ["","",""]
                foundProfile = false
               
            }
        
            currentStr = ""
            isCollecting = false
        }
    }
}
*/


