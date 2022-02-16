//
//  NvrHeader.swift
//  DesignIdeas
//
//  Created by Philip Bishop on 05/09/2021.
//

import SwiftUI

class GroupHeaderModel : ObservableObject {
    @Published var groupName: String
    @Published var isEditMode: Bool
    @Published var playEnabled = true
    @Published var rotation: Double = 90
    
    var allGroups: [CameraGroup]
    
    var group: CameraGroup
    
    init(group: CameraGroup,allGroups: [CameraGroup]){
        self.group = group
        self.allGroups = allGroups
        self.isEditMode = false
        self.groupName = group.name
        self.playEnabled = true
    }
    
    func validateChange() -> Bool{
        if groupName.lowercased() == CameraGroup.DEFAULT_GROUP_NAME.lowercased(){
            return false
        }
        for cg in allGroups{
            if cg.id == group.id {
                continue
            }
            if cg.name.lowercased() == groupName.lowercased(){
                return false
            }
        }
        return true
    }
}
class GroupHeaderFactory{
    static var groupHeaders = [GroupHeader]()
    static var nvrHeaders = [NvrHeader]()
    
    static func getNvrHeader(camera: Camera) -> NvrHeader{
        for nvrh in nvrHeaders{
            if nvrh.camera.id == camera.id{
                return nvrh
            }
        }
        let nh = NvrHeader(camera: camera)
        nvrHeaders.append(nh)
        return nh
    }
    
    static func getHeader(group: CameraGroup,allGroups: [CameraGroup]) -> GroupHeader{
        for gh in groupHeaders{
            if gh.model.group.id == group.id{
                return gh
            }
        }
        let groupHeader = GroupHeader(group: group, allGroups: allGroups)
        groupHeaders.append(groupHeader)
        return groupHeader
    }
    static func enableAllPlay(){
        for gh in groupHeaders{
            gh.enablePlay(enable: true)
        }
        for nvrh in nvrHeaders{
            nvrh.enablePlay(enable: true)
        }
    }
    static func disablePlay(group: CameraGroup){
        for gh in groupHeaders{
            if gh.model.group.id == group.id{
                gh.enablePlay(enable: false)
            }else{
                gh.enablePlay(enable: true)
            }
        }
        for nvrh in nvrHeaders{
            if(nvrh.model.vGroup.id == group.id ){
                nvrh.enablePlay(enable: false)
            }else{
                nvrh.enablePlay(enable: true)
            }
        }
    }
}
struct GroupHeader: View {
    
   
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var iconModel = AppIconModel()
    
    @ObservedObject var model: GroupHeaderModel
   
    init(group: CameraGroup,allGroups: [CameraGroup]){
        self.model = GroupHeaderModel(group: group,allGroups: allGroups)
       
    }
    
    func enablePlay(enable: Bool){
        model.playEnabled = enable
    }
    var body: some View {
        HStack{
            Button(action: {
                if model.rotation == 0{
                    model.rotation = 90
                }else{
                    model.rotation = 0
                }
                for cam in model.group.cameras{
                    cam.vcamVisible = model.rotation == 90
                    
                }
                globalCameraEventListener?.onGroupStateChanged()
                
            }){
                Image(systemName: (model.rotation==0 ? "arrow.right.circle" : "arrow.down.circle")).resizable().frame(width: 18,height: 18)
            }.padding(0).buttonStyle(PlainButtonStyle())
            
            //Text(model.groupName).hidden(model.isEditMode).frame(alignment: .leading)
            TextField(model.groupName,text: $model.groupName,onEditingChanged: { edit in
                    
                },onCommit: {
                    //check isn't already in use
                    if model.groupName.count>=4 && model.validateChange(){
                        model.isEditMode = false
                        model.group.name = model.groupName
                        model.group.save()
                        //globalToolbarListener?.refreshCameraProperties()
                    }else{
                        //Sound.beep()
                       
                    }
                })
            /*
            ZStack(alignment: .topLeading){
                Text(model.groupName).hidden(model.isEditMode).frame(alignment: .leading)
                   
                    .onTapGesture {
                        model.isEditMode = true
                    }
                
                TextField(model.groupName,text: $model.groupName,onEditingChanged: { edit in
                        
                    },onCommit: {
                        //check isn't already in use
                        if model.groupName.count>=4 && model.validateChange(){
                            model.isEditMode = false
                            model.group.name = model.groupName
                            model.group.save()
                            //globalToolbarListener?.refreshCameraProperties()
                        }else{
                            //Sound.beep()
                           
                        }
                    }).textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame( alignment: .leading)
                    .hidden(model.isEditMode ==  false)
            }
           */
            
            Spacer()
            
            Button(action:{
                //globalToolbarListener?.openGroupMulticams(group: model.group)
            }){
                Image(systemName: "play").resizable()
                    .opacity((model.playEnabled ? 1 : 0.5))
                    .frame(width: 16,height: 16)
            }.buttonStyle(PlainButtonStyle()).disabled(model.playEnabled==false)
                //.padding()
 
            
        }.onAppear(){
            iconModel.initIcons(isDark: colorScheme == .dark)
        }
    }
}


