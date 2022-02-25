//
//  CameraEventHandler.swift
//  nxvpro
//
//  Created by Philip Bishop on 19/02/2022.
//

import SwiftUI

class CameraEventHandler : PtzPresetEventListener,ImagingActionListener,ContextHelpViewListener{
    
    @ObservedObject var model: SingleCameraModel
    
    var helpView: ContextHelpView
    var settingsView: CameraPropertiesView
    var toolbar: CameraToolbarView
    var ptzControls: PTZControls
    var presetsView: PtzPresetView
    var imagingCtrls: ImagingControlsContainer
    
    init(model: SingleCameraModel,toolbar: CameraToolbarView,ptzControls: PTZControls,settingsView: CameraPropertiesView,helpView: ContextHelpView
    ,presetsView: PtzPresetView,imagingCtrls: ImagingControlsContainer){
        self.model = model
        self.toolbar = toolbar
        self.ptzControls = ptzControls
        self.settingsView = settingsView
        self.helpView = helpView
        
        self.presetsView = presetsView
        self.imagingCtrls = imagingCtrls
    }
    //MARK: ContextHelpViewListener
    func onCloseHelp() {
        model.helpHidden = true
    }
    //MARK: CameraToolbarListener
    func itemSelected(cameraEvent: CameraActionEvent,thePlayer: CameraStreamingView?) {
       
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
            model.hideConrols()
            model.ptzCtrlsHidden = false
            break
        case .Vmd:
            model.hideConrols()
            
            model.vmdCtrlsHidden = false
            break
        
        case .Record:
            if let player = thePlayer{
            let isRecording = player.startStopRecording(camera: cam)
                toolbar.setSettingsEnabled(enabled: isRecording == false)
                toolbar.iconModel.recordingStatusChange(status: isRecording)
                model.recordingLabelHidden = isRecording == false
                print("isRecording: ",isRecording)
            }
            break
        case .Mute:
            if let player = thePlayer{
                cam.muted = !cam.muted
                cam.save()
                player.setMuted(muted: cam.muted)
            }
            break
        case .Rotate:
            if let player = thePlayer{
                player.rotateNext()
            }
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
            
        case .CloseVmd:
            model.vmdCtrlsHidden = true
            model.toolbarHidden = false
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
    
    func getPresets(cam: Camera){
        presetsView.reset()
        if cam.ptzXAddr.isEmpty == false{
            let disco = OnvifDisco()
            disco.prepare()
            disco.getPtzPresets(camera: cam) { camera, error, ok in
                DispatchQueue.main.async{
                   
                    self.presetsView.setCamera(camera: cam,listener: self)
                    self.ptzControls.model.setPresetsEnabled(enabled: ok)
                    
                }
            }
        }
    }
    
    //MARK: Imaging
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
}
