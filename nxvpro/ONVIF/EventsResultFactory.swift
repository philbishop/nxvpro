//
//  EventsResultFactory.swift
//  TestMacUI
//
//  Created by Philip Bishop on 06/01/2022.
//

import Foundation

class EventsResultFactory{
    
    var recordingEvents = [RecordToken]()
    
    func getRecordingEvents(profileToken: String) -> [RecordToken]{
        for rt in recordingEvents{
            rt.ProfileToken = profileToken
        }
        return recordingEvents
    }
    
    var currentToken: RecordToken?
    var timeItem = ""
    var includeAllStates = true
    
    private func createTokenIfNil(){
        if currentToken == nil{
            currentToken = RecordToken()
        }
    }
    func consumeXPath(xpath: String,pathSeparator: String){
        let path = xpath.components(separatedBy: pathSeparator)
        
        if path.count == 4{
            if path[2].hasSuffix("RecordingToken"){
                createTokenIfNil()
                currentToken!.Token = path[3]
            }else if path[2].hasSuffix("TrackToken"){
                createTokenIfNil()
                currentToken!.TrackToken = path[3]
            }else if path[2].hasSuffix("Time"){
                timeItem = path[3]
            }else if path[2].hasSuffix("StartStateEvent"){
                if includeAllStates || path[3] == "true"{
                    createTokenIfNil()
                    currentToken!.Time = timeItem
                    currentToken?.isComplete = true
                    addCurrentIfNotExists()
                    currentToken = nil
                    
                }else{
                    currentToken = nil
                }
                    
            }
        }
        /*
            tse:ResultList/tt:Result/tt:RecordingToken/OnvifRecordingToken_1
            tse:ResultList/tt:Result/tt:TrackToken/videotracktoken_1
            tse:ResultList/tt:Result/tt:Time/2022-01-06T00:00:00Z
            tse:ResultList/tt:Result/tt:Event/wsnt:Topic/tns1:RecordingHistory/Track/State
            tse:ResultList/tt:Result/tt:StartStateEvent/true
         */
    }
    private func addCurrentIfNotExists(){
        let lcToken = currentToken!.TrackToken.lowercased()
        if lcToken.contains("audio"){
            return
        }
        for rt in recordingEvents{
            if rt.Time == currentToken!.Time{
                return
            }
        }
        recordingEvents.append(currentToken!)
    }
   
}
