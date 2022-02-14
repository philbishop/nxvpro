//
//  OnvifVideoEncoder.swift
//  NX-V
//
//  Created by Philip Bishop on 21/01/2022.
//

import Foundation
import Network
import SwiftUI

class VideoProfile{
    var profileToken = ""
    var name = ""
    var sourceToken = ""
    var encoderToken = ""
    var userCount = ""
    var encoding = "H264" //MUST HAVE
    var videoEncoderConfToken = ""
    var resWidth = ""
    var resHeight = ""
    var quality = ""
    var frameRateRateLimit = ""
    var encodingInterval = ""
    var bitRateLimit = ""
    var govLength = ""
    var h264Profile = ""
    
    //READONLY
    var sessionTimesout = ""
    var port = ""
    var ttl = ""
    var autoStart = ""
    var ipAddressType = ""
    var ip4Addr = ""
    var ip6Addr = ""
   
    var options = VideoProfileOptions()
    
    func populateXmlTemplate(soapPacket: String) ->String{
        let keys = ["_ENCODER_TOKEN_","_VIDEO_CONFIG_TOKEN_","_USER_COUNT_","_RES_WIDTH_","_RES_HEIGHT_","_QUALITY_","_FPS_","_INTERVAL_","_BITRATE_","_GOVLEN_","_H264_PROFILE_","_IPA_TYPE_","_IP_ADDR_","_PORT_","_TTL_","_AUTOSTART_","_TIMEOUT_"]
        
        let ipa = ip4Addr.isEmpty ? ip6Addr : ip4Addr
        let ucount = "1"
        let vals = [encoderToken,videoEncoderConfToken,ucount,resWidth,resHeight,quality,frameRateRateLimit,encodingInterval,bitRateLimit,govLength,h264Profile,ipAddressType,ipa,port,ttl,autoStart,sessionTimesout]
        
        var sp = soapPacket
        
        for i in 0...keys.count-1{
            sp = sp.replacingOccurrences(of: keys[i], with: vals[i].trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
        }
        
        return sp
    }
}
class VideoProfileOptions{
    var qualityRange = [String]()
    var govLengthRange = [String]()
    var frameRateRange = [String]()
    var bitRateRange = [String]()
    var resWidths = [String]()
    var resHeights = [String]()
    var intervalRange = [String]()
    var h264Profiles = [String]()
}

class VideoEncoderFactory{
    var profiles = [VideoProfile]()
    
    var currentProfile: VideoProfile!
    
