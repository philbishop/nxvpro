//
//  ProfileVideoSourceParser.swift
//  NXV-IOS
//
//  Created by Philip Bishop on 02/01/2022.
//

import Foundation

class ProfileVideoSourceParser : NSObject, XMLParserDelegate{
    var firstTag = ":VideoSourceConfiguration"
    var token: String = ""
    private var srcId: String = ""
    
    func getVideoSourceId() -> String{
        return srcId + "_" + token
    }
    

    
    func parseRespose(xml: Data){
        let parser = XMLParser(data: xml)
        parser.delegate = self
        parser.parse()
    }
    
    var currentStr = ""
    var isCollecting  = false;
    var foundFirst = false
    var tagFound = false
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        
        if token.isEmpty {
            if foundFirst && elementName.contains(":SourceToken"){
                isCollecting = true
            
            }else if(elementName.contains(self.firstTag)){
                foundFirst = true
                srcId = attributeDict["token"]!
            }
                //srcId = attributeDict["token"]!;
                //tagFound = true
                //isCollecting=true
            //}
        }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if(isCollecting && string != "\n"){
            currentStr += string
        }
    }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        
        if(isCollecting){
            token = currentStr
            isCollecting = false
        }
    }
}
