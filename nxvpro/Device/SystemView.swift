//
//  SystemView.swift
//  TestMacUI
//
//  Created by Philip Bishop on 30/12/2021.
//

import SwiftUI

//
//  SystemView.swift
//  NX-V
//
//  Created by Philip Bishop on 30/12/2021.
//

import SwiftUI

protocol SystemModeAction{
    func onCancelled()
    func onUserModified(success: Bool,status: String,modifiedUser: CameraUser)
}

class SystemUserModel: ObservableObject{
    @Published var user = CameraUser(id: 0,name: "")
    @Published var editable = false
    @Published var applyDisabled = false
    @Published var newPwd = ""
    @Published var newUser = ""
    
    @Published var status = ""
    
    var camera: Camera?
    
    var listener: SystemModeAction?
    
    func reset(){
        newUser = ""
        newPwd = ""
        
        
    }
    func modifyUser(){
        let disco = OnvifDisco()
        disco.prepare()
        disco.modifyUser(camera: camera!, user: user) { cam, ok, error in
            DispatchQueue.main.async{
                self.applyDisabled = false
                self.listener?.onUserModified(success: ok, status: error,modifiedUser: self.user)
                
            }
        }
    }
    func createUser(){
        let disco = OnvifDisco()
        disco.prepare()
        disco.createUser(camera: camera!, user: user) { cam, ok, error in
            DispatchQueue.main.async{
                self.applyDisabled = false
                self.listener?.onUserModified(success: ok, status: error,modifiedUser: self.user)
                
            }
        }
    }
}
struct SystemUsersView: View {
    
    @ObservedObject var model = SystemUserModel()
    
    init(user: CameraUser){
        model.user = user
    }
    
    var body: some View {
        VStack(alignment: .leading){
            HStack(spacing: 5){
                Text("User name").fontWeight(.semibold)
                    .frame(width: 90, alignment: .leading)
                Text(model.user.name)
                Spacer()
            }
            HStack(spacing: 5){
                Text("Role").fontWeight(.semibold)
                    .frame(width: 90, alignment: .leading)
                Text(model.user.role)
                Spacer()
            }
        }.frame(width: 250, alignment: .leading)
    }
}
struct SystemCreatUserView: View {
    
    @ObservedObject var model = SystemUserModel()
    @State var selectedRole = "User"
    @State var roles = ["Administrator","Operator","User"]
    
    
    init(){
        model.user = CameraUser(id: 100,name: "")
    }
    
    func setUser(user: CameraUser){
        model.newUser = user.name
        model.newPwd = user.pwd
        selectedRole = user.role
        model.editable = true
    }
    
    var body: some View {
        VStack(alignment: .leading){
            Text(model.editable ? "Modify user" : "Create new user").appFont(.smallTitle)
            HStack(spacing: 5){
                Text("User name").fontWeight(.semibold).appFont(.caption)
                    .frame(width: 90, alignment: .leading)
                TextField("",text: $model.newUser).appFont(.caption)
                    .disabled(model.editable)
                Spacer()
            }
            HStack(spacing: 5){
                Text("Password").fontWeight(.semibold)
                    .frame(width: 90, alignment: .leading)
                TextField("",text: $model.newPwd)
                Spacer()
            }

            HStack(spacing: 5){
                Text("Role").fontWeight(.semibold).appFont(.caption)
                    .frame(width: 90, alignment: .leading)
                Picker("",selection: $selectedRole) {
                    ForEach(self.roles, id: \.self) {
                        Text($0).foregroundColor(Color(UIColor.label)).appFont(.caption)
                            
                    }
                }.onChange(of: selectedRole) { newRole in
                    print("role changed",newRole)
                    
                }
                Spacer()
            }
            HStack(spacing: 10){
                Spacer()
                
                Button("Cancel",action:{
                    model.listener?.onCancelled()
                }).appFont(.helpLabel)
             
                Button("Apply",action:{
                    model.status = "Saving...."
                    model.applyDisabled = true
                    
                    model.user = CameraUser(id: 100,name: model.newUser,pwd: model.newPwd,role: selectedRole)
                    if model.editable{
                        model.modifyUser()
                    }else{
                        model.createUser()
                    }
                    //global
                }).appFont(.helpLabel)
                    .disabled(model.applyDisabled)
            }
            
            Text(model.status).appFont(.caption).foregroundColor(.accentColor)
                .appFont(.caption)
            
        }.frame(width: 250, alignment: .leading)
    }
}

class SystemViewModel : ObservableObject{
    @Published var users = [CameraUser]()
    @Published var createEnabled = true
    @Published var deleteEnabled = false
    @Published var modifyEnabled = false
    @Published var selectedUser: CameraUser?
    @Published var createUserVisible = false
    @Published var confirmDeleteVisible = false
    @Published var confirmDeleteError = ""
    @Published var selectedUserString = ""
    
    var camera: Camera?
    
    func resetCamera(camera: Camera){
        
        self.selectedUser = nil
        self.confirmDeleteError = ""
        self.selectedUserString = ""
        self.createUserVisible = false
        self.createEnabled = true
        self.confirmDeleteVisible = false
        self.camera = camera
        
        self.users.removeAll()
        for user in camera.systemUsers{
            self.users.append(user)
        }
        
    }
    
