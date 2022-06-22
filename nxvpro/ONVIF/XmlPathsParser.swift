//
//  ImagingParser.swift
//  NX-V
//
//  Created by Philip Bishop on 29/12/2021.
//

import Foundation

class XmlAttribsParser : NSObject, XMLParserDelegate{
    
    func parseRespose(xml: Data){
        
        let parser = XMLParser(data: xml)
        parser.delegate = self
        parser.parse()
    }
    var firstTag = ":System"
   
    
    var attribs = [String:String]()
    
    init(tag: String){
        self.firstTag = tag
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if(elementName.contains(firstTag)){
            for (key,value) in attributeDict{
                attribs[key] = value
            }
            
        }
    }
    
}

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
   
    var pathSeparator: String
    
    init(tag: String,separator: String = "/"){
        self.firstTag = tag
        self.pathSeparator = separator
    }
    
    var attribStack = [String]()
    var attribKeyStack = [String]()
    var attribPaths = [String]()
    
    var elementStack = [String]()
    //MARK: Flat xml paths
    var itemPaths = [String]()
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if foundFirst{
            elementStack.append(elementName)
            
            if attrTag.isEmpty == false{
                if let token = attributeDict[attrTag]{
                    attribKeyStack.append(elementName)
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
            currentStr += string.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        }
    }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
       
        if elementStack.count > 0 {
            
            var es = ""
            for el in elementStack {
                es = es + el + pathSeparator
            }
            es = es + currentStr
            
            if currentStr.isEmpty == false{
                //print(es)
                itemPaths.append(es)
            }
        
            elementStack.removeLast()
        }
        currentStr = ""
        isCollecting = false
        
    }
    
    func getKeyValuePair(xpath: String) -> [String]{
        
        let parts = xpath.components(separatedBy: "/")
        if parts.count >= 2{
            let nparts = parts[0].components(separatedBy: ":")
            if nparts.count > 1{
                return [nparts[1],parts[1]]
            }
        }
        
        return [String]()
    }
    
    func dumpPaths(){
        print(">>>XmlParser:"+firstTag)
        for path in itemPaths{
            print(path)
        }
        if attribStack.count>0{
            print("<<<ATTRIBS>>")
            for i in 0...attribStack.count-1{
                print(i,attribKeyStack[i],attribStack[i])
            }
        }
        print("<<<XmlParser:"+firstTag)
    }
}
