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
    
    @Published var storageTypes = ["FTP"]//,"SMB/CIF","NFS"]
    @Published var selectedType = "FTP"
    var st = ["ftp","smb","nfs"]
    
    func getStorageType() -> String{
        
        for i in 0...storageTypes.count-1{
            if storageTypes[i] ==  selectedType{
                return st[i]
            }
        }
        return ""
    }
    func setStorageType(ss: StorageSettings){
        for i in 0...st.count-1{
            if st[i] ==  ss.storageType{
                selectedType = storageTypes[i]
            }
        }
        
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
    
    var camera: Camera?
    var changeListener: StorageSettingsChangedListener?
    
    func setCamera(camera: Camera,changeListener: StorageSettingsChangedListener){
    
        self.camera = camera
        self.changeListener = changeListener
        self.dirs.removeAll()
        statusHidden = true
        
        let ss = camera.storageSettings
        setStorageType(ss: ss)
        
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
            selectedType = storageTypes[0]
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
        VStack{
            HStack{
               
                Picker("Type",selection: $model.selectedType){
                    ForEach(model.storageTypes, id: \.self) {
                        Text($0)
                    }
                }.onChange(of: model.selectedType) { newType in
                    model.selectedType = newType
                    if newType == "FTP"{
                        model.showPort = true
                        model.port = "21"
                    }else{
                        model.showPort = false
                        model.port = "n/a"
                    }
                    model.saveEnabled = false
                }.pickerStyle(SegmentedPickerStyle())
                .frame(width: 160)
                Text("Host").appFont(.caption)
                TextField("",text: $model.host).appFont(.caption).autocapitalization(.none)
                Text("Port").appFont(.caption)
                TextField("",text: $model.port).frame(width: 40).disabled(model.showPort==false).appFont(.caption)
                
            }
            HStack{
                Text("User").appFont(.caption)
                TextField("",text: $model.user).frame(width: 100).appFont(.caption).autocapitalization(.none)
                Text("Password").appFont(.caption)
                SecureField("",text: $model.password).frame(width: 100).appFont(.caption).autocapitalization(.none)
                Spacer()
                Button("Test",action: {
                    model.doVerify()
                }).appFont(.caption).foregroundColor(Color(UIColor.systemBlue))
                    .padding(.trailing)
                    .disabled(model.verifyEnabled==false)
                Button("Save",action: {
                    model.saveSettings()
                }).appFont(.caption).foregroundColor(Color(UIColor.systemBlue))
                    .disabled(model.saveEnabled == false)
                
            }
            HStack{
                HStack{
                    Text("Path").appFont(.caption)
                    TextField("",text: $model.path).frame(width: 140).appFont(.caption)
                    Picker("Folder",selection: $model.path){
                        ForEach(model.dirs, id: \.self) {
                            Text($0)
                        }
                    }.pickerStyle(SegmentedPickerStyle())
                    .hidden(model.dirs.count == 0)
                }.hidden(model.statusHidden==false)
                
                Spacer()
                Text(model.status).appFont(.caption).hidden(model.statusHidden)
            }
        }.frame(width: 450)
        /*
        VStack{
            
            HStack{
                HStack{
                    Text("User")
                    TextField("User",text: $model.user)
                }.frame(width: 200)
                Text("Password").frame(alignment: .leading)
                SecureField("Password",text: $model.password)
                Spacer()
            }
            HStack{
                HStack{
                    Text("Host")
                    TextField("Server",text: $model.host)
                }.frame(width: 200)
                HStack{
                    Text("Port")
                    TextField("Port",text: $model.port)
                }.hidden(model.showPort==false)
                
                Button("Verify",action: {
                    model.doVerify()
                }).keyboardShortcut(.defaultAction).disabled(model.verifyEnabled==false)
                Spacer()
            }
            ZStack{
                HStack{
                    if model.authenticated{
                        Text("Path")
                        TextField("Path",text: $model.path)
                    }else{
                        Picker("Path",selection: $model.path){
                            ForEach(model.paths, id: \.self) {
                                Text($0)
                            }.onChange(of: model.path) { newPath in
                                model.checkAndEnableSave()
                            }
                        }.frame(width: 200)
                    }
                    
                    Text("File ext")
                    TextField("File ext",text: $model.fileExt)
                    Button("Save",action: {
                        model.saveSettings()
                    }).keyboardShortcut(.defaultAction).disabled(model.saveEnabled==false)
                    Spacer()
                }.hidden(model.statusHidden==false)
                
                HStack{
                    Spacer()
                    Text(model.status).padding(.trailing)
                }.hidden(model.statusHidden)
            }
        }
         */
    }
}
