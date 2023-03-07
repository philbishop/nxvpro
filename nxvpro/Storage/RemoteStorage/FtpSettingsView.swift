//
//  FtpSettingsView.swift
//  NX-V
//
//  Created by Philip Bishop on 31/01/2022.
//

import SwiftUI
import FilesProvider

protocol StorageSettingsChangedListener{
    func storageSettingsChanged(camera: Camera)
}

class FtpSettingsModel : ObservableObject, FtpDataSourceListener{
    
    @Published var user = "" {
        didSet{
            checkEnableVerify()
        }
    }
    @Published var password = "" {
        didSet{
            checkEnableVerify()
        }
    }
    @Published var host: String = "" {
        didSet{
            checkEnableVerify()
        }
    }
    @Published var port = "21"{
        didSet{
            checkEnableVerify()
        }
    }
    
    
    
    @Published var selectedType = "ftp"
    func getStorageType() -> String{
        
        return selectedType
    }
    
    @Published var status = ""
    @Published var statusHidden = true
    
    @Published var path = "/"
    @Published var paths = [String]()
    @Published var fileExt = ".mp4"
    
    @Published var saveEnabled = false
    @Published var verifyEnabled = false
    @Published var authenticated = false
    @Published var showPort = true
    
    var formFont = AppFont.TextStyle.helpLabel
    var activeColor = Color.accentColor
    var noColor = Color(UIColor.label)
    
    @Published var camName = "IP CAM"
    var camera: Camera?
    var changeListener: StorageSettingsChangedListener?
    var authListener: FtpSettingsAuthListener?
    
    init(){
        if ProcessInfo.processInfo.isiOSAppOnMac{
            formFont = .body
        }
    }
    func updateStorageSettings(_ ss: StorageSettings){
        self.camera!.storageSettings = ss
      
        
        user = ss.user
        password = ss.password
        host = ss.host
        if ss.path.isEmpty{
            path = "/"
        }else{
            path = ss.path
        }
        port = ss.port
        if ss.fileExt.isEmpty{
            fileExt = ".mp4"
        }else{
            fileExt = ss.fileExt
        }
        authenticated = ss.authenticated
        
        if ss.storageType.isEmpty{
            selectedType = "ftp"
            showPort = true
            port = "21"
        }else{
        
            if ss.storageType != "ftp"{
                showPort = false
                port = ""
                //verifyEnabled = true
            }else{
                showPort = true
            }
        }
    }
    func setCamera(camera: Camera,changeListener: StorageSettingsChangedListener){
    
        self.camera = camera
        self.camName = camera.getDisplayName()+" "+camera.getDisplayAddr()
        self.changeListener = changeListener
        self.dirs.removeAll()
        
        statusHidden = true
        
        updateStorageSettings(camera.storageSettings)
    }
    
    private func checkEnableVerify(){
        
        let validIp = host.isValidIpAddressOrHost
        if showPort{
            if let iport = Int(port){
                if validIp && user.count > 2 && password.count > 2{
                    verifyEnabled = true
                    return
                }
            }
            verifyEnabled = false
        }
        verifyEnabled = validIp
    }
    func checkAndEnableSave(){
        checkEnableVerify()
        if verifyEnabled{
            if path.isEmpty == false && fileExt.isEmpty == false{
                saveEnabled = true
                return
            }
        }
        saveEnabled = false
    }
    private func handleVerify(ok: Bool){
        DispatchQueue.main.async{
            self.status = "Auth " + (ok ? "OK" : "Failed or connection error")
            self.statusHidden = ok
            
            if self.verifyOk{
                self.paths.removeAll()
                if self.dirs.isEmpty{
                    self.dirs.append("/")
                    self.path = "/"
                }
                self.paths.append(contentsOf: self.dirs)
                self.checkAndEnableSave()
            }
        }
    }
    var verifyOk = false
    @Published var dirs = [String]()
    
    func doVerify(){
        DispatchQueue.main.async{
            self.status = "Authenticating..."
            self.statusHidden = false
            self.dirs.removeAll()
        }
        
        AppLog.write("FtpSettingsView",user,password,host,port)
        
        let credential = URLCredential(user: user,password: password,persistence: .forSession)
        
        verifyOk = false
        let scheme = getStorageType()
        
        if scheme == "ftp" {
        
            let sd = FtpDataSource(listener: self)
            if sd.connect(credential: credential, host: host + ":" + port){
                sd.searchDirs(path: "/",recursive: false)
            }else{
                handleVerify(ok: false)
            }
        }else{
            //SMB or NFS handled by SharedStorage on iOS
           
        }
    }
    
    func saveSettings(){
        let storageTYpe = getStorageType()
        
        if let cam = camera{
            let ss = StorageSettings()
            ss.user = user
            ss.password = password
            ss.host = host
            ss.port = port
            ss.path = path
            ss.storageType = storageTYpe
            ss.fileExt = fileExt
            ss.authenticated = true
            
            cam.storageSettings = ss
            //currently all saved with "ftp" filename
            cam.saveStorageSettings(storageType: "ftp")
            
           
            
            DispatchQueue.main.async{
                self.saveEnabled = false
                self.authenticated = true
                self.changeListener?.storageSettingsChanged(camera: self.camera!)
                self.authListener?.onFtpAuthenticated(ss: ss)
            }
        }
    }
    