    func parseProfile(profileToken: String,cp: CameraProfile, xmlPaths: [String]){
        currentProfile = VideoProfile()
        for xmlPath in xmlPaths{
            consumeProfile(profileToken: profileToken,cp: cp,xmlPath: xmlPath)
        }
    }
    func parseSettings(profile: VideoProfile,xmlPaths: [String]){
        currentProfile = profile
        
        for xmlPath in xmlPaths{
            consumeSetting(xmlPath: xmlPath)
        }
    }
    private func consumeSetting(xmlPath: String){
        /*
         trt:Options/tt:QualityRange/tt:Min/0
         trt:Options/tt:QualityRange/tt:Max/4
         trt:Options/tt:H264/tt:ResolutionsAvailable/tt:Width/2592
         trt:Options/tt:H264/tt:ResolutionsAvailable/tt:Height/1944
         trt:Options/tt:H264/tt:ResolutionsAvailable/tt:Width/2592
         trt:Options/tt:H264/tt:ResolutionsAvailable/tt:Height/1520
         trt:Options/tt:H264/tt:ResolutionsAvailable/tt:Width/2560
         trt:Options/tt:H264/tt:ResolutionsAvailable/tt:Height/1440
         trt:Options/tt:H264/tt:ResolutionsAvailable/tt:Width/2304
         trt:Options/tt:H264/tt:ResolutionsAvailable/tt:Height/1296
         trt:Options/tt:H264/tt:ResolutionsAvailable/tt:Width/2048
         trt:Options/tt:H264/tt:ResolutionsAvailable/tt:Height/1536
         trt:Options/tt:H264/tt:ResolutionsAvailable/tt:Width/1920
         trt:Options/tt:H264/tt:ResolutionsAvailable/tt:Height/1080
         trt:Options/tt:H264/tt:ResolutionsAvailable/tt:Width/1280
         trt:Options/tt:H264/tt:ResolutionsAvailable/tt:Height/960
         trt:Options/tt:H264/tt:ResolutionsAvailable/tt:Width/1280
         trt:Options/tt:H264/tt:ResolutionsAvailable/tt:Height/720
         trt:Options/tt:H264/tt:ResolutionsAvailable/tt:Width/720
         trt:Options/tt:H264/tt:ResolutionsAvailable/tt:Height/576
         trt:Options/tt:H264/tt:ResolutionsAvailable/tt:Width/720
         trt:Options/tt:H264/tt:ResolutionsAvailable/tt:Height/480
         trt:Options/tt:H264/tt:ResolutionsAvailable/tt:Width/1
         trt:Options/tt:H264/tt:ResolutionsAvailable/tt:Height/120
         trt:Options/tt:H264/tt:ResolutionsAvailable/tt:Width/3
         trt:Options/tt:H264/tt:ResolutionsAvailable/tt:Height/25
         trt:Options/tt:H264/tt:GovLengthRange/tt:Min/1
         trt:Options/tt:H264/tt:GovLengthRange/tt:Max/120
         trt:Options/tt:H264/tt:FrameRateRange/tt:Min/3
         trt:Options/tt:H264/tt:FrameRateRange/tt:Max/25
         trt:Options/tt:H264/tt:EncodingIntervalRange/tt:Min/1
         trt:Options/tt:H264/tt:EncodingIntervalRange/tt:Max/200
         trt:Options/tt:H264/tt:H264ProfilesSupported/High
         trt:Options/tt:H264/tt:H264ProfilesSupported/Baseline
         */
        let path = xmlPath.components(separatedBy: "/")
        
        if path[1].hasSuffix(":QualityRange"){
            let val = path[3]
            if currentProfile.options.qualityRange.count<2{
                currentProfile.options.qualityRange.append(val)
            }
            return
        }
        
        if path[1].hasSuffix(":H264") == false{
            return
        }
        
        if path.count == 4{
            let keyParts = path[1].components(separatedBy: ":")
            guard keyParts.count > 1 else{
                return
            }
            let key = keyParts[1]
            let val = path[3]
            
            if key == "H264ProfilesSupported"{
                currentProfile.options.h264Profiles.append(val)
            }
        }else if path.count == 5{
            let parentKeyParts = path[2].components(separatedBy: ":")
            guard parentKeyParts.count > 1 else{
                return
            }
            let parentKey = parentKeyParts[1]
            let keyParts = path[3].components(separatedBy: ":")
            guard keyParts.count > 1 else{
                return
            }
            let key = keyParts[1]
            let val = path[4]
            
            if parentKey == "ResolutionsAvailable"{
                if key == "Width"{
                    currentProfile.options.resWidths.append(val)
                }else if key == "Height"{
                    currentProfile.options.resHeights.append(val)
                }
            }else if parentKey == "GovLengthRange"{
                currentProfile.options.govLengthRange.append(val)
            }else if parentKey == "FrameRateRange"{
                currentProfile.options.frameRateRange.append(val)
            }else if parentKey == "EncodingIntervalRange"{
                currentProfile.options.intervalRange.append(val)
            }else if parentKey == "EncodingIntervalRange"{
                currentProfile.options.intervalRange.append(val)
            }
        }else if path.count == 6{
            let parentKeyParts = path[3].components(separatedBy: ":")
            guard parentKeyParts.count > 1 else{
                return
            }
            let parentKey = parentKeyParts[1]
            let keyParts = path[4].components(separatedBy: ":")
            guard keyParts.count > 1 else{
                return
            }
            let key = keyParts[1]
            let val = path[5]
            
            if parentKey == "BitrateRange"{
               currentProfile.options.bitRateRange.append(val)
           }
        }
    }
    
