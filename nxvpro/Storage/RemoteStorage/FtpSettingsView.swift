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
    /*
     @Published var storageTypes = ["FTP"]//,"SMB/CIF","NFS"]
     
     var st = ["ftp","smb","nfs"]
    func setStorageType(ss: StorageSettings){
        for i in 0...st.count-1{
            if st[i] ==  ss.storageType{
                selectedType = storageTypes[i]
            }
        }
        
    }
     */
    @Published var status = ""
    @Published var statusHidden = true
    
    @Published var path = "/"
    @Published var paths = [String]()
    @Published var fileExt = ".mp4"
    
    @Published var saveEnabled = false
    @Published var verifyEnabled = false
    @Published var authenticated = false
    @Published var showPort = true
    
    var camera: Camera?
    var changeListener: StorageSettingsChangedListener?
    
    func setCamera(camera: Camera,changeListener: StorageSettingsChangedListener){
    
        self.camera = camera
        self.changeListener = changeListener
        self.dirs.removeAll()
        statusHidden = true
        
        let ss = camera.storageSettings
        //moved to parent container
        //setStorageType(ss: ss)
        
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
        
        print("FtpSettingsView",user,password,host,port)
        
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
            //SMB or NFS
           /*
            let smb = SMBDataSource(scheme: scheme)
            let ok = smb.mount(camera: camera!, host: host, user: user, password: password)
            DispatchQueue.main.async{
                if ok{
                   
                    self.dirs.append(contentsOf: smb.folders)
                }
                self.saveEnabled = ok
                self.statusHidden = true
            }
            */
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
            
            authenticated = true
            saveEnabled = false
            changeListener?.storageSettingsChanged(camera: camera!)
        }
    }
    
    //MARK: FtpDataSourceListener
    func actionComplete(success: Bool) {
        print("FtpSettingsModel:actionOomplete",success)
    }
    
    func fileFound(path: String, modified: Date?) {
        verifyOk = true
    }
    
    func directoryFound(dir: String) {
        verifyOk = true
        //add to path list
        DispatchQueue.main.async {
            self.dirs.append(dir)
            print("FtpSettingsModel:directoryFound",dir)
        }
        
    }
    
    func downloadComplete(localFilePath: String, success: String?) {
    }
    
    func done() {
        print("FtpSettingsModel:done",verifyOk,dirs.count)
        handleVerify(ok: verifyOk)
        
        
    }
}
struct FtpSettingsView2: View {
    @ObservedObject var model = FtpSettingsModel()
    
    var formFont = AppFont.TextStyle.helpLabel
    
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
                
                Text("Host").appFont(formFont)
                TextField("",text: $model.host).appFont(formFont).autocapitalization(.none)
                //Spacer()
                Text("Port").appFont(formFont)
                TextField("",text: $model.port).frame(width: 40).disabled(model.showPort==false).appFont(formFont)
               
            }.padding(.trailing,5)
            HStack{
                Text("User").appFont(formFont)
                TextField("",text: $model.user).frame(width: 80).appFont(formFont).autocapitalization(.none)
                Text("Password").appFont(formFont)
                SecureField("",text: $model.password).frame(width: 80).appFont(formFont).autocapitalization(.none)
                Spacer()
                Button("Test",action: {
                    model.doVerify()
                }).appFont(formFont).foregroundColor(Color(UIColor.systemBlue))
                    .padding(.trailing)
                    .disabled(model.verifyEnabled==false)
                Button("Save",action: {
                    model.saveSettings()
                }).appFont(formFont).foregroundColor(Color(UIColor.systemBlue))
                    .disabled(model.saveEnabled == false)
                    .padding(.trailing)
                
            }.padding(.trailing,5)
            HStack{
                HStack{
                    Text("Path").appFont(formFont)
                    TextField("",text: $model.path).frame(width: 140).appFont(formFont)
                    Picker("Folder",selection: $model.path){
                        ForEach(model.dirs, id: \.self) {
                            Text($0)
                        }
                    }.pickerStyle(SegmentedPickerStyle())
                    .hidden(model.dirs.count == 0)
                }.hidden(model.statusHidden==false)
                
                Spacer()
                Text(model.status).appFont(formFont).hidden(model.statusHidden)
            }
        }
    }
}
