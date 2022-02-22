//
//  NvrHeader.swift
//  DesignIdeas
//
//  Created by Philip Bishop on 05/09/2021.
//

import SwiftUI


class GroupHeaderFactory{
    static var groupHeaders = [GroupHeader]()
    static var nvrHeaders = [NvrHeader]()
    
    static func checkAndEnablePlay(){
        //first check if we have a group playing, if so don't enable play
        for gh in groupHeaders{
            if gh.model.isPlaying{
                return
            }
        }
        for gh in nvrHeaders{
            if gh.model.isPlaying{
                return
            }
        }
        //no check
        for gh in groupHeaders{
            gh.model.checkAndEnablePlay()
        }
        for gh in nvrHeaders{
            gh.model.checkAndEnablePlay()
        }
    }
    
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
    static func nameChanged(group: CameraGroup){
        for gh in groupHeaders{
            if gh.model.group.id == group.id{
                gh.updateGroup(group: group)
                break
            }
        }
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
    static func disableNotPlaying(){
        for gh in groupHeaders{
            if gh.model.isPlaying == false{
                gh.model.playEnabled = false
            }
        }
        for gh in nvrHeaders{
            if gh.model.isPlaying == false{
                gh.model.playEnabled = false
            }
        }
    }
    static func resetPlayState(){
        for gh in groupHeaders{
            gh.model.isPlaying = false
        }
        for gh in nvrHeaders{
            gh.model.isPlaying = false
        }
        checkAndEnablePlay()
    }
    /*
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
     */
}
class GroupHeaderModel : ObservableObject {
    @Published var groupName: String
    @Published var isEditMode: Bool
    @Published var playEnabled = false
    @Published var rotation: Double = 90
    @Published var isPlaying = false
    @Published var showEdit = false
    @Published var vizId = 1
    
    var allGroups: [CameraGroup]
    
    var group: CameraGroup
    
    init(group: CameraGroup,allGroups: [CameraGroup]){
        self.group = group
        self.allGroups = allGroups
        self.isEditMode = false
        self.groupName = group.name
        self.playEnabled = true
    }
    
    func checkAndEnablePlay(){
        var nFavs = 0
        for cam in group.cameras{
            if cam.isFavorite && cam.isAuthenticated(){
                nFavs += 1
            }
        }
        playEnabled = nFavs > 1
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
struct GroupHeader: View, NXSheetDimissListener {
    
   
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var iconModel = AppIconModel()
    
    @ObservedObject var model: GroupHeaderModel
   
    init(group: CameraGroup,allGroups: [CameraGroup]){
        self.model = GroupHeaderModel(group: group,allGroups: allGroups)
       
    }
    func updateGroup(group: CameraGroup){
        model.group = group
        model.groupName = group.name
        model.vizId = model.vizId + 1
        
    }
    func dismissSheet() {
        model.showEdit = false
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
            
            if model.vizId > 0{
                Text(model.groupName).frame(alignment: .leading).onTapGesture {
                    //print("GroupHeader name tapped",model.$groupName)
                    model.showEdit = true
                    //show the groups sheet used for New Group
                }.sheet(isPresented: $model.showEdit) {
                    model.showEdit = false
                } content: {
                    GroupPropertiesSheet(group: model.group,allGroups: model.allGroups, listener: self)
                }
            }
            
           /*
            TextField(model.groupName,text: $model.groupName,onEditingChanged: { edit in
                    
                },onCommit: {
                    //check isn't already in use
                    if model.groupName.count>=4 && model.validateChange(){
                        model.isEditMode = false
                        model.group.name = model.groupName
                        model.group.save()
                        globalCameraEventListener?.refreshCameraProperties()
                    }else{
                        //Sound.beep()
                       
                    }
            })
            */
            
            Spacer()
            
            Button(action:{
                //state change must be first
                model.isPlaying = true
                globalCameraEventListener?.openGroupMulticams(group: model.group)
               
            }){
                Image(systemName: model.isPlaying ? "play.slash" : "play").resizable()
                    .opacity((model.playEnabled ? 1 : 0.5))
                    .frame(width: 16,height: 16)
            }.buttonStyle(PlainButtonStyle()).disabled(model.playEnabled==false)
                //.padding()
 
            
        }.onAppear(){
            iconModel.initIcons(isDark: colorScheme == .dark)
        }
    }
}