    private func consumeProfile(profileToken: String,cp: CameraProfile,xmlPath: String){
        
        //trt:Profile/tt:Name/MediaProfile_Channel1_SubStream2
        //trt:Profile/tt:VideoSourceConfiguration/tt:SourceToken/000
        /*
         trt:Profile/tt:VideoEncoderConfiguration/tt:Name/H264_MINOR_CH0
         trt:Profile/tt:VideoEncoderConfiguration/tt:UseCount/1
         
         trt:Profile/tt:VideoEncoderConfiguration/tt:Encoding/H264
         trt:Profile/tt:VideoEncoderConfiguration/tt:Resolution/tt:Width/720
         trt:Profile/tt:VideoEncoderConfiguration/tt:Resolution/tt:Height/480
         trt:Profile/tt:VideoEncoderConfiguration/tt:Quality/2
         trt:Profile/tt:VideoEncoderConfiguration/tt:RateControl/tt:FrameRateLimit/15
         trt:Profile/tt:VideoEncoderConfiguration/tt:RateControl/tt:EncodingInterval/1
         trt:Profile/tt:VideoEncoderConfiguration/tt:RateControl/tt:BitrateLimit/512
         trt:Profile/tt:VideoEncoderConfiguration/tt:H264/tt:GovLength/30
         
         trt:Profile/tt:VideoEncoderConfiguration/tt:H264/tt:H264Profile/High

         */
        
        /*
         READONLY
         //6
         trt:Profile/tt:MetadataConfiguration/tt:Multicast/tt:Address/tt:Type/IPv4
         trt:Profile/tt:MetadataConfiguration/tt:Multicast/tt:Address/tt:IPv4Address/0.0.0.0
         trt:Profile/tt:MetadataConfiguration/tt:Multicast/tt:Address/tt:IPv6Address/0000:0000:0000:0000:0000:0000:0000:0000
         //5
         trt:Profile/tt:MetadataConfiguration/tt:Multicast/tt:Port/60000
         trt:Profile/tt:MetadataConfiguration/tt:Multicast/tt:TTL/64
         trt:Profile/tt:MetadataConfiguration/tt:Multicast/tt:AutoStart/false
         */
        let path = xmlPath.components(separatedBy: "/")
        
        if path.count == 4{
            let keyParts = path[2].components(separatedBy: ":")
            guard keyParts.count > 1 else{
                return
            }
            let key = keyParts[1]
            let val = path[3]
            if key == "SourceToken"{
                currentProfile.profileToken = profileToken
                currentProfile.encoderToken = cp.encoderConfigToken
                currentProfile.videoEncoderConfToken = cp.videoEncoderConfToken
                currentProfile.sourceToken = val
            }
            else if key == "Name"{
                currentProfile.name = val
            }else if key == "UseCount"{
                currentProfile.userCount = val
            }else if key == "Encoding"{
                if val == "H264"{
                    profiles.append(currentProfile)
                }
            }else if key == "Quality"{
                currentProfile.quality = val
            }else if key == "SessionTimeout" && path[1].hasSuffix(":VideoEncoderConfiguration"){
                currentProfile.sessionTimesout = val
            }
        }else if path.count == 5{
            let parentKeyParts = path[2].components(separatedBy: ":")
            guard parentKeyParts.count > 1 else{
                return
            }
            let parentKey = parentKeyParts[1]
            let keyParts = path[3].components(separatedBy: ":")
            guard keyParts.count > 1 else{
                return
            }
            let key = keyParts[1]
            let val = path[4]
            
            if parentKey == "Resolution"{
                if key == "Width"{
                    currentProfile.resWidth = val
                }else if key == "Height"{
                    currentProfile.resHeight = val
                }
            }else if parentKey == "RateControl"{
                if key == "FrameRateLimit"{
                    currentProfile.frameRateRateLimit = val
                }else if key == "EncodingInterval"{
                    currentProfile.encodingInterval = val
                }else if key == "BitrateLimit"{
                    currentProfile.bitRateLimit = val
                }
            }else if parentKey == "H264"{
                if key == "GovLength"{
                    currentProfile.govLength = val
                }else if key == "H264Profile"{
                    currentProfile.h264Profile = val
                }
            }else if parentKey == "Multicast" && path[1].hasSuffix("VideoEncoderConfiguration"){
                 if key == "Port"{
                    currentProfile.port = val
                }else if key == "TTL"{
                    currentProfile.ttl = val
                }else if key == "AutoStart"{
                    currentProfile.autoStart = val
                }
            }
        }else if path.count == 6 && path[1].hasSuffix("VideoEncoderConfiguration"){
            let parentKeyParts = path[3].components(separatedBy: ":")
            guard parentKeyParts.count > 1 else{
                return
            }
            let parentKey = parentKeyParts[1]
            let keyParts = path[4].components(separatedBy: ":")
            guard keyParts.count > 1 else{
                return
            }
            let key = keyParts[1]
            let val = path[5]
            if key == "Type"{
                currentProfile.ipAddressType = val
            }else if key == "IPv4Address"{
                currentProfile.ip4Addr = val
            }else if key == "IPv6Address"{
                currentProfile.ip6Addr = val
            }
        }
        
    }
}

protocol OnvifVideoEncoderListener{
    func onError(camera: Camera,error: String)
    func onComplete(camera: Camera)
}

/*
 OnvifVideoEncloder must be used a single instance per camera
 */
class OnvifVideoEncoder : NSObject,  URLSessionDelegate{
    private var onvifBase = BaseOnvifAuth()
    
