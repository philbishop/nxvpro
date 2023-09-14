//
//  NxvProMulticamView.swift
//  nxvpro
//
//  Created by Philip Bishop on 16/02/2022.
//

import SwiftUI

class NxvProMulticamModel : ObservableObject{
    @Published var selectedPlayer: CameraStreamingView?
    @Published var selectedCamera: Camera?
    @Published var multicamTitle = "Multicams"
    
    @Published var selectedHeader = "Multicams"
    @Published var segHeaders = ["Multicams","Local storage","Locations"]
    
    @Published var multicamsHidden = false
    @Published var storageHidden = true
    @Published var locationHidden = true
    
    @Published var gridIconHidden: Bool = true
    
    @Published var isFullScreen = false
    
    func onTabChanged(){
        if selectedHeader == segHeaders[0]{
            multicamsHidden = false
            locationHidden = true
            storageHidden = true
        }else if selectedHeader == segHeaders[1]{
            multicamsHidden = true
            locationHidden = true
            storageHidden = false
        }else if selectedHeader == segHeaders[2]{
            multicamsHidden = true
            locationHidden = false
            storageHidden = true
        }
    }
    
}

struct NxvProMulticamView: View, MulticamActionListener, CameraToolbarListener, VmdEventListener{
    //MARK: VmdEventListener
    func vmdVideoEnabledChanged(camera: Camera, enabled: Bool) {
        if let thePlayer = mcModel.selectedPlayer{
            thePlayer.playerView.setVmdVideoEnabled(enabled: enabled)
        }
        
    }
    
    func vmdEnabledChanged(camera: Camera, enabled: Bool) {
        if let thePlayer = mcModel.selectedPlayer{
            thePlayer.playerView.setVmdEnabled(enabled: enabled)
        }
        DispatchQueue.main.async {
            //model.vmdLabelHidden = !enabled
            let multicamFactory = multicamView.multicamFactory
            multicamFactory.setVmdOn(camera, isOn: enabled)
        }
        
    }
    
    func vmdSensitivityChanged(camera: Camera, sens: Int) {
        if let thePlayer = mcModel.selectedPlayer{
            thePlayer.playerView.setVmdSensitivity(sens: sens)
        }
    }
    
    func showHelpContext(context: Int) {
        helpView.setContext(contextId: context, listener: model.cameraEventHandler!)
        model.helpHidden = false
    }
    
    func closeVmd() {
        model.vmdCtrlsHidden = true
        model.toolbarHidden = false
        model.helpHidden = true
    }
    
    func onMotionEvent(camera: Camera,start: Bool){
        multicamView.onMotionEvent(camera: camera, start: start)
    }
    
    @ObservedObject var mcModel = NxvProMulticamModel()
    @ObservedObject var model = SingleCameraModel()
    
    let multicamView = MulticamView2()
    
    let toolbar = CameraToolbarView()
    let vmdCtrls = VMDControls()
    let helpView = ContextHelpView()
    let settingsView = CameraPropertiesView()
    let ptzControls = PTZControls()
    let presetsView = PtzPresetView()
    let imagingCtrls = ImagingControlsContainer()
    
    let storageView =  OnDeviceStorageView()
    let locationView = CameraLocationView()
    
