//
//  OnDeviceStorage.swift
//  nxvpro
//
//  Created by Philip Bishop on 14/02/2022.
//

import SwiftUI


class OnDeviceStorageModel : ObservableObject{
    var camera: Camera?
    
}

struct OnDeviceStorageView : View{

    @ObservedObject var model = OnDeviceStorageModel()
    
    let videosList = OnDeviceVideoItemsView()
    
    func setCamera(camera: Camera){
        model.camera = camera
        videosList.refresh(camera: camera)
    }
    func refresh(){
        if let cam = model.camera{
            videosList.refresh(camera: cam)
            //model.vizState = model.vizState + 1
        }
    }
    var body: some View {
        ZStack{
            
                videosList
            
        }.onAppear {
            if let cam = model.camera{
                videosList.refresh(camera: cam)
                print("OnDeviceStorageView:OnAppear",cam.getDisplayName())
            }
        }
    }
}
