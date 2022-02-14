//
//  OnDeviceStorage.swift
//  nxvpro
//
//  Created by Philip Bishop on 14/02/2022.
//

import SwiftUI



struct OnDeviceStorageView : View{

    let videosList = OnDeviceVideoItemsView()
    
    func setCamera(camera: Camera){
        videosList.refresh(camera: camera)
    }
    
    var body: some View {
         videosList
    }
}
