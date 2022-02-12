//
//  SingleCameraView.swift
//  nxvpro
//
//  Created by Philip Bishop on 12/02/2022.
//

import SwiftUI

class SingleCameraModel : ObservableObject{
    @Published var toolbarHidden = true
    @Published var helpHidden = true
    @Published var settingsHidden = true
    
    var theCamera: Camera?
    @Published var cameraEventListener: CameraEventListener?
}

struct SingleCameraView : View, CameraToolbarListener, ContextHelpViewListener{
    
    @ObservedObject var model = SingleCameraModel()
    
    let thePlayer = CameraStreamingView()
    let toolbar = CameraToolbarView()
    let helpView = ContextHelpView()
    let settingsView = CameraPropertiesView()
    
    func setCamera(camera: Camera,listener: VLCPlayerReady,eventListener: CameraEventListener){
        model.theCamera = camera
        model.cameraEventListener = eventListener
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
        switch(cameraEvent){
        case .Ptz:
            //action on model.theCamera
            break
        case .Vmd:
            
            break
            
        case .Record:
            break
            
        case .Rotate:
            break
            
        case .Settings:
            settingsView.setCamera(camera: model.theCamera!)
            model.settingsHidden = false
            model.helpHidden = true
            break
        
        case .ProfileChanged:
            model.theCamera?.flagChanged()
            
            model.cameraEventListener?.onCameraNameChanged(camera: model.theCamera!)
            
            if settingsView.hasProfileChanged(){
                //reconnect to camera
                print("Camera profile changed",model.theCamera?.getDisplayName())
                model.cameraEventListener?.onCameraSelected(camera: model.theCamera!, isMulticamView: false)
            }
            break
        case .CloseSettings:
            model.settingsHidden = true
            break;
        case .Help:
            
            helpView.setContext(contextId: 0, listener: self)
            model.settingsHidden = true
            model.helpHidden = false
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
