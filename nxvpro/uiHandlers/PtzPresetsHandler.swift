//
//  PtzPresetsHandler.swift
//  nxvpro
//
//  Created by Philip Bishop on 13/02/2022.
//

import SwiftUI

class PtzPresetsHandler{
    var presetsView: PtzPresetView
    var listener: PtzPresetEventListener
    
    init(presetsView: PtzPresetView,listener: PtzPresetEventListener){
        self.presetsView = presetsView
        self.listener = listener
    }
    func gotoPtzPreset(camera: Camera,presetToken: String){
        let disco = OnvifDisco()
        disco.prepare()
        disco.gotoPtzPreset(camera: camera, presetToken: presetToken) { cam, error, ok in
            DispatchQueue.main.async {
                
                self.presetsView.gotoComplete(ok: ok, error: error)
                
            }
        }
    }
    
    func deletePtzPreset(camera: Camera,presetToken: String){
        AppLog.write("SingleCameraView:deletePtzPreset",presetToken)
        let disco = OnvifDisco()
        disco.prepare()
        disco.deletePtzPreset(camera: camera, presetToken: presetToken) { cam, error, ok in
            
            DispatchQueue.main.async {
                self.presetsView.deleteComplete(ok: ok, error: error)
            }
        }
    }
    
    func createPtzPresetWithCallback(camera: Camera, presetName: String,callback: @escaping (Camera,String,Bool)->Void){
     
        for ps in camera.ptzPresets!{
            if ps.name == presetName{
                callback(camera,"Duplicate name, to change an existing preset delete it first",false)
                return
            }
        }
        let notAllowed = "<>/\\&%"
        let characterSet = CharacterSet(charactersIn: notAllowed)
        let check = presetName.rangeOfCharacter(from: characterSet)
        if check != nil {
            callback(camera,"Name contains illegal characters",false)
            return
        }
        let disco = OnvifDisco()
        disco.prepare()
        disco.createPtzPreset(camera: camera, presetToken: presetName) { cam, error, ok in
            DispatchQueue.main.async {
                //new token has been added to camera
                if ok{
                    
                    self.presetsView.setCamera(camera: camera,listener: self.listener)
                }
                callback(camera,error,ok)
            }
        }
    }
}

