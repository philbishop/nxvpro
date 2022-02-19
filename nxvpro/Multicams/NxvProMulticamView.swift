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
}
struct NxvProMulticamView: View, MulticamActionListener, CameraToolbarListener {
    
    @ObservedObject var mcModel = NxvProMulticamModel()
    @ObservedObject var model = SingleCameraModel()
    
    let multicamView = MulticamView2()
    
    let toolbar = CameraToolbarView()
    let helpView = ContextHelpView()
    let settingsView = CameraPropertiesView()
    let ptzControls = PTZControls()
    let presetsView = PtzPresetView()
    let imagingCtrls = ImagingControlsContainer()
    
    
    func setCameras(cameras: [Camera]){
        
        multicamView.setCameras(cameras: cameras,listener: self)
    }
    func playAll(){
        multicamView.playAll()
        
    }
    func stopAll(){
        model.hideConrols()
        multicamView.stopAll()
        
    }
    //MARK: CameraToolbarListener
    func itemSelected(cameraEvent: CameraActionEvent) {
        if let thePlayer = mcModel.selectedPlayer{
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
        
        model.cameraEventHandler = CameraEventHandler(model: model,toolbar: toolbar,ptzControls: ptzControls,settingsView: settingsView,helpView: helpView,presetsView: presetsView,imagingCtrls: imagingCtrls)
        
        if let handler = model.cameraEventHandler{
            
            ptzControls.setCamera(camera: camera, toolbarListener: self, presetListener: handler)
            
            handler.getPresets(cam: camera)
            handler.getImaging(camera: camera)
        }
        
        model.toolbarHidden = false
    }
    
    var body: some View {
        ZStack(alignment: .bottom){
            multicamView
            toolbar.hidden(model.toolbarHidden)
            ptzControls.hidden(model.ptzCtrlsHidden)
            
          
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
