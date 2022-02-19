//
//  SingleCameraView.swift
//  nxvpro
//
//  Created by Philip Bishop on 12/02/2022.
//

import SwiftUI

class SingleCameraModel : ObservableObject{
    @Published var toolbarHidden = true
    @Published var ptzCtrlsHidden = true
    @Published var helpHidden = true
    @Published var settingsHidden = true
    @Published var presetsHidden = true
    @Published var imagingHidden = true
    @Published var recordingLabelHidden = true
    @Published var vmdLabelHidden = true
    
    var theCamera: Camera?
    var cameraEventHandler: CameraEventHandler?
    @Published var cameraEventListener: CameraEventListener?
    
    func hideConrols(){
        toolbarHidden = true
        ptzCtrlsHidden = true
        helpHidden = true
        settingsHidden = true
        presetsHidden = true
        imagingHidden = true
        recordingLabelHidden = true
        vmdLabelHidden = true
    }
}

struct SingleCameraView : View, CameraToolbarListener{//, ContextHelpViewListener{//}, PtzPresetEventListener, ImagingActionListener{
    
    @ObservedObject var model = SingleCameraModel()
    
    let thePlayer = CameraStreamingView()
    let toolbar = CameraToolbarView()
    let helpView = ContextHelpView()
    let settingsView = CameraPropertiesView()
    let ptzControls = PTZControls()
    let presetsView = PtzPresetView()
    let imagingCtrls = ImagingControlsContainer()
    
    
    
    func setCamera(camera: Camera,listener: VLCPlayerReady,eventListener: CameraEventListener){
        model.theCamera = camera
        model.cameraEventListener = eventListener
        toolbar.setCamera(camera: camera)
        
        model.cameraEventHandler = CameraEventHandler(model: model,toolbar: toolbar,ptzControls: ptzControls,settingsView: settingsView,helpView: helpView,presetsView: presetsView,imagingCtrls: imagingCtrls)
        
        if let handler = model.cameraEventHandler{
            
            ptzControls.setCamera(camera: camera, toolbarListener: self, presetListener: handler)
            thePlayer.setCamera(camera: camera,listener: listener)
            
            
            handler.getPresets(cam: camera)
            handler.getImaging(camera: camera)
        }
    }
    func stop(camera: Camera) -> Bool{
        hideControls()
        return thePlayer.stop(camera: camera)
    }
    func hideControls(){
        model.toolbarHidden = true
        model.settingsHidden = true
        model.helpHidden = true
        model.presetsHidden = true
        model.imagingHidden = true
        
    }
    func showToolbar(){
        model.toolbarHidden = false
    }
    
    //MARK: ContextHelpViewListener
    func onCloseHelp() {
        model.helpHidden = true
    }
    
    //MARK: CameraToolbarListener
    func itemSelected(cameraEvent: CameraActionEvent) {
        //Ptz, Vmd, Mute, Record, Cloud, Rotate, Settings, Help, CloseToolbar, ProfileChanged, CapturedVideos, StopVideoPlayer, StopMulticams, Feedback, StopMulticamsShortcut, Imaging
        
        guard let cam = model.theCamera else{
            print("SingleCameraView:itemSelected model.theCamera == nil")
            return
        }
        
        if let handler = model.cameraEventHandler{
            handler.itemSelected(cameraEvent: cameraEvent, thePlayer: thePlayer)
        }
    }

    //MARK: BODY
    var body: some View {
        ZStack(alignment: .bottom){
            thePlayer
            toolbar.hidden(model.toolbarHidden)
            ptzControls.hidden(model.ptzCtrlsHidden)
            
          
            VStack{
                Text(" MOTION ON ").appFont(.caption)
                    .foregroundColor(Color.white).background(Color.green).padding(0)
                    .hidden(model.vmdLabelHidden)
                
                Text(" RECORDING ").appFont(.caption)
                    .foregroundColor(Color.white).background(Color.red)
                    .padding(0).hidden(model.recordingLabelHidden)
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
            
        }.onAppear{
            toolbar.setListener(listener: self)
            settingsView.model.listener = self
        }
    }
}
