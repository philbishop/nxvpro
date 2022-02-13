//
//  ImagingHandler.swift
//  nxvpro
//
//  Created by Philip Bishop on 13/02/2022.
//

import SwiftUI

class ImagingHandler{
    var imagingCtrls: ImagingControlsContainer
    var cameraToolbarInstance: CameraToolbarView
    var listener: ImagingActionListener
    let disco = OnvifDisco()
    
    init(imagingCtrls: ImagingControlsContainer,cameraToolbarInstance: CameraToolbarView,listener: ImagingActionListener){
        self.imagingCtrls = imagingCtrls
        self.cameraToolbarInstance = cameraToolbarInstance
        self.listener = listener
        self.disco.prepare()
    }
    func getImaging(camera: Camera){
        if camera.imagingXAddr.isEmpty == false{
            let disco = OnvifDisco()
            disco.prepare()
            disco.getImagingOptions(camera: camera,callback: imagingUpdated)
        }
    }
    func imagingUpdated(camera: Camera){
        if let opts = camera.imagingOpts{
            print("ImagingHandler:imagingUpdated",opts.count)
              }
        
        print("ImagingHandler:imagingUpdated",camera.getDisplayAddr())
        DispatchQueue.main.async{
            let settingsBtnEnabled = true //camera.hasImaging()
            var currentImagingCtrls = self.imagingCtrls
            
            self.cameraToolbarInstance.setImagingEnabled(enabled: settingsBtnEnabled)
            
            currentImagingCtrls.setStatus("")
            if camera.imagingFault.isEmpty == false{
                currentImagingCtrls.model.status = camera.imagingFault
                
                camera.imagingFault = ""
            }else{
                currentImagingCtrls.imagingView.cameraUpdated(camera: camera)
                
            }
            
        }
    }
    
    
    func applyImagingChanges(camera: Camera) {
        disco.applyImagingSettings(camera: camera,callback: imagingUpdated)
    }
    func applyEncoderChanges(camera: Camera,success: Bool) {
        //TO DO
        DispatchQueue.main.async{
            if success{
                //update camera item with any change to resolution
                DiscoCameraViewFactory.getInstance(camera: camera).onCameraChanged()
                
            }else{
                self.imagingCtrls.setStatus("FAILED")
            }
            self.imagingCtrls.setStatus("")
            self.imagingCtrls.setCamera(camera: camera,listener: self.listener,isEncoderUpdate: true)
            
        }
    }
}