    func setCameras(cameras: [Camera],title: String = "Multicams"){
        toolbar.model.settingsEnabled = false
        multicamView.setCameras(cameras: cameras,listener: self)
        
       var tabName = title
        if tabName.count > 10{
            tabName = Helpers.truncateString(inStr: title, length: 10)
        }
       mcModel.segHeaders[0] = tabName
        
        storageView.setCameras(cameras: cameras)
        locationView.setCamera(camera: cameras[0], allCameras: cameras, isGlobalMap: false)
        
    }
    func playAll(){
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5,execute:{
            multicamView.playAll()
        })
    }
    func stopAll(){
        model.setIsRecording(false)
        model.hideConrols()
        multicamView.stopAll()
        
    }
    func disableAltMode(){
        multicamView.disableAltMode()
    }
    func selectedCamera() -> Camera?{
        return mcModel.selectedCamera
    }
    func setSelectedCamera(camera: Camera?,isLandscape: Bool){
        
        if let smc = camera{
            multicamView.model.autoSelectCamMode = isLandscape
            multicamView.model.autoSelectMulticam = smc
        }
    }
    
    
    
    //MARK: CameraToolbarListener
    func itemSelected(cameraEvent: CameraActionEvent) {
        if let thePlayer = mcModel.selectedPlayer{
            
            if cameraEvent == .bodyDetection{
                if let cam = mcModel.selectedCamera{
                    cam.vmdOn = !cam.vmdOn
                    cam.vmdMode = cam.vmdOn ? 1 : 0
                    cam.save()
                    vmdEnabledChanged(camera: cam, enabled: cam.vmdOn)
                    //need to set vmd controls to disabled
                    vmdCtrls.model.vmdEnabled = false
                }
            }
            
            model.cameraEventHandler?.itemSelected(cameraEvent: cameraEvent, thePlayer: thePlayer)
            
            if cameraEvent == .Record{
                if let cam = mcModel.selectedCamera{
                    multicamView.toggleRecordingState(camera: cam)
                }
            }
        }
    }
    //MARK: MulticamActionListener
    func multicamSelected(camera: Camera, mcPlayer: CameraStreamingView) {
        mcModel.selectedPlayer = mcPlayer
        mcModel.selectedCamera = camera
        if multicamView.isPlayerReady(cam: camera) == false{
            return
        }
        
        
        model.hideConrols()
        model.theCamera = camera
        //model.cameraEventListener = eventListener
        toolbar.setCamera(camera: camera)
        if mcPlayer.playerView.isRecording{
            model.setIsRecording(true)
            toolbar.setRecordStartTime(startTime: mcPlayer.playerView.recordStartTime)
        }else{
            model.setIsRecording(false)
        }
        
        vmdCtrls.setCamera(camera: camera, listener: self)
        mcPlayer.playerView.motionListener = vmdCtrls
        
        model.cameraEventHandler = CameraEventHandler(model: model,toolbar: toolbar,ptzControls: ptzControls,settingsView: settingsView,helpView: helpView,presetsView: presetsView,imagingCtrls: imagingCtrls)
        
        if let handler = model.cameraEventHandler{
            
            ptzControls.setCamera(camera: camera, toolbarListener: self, presetListener: handler)
            
            handler.getPresets(cam: camera)
            handler.getImaging(camera: camera)
        }
        
        model.toolbarHidden = false
        
        let isOn = multicamView.isAltMode()
        globalCameraEventListener?.multicamAltModeOn(isOn: isOn)
        
        locationView.changeCamera(camera: camera)
    }
    
    func clearStorage(){
        locationView.resetMap()
    }
    
    func setFullScreen(isFullScreen: Bool){
        mcModel.isFullScreen = isFullScreen
    }
    
    var tabHeight = CGFloat(32.0)
    
    var body: some View {
        
        ZStack{
            Color(uiColor: .secondarySystemBackground)
        VStack(spacing: 0){
            if mcModel.isFullScreen == false{
                HStack{
                    Picker("", selection: $mcModel.selectedHeader) {
                        ForEach(mcModel.segHeaders, id: \.self) {
                            Text($0)
                        }
                    }.onChange(of: mcModel.selectedHeader) { tabItem in
                        mcModel.onTabChanged()
                    }.pickerStyle(.segmented)
                        .fixedSize()
                    
                    Spacer()
                    
                }.frame(height: tabHeight)
            }
            ZStack{
                ZStack(alignment: .bottom){
                    multicamView
                    toolbar.hidden(model.toolbarHidden)
                    ptzControls.hidden(model.ptzCtrlsHidden)
                    vmdCtrls.hidden(model.vmdCtrlsHidden)
                    
                    VStack{
                        
                        Spacer()
                        HStack{
                            Spacer()
                            ZStack{
                                helpView.hidden(model.helpHidden)
                                settingsView.hidden(model.settingsHidden)
                                presetsView.hidden(model.presetsHidden)
                            }
                        }
                        Spacer()
                        
                    }
                    HStack{
                        VStack{
                            Spacer()
                            imagingCtrls.padding()
                            Spacer()
                        }//.padding()
                        Spacer()
                    }.hidden(model.imagingHidden)
                    
                }
                
                ZStack{
                    Color(uiColor: .secondarySystemBackground)
                    storageView
                    
                }
                .hidden(mcModel.storageHidden)
                
                ZStack{
                    Color(uiColor: .secondarySystemBackground)
                    //Text("Location place holder")
                    locationView
                }
                .hidden(mcModel.locationHidden)
            }
        }
        }.onAppear{
            toolbar.setListener(listener: self)
            settingsView.model.listener = self
            
        }
    }
}

struct NxvProMulticamView_Previews: PreviewProvider {
    static var previews: some View {
        NxvProMulticamView()
    }
}
