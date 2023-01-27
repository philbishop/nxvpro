//
//  SDCardIndexer.swift
//  NX-V
//
//  Created by Philip Bishop on 08/01/2022.
//

import Foundation


class SDCardEventsMonitor: OnvifSearchListener{
    var cameras = [Camera]()
    
    var lock = NSLock()
    
    var recentEvents = [String:Bool]()
    var itemModels = [String:CameraLocationItemViewModel]()
    var mapModel: GlobalMapModel?
    var mapAlertModel: GlobalMapAlertsModel?
    var cameraPropsModel: GlobalMapPropertiesModel?
    
    func registerModel(camera: Camera, model: CameraLocationItemViewModel){
        lock.lock()
        itemModels[camera.getStringUid()] = model
        lock.unlock()
    }
    func hasRecentEvents(camera: Camera) -> Bool{
        if let hasEvents = recentEvents[camera.getStringUid()]{
            return hasEvents
        }
        return false
    }
    
    func addCamera(camera: Camera){
        /*
        if camera.isNvr(){
            AppLog.write("SDCardEventsMonitor:addCamera-> NVR ignored for testing",camera.getStringUid())
            return
        }
         */
        if camera.isVirtual{
            AppLog.write("SDCardEventsMonitor:addCamera-> should add NVR not VCAMs",camera.getStringUid())
            return
        }
        lock.lock()
        
        var exists = false
        for cam in cameras{
            if cam.getStringUid() == camera.getStringUid(){
                exists = true
                break;
            }
        }
        if !exists{
            cameras.append(camera)
            recentEvents[camera.getStringUid()] = false
        }
        
        lock.unlock()
    }
    
   
    private var running = false
    
    func stop(){
        running = false
    }
    
    func start(){
        
        if !running{
            
           
            running = true
            DispatchQueue.global(qos: .background).async {
                self.doRun()
            }
            
        }
    }
    
    var camera: Camera?
    //var onvifSearch = OnvifSearch()
    
    private func doRun(){
        AppLog.write("$>>>SDCardEventsMonitor:STARTED")
        
        while running{
            
            for cam in cameras{
                if cam.searchXAddr.isEmpty{
                    continue
                }
                let onvifSearch = OnvifSearch()
                onvifSearch.listener = self
                onvifSearch.checkForRecentEvents(camera: cam, minutesAgo: 2)
                sleep(1)
                
                if !running{
                    AppLog.write("$>>>SDCardEventsMonitor:STOPPED")
                    return
                }
            }
            for _ in 0...119{
                sleep(1)
                if !running{
                    AppLog.write("$>>>SDCardEventsMonitor:STOPPED")
                    return
                }
            }
        }
        
        
        
    }
    
    
    //MARK: OnvifSearchListener
    func onTokensUpdated(camera: Camera, results: [RecordToken]) {
        AppLog.write("$>>>SDCardEventsMonitor:onTokensUpdated")
    }
    func onSearchStateChanged(camera: Camera,status: String){
        AppLog.write("$>>>SDCardEventsMonitor:",status,camera.getStringUid())
    }
    func onPartialResults(camera: Camera,partialResults: [RecordToken]){
        AppLog.write("$>>>SDCardEventsMonitor:onPartialResults",partialResults.count,camera.getStringUid())
        
        
    }
    func onSearchComplete(camera: Camera,allResults: [RecordToken],success: Bool,anyError: String){
        AppLog.write("$>>>SDCardEventsMonitor:COMPLETE",camera.getStringUid(),success);
        
        if !success{
            return
        }
        
        let partialResults = allResults
        
        recentEvents[camera.getStringUid()] = partialResults.count > 0
        
        if let itemModel = itemModels[camera.getStringUid()]{
            DispatchQueue.main.async {
                itemModel.setHasEvents(hasEvents: partialResults.count > 0)
            }
        }
        
        
        if partialResults.count > 0{
            AppLog.write("$>>>SDCardEventsMonitor:ALERT -> send event to map",camera.getStringUid())
            if mapModel != nil{
                let nr = partialResults.count
                let last = partialResults[nr-1]
                var name = camera.getDisplayName()
                if camera.isNvr(){
                    name = name + " " + last.Token
                }
                let alert = String(format: " RECENT EVENT: %@ %@ ", last.Time,name)
                DispatchQueue.main.async {
                    self.mapModel!.recentAlert = alert
                    self.mapModel!.camera = camera
                    
                    self.mapAlertModel?.addEvent(camera: camera, rt: last)
                    self.cameraPropsModel?.handleEvent(camera: camera, token: last)
                }
            }
        }
        let oldState = camera.hasRecentAlerts
        let newState = partialResults.count > 0
        if oldState != newState{
            camera.hasRecentAlerts = newState
        
            DispatchQueue.main.async{
                globalMapViewListener?.cameraMapPropertyChanged(camera: camera)
            }
        }
    }
    
}
