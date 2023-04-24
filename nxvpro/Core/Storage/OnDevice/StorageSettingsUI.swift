//
//  StorageSettingsUI.swift
//  NX-V
//
//  Created by Philip Bishop on 18/07/2021.
//

import SwiftUI
import UserNotifications

class StorageModel : ObservableObject{
    @Published var useDownloadsDir: Bool = false
    @Published var storageLimits: [String] = [String]();
    @Published var storageLimit: String = "";
    @Published var retentionDays: [String] = [String]()
    @Published var retention = ""
    @Published var initialUseDownloadsDir: Bool = false
    @Published var moveExistingFiles: Bool = false
    @Published var saveEnabled: Bool = false
    
    @Published var vmdFolderSize: String = ""
    @Published var videoFolderSize: String = ""
    
    @State var useDownloads: Bool = false
    @State var limit: String = ""
    @State var retDays: String = ""
    
    @Published var storageLimitExceeded: Bool = false
    
    @Published var userNotificationEnabled: Bool = false
    
    @Published var cloudCopyEnabled: Bool = false
    
    let npre = [5,10,15]
    var preroll = ["5 seconds","10 seconds","15 seconds"]
    
    let npost = [10,20,30,60]
    var postEvent = ["10 seconds","20 seconds","30 seconds","60 seconds"]
    
    let nconf = [0.5,0.60,0.65,0.7,0.75,0.8,0.85,0.9]
    var confLevel = ["50%","60%","65%","70%","75%","80%","85%","90%"]
    
    @Published var selectedPreroll = "5 seconds"
    @Published var selectedPostEvent = "10 seconds"
    @Published var selecteConfidence = "60%"
    
    //MARK: ANPR Region
    @Published var showAnprSettings = false
    @Published var anprOn = false
    let aconf = [0.3,0.4,0.5,0.6,0.7,0.8,0.9]
    var aconfLevel = ["30%","40%","50%","60%","70%","80%","90%"]
    @Published var selectedAnprConfidence = "30%"
    
    @Published var frameHeight = 350.0
    
    var cameras = [Camera]()
    var listener: LocalStorageChangeListener?
    
    func setCameras(cameras: [Camera],listener: LocalStorageChangeListener){
        self.cameras = cameras
        self.listener = listener
        
        if cameras.count == 0{
            return
        }
        showAnprSettings = false
#if os(OSX)
        if AppSettings.IS_PRO{
            let countryCode = Locale.current.identifier
            if countryCode == "GB" || countryCode.hasSuffix("_GB") {
                if cameras.count == 1{
                    showAnprSettings = true
                    anprOn = cameras[0].anprOn
                    print("Show ANPR Settings",Locale.current.identifier,cameras[0].getDisplayName())
                }
            }
        }
#endif
        //for now select first camera values
        let cam = cameras[0]
        
        refreshMotionSettings(cam: cam)
        
        
        frameHeight = AppSettings.IS_PRO ? (470+170) : frameHeight
        if showAnprSettings{
            frameHeight = frameHeight + 42
        }
        
    }
    private func refreshMotionSettings(cam: Camera){
        selectedPostEvent = String(cam.vmdRecTime) + " seconds"
        //preroll needs to go into AppSettings
        let pre = AppSettings.getPreroll()
        if pre == 10{
            selectedPreroll = preroll[1]
        }else if pre == 15{
            selectedPreroll = preroll[2]
        }else{
            selectedPreroll = preroll[0]
        }
        
        //confidence
        var conf = cam.vmdMinConfidence
        if conf == 0.62 {
            conf = 0.6
        }
        for i in 0...nconf.count-1{
            if conf == Float(nconf[i]){
                selecteConfidence = confLevel[i]
            }
        }
        
        //anpr conf
        for i in 0...aconf.count-1{
            if cam.anprMinConfidence == Float(aconf[i]){
                selectedAnprConfidence = aconfLevel[i]
            }
        }
    }
    
