//
//  RecordingsParser.swift
//  NX-V
//
//  Created by Philip Bishop on 07/09/2021.
//

import Foundation

class RecordingsXmlParser : NSObject, XMLParserDelegate{
    
    var recordTokens = [String]()
    var isCollecting = false
    var searchState = ""
    var isCollectingState = false
    var currentString = ""
    func parseRespose(xml: Data){
        let parser = XMLParser(data: xml)
        parser.delegate = self
        parser.parse()
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
    
        if elementName == "tt:RecordingToken"{
            isCollecting = true
            isCollectingState = false
        }else if elementName.hasSuffix(":SearchState"){
            isCollecting = false
            currentString = ""
            isCollectingState = true
        }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if(isCollecting || isCollectingState){
            currentString += string
        }
    }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        
        if(isCollecting){
            recordTokens.append(currentString)
            isCollecting = false
            currentString = ""
        }else if isCollectingState{
            searchState = currentString
            isCollectingState = false
            currentString = ""
        }
    }
}

class RecordingsResultsParser: NSObject, XMLParserDelegate{

    var resultTag = ":RecordingInformation"
    var recordTag = ":RecordingToken"
    var earliestTag = ":EarliestRecording"
    var latestTag = ":LatestRecording"

    var result = RecordProfileToken()
    var allResults = [RecordProfileToken]()
    
    func hasResult() -> Bool {
        return allResults.count > 0
    }
    
    var foundFirst = false
    var isCollecting = false
    var fieldId = -1
    var currentString = ""
    
    func parseRespose(xml: Data){
        let parser = XMLParser(data: xml)
        parser.delegate = self
        parser.parse()
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
    
        if !foundFirst && elementName.contains(resultTag){
            foundFirst = true
            
        }
        else if foundFirst{
            if elementName.contains(recordTag){
                fieldId = 0
                isCollecting = true
            }else if elementName.contains(earliestTag){
                fieldId = 1
                isCollecting = true
            }else if elementName.contains(latestTag){
                fieldId = 2
                isCollecting = true
            }
        }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if(isCollecting){
            currentString += string
        }
    }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        
        if(isCollecting){
            
            switch(fieldId){
            case 0:
                //result.recordingToken = currentString
                break;
            case 1:
                result.earliestRecording = currentString
                break;
            case 2:
                result.latestRecording = currentString
                break;
            default:
                break
            }
            
            isCollecting = false
            currentString = ""
            
            if result.isComplete(){
                allResults.append(result)
                result = RecordProfileToken()
            }
        }
    }
}
