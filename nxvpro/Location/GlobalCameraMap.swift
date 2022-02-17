//
//  GlobalCameraMap.swift
//  NX-V
//
//  Created by Philip Bishop on 01/01/2022.
//

import SwiftUI

//Global recording events
var recordingEventMonitor = SDCardEventsMonitor()

class CameraLocationItemViewModel : ObservableObject{
    
    @Published var camera: Camera?
    @Published var name = ""
    @Published var ipa = ""
    
    @Published var statusIcon = "circle.fill"
    @Published var statusColor =  Color.gray
    
    @Published var hasRecentEvents = false
    func setHasEvents(hasEvents: Bool){
        statusColor = hasEvents ? .red : .accentColor
        if camera!.location == nil{
            statusColor =  Color.gray
        }
        hasRecentEvents = hasEvents
    }
    
    func setCamera(camera: Camera){
        print("CameraLocationItemViewModel",camera.getStringUid())
        
        self.camera = camera
        self.name = camera.getDisplayName()
        
        if camera.isVirtual == false{
            var dipa = camera.getDisplayAddr()
            if dipa.count > 15{
                dipa = Helpers.truncateString(inStr: dipa, length: 15)
            }
            self.ipa = dipa
        }
        if camera.locationLoaded == false {
            camera.loadLocation()
        }
        if camera.location != nil{
            statusColor =  Color.accentColor
        }
        
        setHasEvents(hasEvents: recordingEventMonitor.hasRecentEvents(camera: camera))
    }
    
}
struct CameraLocationItemView: View {
    
    @ObservedObject var model = CameraLocationItemViewModel()
    
    init(camera: Camera){
        self.model.setCamera(camera: camera)
        recordingEventMonitor.registerModel(camera: camera, model: model)
    }
    
    var body: some View {
        
        HStack(spacing: 10){
            Image(systemName: model.statusIcon).foregroundColor(model.statusColor)
            Text(model.name).appFont(.body)
            Text(model.ipa).appFont(.caption)
            Spacer()
            if model.hasRecentEvents{
                Image(systemName: "waveform.badge.exclamationmark").foregroundColor(.red)
            }
        }.padding(3).frame(height: 20)
        
    }
    
}

class CameraLocationViewFactory{
    static var views = [String:CameraLocationItemView]()
    
    static func reset(){
        views.removeAll()
    }
    
    static func getInstance(camera: Camera) -> CameraLocationItemView{
        if let view = views[camera.getStringUid()]{
            return view
        }
        let view = CameraLocationItemView(camera: camera)
        views[camera.getStringUid()] = view
        
        return view
        
    }
}
class GlobalMapModel : ObservableObject{
    @Published var recentAlert = ""
    @Published var camera: Camera?
    @Published var alertsHidden = true
    @Published var playerHidden = true
    //@Published var rightPaneHidden = true
}
var globalMapViewListener: MapViewEventListener?

struct GlobalCameraMap: View {
    var locationView = CameraLocationView()
    //var eventAlertsView = GlobalMapAlertsView()
   // var rightPanel = GlobalMapPropertiesPanel()
    
    //var borderlessPlayer = SinglePlayerLoaderView()
    
    @ObservedObject var model = GlobalMapModel()
    
    init(){
        locationView.model.isGlobalMap = true
        
    }
    
    func windowDidEndLiveResize(newSize: CGSize){
        locationView.miniMap.windowSizeChanged(newSize: newSize)
    }
    
    func showMiniMap(group: CameraGroup){
        locationView.showMiniMap(group: group)
    }
    
    func setCamera(camera: Camera,allCameras: [Camera]){
        var cams = [Camera]()
        for cam in allCameras{
            if cam.isNvr(){
                for vcam in cam.vcams{
                    cams.append(vcam)
                }
            }else{
                cams.append(cam)
            }
        }
        
        
        self.locationView.setCamera(camera: camera,allCameras: cams,isGlobalMap: true)
        
        recordingEventMonitor.mapModel = model
        
        /*
        if eventAlertsView.model.recentAlerts.count > 0{
            model.alertsHidden = false
        }
         */
    }
    func showFullRegion(allCameras: [Camera]){
        locationView.showFullRegion(allCameras: allCameras)
    }
    var body: some View {
        
            
            HStack{
                ZStack(alignment: .top){
                    locationView
                    
                    if model.recentAlert.count > 0{
                        Text(model.recentAlert).foregroundColor(Color.white).background(Color.red).appFont(.sectionHeader).padding().onTapGesture {
                            //move to camera on map
                            if let cam = model.camera{
                                locationView.gotoCamera(cam: cam)
                                //model.alertsHidden = false
                                if cam.isNvr() == false{
                                    //showPlayer(camera: cam)
                                }
                            }
                        }
                    }
                    
                }
               
            }.onAppear{
               
                //eventAlertsView.model.parentModel = model
                //eventAlertsView.model.mapView = locationView
                locationView.mapView.model.isGlobalMap = true
                globalMapViewListener = locationView.mapView.model.mapViewListener
        }
        
    }
    
    func showPlayer(camera: Camera){
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5,execute:{
            
            //borderlessPlayer.play(camera: camera)
            //model.playerHidden = false;
        });
    }
}

struct GlobalCameraMap_Previews: PreviewProvider {
    static var previews: some View {
        GlobalCameraMap()
    }
}
