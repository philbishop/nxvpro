//
//  CameraSettingsView.swift
//  NX-V
//
//  Created by Philip Bishop on 02/06/2021.
//

import SwiftUI

class CameraProperies : ObservableObject{
    @Published var props = [CameraProperty]()
}

struct CameraProperty : Hashable {
    
    var id: Int = 0
    var name: String = ""
    var val: String = ""
    var editable: Bool = false
    
    init(id: Int,name: String,val: String,editable: Bool){
        self.id = id
        self.name = name
        self.val = val
        self.editable = editable
    }
    
}
class CameraPropertiesModel : ObservableObject{
    var camera: Camera?
    var isDirty = false
    var profileChanged = false
    var listener: CameraToolbarListener?
    var nameChanged = false
    var recordRange: RecordProfileToken?
    var recordingResults: [RecordingResults]?
    
   // @Published var copyToClipText: String = "Copy all camera details to clipboard"
    @Published var makeModel: String = ""
    //@Published var profile1: String = ""
    //@Published var profile2: String = ""
    
    @Published var profiles = [String]()
    
    @Published var selectedprofile: String = ""
    @Published var profilesLabel = "Profiles"
    
    @Published var closeLabel: String = "Close"
    
    @Published var nameColor: Color = Color(UIColor.label)
    
    @Published var camName: String = "" {
        didSet {
            //AppLog.write("CameraPropertiesModel:camName changed",camName)
            //validate name and update camera
            if camName.count > Camera.MAX_NAME_LEN {
                camName.removeLast()
            }
        
            isDirty = camName.count>=Camera.MIN_NAME_LEN
            if isDirty{
                nameChanged = true
                camera!.displayName = camName
                nameColor = Color(UIColor.label)
            }else{
                nameColor = Color(UIColor.red)
            }
            checkDirty()
        }
    }
    func reset()
    {
        profiles = [String]()
        profilesLabel = "Profiles"
        selectedprofile = ""
        nameChanged = false
        profileChanged = false
    }
    func selectedProfileChanged(pfn: String)
    {
        for i in 0...profiles.count-1{
            if pfn ==  profiles[i]{
                camera!.profileIndex = i
                flagProfileChanged()
                break;
            }
        }
        
    }
    func flagProfileChanged(){
        isDirty = true
        profileChanged = true
        checkDirty()
    }
    func checkDirty(){
        
        closeLabel = isDirty ? "Apply changes" : "Close"
    }
    func save(){
        if isDirty {
            camera?.save()
            camera?.flagChanged()
            listener?.itemSelected(cameraEvent: CameraActionEvent.ProfileChanged)
            
        }
        isDirty = false
    }
}

struct CameraPropertiesView: View {

    @ObservedObject var allProps = CameraProperies()
    
    @ObservedObject var model = CameraPropertiesModel()
     
    @State var camera: Camera?
    @State var clipBtnDisabled = false
    
    func setCamera(camera: Camera){
        self.camera = camera
        model.reset()
        allProps.props = [CameraProperty]()
        model.camera = camera
        model.camName = camera.getDisplayName()
        model.makeModel = camera.makeModel
        model.profiles = [String]()
        
        let useRes = camera.profiles.count<4
        if camera.profiles.count > 0{
            for pf in camera.profiles{
                model.profiles.append(pf.getDisplayName(useResolution: useRes))
            }
            model.selectedprofile = camera.selectedProfile()!.getDisplayName(useResolution: useRes)
        }
        
        model.profilesLabel = "Profiles (" + String(camera.profiles.count) + ")"
        
        model.closeLabel = "Close"
        model.profileChanged = false;
        model.isDirty = false
        
        allProps.props.append(CameraProperty(id: 0,name: "Name",val: camera.getDisplayName(),editable: true))
        
        let camProps = camera.getProperties()
        
        for i in 0...camProps.count-1 {
            let cp = camProps[i]
            allProps.props.append(CameraProperty(id: i+1,name: cp.0,val: cp.1,editable: false))
        }
        
    }
   
    func hasProfileChanged() -> Bool{
        return model.profileChanged
    }
    func hasNameChanged() -> Bool{
        return model.nameChanged
    }
    var fontSize = CGFloat(14)
    @State var isFirstResponder = false
    @State var selected = 0
    
    var characterLimit = 14
    
    var body: some View {
        ZStack(alignment: .top){
            Color(UIColor.secondarySystemBackground)
            ScrollView(showsIndicators: false){
                VStack(alignment: .leading,spacing: 10){
                    Text("Camera properties").fontWeight(.semibold).appFont(.titleBar)
                    Divider()
                    Text("Name").fontWeight(.semibold).appFont(.caption).frame(alignment: .leading)
                   
                    TextField(model.camName,text: $model.camName, onEditingChanged: { (changed) in
                        //AppLog.write("Camera name onEditingChanged - \(changed)")
                    }) {
                        AppLog.write("Camera name onCommit")
                        model.save()
                    }.appFont(.body)
                    .foregroundColor(model.nameColor)
                    .border(Color.blue,width: 1)
                    
                    
                    Text("Make / Model").fontWeight(.semibold).appFont(.caption).frame(alignment: .leading)
                    
                    Text(model.makeModel).appFont(.body)
                   
                    Divider()
                    

                    Text(model.profilesLabel).fontWeight(.semibold).appFont(.caption).frame(alignment: .leading)
                    ScrollView(.vertical,showsIndicators: true) {
                        RadioButtonGroup(items: model.profiles, selectedId: model.selectedprofile) { selectedItem in
                                        AppLog.write("Profile selected is: \(selectedItem)")
                            
                            /*
                            if selectedItem == model.profile1 {
                                model.camera!.profileIndex = 0
                            }else{
                                model.camera!.profileIndex = 1
                            }
                             model.flagProfileChanged()
                            */
                            
                            model.selectedProfileChanged(pfn: selectedItem)
                            
                        }
                    }.frame(height: 90)
                    Spacer()
                }
                //Spacer()
            HStack{
                
                
                Button(action: {
                    model.save()
                    model.listener?.itemSelected(cameraEvent: .CloseSettings)
                }){
                    Text(model.closeLabel).appFont(.body)
                }
            }
        }.padding()
        }.cornerRadius(15).frame(width: 220,height: 350).padding(.vertical, 10)
        /*
        onDisappear(){
            AppLog.write("CameraSettings:onDisappear()")
            model.save()
        }.onAppear(){
            AppLog.write("CameraSettings:onAppear()")
        
            
        }
 */
    }
    
}
struct CameraPropertiesView_Previews: PreviewProvider {
    static var previews: some View {
        CameraPropertiesView()
    }
}

