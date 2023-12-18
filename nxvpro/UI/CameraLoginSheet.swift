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
                self.loginError = true
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
    @Published var loginError = false
    
    @Published var showUseLastLogin = false
    let defaultStatus = "Enter credentials"
    
    var grpName = ""
    
    init(){
        authStatus = defaultStatus
    }
    
    var listener: CameraLoginListener?
    
    func setCamera(camera: Camera){
        self.camera = camera
        self.camName = camera.getDisplayName()
        self.camIp = camera.getDisplayAddr()
        self.camXAddr = camera.xAddr
        self.statusColor = Color.primary
        if camera.isZombie{
            authStatus = "Warning: camera not found"
        }else{
            authStatus = defaultStatus
        }
        self.loginError = false
        let groups = CameraGroups()
        self.grpName = groups.getGroupNameFor(camera: camera)
    }
    
    func doAuth(cUser: String,cPwd: String){
        if loginDisabled{
            AppLog.write("CameraLogin:doAuth loginDisabled, return")
            return
        }
        if cUser.isEmpty {
            statusColor = Color.red
            authStatus = "Missing user name"
            return
        }
        loginDisabled = true
        loginError = false
        camera!.user = cUser
        camera!.password = cPwd
        statusColor = Color.accentColor
        
        authStatus =  "Authenticating..."
        let onvifAuth = OnvifDisco()
        onvifAuth.startAuthorized(camera: camera!, authListener: self,src: "LoginSheet")
    }
    
}
class LastLogin{
    var user = ""
    var pass = ""
}

var globalLastLogin = LastLogin()

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
    
    enum FocusedField {
           case user, pass, submit
       }
    
    @FocusState private var focusedField: FocusedField?
    
    private func changeFocusTo(fld: FocusedField){
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5){
            focusedField = fld
        }
    }
    
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
                    TextField(placeHolder,text: $cUser)
                        .autocapitalization(.none).appFont(.titleBar)
                        .onSubmit{
                            changeFocusTo(fld: .pass)
                        }
                        .focused($focusedField,equals: .user)
                        
                        .padding()
                    
                SecureInputView("Password",text: $cPwd).appFont(.titleBar)
                        .autocapitalization(.none).padding().onSubmit{
                            changeFocusTo(fld: .submit)
                            doAuth()
                        }
                        .focused($focusedField,equals: .pass)
                   
                }
            }
            HStack{
                if globalLastLogin.user.isEmpty == false && model.loginDisabled == false && model.loginError == false{
                    Toggle("Use last login",isOn: $model.showUseLastLogin)
                        .onChange(of: model.showUseLastLogin, perform: { doShow in
                            if doShow{
                                cUser = globalLastLogin.user
                                cPwd = globalLastLogin.pass
                            }else{
                                cUser = ""
                                cPwd = ""
                            }
                        }).toggleStyle(CheckToggleStyle())
                    
                    
                
                }else{
                    Text(model.authStatus)
                }
                Spacer()
                Button("Login",action: {
                    doAuth()
                })
                .disabled(model.loginDisabled)
                .padding(0)
            }
            Section(header: Text("ONVIF Information").appFont(.sectionHeader)){
                Text(model.camXAddr).fontWeight(.light).appFont(.caption)
            }
            
            if AppSettings.IS_PRO && model.grpName != CameraGroup.MISC_GROUP{
            
                HStack{
                    Text("Move camera to " + CameraGroup.MISC_GROUP + " group (hides camera in main list").fontWeight(.light)
                        .appFont(.body)
                    Spacer()
                    Button("Move",action: {
                        globalCameraEventListener?.moveCameraToGroup(camera: model.camera!, grpName: CameraGroup.MISC_GROUP)
                        model.listener?.loginCancelled()
                    }).foregroundColor(Color.accentColor).appFont(.body)
                        .disabled(model.loginDisabled)
                }
            }
        }.onAppear{
            changeFocusTo(fld: .user)
            if let cam = model.camera{
                if cam.user.isEmpty == false{
                    cUser = cam.user
                    cPwd = cam.password
                }else{
                    cUser = globalLastLogin.user
                    cPwd = globalLastLogin.pass
                    model.showUseLastLogin = cUser.isEmpty == false
                }
            }
            
        }
    }
    
    func doAuth(){
        UIApplication.shared.endEditing()
        globalLastLogin.user = cUser
        globalLastLogin.pass = cPwd
        DispatchQueue.main.async{
            model.doAuth(cUser: cUser, cPwd: cPwd)
        }
    }
    
}

struct CameraLoginSheet_Previews: PreviewProvider {
    @State static var showLogin = true
    static var previews: some View {
        CameraLoginSheet()
    }
}
