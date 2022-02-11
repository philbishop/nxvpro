//
//  ImagingParser.swift
//  NX-V
//
//  Created by Philip Bishop on 29/12/2021.
//

import Foundation
class XmlPathsParser : NSObject, XMLParserDelegate{
    func parseRespose(xml: Data){
        
        let parser = XMLParser(data: xml)
        parser.delegate = self
        parser.parse()
    }
    var attrTag = ""
    var firstTag = ":ImagingSettings"
   
    var foundFirst = false
    var isCollecting = false
    var currentStr = ""
   
    init(tag: String){
        self.firstTag = tag
    }
    
    var attribStack = [String]()
    var elementStack = [String]()
    //MARK: Flat xml paths
    var itemPaths = [String]()
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if foundFirst{
            elementStack.append(elementName)
            if attrTag.isEmpty == false{
                if let token = attributeDict[attrTag]{
                    attribStack.append(token)
                    //print(token)
                }
            }
            isCollecting = true
        }  else if(elementName.contains(firstTag)){
            foundFirst = true
        }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if(isCollecting && string.isEmpty == false && string != "\n"){
            currentStr += string
        }
    }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
       
        if elementStack.count > 0 {
            
            var es = ""
            for el in elementStack {
                es = es + el + "/"
            }
            es = es + currentStr
            
            if currentStr.isEmpty == false{
                print(es)
                itemPaths.append(es)
            }
        
            elementStack.removeLast()
        }
        currentStr = ""
        isCollecting = false
        
    }
    
    func getKeyValuePair(xpath: String) -> [String]{
        
        let parts = xpath.components(separatedBy: "/")
        if parts.count == 2{
            let nparts = parts[0].components(separatedBy: ":")
            return [nparts[1],parts[1]]
        }
        
        return [String]()
    }
}
