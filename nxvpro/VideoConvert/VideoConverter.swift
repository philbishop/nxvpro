//
//  VideoConverter.swift
//  NX-V PRO
//
//  Created by Philip Bishop on 09/12/2022.
//

import Foundation
import ffmpegkit

class VideoConverter{
    
    var deleteOriginal = false
    
    func convertToMp4(video: String,callback:@escaping(String,Bool) -> Void){
    
        let bfn = FileHelper.stripFileExtension(video)
        
        let outPath = bfn + ".mp4"
        
        if FileManager.default.fileExists(atPath: outPath){
            callback(outPath,true)
            return
        }
        
        
        let cmd = "-i \""+video+"\" -vcodec copy -acodec aac \""+outPath+"\""
        print("ffmpeg",cmd)
        let ffmpeg = FFmpegKit.executeAsync(cmd) { session in
            if let ses = session{
                if let exitCode = ses.getReturnCode(){
                    print("FFMPEG SESSION",exitCode)
                    callback(outPath,exitCode.isSuccess())
                    
                    if exitCode.isSuccess() && self.deleteOriginal{
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
                    print("ffmpeg:",logItem.getMessage())
                #endif
            }
        } withStatisticsCallback: { stats in
            if let theStats = stats{
                //print("STAT",theStats)
            }
        }

        if ffmpeg == nil{
            print("FAILED TO CREATE FFMPEG SESSION")
            callback(outPath,false)
        }else{
            let sessionId = ffmpeg!.getId();
            
            print("FFMPEG-SESSION",ffmpeg.debugDescription,sessionId)
        }
            
    }
}