    private var soapVideoProfile = "soap_get_video_profile"
    private var soapVideoEncoder = "soap_get_video_encoder"
    private var soapVideoEncoderConifg = "soap_get_video_encoder_config"
    var setEncoderTemplate = "soap_set_video_encoder"
    
    private var factory = VideoEncoderFactory()
    
    var listener: OnvifVideoEncoderListener?
    
    override init(){
        super.init()
        soapVideoProfile = onvifBase.getXmlPacket(fileName: soapVideoProfile)
        soapVideoEncoder = onvifBase.getXmlPacket(fileName: soapVideoEncoder)
        soapVideoEncoderConifg = onvifBase.getXmlPacket(fileName: soapVideoEncoderConifg)
        setEncoderTemplate = onvifBase.getXmlPacket(fileName: setEncoderTemplate)
    }
    
    func getVideoProfiles(camera: Camera){
        getVideoProfile(camera: camera,profileIndex: 0,callback: handleGetVideoProfile)
    }
    private func handleGetVideoProfile(camera: Camera,profileIndex: Int,xmlPaths: [String],success: Bool){
        if !success{
            listener?.onError(camera: camera, error: xmlPaths[0])
            print("OnvifVideoEncoder:handleGetVideoProfile",xmlPaths[0])
            return
        }
        let cp = camera.profiles[profileIndex]
        factory.parseProfile(profileToken: cp.token,cp: cp, xmlPaths: xmlPaths)
        
        if profileIndex+1 < camera.profiles.count{
            getVideoProfile(camera: camera, profileIndex: profileIndex+1, callback: handleGetVideoProfile)
        }else{
            var profiles = factory.profiles
            print("OnvifVideoEncoder:handleGetVideoProfile COMPLETED",profiles.count)
            
            print(">>OnvifVideoEncoder:getVideoEncoder<<")
            
            getVideoEncoder(camera: camera, factory: factory, profileIndex: 0, callback: handleGetVideoEncoder)
            //getVideoEncoderConfiguration(camera: camera, factory: factory, profileIndex: 0)
            
        }
    }
    private func handleGetVideoEncoder(camera: Camera,factory: VideoEncoderFactory,profileIndex: Int,xmlPaths: [String],success: Bool){
        if !success{
            print("OnvifVideoEncoder:handleGetVideoEncoder",xmlPaths[0])
            listener?.onError(camera: camera, error: xmlPaths[0])
            return
        }
        let vp = factory.profiles[profileIndex]
        factory.parseSettings(profile: vp,xmlPaths: xmlPaths)
        
        if profileIndex+1 < factory.profiles.count{
            getVideoEncoder(camera: camera, factory: factory, profileIndex: profileIndex+1, callback: handleGetVideoEncoder)
        }else{
            var profiles = factory.profiles
            print("OnvifVideoEncoder:handleGetVideoEncoder COMPLETED",profiles.count)
            camera.videoProfiles = factory.profiles
            listener?.onComplete(camera: camera)
        }
    }
    private func getVideoProfile(camera: Camera,profileIndex: Int,callback: @escaping(Camera,Int,[String],Bool) -> Void){
        let cp = camera.profiles[profileIndex]
        let action = "http://www.onvif.org/ver10/media/wsdlGetProfile"
        
        var soapPacket = soapVideoProfile.replacingOccurrences(of: "_PROFILE_", with: cp.token)
        soapPacket = onvifBase.addAuthHeader(camera: camera, soapPacket: soapPacket)
        
         
        let contentType = "application/soap+xml; charset=utf-8; action=\"" + action + "\""
        
        let endpoint = URL(string: camera.mediaXAddr)!
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Connection", forHTTPHeaderField: "Close")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        
        request.httpBody = soapPacket.data(using: String.Encoding.utf8)
       
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                let error = (error?.localizedDescription ?? "Connect error")
                callback(camera,profileIndex,[error],false)
                
                return
            }else{
                if let str = String(data: data!,encoding: .utf8){
                    self.onvifBase.saveSoapPacket(endpoint: endpoint, method: "media_profile_" + String(profileIndex) ,xml: str)
                }
                let fparser = FaultParser()
                fparser.parseRespose(xml: data!)
                if fparser.hasFault(){
                    callback(camera,profileIndex,[fparser.authFault],false)
                }else{
                    let xmlParser = XmlPathsParser(tag: ":GetProfileResponse")
                    xmlParser.parseRespose(xml: data!)
                    
                    callback(camera,profileIndex,xmlParser.itemPaths,true)
                }
            }
        }
        task.resume()
    }
    private func getVideoEncoderConfiguration(camera: Camera,factory: VideoEncoderFactory,profileIndex: Int){
        let cp = factory.profiles[profileIndex]
        let function = "GetVideoEncoderConfiguration"
        
        var soapPacket = soapVideoEncoderConifg.replacingOccurrences(of: "_ENCODER_TOKEN_", with: cp.encoderToken)
        soapPacket = onvifBase.addAuthHeader(camera: camera, soapPacket: soapPacket)
        
        executeMediaFunc(function: function, soapPacket: soapPacket, camera: camera, index: profileIndex) { cam, pid, xpaths, success in
            
            /*
             trt:Configuration/tt:Name/VideoEncoderConfig_Channel1_MainStream
             trt:Configuration/tt:UseCount/1
             trt:Configuration/tt:Encoding/H264
             trt:Configuration/tt:Resolution/tt:Width/1920
             trt:Configuration/tt:Resolution/tt:Height/1080
             trt:Configuration/tt:Quality/4.000000
             trt:Configuration/tt:RateControl/tt:FrameRateLimit/15
             trt:Configuration/tt:RateControl/tt:EncodingInterval/1
             trt:Configuration/tt:RateControl/tt:BitrateLimit/5888
             trt:Configuration/tt:H264/tt:GovLength/30
             trt:Configuration/tt:H264/tt:H264Profile/Main
             trt:Configuration/tt:Multicast/tt:Address/tt:Type/IPv4
             trt:Configuration/tt:Multicast/tt:Address/tt:IPv4Address/224.1.0.0
             trt:Configuration/tt:Multicast/tt:Port/40000
             trt:Configuration/tt:Multicast/tt:TTL/64
             trt:Configuration/tt:Multicast/tt:AutoStart/false
             trt:Configuration/tt:SessionTimeout/PT1M
             */
            print(camera,factory,pid,xpaths,success)
        }
    }
    
    func updateVideoEncoder(camera: Camera,xmlPacket: String,callback: @escaping(String,Bool)->Void){
        let soapPacket = onvifBase.addAuthHeader(camera: camera, soapPacket: xmlPacket)
        let function = "SetVideoEncoderConfiguration"
        
        let endpoint = URL(string: camera.mediaXAddr)!
        self.onvifBase.saveSoapPacket(endpoint: endpoint, method: function ,xml: soapPacket)

        
        executeMediaFunc(function: function, soapPacket: soapPacket, camera: camera, index: -1) { cam, pid, xpaths, success in
        
            var status = xpaths.count > 0 ? xpaths[0] : "no status"
            if success{
                status = "OK"
            }
            callback(status,success)
        }
    }
    
    private  func getVideoEncoder(camera: Camera,factory: VideoEncoderFactory,profileIndex: Int,callback: @escaping(Camera,VideoEncoderFactory,Int,[String],Bool) -> Void){
        
        let cp = factory.profiles[profileIndex]
        let action = "http://www.onvif.org/ver10/media/GetVideoEncoderConfigurationOptions"
        
        var soapPacket = soapVideoEncoder.replacingOccurrences(of: "_ENCODER_TOKEN_", with: cp.encoderToken)
        soapPacket = soapPacket.replacingOccurrences(of: "_PROFILE_", with: cp.profileToken)
        soapPacket = onvifBase.addAuthHeader(camera: camera, soapPacket: soapPacket)
        
        executeMediaFunc(function: "GetVideoEncoderConfigurationOptions", soapPacket: soapPacket, camera: camera, index: profileIndex) { cam, pid, xpaths, success in
            
            callback(camera,factory,pid,xpaths,success)
        }
        
    }
    let opQueue = OperationQueue()
    
    private func executeMediaFunc(function: String,soapPacket: String,camera: Camera,index: Int,callback: @escaping(Camera,Int,[String],Bool) -> Void)
    {
        let action = "http://www.onvif.org/ver10/media/wsdl/"+function
        let contentType = "application/soap+xml; charset=utf-8; action=\"" + action + "\""
        
        let endpoint = URL(string: camera.mediaXAddr)!
        
        
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        //request.setValue("Connection", forHTTPHeaderField: "Close")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("Connection", forHTTPHeaderField: "Close")
      
        request.httpBody = soapPacket.data(using: String.Encoding.utf8)
      
    
        let config  = URLSessionConfiguration.default
        config.urlCache = nil
        let session = URLSession(configuration: config,delegate: self,delegateQueue: opQueue)
       
        let task = session.dataTask(with: request) { data, response, error in
            if error != nil {
                let error = (error?.localizedDescription ?? "Connect error")
                callback(camera,index,[error],false)
                
                return
            }else{
                if let str = String(data: data!,encoding: .utf8){
                    self.onvifBase.saveSoapPacket(endpoint: endpoint, method: function + "_" + String(index) ,xml: str)
                }
                
                let fparser = FaultParser()
                fparser.parseRespose(xml: data!)
                if fparser.hasFault(){
                    callback(camera,index,[fparser.authFault],false)
                }else{
                    let xmlParser = XmlPathsParser(tag: ":" + function + "Response")
                    xmlParser.parseRespose(xml: data!)
                    
                    callback(camera,index,xmlParser.itemPaths,true)
                }
            }
        }
        task.resume()
    }
}

