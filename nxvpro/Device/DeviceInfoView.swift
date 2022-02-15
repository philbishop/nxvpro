//
//  DeviceInfoView.swift
//  nxvpro
//
//  Created by Philip Bishop on 15/02/2022.
//

import SwiftUI

class DeviceInfoModel : ObservableObject{
    var camera: Camera?
    var isDirty = false
    var groups: CameraGroups?
    var existingGrpName: String = CameraGroup.DEFAULT_GROUP_NAME
    var recordRange: RecordProfileToken?
    var recordingResults: [RecordingResults]?
    
    @Published var listener: GroupChangedListener?
   
    @Published var camName: String = "" {
        didSet {
            if oldValue == camName{
                return
            }
            print("CameraPropertiesModel:camName changed",camName)
            //validate name and update camera
            if camName.count >= Camera.MIN_NAME_LEN {
                var displayName = camName
                if displayName.count > Camera.MAX_NAME_LEN {
                    
                    displayName = Helpers.truncateString(inStr: camName, length: Camera.MIN_NAME_LEN)
                }
                camName = displayName
            }
        }
    }
    func save(){
        if isDirty {
            camera?.save()
            
            let dcv = DiscoCameraViewFactory.getInstance(camera:  camera!)
            dcv.viewModel.cameraName = camera!.getDisplayName()
            
            //globalToolbarListener?.cameraPreferenceChanged(camera: camera!)
        }
        isDirty = false
    }

    func getExistingGroupName() ->String{
        if groups == nil{
            return CameraGroup.DEFAULT_GROUP_NAME
        }
        return groups!.getGroupNameFor(camera: camera!)
    }
    
    func getGroupNames() -> [String]{
        var grpNames = [String]()
        existingGrpName = "Cameras"
        
        if groups != nil{
            let names = groups!.getNames()
        
            existingGrpName = groups!.getGroupNameFor(camera: camera!)
            if existingGrpName != CameraGroup.DEFAULT_GROUP_NAME{
                grpNames.append(CameraGroup.DEFAULT_GROUP_NAME)
            }
            grpNames.append(existingGrpName)
            for name in names{
                if name != existingGrpName{
                    grpNames.append(name)
                }
            }
        }else{
            grpNames.append("Cameras")
        }
        grpNames.append("New group")
        return grpNames;
    }
}

struct DeviceInfoView: View {
    
    @ObservedObject var allProps = CameraProperies()
    @ObservedObject var profileProps = CameraProperies()
    @ObservedObject var editableProps = CameraProperies()
   
    @ObservedObject var model = DeviceInfoModel()
    
    @State var camera: Camera?
     
    
    
    func setCamera(camera: Camera,cameras: DiscoveredCameras,listener: GroupChangedListener){
        self.camera = camera
        model.listener = listener
        
        allProps.props = [CameraProperty]()
        profileProps.props = [CameraProperty]()
        
        editableProps.props = [CameraProperty]()
        model.camera = camera
        model.camName = camera.getDisplayName()
        model.groups =  cameras.cameraGroups
       
        editableProps.props.append(CameraProperty(id: 0,name: "Name",val: camera.getDisplayName(),editable: true))
        //if NxvPro add groups
        if camera.isVirtual == false{
            editableProps.props.append(CameraProperty(id: 1,name: "Group",val: "",editable: true))
           
        }
        var nextId = 0
        let camProps = camera.getProperties()
        
        for i in 0...camProps.count-1 {
            let cp = camProps[i]
            allProps.props.append(CameraProperty(id: nextId,name: cp.0,val: cp.1,editable: false))
            nextId += 1
        }
        
        let camProfiles = camera.getProfileProperties()
        if camProfiles.count > 0 {
            for i in 0...camProfiles.count-1 {
                let cp = camProfiles[i]
                profileProps.props.append(CameraProperty(id: nextId,name: cp.0,val: cp.1,editable: false))
                nextId += 1
            }
        }
        if model.recordRange != nil{
            addRecordProfile(rp: model.recordRange!,maxId: nextId)
        }
        
    }
    func addRecordProfile(rp: RecordProfileToken,maxId: Int){
        var nextId = maxId+1
        allProps.props.append(CameraProperty(id: nextId,name: "RECORDINGS",val: "",editable: false))
        nextId += 1
        //allProps.props.append(CameraProperty(id: nextId,name: "Profile",val: rp.recordingToken,editable: false))
        //nextId += 1
        allProps.props.append(CameraProperty(id: nextId,name: "Earliest recording",val: rp.earliestRecording,editable: false))
        nextId += 1
        allProps.props.append(CameraProperty(id: nextId,name: "Latest recording",val: rp.latestRecording,editable: false))
        
        if let results = model.recordingResults{
            let fmt = DateFormatter()
            fmt.dateFormat = "dd MMM yyyy"
            
            for rt in results{
                nextId += 1
                let dstr = fmt.string(from: rt.date)
                let vstr = String(rt.results.count)
                allProps.props.append(CameraProperty(id: nextId,name: dstr,val: vstr,editable: false))
                
            }
        }
        
    }
   
    var body: some View {
        
        let grpSelector = GroupSelectorView(camera: model.camera,groups: model.getGroupNames(),existingGrp: model.getExistingGroupName())
        let textField = TextField("",text: $model.camName)

        List(){
            Section(header: Text("Preferences")){
               
                     ForEach(editableProps.props, id: \.self) { prop in
                        HStack{
                            Text(prop.name).fontWeight(.bold).appFont(.caption)
                                .frame(width: 150,alignment: .leading)
                          
                            if prop.name == "Group"{
                               
                                grpSelector.frame(alignment: .leading)
                                
                            }else{
                                textField.appFont(.caption)
                                    .frame(width: 150)
                            }
                        }.frame(alignment: .leading)
                    }
                

            }
            Section(header: Text("Device details")){
            
                ForEach(allProps.props, id: \.self) { prop in
                    HStack{
                        Text(prop.name).fontWeight(prop.val.isEmpty ? .none : /*@START_MENU_TOKEN@*/.bold/*@END_MENU_TOKEN@*/).appFont(.caption)
                            .frame(width: 150,alignment: .leading)
                        
                        Text(prop.val).appFont(.caption)
                        
                    }.frame(alignment: .leading)
                }
            }
            Section(header: Text("Device profiles")){
            
                ForEach(profileProps.props, id: \.self) { prop in
                    HStack{
                        Text(prop.name).fontWeight(prop.val.isEmpty ? .none : /*@START_MENU_TOKEN@*/.bold/*@END_MENU_TOKEN@*/).appFont(.caption)
                            .frame(width: 150,alignment: .leading)
                        
                        Text(prop.val).appFont(.caption)
                        
                    }.frame(alignment: .leading)
                }
            }
            Spacer()
            
            
        }.listStyle(PlainListStyle()).onDisappear(){
            model.save()
        }.onAppear(){
            if model.listener != nil{
                grpSelector.setListener(listener: model.listener!)
            }
            
        }
        
    }
    
}

struct DeviceInfoView_Previews: PreviewProvider {
    static var previews: some View {
        DeviceInfoView()
    }
}
