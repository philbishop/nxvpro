//
//  XmlProfilesParser.swift
//  NX-V PRO
//
//  Created by Philip Bishop on 22/04/2022.
//

import SwiftUI
class CameraProfileRep{
    var name = ""
    var token = ""
    var videoSourceId = ""
    var videoSrcToken = ""
    var encoderConfigToken = ""
    var videoEncoderConfToken = ""
    var width = ""
    var height = ""
    
    func isComplete()->Bool{
        return name.isEmpty==false && token.isEmpty == false && videoSrcToken.isEmpty==false
        //&& width.isEmpty == false && height.isEmpty == false
    }
}

class XmlProfilesParser{
    
    var profiles = [CameraProfile]()
    var profileReps = [CameraProfileRep]()
    
    func parseRespose(xml: Data){
        var separator = "|"
        let xmlParser = XmlPathsParser(tag: ":GetProfilesResponse",separator: separator)
        xmlParser.attrTag = "token"
        xmlParser.parseRespose(xml: xml)
        
        //xmlParser.dumpPaths()
        
        /*
         trt:Profiles|tt:Name|MediaProfile_Channel1_MainStream
         trt:Profiles|tt:VideoSourceConfiguration|tt:Name|VideoSourceConfig_Channel1
         trt:Profiles|tt:VideoSourceConfiguration|tt:UseCount|3
         trt:Profiles|tt:VideoSourceConfiguration|tt:SourceToken|00100
         trt:Profiles|tt:VideoEncoderConfiguration|tt:Name|VideoEncoderConfig_Channel1_MainStream
         trt:Profiles|tt:VideoEncoderConfiguration|tt:UseCount|1
         trt:Profiles|tt:VideoEncoderConfiguration|tt:Encoding|H264
         trt:Profiles|tt:VideoEncoderConfiguration|tt:Resolution|tt:Width|1920
         trt:Profiles|tt:VideoEncoderConfiguration|tt:Resolution|tt:Height|1080
         trt:Profiles|tt:VideoEncoderConfiguration|tt:Quality|50
         trt:Profiles|tt:VideoEncoderConfiguration|tt:RateControl|tt:FrameRateLimit|25
         trt:Profiles|tt:VideoEncoderConfiguration|tt:RateControl|tt:EncodingInterval|1
         trt:Profiles|tt:VideoEncoderConfiguration|tt:RateControl|tt:BitrateLimit|1536
         trt:Profiles|tt:VideoEncoderConfiguration|tt:H264|tt:GovLength|50
         trt:Profiles|tt:VideoEncoderConfiguration|tt:H264|tt:H264Profile|Baseline
         trt:Profiles|tt:VideoEncoderConfiguration|tt:Multicast|tt:Address|tt:Type|IPv4
         trt:Profiles|tt:VideoEncoderConfiguration|tt:Multicast|tt:Port|0
         trt:Profiles|tt:VideoEncoderConfiguration|tt:Multicast|tt:TTL|0
         trt:Profiles|tt:VideoEncoderConfiguration|tt:Multicast|tt:AutoStart|false
         trt:Profiles|tt:VideoEncoderConfiguration|tt:SessionTimeout|PT60S
         */
        
        var cp = CameraProfileRep()
        var attribStartIndex = 0
        for path in xmlParser.itemPaths{
            let parts = path.components(separatedBy: separator)
            let p1 = parts[1].components(separatedBy: ":")
            if p1.count==2{
                let tag = p1[1]
                //trt:Profiles|tt:VideoSourceConfiguration|tt:Name|VideoSourceConfig_Channel8
                //trt:Profiles|tt:VideoSourceConfiguration|tt:SourceToken|00800
                if parts.count==3 && tag=="Name"{
                    if cp.name.isEmpty==false{
                        profileReps.append(cp)
                       
                    }
                    cp = CameraProfileRep()
                    cp.name = parts[2]
                }else if parts.count==4{
                    let stag = parts[2].components(separatedBy: ":")
                    if stag.count==2 && stag[1]=="SourceToken"{
                        cp.videoSourceId = parts[3]
                    }
                    if tag=="VideoEncoderConfiguration"{
                        let stag = parts[2].components(separatedBy: ":")
                        if stag.count==2 && stag[1]=="Name"{
                            cp.videoEncoderConfToken = parts[3]
                        }
                    }
                }
                /*
                 trt:Profiles|tt:VideoEncoderConfiguration|tt:Resolution|tt:Width|352
                 trt:Profiles|tt:VideoEncoderConfiguration|tt:Resolution|tt:Height|288
                 trt:Profiles|tt:VideoEncoderConfiguration|tt:Name|VideoEncoderConfig_Channel1_MainStream
                 */
                
               
                else if parts.count == 5 && tag=="VideoEncoderConfiguration"{
                    let p2 = parts[2].components(separatedBy: ":")
                    if p2.count==2{
                        let vtag = p2[1]
                        if vtag=="Resolution"{
                            let p3 = parts[3].components(separatedBy: ":")
                            if p3.count==2{
                                let rtag = p3[1]
                                if rtag=="Width"{
                                    cp.width = parts[4]
                                }else if rtag == "Height"{
                                    cp.height = parts[4]
                                }
                            }
                        }
                    }
                }
            }
            
        }
        if cp.name.isEmpty==false{
            profileReps.append(cp)
        }
        if xmlParser.attribStack.count>0{
            var pi = 0
            var pf = profileReps[pi]
            
            for i in 0...xmlParser.attribStack.count-1{
                let val = xmlParser.attribStack[i]
                let key = xmlParser.attribKeyStack[i].components(separatedBy: ":")
                if key.count==2{
                    if key[1]=="Profiles"{
                        if pf.token.isEmpty==false{
                            pi += 1
                            if pi < profileReps.count{
                                pf = profileReps[pi]
                            }
                        }
                        pf.token = val
                    }else if key[1]=="VideoSourceConfiguration"{
                       
                       pf.videoSrcToken = val
                       
                    }else if key[1]=="VideoEncoderConfiguration"{
                        pf.encoderConfigToken = val
                    }
                    /*else if key[1]=="VideoEncoderConfiguration"{
                        pf.encoderConfig = val
                    }*/
                    
                }
                /*
                 3 trt:Profiles token:17/0/1/1/1/s0
                 4 tt:VideoSourceConfiguration 00100
                 5 tt:VideoEncoderConfiguration 00100
                 6 tt:VideoAnalyticsConfiguration 00100
                 */
                
            }
        }
        
        for pr in profileReps{
            if pr.isComplete(){
                print("ProfileRep",pr.name,pr.token,pr.videoEncoderConfToken,pr.videoSrcToken,pr.videoEncoderConfToken,pr.width,pr.height)
                
                let cp = CameraProfile(name: pr.name,resolution: pr.width+"x"+pr.height,url: "")
                cp.token = pr.token
                cp.videoSrcToken = pr.videoSrcToken
                cp.videoEncoderConfToken = pr.videoEncoderConfToken
                cp.videoSourceId = pr.videoSourceId
                cp.encoderConfigToken = pr.encoderConfigToken
                profiles.append(cp)
            }
        }
    }
}

