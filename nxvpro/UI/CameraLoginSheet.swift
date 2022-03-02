//
//  CameraLoginSheet.swift
//  NXV-IOS
//
//  Created by Philip Bishop on 21/06/2021.
//

import SwiftUI

class CameraLoginSheetModel : ObservableObject, AuthenicationListener {
    
    func cameraAuthenticated(camera: Camera, authenticated: Bool) {
        DispatchQueue.main.async {
            if authenticated {
                self.listener?.loginStatus(camera: self.camera!, success: authenticated)
            }else{
                self.loginDisabled = false
                if camera.authFault.trimmingCharacters(in: CharacterSet.whitespaces).isEmpty{
                    self.authStatus = "Login failed"
                }else{
                    self.authStatus = camera.authFault
                }
                self.statusColor = Color.red
            }
        }
    }
    
    
    @Published var camera: Camera?
    @Published var camName = "Login"
    @Published var camIp = "x.x.x.x"
    @Published var camXAddr = ""
    @Published var authStatus = ""
    @Published var statusColor = Color.primary
    @Published var loginDisabled = false
    
    let defaultStatus = "Enter credentials"
    
    var grpName = ""
    
    init(){
        authStatus = defaultStatus
    }
    
    var listener: CameraLoginListener?
    
    func setCamera(camera: Camera){
        self.camera = camera
        self.camName = camera.name
        self.camIp = camera.getDisplayAddr()
        self.camXAddr = camera.xAddr
        self.statusColor = Color.primary
        if camera.isZombie{
            authStatus = "Warning: camera not found"
        }else{
            authStatus = defaultStatus
        }
        
        let groups = CameraGroups()
        self.grpName = groups.getGroupNameFor(camera: camera)
    }
    
    func doAuth(cUser: String,cPwd: String){
        
        if cUser.isEmpty {
            statusColor = Color.red
            authStatus = "Missing user name"
            return
        }
        camera!.user = cUser
        camera!.password = cPwd
        statusColor = Color.accentColor
        loginDisabled = true
        authStatus =  "Authenticating..."
        let onvifAuth = OnvifDisco()
        onvifAuth.startAuthorized(camera: camera!, authListener: self)
    }
    
}

protocol CameraLoginListener{
    func loginCancelled()
    func loginStatus(camera: Camera,success: Bool)
}

struct CameraLoginSheet: View {
    
    //@State var camera: Camera
    @ObservedObject var model = CameraLoginSheetModel()
    
    @State var cUser = ""
    @State var cPwd = ""
    
    
    func setCamera(camera: Camera,listener: CameraLoginListener){
        model.listener = listener
        model.setCamera(camera: camera)
        model.statusColor = Color.primary
        model.authStatus =  model.defaultStatus
        model.loginDisabled = false
    }
    @State var ifr = true
    @State var placeHolder = "User"
    var body: some View {
        List(){
            VStack (alignment: .leading){
                HStack{
                    VStack{
                        Text("Camera login").appFont(.title)
                            .padding()
                    }
                    Spacer()
                    Button(action: {
                        //presentationMode.wrappedValue.dismiss()
                        model.listener?.loginCancelled()
                    })
                    {
                        Image(systemName: "xmark").resizable()
                            .frame(width: 18,height: 18).padding()
                    }.foregroundColor(Color.accentColor)
                }
                Text(model.camName + " " + model.camIp).fontWeight(.light).appFont(.caption)
            }
            
            Section(header: Text("Credentials").appFont(.sectionHeader)){
                VStack(spacing: 0){
                    //LegacyTextField(placeholder: $placeHolder,text: $cUser,isFirstResponder: $ifr).autocapitalization(.none).appFont(.titleBar)
                TextField(placeHolder,text: $cUser).autocapitalization(.none).padding()
                    
                SecureInputView("Password",text: $cPwd).appFont(.titleBar)
                    .autocapitalization(.none).padding()
                    //.background(Color(UIColor.systemBackground))
                }
                
            }
            HStack{
                Text(model.authStatus).fontWeight(.light).foregroundColor(model.statusColor)
                    .appFont(.body)
                Spacer()
                Button("Login",action: {
                    doAuth()
                }).foregroundColor(Color.accentColor).appFont(.body)
                    .hidden(model.loginDisabled)
            }
            Section(header: Text("ONVIF Information").appFont(.sectionHeader)){
                Text(model.camXAddr).fontWeight(.light).appFont(.caption)
            }
            
            if model.grpName != CameraGroup.MISC_GROUP{
            
                HStack{
                    Text("Move camera to misc group (hides camera in main list").fontWeight(.light).foregroundColor(model.statusColor)
                        .appFont(.body)
                    Spacer()
                    Button("Move",action: {
                        globalCameraEventListener?.moveCameraToGroup(camera: model.camera!, grpName: CameraGroup.MISC_GROUP)
                        model.listener?.loginCancelled()
                    }).foregroundColor(Color.accentColor).appFont(.body)
                }
            }
        }
        //.interactiveDismissDisabled()
    }
    
    func doAuth(){
        UIApplication.shared.endEditing()
        model.doAuth(cUser: cUser, cPwd: cPwd)
    }
}

struct CameraLoginSheet_Previews: PreviewProvider {
    @State static var showLogin = true
    static var previews: some View {
        CameraLoginSheet()
    }
}