    func handleSelectedUser(){
        let sameUser = camera!.user == selectedUser!.name
        
        deleteEnabled = !sameUser
        modifyEnabled = deleteEnabled
    }
    
    func modifyUser(updatedUser: CameraUser){
        for user in users{
            if user.name == updatedUser.name{
                user.role = updatedUser.role
            }
        }
    }
    func addUser(updatedUser: CameraUser){
        var maxId = 0
        for user in users{
            maxId = max(maxId,user.id)
        }
        
        updatedUser.id = maxId + 1
        
        users.append(updatedUser)
        
    }
    func deleteUser(deletedUser: CameraUser){
        var uindex = -1
        if users.count > 0{
            for i in 0...users.count-1{
                if users[i].name == deletedUser.name{
                    uindex = i
                    break
                }
            }
        }
        
        if uindex != -1{
            users.remove(at: uindex)
        }
    }
}

struct SystemView: View, SystemModeAction {
    @ObservedObject var model = SystemViewModel()
    @ObservedObject var iconModel = AppIconModel()
    
    var systemCreateView = SystemCreatUserView()
    
    func setCamera(camera: Camera){
        
        //refactor to model.setCamera
        model.resetCamera(camera: camera)
        systemCreateView.model.reset()
        systemCreateView.model.camera = camera
    
    }
    func deleteSelectedUser(){
        let disco = OnvifDisco()
        disco.prepare()
        disco.deleteUser(camera: model.camera!, user: model.selectedUser!) { cam, ok, error in
            DispatchQueue.main.async{
                if ok{
                    model.deleteUser(deletedUser: model.selectedUser!)
                }else{
                    print("Failed to delete user",error)
                    model.confirmDeleteError = error
                    model.confirmDeleteVisible  = true
                }
                
            }
        }
    }
    func onUserModified(success: Bool,status: String,modifiedUser: CameraUser){
        
        if success{
            //update users
            if status == "modify"{
                model.modifyUser(updatedUser: modifiedUser)
            }else if status == "create"{
                model.addUser(updatedUser: modifiedUser)
            }
            model.createUserVisible = false
        }else{
            systemCreateView.model.status = status
        }
    
        
    }
    func onCancelled() {
        model.createUserVisible = false
        model.createEnabled = true
    }
    
   
    
    var body: some View {
        ZStack(alignment: .topLeading){
            if model.users.count == 0{
                Text("Device does not support user management")
            }else{
            HStack{
                VStack{
                    List{
                        Section(header: Text("Users")){
                            ForEach(model.users,id: \.self) { user in
                                SystemUsersView(user: user).onTapGesture {
                                    model.selectedUser = user
                                    model.handleSelectedUser()
                                    model.confirmDeleteVisible = false
                                }.listRowBackground(model.selectedUser == user ? Color(iconModel.selectedRowColor) : Color(UIColor.tertiarySystemBackground)).padding(0)
                            }
                        }
                        Section(header: Text("Options")){
                            HStack(spacing: 5){
                                Button("Create",action:{
                                    model.createUserVisible = true
                                    model.createEnabled = false
                                    systemCreateView.model.status = ""
                                    systemCreateView.model.editable = false
                                    
                                }).appFont(.helpLabel)
                                    .disabled(model.createEnabled==false || model.createUserVisible)
                                
                                Button("Modify",action:{
                                    model.createUserVisible = true
                                    model.createEnabled = false
                                    systemCreateView.model.status = ""
                                    systemCreateView.setUser(user: model.selectedUser!)
                                   
                                }).appFont(.helpLabel)
                                    .disabled(model.modifyEnabled==false  || model.createUserVisible)
                                
                                Button("Delete",action:{
                                    //prompt
                                    model.confirmDeleteVisible=true
                                    model.selectedUserString = model.selectedUser!.name + " [" + model.selectedUser!.role + "]"
                                }).appFont(.helpLabel)
                                    .disabled(model.deleteEnabled==false  || model.createUserVisible)
                            }
                        }.hidden(model.confirmDeleteVisible)
                        
                    }.listStyle(PlainListStyle())
                    
                   
                }
                VStack{
                    ZStack{
                        systemCreateView.hidden(model.createUserVisible==false)
                            .frame(alignment: .topLeading).onAppear{
                            systemCreateView.model.listener = self
                            }
                        VStack{
                            Text("Confirm delete").appFont(.smallTitle)
                            
                            Text(model.selectedUserString).foregroundColor(.accentColor).appFont(.smallTitle)
                            
                            HStack{
                                Button("Cancel",action: {
                                    model.confirmDeleteVisible=false
                                }).appFont(.helpLabel)
                                Button("Delete",action:{
                                    self.deleteSelectedUser()
                                    model.confirmDeleteVisible=false
                                }).appFont(.helpLabel)
                            }
                            Text(model.confirmDeleteError).appFont(.caption).foregroundColor(.red).appFont(.caption)
                        }.hidden(model.confirmDeleteVisible==false)
                    }
                    Spacer()
                }.padding()
                
                Spacer()
            
            }.frame(alignment: .topLeading)
            }
        }
    }
}

struct SystemView_Previews: PreviewProvider {
    static var previews: some View {
        SystemView()
    }
}

