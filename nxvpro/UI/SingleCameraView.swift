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
    
    var theCamera: Camera?
    @Published var cameraEventListener: CameraEventListener?
}

struct SingleCameraView : View, CameraToolbarListener, ContextHelpViewListener{
    
    @ObservedObject var model = SingleCameraModel()
    
    let thePlayer = CameraStreamingView()
    let toolbar = CameraToolbarView()
    let helpView = ContextHelpView()
    let settingsView = CameraPropertiesView()
    let ptzControls = PTZControls()
    
    func setCamera(camera: Camera,listener: VLCPlayerReady,eventListener: CameraEventListener){
        model.theCamera = camera
        model.cameraEventListener = eventListener
        toolbar.setCamera(camera: camera)
        ptzControls.setCamera(camera: camera, toolbarListener: self, presetListener: nil)
        thePlayer.setCamera(camera: camera,listener: listener)
    }
    
    func hideControls(){
        model.toolbarHidden = true
        model.settingsHidden = true
        model.helpHidden = true
        
    }
    func showToolbar(){
        model.toolbarHidden = false
    }
    
    //MARK: ContextHelpViewListener
    func onCloseHelp() {
        model.helpHidden = true
    }
    
    //MARK: CameraToolbarListener
    func itemSelected(cameraEvent: CameraEvent) {
        //Ptz, Vmd, Mute, Record, Cloud, Rotate, Settings, Help, CloseToolbar, ProfileChanged, CapturedVideos, StopVideoPlayer, StopMulticams, Feedback, StopMulticamsShortcut, Imaging
        
        guard let cam = model.theCamera else{
            print("SingleCameraView:itemSelected model.theCamera == nil")
            return
        }
        
        switch(cameraEvent){
        case .Ptz:
            //action on model.theCamera
            model.toolbarHidden = true
            model.ptzCtrlsHidden = false
            break
        case .Vmd:
            
            break
            
        case .Record:
            break
        case .Mute:
            cam.muted = !cam.muted
            cam.save()
            thePlayer.setMuted(muted: cam.muted)
            break
        case .Rotate:
            thePlayer.rotateNext()
            break
            
        case .Settings:
            settingsView.setCamera(camera: cam)
            model.settingsHidden = false
            model.helpHidden = true
            break
        
        case .ProfileChanged:
            model.theCamera?.flagChanged()
            
            model.cameraEventListener?.onCameraNameChanged(camera:cam)
            
            if settingsView.hasProfileChanged(){
                //reconnect to camera
                print("Camera profile changed",cam.getDisplayName())
                model.cameraEventListener?.onCameraSelected(camera: cam, isMulticamView: false)
            }
            break
        case .CloseSettings:
            model.settingsHidden = true
            break;
        case .Help:
            var helpContext = 0
            if model.ptzCtrlsHidden == false{
                helpContext = 1
            }
            helpView.setContext(contextId: helpContext, listener: self)
            model.presetsHidden = true
            model.settingsHidden = true
            model.helpHidden = false
            break
         
        case .CloseToolbar:
            if model.ptzCtrlsHidden == false{
                model.ptzCtrlsHidden = true
                model.toolbarHidden = false
            }
            break
        default:
            break
        }
    }
    
    
    //MARK: BODY
    var body: some View {
        ZStack(alignment: .bottom){
            thePlayer
            toolbar.hidden(model.toolbarHidden)
            ptzControls.hidden(model.ptzCtrlsHidden)
            
            VStack{
                Spacer()
                HStack{
                    Spacer()
                    ZStack{
                        helpView.hidden(model.helpHidden)
                        settingsView.hidden(model.settingsHidden)
                    }
                }
                Spacer()
                
            }
        }.onAppear{
            toolbar.setListener(listener: self)
            settingsView.model.listener = self
        }
    }
}