    //MARK: FtpDataSourceListener
    func actionComplete(success: Bool) {
        AppLog.write("FtpSettingsModel:actionOomplete",success)
    }
    
    func fileFound(path: String, modified: Date?) {
        verifyOk = true
    }
    func searchComplete(filePaths: [String]) {
        //not used
    }
    func directoryFound(dir: String) {
        verifyOk = true
        //add to path list
        DispatchQueue.main.async {
            self.dirs.append(dir)
            if self.path.isEmpty || self.path == "/"{
                self.path = dir
            }
            AppLog.write("FtpSettingsModel:directoryFound",dir)
        }
        
    }
    
    func downloadComplete(localFilePath: String, success: String?) {
    }
    
    func done() {
        
        AppLog.write("FtpSettingsModel:done",verifyOk,dirs.count)
        handleVerify(ok: verifyOk)
        
        
    }
}

class FtpSheetModel : ObservableObject{
    @Published var showSheet = false
    var settingsSheet = FtpSettingsSheet()
    @Published var displayDetails = ""
}

struct FtpSettingsView2: View, FtpSettingsAuthListener {
    @ObservedObject var model = FtpSettingsModel()
    @ObservedObject var sheetModel = FtpSheetModel()
    
    func onFtpAuthenticated(ss: StorageSettings) {
        sheetModel.showSheet = false
        
        sheetModel.displayDetails = ss.host+":"+ss.port+ss.path
        AppLog.write("onFtpAuthenticated",sheetModel.displayDetails)
        
        //update actual model
        model.updateStorageSettings(ss)
    }
    
    func setCamera(camera: Camera,changeListener: StorageSettingsChangedListener){
        model.setCamera(camera: camera, changeListener: changeListener)
        sheetModel.settingsSheet.setCamera(camera: camera, listener: changeListener,authListener: self)
        sheetModel.displayDetails = ""
        if model.authenticated{
            sheetModel.displayDetails = model.host+":"+model.port+model.path
        }
        
    }
    func getHostAndPort() -> String{
        var hostAndPort = model.host
        if let iport = Int(model.port){
            hostAndPort = hostAndPort + ":" + model.port
        }
        return hostAndPort
    }
    func getCredentials() -> URLCredential{
        return URLCredential(user: model.user, password: model.password, persistence: .forSession)
    }
    var body: some View {
        VStack(alignment: .leading){
            HStack{
                if sheetModel.displayDetails.isEmpty == false{
                    Text(sheetModel.displayDetails)
                            .padding()
                }
                Button("FTP settings"){
                    sheetModel.showSheet = true
                }.appFont(.body)
                .padding()
                Spacer()
            }.sheet(isPresented: $sheetModel.showSheet) {
                sheetModel.settingsSheet
            }

            /*
            HStack{
                
                Text("Host").fontWeight(.semibold)
                TextField("",text: $model.host).autocapitalization(.none).border(Color(UIColor.separator))
                    .frame(width: 190)
                
                Text("Port").fontWeight(.semibold).padding(.leading,20)
                TextField("",text: $model.port).frame(width: 40).disabled(model.showPort==false).border(Color(UIColor.separator))
               
                Spacer()
                
                Button("Test",action: {
                    model.doVerify()
                }).foregroundColor(model.verifyEnabled ?model.activeColor:model.noColor)
                    .padding(.trailing)
                    .disabled(model.verifyEnabled==false)
                    .buttonStyle(.bordered)
            }.padding(.trailing,5)
            HStack{
                Text("User").fontWeight(.semibold)
                TextField("",text: $model.user).frame(width: 100).autocapitalization(.none).border(Color(UIColor.separator))
                Text("Password").fontWeight(.semibold)
                SecureField("",text: $model.password).frame(width: 100).autocapitalization(.none).border(Color(UIColor.separator))
                Spacer()
                
                Spacer()
                
                Button("Save",action: {
                    model.saveSettings()
                }).foregroundColor(model.saveEnabled ?model.activeColor:model.noColor)
                    .disabled(model.saveEnabled == false)
                    .buttonStyle(.bordered)
                    .padding(.trailing)
                
            }.padding(.trailing,5)
            HStack{
                HStack{
                    Text("Path").fontWeight(.semibold)
                    TextField("",text: $model.path).frame(width: 140)
                    Picker("",selection: $model.path){
                        ForEach(model.dirs, id: \.self) {
                            Text($0)
                        }
                    }.onChange(of: model.path) { newPath in
                        model.path = newPath
                    }
                    .pickerStyle(.menu)
                    .hidden(model.dirs.count == 0)
                    Spacer()
                    
                  
                }.hidden(model.statusHidden==false)
                
                Spacer()
                Text(model.status).hidden(model.statusHidden).padding(.trailing,20)
            }
           */
            
        }.padding(.leading,5)
    }
}