    init(){
        refresh()
       
    }
    func refresh(){
        cloudCopyEnabled = FileHelper.isCloudSaveEnabled()
        
        storageLimits = FileHelper.storageLimits
        storageLimit = FileHelper.getStorageLimit()
        
        retentionDays = FileHelper.retentionDays
        retention = FileHelper.getRetentionDays()
        
        useDownloadsDir = FileHelper.getUseDownloadDirForMedia()
        initialUseDownloadsDir = useDownloadsDir
        let sizes = FileHelper.getMediaSizes()
        
        videoFolderSize = sizes[0]
        vmdFolderSize = sizes[1]
        
        storageLimitExceeded = FileHelper.hasExceededMediaLimit()
        
        //initial values used for checking enabling save
        useDownloads = useDownloadsDir
        limit = storageLimit
        retDays = retention
        
        if cameras.count > 0{
            refreshMotionSettings(cam: cameras[0])
        }
        
        let center = UNUserNotificationCenter.current()
    
        center.requestAuthorization(options: [.alert, .badge, .sound]) { (granted, error) in
            DispatchQueue.main.async{
                self.userNotificationEnabled = granted
            }
        }
    }
    func checkAndEnableSave(){
        AppLog.write("checkAndEnableSave:model",useDownloadsDir,storageLimit,retention)
        AppLog.write("checkAndEnableSave:state",useDownloads,limit,retDays)
        
        var enableSave = false
        if useDownloads != useDownloadsDir {
            enableSave = true
        }
        if limit != storageLimit {
            enableSave = true
        }
        if retDays != retention {
            enableSave = true
        }
        
        saveEnabled = enableSave
    }
    private func updatePreroll(){
        for i in 0...npre.count-1{
            if selectedPreroll == preroll[i]{
                AppSettings.setPreroll(seconds: npre[i])
                break;
            }
        }
    }
    private func updatePostEvent(){
        for i in 0...npost.count-1{
            if selectedPostEvent == postEvent[i]{
               let post = npost[i]
                for cam in cameras{
                    cam.vmdRecTime = post
                    
                }
                break;
            }
        }
    }
    private func updateConfidence(){
        for i in 0...nconf.count-1{
            if selecteConfidence == confLevel[i]{
               let conf = nconf[i]
                for cam in cameras{
                    cam.vmdMinConfidence = Float(conf)
                   
                }
                break;
            }
        }
    }
    private func updateAnprConfidence(){
        for i in 0...aconf.count-1{
            if selectedAnprConfidence == aconfLevel[i]{
               let conf = aconf[i]
                for cam in cameras{
                    cam.anprMinConfidence = Float(conf)
                   
                }
                break;
            }
        }
    }
    func applyChanges(){
        FileHelper.setCloudSaveEnabled(enabled: cloudCopyEnabled)
        
        //Motion and body
        updatePreroll()
        updatePostEvent()
        updateConfidence()
        updateAnprConfidence()
        
        for cam in cameras{
            //Anpr
            cam.anprOn = anprOn
            if anprOn {
                cam.vmdMode = 1
                cam.vmdOn = true
                RemoteLogging.log(item: "ANPR enabled " + cam.getDisplayName())
            }else{
                cam.vmdOn = false
            }
                
            cam.save()
        }
        
        globalCameraEventListener?.onSettingsUpdated()
        
        let storageModel = self
        storageModel.initialUseDownloadsDir = storageModel.useDownloadsDir
        storageModel.saveEnabled = false
        //configure and copy if selected
       
       let task = DispatchQueue(label: "nxv_move_dir")
       task.async {
            FileHelper.setStorageLimitIndex(si: storageModel.storageLimit)
            FileHelper.setRetentionIndex(si: storageModel.retention)
            FileHelper.setUseDownloadDirForMedia(yes: storageModel.useDownloadsDir, copyExisting: storageModel.moveExistingFiles)
           
           DispatchQueue.main.async{
               
               self.listener?.onLocalStorageChanged()
           }
       }
    }
}

struct StorageSettingsUI: View {
    @State var isPreview: Bool = false
   
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var model = StorageModel()
    
    /*
    var listener: LocalStorageChangeListener?
    
    init(listener: LocalStorageChangeListener){
        self.listener = listener
    }
    */
    
    func setCameras(cameras: [Camera],listener: LocalStorageChangeListener){
        model.setCameras(cameras: cameras, listener: listener)
    }
    
    func refresh(){
        model.refresh()
    }
    func motionSettings() -> some View{

        VStack(alignment: .leading){

        let fw = 150.0

            Text("Motion detection settings")//.fontWeight(.semibold)
            HStack{
            Section(header: Text("Pre event recording")){
                Spacer()
                    Picker("",selection: $model.selectedPreroll){
                        ForEach(self.model.preroll, id: \.self) {
                            Text($0)
                        }
                    }.onChange(of: model.selectedPreroll, perform: { newValue in
                        DispatchQueue.main.async{
                            
                            model.checkAndEnableSave()
                        }
                    })
#if os(OSX)
                    .frame(width: fw)
#endif
                }
            }
            HStack{
            Section(header: Text("Post event recording")){
                Spacer()
                Picker("",selection: $model.selectedPostEvent){
                        ForEach(self.model.postEvent, id: \.self) {
                            Text($0)
                        }
                    }.onChange(of: model.selectedPostEvent, perform: { newValue in
                        DispatchQueue.main.async{
                            
                            model.checkAndEnableSave()
                        }
                    })
#if os(OSX)
                    .frame(width: fw)
#endif
                }
            }
            
            Divider()
            Text("Body detection settings")//.fontWeight(.semibold)
            HStack{
            
            Section(header: Text("Confidence level")){
                Spacer()
                    Picker("",selection: $model.selecteConfidence){
                        ForEach(self.model.confLevel, id: \.self) {
                            Text($0)
                        }
                    }.onChange(of: model.selecteConfidence, perform: { newValue in
                        DispatchQueue.main.async{
                            
                            model.checkAndEnableSave()
                        }
                    })
#if os(OSX)
                    .frame(width: fw)
#endif
                } //.
            }
           
            if model.showAnprSettings{
                Divider()
                anprSettings()
            }
        }.frame(width: 300)
    }
    private func anprSettings() -> some View{
        VStack{
            HStack{
                Section(header: Text("ANPR (UK plates) enabled")) {
                    Spacer()
                    Toggle("",isOn: $model.anprOn).onChange(of: model.anprOn){ vmdOn in
                        DispatchQueue.main.async{
                            
                            model.checkAndEnableSave()
                        }
                    }
                }
            }
            HStack{
                Section(header: Text("Confidence level")){
                    Spacer()
                    
                    Picker("",selection: $model.selectedAnprConfidence){
                        ForEach(self.model.aconfLevel, id: \.self) {
                            Text($0)
                        }
                    }.onChange(of: model.selectedAnprConfidence, perform: { newValue in
                        DispatchQueue.main.async{
                            model.checkAndEnableSave()
                        }
                        
                    })
                }
            }
        }
    }
    var body: some View {
        VStack(alignment: .leading){
            HStack{
                Spacer()
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                })
                {
                   Text("Done")
                }.foregroundColor(Color.accentColor)
                    .buttonStyle(.plain)
            }
            
