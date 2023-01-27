//
//  LocationGroupHeader.swift
//  NX-V
//
//  Created by Philip Bishop on 23/01/2022.
//

import SwiftUI

class LocationHeaderFactory{
    static var groupHeaders = [LocationHeader]()
    static var nvrHeaders = [LocationHeader]()
    static var unassignedHeader: LocationHeader?
    
    static func getUnassignedHeader(cameras: [Camera],cameraGroups: CameraGroups) -> LocationHeader{
        
        var uGroup = CameraGroup()
        uGroup.name = Camera.DEFAULT_TAB_NAME
        for cam in cameras{
            if !cam.isNvr() && !cameraGroups.isCameraInGroup(camera: cam){
                uGroup.cameras.append(cam)
            }
        }
        if unassignedHeader == nil{
            unassignedHeader = LocationHeader(group: uGroup)
        }else{
            unassignedHeader!.model.group = uGroup
        }
        return unassignedHeader!
    }
    
    static func getHeader(group: CameraGroup) -> LocationHeader{
        for gh in groupHeaders{
            if gh.model.group.id == group.id{
                return gh
            }
        }
        let groupHeader = LocationHeader(group: group)
        groupHeaders.append(groupHeader)
        return groupHeader
    }
    static func getHeader(nvr: Camera) -> LocationHeader{
        for gh in nvrHeaders{
            if let groupNvr = gh.model.nvr{
                if groupNvr.getStringUid() == nvr.getStringUid(){
                    return gh
                }
            }
        }
        let groupHeader = LocationHeader(nvr: nvr)
        nvrHeaders.append(groupHeader)
        return groupHeader
    }
    static func expandCollapseAll(expanded: Bool){
        for gh in groupHeaders{
            if expanded{
                gh.expand()
            }else{
                gh.collapse()
            }
        }
        for gh in nvrHeaders{
            if expanded{
                gh.expand()
            }else{
                gh.collapse()
            }
        }
        
        if let gh = unassignedHeader{
            if expanded{
                gh.expand()
            }else{
                gh.collapse()
            }
        }
    }
}

class LocationHeaderModel : ObservableObject {

    @Published var groupName: String
    @Published var rotation: Double = 90
    @Published var vizId = 1
    @Published var miniMapEnabled = false
    
    var nvr: Camera?
    var group: CameraGroup
    var cameras = [Camera]()
    
    init(nvr: Camera){
        self.nvr = nvr
        group = CameraGroup()
        group.name = nvr.getDisplayName()
        nvr.getVirtualCameras()
        group.cameras = nvr.vcams
        groupName = group.name
        
    }
    
    init(group: CameraGroup){
        self.group = group
        self.groupName = group.name
        self.cameras = group.cameras
    }
}

struct LocationHeader: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var iconModel = AppIconModel()
    
    @ObservedObject var model: LocationHeaderModel
   
    init(nvr: Camera){
        self.model = LocationHeaderModel(nvr: nvr)
    }
    
    init(group: CameraGroup){
        self.model = LocationHeaderModel(group: group)
    }
    func collapse(){
        model.rotation = 0
        updateVisibility()
    }
    func expand(){
        model.rotation = 90
        updateVisibility()
    }
    private func updateVisibility(){
        if let nvr = model.nvr{
            nvr.locCamVisible = model.rotation == 90
        }else{
            for cam in model.group.cameras{
                cam.locCamVisible = model.rotation == 90
                
            }
        }
    }
    var body: some View {
        HStack{
            Button(action: {
                if model.rotation == 0{
                    model.rotation = 90
                }else{
                    model.rotation = 0
                }
                updateVisibility()
                globalCameraEventListener?.onGroupStateChanged(reload: false)
                
            }){
                Image(systemName: (model.rotation==0 ? "arrow.right.circle" : "arrow.down.circle")).resizable().frame(width: 18,height: 18)
            }.padding(0).buttonStyle(PlainButtonStyle())
            
            if model.vizId > 0{
                Text(model.groupName).frame(alignment: .leading)
                Spacer()
                Button(action:{
                    AppLog.write("Open mini map for group NOT Implemented yet")
                    //globalToolbarListener?.openMiniMap(group: model.group)
                }){
                    Image(systemName: "mappin").resizable().rotationEffect(Angle(degrees: 180))
                        .frame(width: 14, height: 14, alignment: .center)
                        .padding(.trailing)
                }.buttonStyle(PlainButtonStyle())
                    .hidden(model.miniMapEnabled==false)
            }
        }
    }
}
