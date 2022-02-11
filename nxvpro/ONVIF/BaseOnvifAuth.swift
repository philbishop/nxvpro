//
//  BaseOnvifAuth.swift
//  NX-V
//
//  Created by Philip Bishop on 21/01/2022.
//

import Foundation

class BaseOnvifAuth{
    var soapHeader = "soap_header"
    
    init(){
        soapHeader = getXmlPacket(fileName: soapHeader)
    }
    
    func getXmlPacket(fileName: String) -> String{
        if let filepath = Bundle.main.path(forResource: fileName, ofType: "xml") {
            do {
                let contents = try String(contentsOfFile: filepath)
                return contents
            } catch {
                print("Failed to load XML from bundle",fileName)
            }
        }
        return ""
    }
    
    func addAuthHeader(camera: Camera,soapPacket: String) -> String{
         if camera.password.isEmpty {
            return soapPacket
        }
        //camera.connectTime = Date()
        
        var sp = ""
        let auth = OnvifAuth(password: camera.password, cameraTime: camera.connectTime)
        
        sp = String(utf8String: soapHeader.cString(using: .utf8)!)!
        sp = sp.replacingOccurrences(of: "_USERNAME_", with: camera.user)
        sp = sp.replacingOccurrences(of: "_PWD_DIGEST_", with: auth.passwordDigest)
        sp = sp.replacingOccurrences(of: "_NONCE_", with: auth.nonce64)
        sp = sp.replacingOccurrences(of: "_TIMESTAMP_", with: auth.creationTime)
        
        var packetWithAuth = "";//"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        
        
        let cleanSoapPacket = soapPacket.replacingOccurrences(of: "\r\n",with: "\n")
        let lines = cleanSoapPacket.components(separatedBy: "\n");
        packetWithAuth += lines[0]//.trimmingCharacters(in: CharacterSet.newlines)
        packetWithAuth += "\n"
        packetWithAuth += sp
        for i in 1...lines.count-1{
            packetWithAuth += lines[i]//.trimmingCharacters(in: CharacterSet.newlines)
            packetWithAuth += "\n"
        }
        return packetWithAuth
    }
    
    //MARK: Save XML
    func saveSoapPacket(endpoint: URL, method: String,xml: String) -> URL{
        
        let host = endpoint.host!
        var port = "80"
        if endpoint.port != nil{
            port = String(endpoint.port!)
        }
        let filename = host + "_" + port + "_" + method+".xml"
        let pathComponent = FileHelper.getPathForFilename(name: filename)
        
        do {
            try xml.write(to: pathComponent, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            // failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
            print("FAILED TO SAVE",pathComponent.path)
        }
        
        return pathComponent
    }
}