            HStack{
                Text("Local (NX-V) storage settings").appFont(.smallTitle)
                    //.padding()
                
                Spacer()
            }
            
            Divider()
            //Form(){
            VStack(alignment: .leading){
                Section(header: Text("Storage space used")){
                    
                    HStack{
                        Text("Videos:")
                        Spacer()
                        Text(model.videoFolderSize)
                    }.padding(5)
                    
                    
                }
                
                Section(header: Text("Local storage notification limit")){
                    VStack(alignment: .leading){
                        Picker("", selection: $model.storageLimit) {
                            ForEach(model.storageLimits, id: \.self) {
                                Text($0).padding()
                            }
                        }
                        .onChange(of: model.storageLimit) { limit in
                            
                            model.checkAndEnableSave()
                        }
                        .frame(width: 150)
                        if model.userNotificationEnabled == false {
                            Text("User notifications are disabled in your system settings").font(.callout).fontWeight(.light).foregroundColor(Color.red)
                        }
                    }
                }
                
#if os(OSX)
                Divider()
                Section(header: Text("Storage folder")){
                    VStack(alignment: .leading){
                        
                        Toggle(isOn: $model.useDownloadsDir){
                            Text("Store captured media in Downloads")
                        }
                        .padding(5)
                        .onChange(of: model.useDownloadsDir) { isOn in
                            AppLog.write("EventsAndVideoViews:Toggle",isOn)
                            
                            DispatchQueue.main.async{
                                model.moveExistingFiles = true
                                model.checkAndEnableSave()
                            }
                        }
                        
                        
                        Toggle(isOn: $model.moveExistingFiles){
                            Text("Move exiting files")
                        }.disabled(model.saveEnabled == false)
                            .padding(5)
                    }
                }
#endif
                if AppSettings.IS_PRO{
                   
                    Divider()
                    motionSettings()
                   
                    Divider()
                    Section(header: Text("iCloud copy")){
                        Toggle(isOn: $model.cloudCopyEnabled){
                            Text("Save a copy to your private NX-V iCloud folder\nThis allows you to access videos from your other devices with NX-V PRO")
                        }.disabled(cloudStorage.iCloudAvailable==false)
                            .padding(5)
                            .onChange(of: model.cloudCopyEnabled) { isOn in
                                AppLog.write("cloudCopyEnabled:Toggle",isOn)
                                DispatchQueue.main.async{
                                    
                                    model.checkAndEnableSave()
                                }
                            }
                    }
                    
                }
                Spacer()
                Divider()
                
                Button("Apply"){
                    applyChanges()
                    presentationMode.wrappedValue.dismiss()
                }.disabled(model.saveEnabled==false)
                    .keyboardShortcut(.defaultAction)
                
                Spacer()
            }.padding(5)
            .onAppear{
                refresh()
            }
        }.padding()
#if os(OSX)
            .frame(width: 520,height: model.frameHeight)
#endif
    }
    
    func applyChanges(){
        model.applyChanges()
        /*
        FileHelper.setCloudSaveEnabled(enabled: model.cloudCopyEnabled)
        let storageModel = model
        storageModel.initialUseDownloadsDir = storageModel.useDownloadsDir
        storageModel.saveEnabled = false
           //configure and copy if selected
           
           let task = DispatchQueue(label: "nxv_move_dir")
           task.async {
                FileHelper.setStorageLimitIndex(si: storageModel.storageLimit)
                FileHelper.setRetentionIndex(si: storageModel.retention)
                FileHelper.setUseDownloadDirForMedia(yes: storageModel.useDownloadsDir, copyExisting: storageModel.moveExistingFiles)
               
               DispatchQueue.main.async{
                   
                   model.listener?.onLocalStorageChanged()
               }
           }
         */
    }
    
}


