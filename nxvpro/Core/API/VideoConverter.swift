//
//  VideoConverter.swift
//  NX-V PRO
//
//  Created by Philip Bishop on 09/12/2022.
//

import Foundation
import ffmpegkit

protocol IVideoConverter{
    func convertToMp4(video: String,callback:@escaping(String,Bool) -> Void)
    func getDuration(video: String,callback:@escaping(String,Bool)->Void)
    func setKeepOriginal(_ keep: Bool)
    func setXtraCmds(_ cmds: String)
}

class VideoConverter : IVideoConverter{
    
    static func getInstance() -> IVideoConverter{
        return VideoConverter()
    }
    
    var deleteOriginal = false
    var xtraCmds = ""
    var keepOriginal = true
    func setKeepOriginal(_ keep: Bool){
        keepOriginal = keep
    }
    func setXtraCmds(_ cmds: String){
        xtraCmds = cmds
    }
    func convertToMp4(video: String,callback:@escaping(String,Bool) -> Void){
    
        let bfn = FileHelper.stripFileExtension(video)
        
        var outPath = bfn + ".mp4"
        if !keepOriginal{
            outPath = bfn + "_pre.mp4"
        }
        if FileManager.default.fileExists(atPath: outPath){
            callback(outPath,true)
            return
        }
        
        var cmd = "-i \""+video+"\" -vcodec copy -acodec aac \""+outPath+"\""
        if xtraCmds.isEmpty == false{
            cmd = "-i \""+video+"\" " + xtraCmds + " -vcodec copy -acodec aac \""+outPath+"\""
        }
        AppLog.write("ffmpeg",cmd)
        let ffmpeg = FFmpegKit.executeAsync(cmd) { session in
            if let ses = session{
                if let exitCode = ses.getReturnCode(){
                    AppLog.write("FFMPEG SESSION",exitCode)
                    callback(outPath,exitCode.isValueSuccess())
                    
                    if exitCode.isValueSuccess() && self.deleteOriginal{
                        do{
                            try FileManager.default.removeItem(atPath: video)
                        }catch{
                            
                        }
                    }
                    
                }else{
                    callback(outPath,false)
                }
            }
        } withLogCallback: { log in
            if let logItem = log{
                #if DEBUG
                    AppLog.write("ffmpeg:",logItem.getMessage())
                #endif
            }
        } withStatisticsCallback: { stats in
            if let theStats = stats{
                //AppLog.write("STAT",theStats)
            }
        }

        if ffmpeg == nil{
            AppLog.write("FAILED TO CREATE FFMPEG SESSION")
            callback(outPath,false)
        }else{
            let sessionId = ffmpeg!.getId();
            
            AppLog.write("FFMPEG-SESSION",ffmpeg.debugDescription,sessionId)
        }
            
    }
    func getDuration(video: String,callback:@escaping(String,Bool)->Void){
        
        
        let cmd = "-i \""+video+"\""
        
        var useNext = false
        
        print("ffmpeg",cmd)
        let ffmpeg = FFmpegKit.executeAsync(cmd) { session in
            if let ses = session{
                if let exitCode = ses.getReturnCode(){
                    print("FFMPEG SESSION",exitCode)
                    //callback(outPath,exitCode.isValueSuccess())
                }else{
                    callback("",false)
                }
            }
        } withLogCallback: { log in
            if let logItem = log{
                let msg = logItem.getMessage().trimmingCharacters(in: .whitespacesAndNewlines)
                if msg == "Duration:"{
                    useNext = true
                }else if useNext{
                    useNext = false
                    callback(msg,true)
                    
                }
                //print(msg)
            }
        } withStatisticsCallback: { stats in
            if let theStats = stats{
                //print("STAT",theStats)
            }
        }
        
        if ffmpeg == nil{
            print("FAILED TO CREATE FFMPEG SESSION")
            callback("",false)
        }else{
            let sessionId = ffmpeg!.getId();
            
            print("FFMPEG-SESSION",ffmpeg.debugDescription,sessionId)
        }
    }
}
