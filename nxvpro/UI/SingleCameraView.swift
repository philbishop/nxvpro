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
    
    var theCamera: Camera?
    @Published var cameraEventListener: CameraEventListener?
}

struct SingleCameraView : View, CameraToolbarListener, ContextHelpViewListener, PtzPresetEventListener, ImagingActionListener{
    
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
        ptzControls.setCamera(camera: camera, toolbarListener: self, presetListener: self)
        thePlayer.setCamera(camera: camera,listener: listener)
        getPresets(cam: camera)
        getImaging(camera: camera)
    }
    func stop(camera: Camera) -> Bool{
        
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
    func itemSelected(cameraEvent: CameraEvent) {
        //Ptz, Vmd, Mute, Record, Cloud, Rotate, Settings, Help, CloseToolbar, ProfileChanged, CapturedVideos, StopVideoPlayer, StopMulticams, Feedback, StopMulticamsShortcut, Imaging
        
        guard let cam = model.theCamera else{
            print("SingleCameraView:itemSelected model.theCamera == nil")
            return
        }
        
        switch(cameraEvent){
        case .Imaging:
            imagingCtrls.setCamera(camera: cam, listener: self,isEncoderUpdate: true)
            model.imagingHidden = false
            break
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
                helpContext = 2
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
    
    func getPresets(cam: Camera){
        presetsView.reset()
        if cam.ptzXAddr.isEmpty == false{
            let disco = OnvifDisco()
            disco.prepare()
            disco.getPtzPresets(camera: cam) { camera, error, ok in
                DispatchQueue.main.async{
                   
                        presetsView.setCamera(camera: cam,listener: self)
                        ptzControls.model.setPresetsEnabled(enabled: ok)
                    
                }
            }
        }
    }
    //MARK: PtzPresetEventListener
    func cancelCreatePreset(){
        presetsView.cancel()
        
    }
    func togglePtzPresets(){
        model.presetsHidden = !model.presetsHidden
        if model.presetsHidden == false{
            model.settingsHidden = true
            model.helpHidden = true
        }
    }
    func hidePtzPresets(){
        model.presetsHidden = true
    }
    func gotoPtzPreset(camera: Camera,presetToken: String){
        
        let handler = PtzPresetsHandler(presetsView: presetsView, listener: self)
        handler.gotoPtzPreset(camera: camera, presetToken: presetToken)
        
    }
    
    func deletePtzPreset(camera: Camera,presetToken: String){
        let handler = PtzPresetsHandler(presetsView: presetsView, listener: self)
        handler.deletePtzPreset(camera: camera, presetToken: presetToken)
    }
    func createPtzPreset(camera: Camera, presetName: String){
        //NOT USED
    }
    func createPtzPresetWithCallback(camera: Camera, presetName: String,callback: @escaping (Camera,String,Bool)->Void){
     
        let handler = PtzPresetsHandler(presetsView: presetsView, listener: self)
        handler.createPtzPresetWithCallback(camera: camera, presetName: presetName, callback: callback)
        
    }
    func getImaging(camera: Camera){
        let handler = ImagingHandler(imagingCtrls: imagingCtrls, cameraToolbarInstance: toolbar, listener: self)
        handler.getImaging(camera: camera)
    }
    
    //MARK: ImagingActionListener
    
    func applyImagingChanges(camera: Camera){
        let handler = ImagingHandler(imagingCtrls: imagingCtrls, cameraToolbarInstance: toolbar, listener: self)
        handler.applyImagingChanges(camera: camera)
    }
    func closeImagingView(){
        model.imagingHidden = true
    }
    func applyEncoderChanges(camera: Camera,success: Bool){
        let handler = ImagingHandler(imagingCtrls: imagingCtrls, cameraToolbarInstance: toolbar, listener: self)
        handler.applyEncoderChanges(camera: camera, success: success)
    }
    func imagingItemChanged(){
        imagingCtrls.imagingItemChanged()
    }
    func encoderItemChanged(){
        imagingCtrls.encoderItemChanged()
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
