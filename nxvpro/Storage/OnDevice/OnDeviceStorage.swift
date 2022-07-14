//
//  OnDeviceStorage.swift
//  nxvpro
//
//  Created by Philip Bishop on 14/02/2022.
//

import SwiftUI


class OnDeviceStorageModel : ObservableObject{
    @Published var cameras = [Camera]()
    
}

struct OnDeviceStorageView : View{

    @ObservedObject var model = OnDeviceStorageModel()
    
    let videosList = OnDeviceVideoItemsView()
    
    func setCamera(camera: Camera){
        model.cameras.removeAll()
        model.cameras.append(camera)
        videosList.refresh(cameras: model.cameras)
    }
    func setCameras(cameras: [Camera]){
        model.cameras.removeAll()
        model.cameras.append(contentsOf: cameras)
        videosList.refresh(cameras: model.cameras)
    }
    func refresh(){
        videosList.refresh(cameras: model.cameras)
        
    }
    var body: some View {
        ZStack{
            videosList
        }.onAppear {
            videosList.refresh(cameras: model.cameras)
            print("OnDeviceStorageView:OnAppear")
            
        }
    }
}
