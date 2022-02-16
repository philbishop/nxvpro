//
//  NxvProMulticamView.swift
//  nxvpro
//
//  Created by Philip Bishop on 16/02/2022.
//

import SwiftUI
class NxvProMulticamModel : ObservableObject{
    
}

struct NxvProMulticamView: View {

    @ObservedObject var model = NxvProMulticamModel()
    
    let multicamView = MulticamView2()
    
    let toolbar = CameraToolbarView()
    let helpView = ContextHelpView()
    let settingsView = CameraPropertiesView()
    let ptzControls = PTZControls()
    let presetsView = PtzPresetView()
    let imagingCtrls = ImagingControlsContainer()
    
    func setCameras(cameras: [Camera]){
        multicamView.setCameras(cameras: cameras)
    }
    
    var body: some View {
        ZStack(alignment: .bottomLeading){
            multicamView
        }
    }
}

struct NxvProMulticamView_Previews: PreviewProvider {
    static var previews: some View {
        NxvProMulticamView()
    }
}
