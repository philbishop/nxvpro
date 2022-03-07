//
//  AppPlayState.swift
//  nxvpro
//
//  Created by Philip Bishop on 07/03/2022.
//

import SwiftUI

class AppPlayState : ObservableObject{
    
    @Published var active = false
    @Published var leftPaneWidth = CGFloat(0)
    @Published var isMulticam = false
    @Published var group: CameraGroup?
    @Published var multicams: [Camera]?
    @Published var camera: Camera?
    @Published var selectedCameraTab = CameraTab.none
    
    func reset(){
        active = false
        isMulticam = false
        group = nil
        camera = nil
        multicams = nil
        selectedCameraTab = CameraTab.none
    }
}
