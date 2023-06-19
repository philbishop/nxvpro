//
//  ImportCamerasSheet.swift
//  NXV-IOS
//
//  Created by Philip Bishop on 05/10/2021.
//

import SwiftUI
import Network

struct ImportItem : View{
    
    @State var label: String
    
    init(label: String){
        self.label = label
    }
    var body: some View {
        HStack{
            Text(label).appFont(.footnote)
            Spacer()
        }
    }
}

class ImportCamerasModel : ObservableObject, DocumentPickerListener{
    
    @Published var status: String = "No file selected"
    @Published var statusColor: Color = Color(UIColor.label)
    @Published var addStatusColor: Color = Color(UIColor.label)
    
    var cameraEventListener: CameraEventListener?
    
    let errorColor = Color(UIColor.systemRed)
    let okColor = Color(UIColor.label)
    let accentColor = Color(UIColor.systemBlue)
    
    @Published var ipAddress: String = "" {
        didSet{
            ipAddressColor = ipAddress.isValidIpAddressOrHost ? okColor : errorColor
            scanBtnDisabled = !ipAddress.isValidIpAddressOrHost
            addBtnDisabled = portNum.count < 2 || scanBtnDisabled
        }
    }
    @Published var ipAddressColor = Color(UIColor.label)
    
    @Published var portNum: String = ""{
        didSet{
            addBtnDisabled = portNum.count < 2 && ipAddress.isValidIpAddressOrHost == false
            
        }
    }
    @Published var portColor = Color(UIColor.label)
    
    @Published var portRange: String = "80-8080"
    @Published var portRangeColor = Color(UIColor.label)
    
    let defaultPrompt = "Enter address & port or Scan for well known ONVIF ports"
    @Published var addStatus = ""
    @Published var btnsDisabled = true
    
    @Published var addBtnDisabled = true
    @Published var scanBtnDisabled = true
    @Published var importDisabled = false
    
    @Published var addBtnLabel = "Check"
    @Published var isCheckMode = true
    @Published var firstTap = true
    
    @Published var txtFieldsDisabled = false
    
    @Published var title = "Add camera"
    
    @Published var info = "Use this screen to add cameras that are not discoverable via multicast"
    
    //adding RTSP streams
    var options = ["ONVIF Camera","Network stream"]
    @Published var selectedOption = "ONVIF Camera"
    @Published var isOnvifMode = true
    
    @Published var rtspUser: String = ""
    @Published var rtspPassword: String = ""
    @Published var rtspHost: String = ""
    @Published var rtspPort: String = "554"
    @Published var rtspPath: String = ""
    @Published var rtspUrl: String = "rtsp://"
    @Published var rtspUrlStatus: String = ""
    @Published var rtspUrlOK = false
    @Published var rtspSubmitEnabled = false
    @Published var isChecking = false
    @Published var rtspUrlFld = ""
    
    var defaultRtspStatus = "Enter address, port, path and optional credentials, then select Check URL"
    @Published var canAddStream = true
    
    func checkIsPro(){
        if AppSettings.IS_PRO{
            canAddStream = true
        }else{
            let ns = AllNetStreams()
            canAddStream = ns.cameras.count == 0
        }
    }
    func validatePastedUrl(){
        let url = rtspUrlFld
        if url.hasPrefix("rtsp://"){
            if let rurl = URL(string: url){
                if let host = rurl.host{
                    if let port = rurl.port{
                        rtspHost = host
                        rtspPort = String(port)
                        rtspPath = rurl.path
                        if let user = rurl.user{
                            rtspUser = user
                        }
                        if let pass = rurl.password{
                            rtspPassword = pass
                        }
                        validateRtspUrl()
                    }
                }
            }
        }
    }
    func validateRtspUrl(){
        
        rtspUrlStatus = ""
        
        if rtspHost.isValidIpAddressOrHost == false{
            rtspUrlStatus = "Invalid host name or IP address"
        }
        
        rtspSubmitEnabled = rtspHost.isValidIpAddressOrHost
        
        var creds = ""
        if rtspUser.isEmpty==false{
            creds = rtspUser+":"+rtspPassword+"@"
        }
        var url = "rtsp://"+creds+rtspHost+":"+rtspPort
        if rtspPath.isEmpty == false && rtspPath.hasPrefix("/")==false{
            url = url + "/"
        }
        url = url+rtspPath
        rtspUrl = url.trimmingCharacters(in: .whitespacesAndNewlines)
        
    }
    func streamAlreadyExists()->Bool{
        let ns = AllNetStreams()
        
        return ns.streamExists(rtspUrl)
    }
    func clearRtspFlags(){
        rtspSubmitEnabled = false
        rtspUrlOK = false
        rtspUrlStatus = ""
        isChecking = false
        rtspUrl = ""
    }
    func resetRtspForm(){
        rtspUrl = "rtsp://"
        rtspHost = ""
        rtspPath = ""
        rtspPort = "554"
        rtspUser = ""
        rtspPassword = ""
        rtspSubmitEnabled = false
        rtspUrlOK = false
        rtspUrlStatus = defaultRtspStatus
    }
    
    var netStreamEnabled = true
    
    var hostKey = "add_host"
    
    init(){
        documentPickerLister = self
        addStatus = defaultPrompt
        
        if UserDefaults.standard.object(forKey: hostKey) != nil {
            ipAddress = UserDefaults.standard.string(forKey: hostKey)!
        }
        
        let fileName = "add_camera_info"
        if let filepath = Bundle.main.path(forResource: fileName, ofType: "txt") {
            do {
                info = try String(contentsOfFile: filepath)
                    
            } catch {
                AppLog.write("Failed to load file from bundle",fileName)
            }
        }
    }
    func setCheckMode(yes: Bool){
        if yes{
            isCheckMode = true
            addBtnLabel = "Check"
        }else{
            isCheckMode = false
            addBtnLabel = "Add camera"
        }
    }
    func reset(){
        let lastIpa = ipAddress
        ipAddress = ""
        portNum = ""
        ipAddress = lastIpa
        portColor = okColor
        ipAddressColor = okColor
        
        txtFieldsDisabled = false
        addStatus = defaultPrompt
        
        status = "No file selected"
        addStatusColor = okColor
        statusColor = okColor
        
        ipAddress = lastIpa
        
        setCheckMode(yes: true)
        addBtnDisabled = true
        scanBtnDisabled = ipAddress.isValidIpAddressOrHost == false
    }
    
    //MARK: DocumentPickerListener
    func onDocumentOpened(fileContents: String) -> Bool{
        AppLog.write("ImportCamerasSheet:onDocumentOpened")
        status = "Processing file..."
        statusColor = accentColor
        
        //parse the files
        return parseConfig(config: fileContents)
    }
    func onError(error: String) {
        status = "Unable to open file"
        statusColor = Color(UIColor.systemRed)
        AppLog.write("ImportCamerasSheet:OnError")
    }
    private func showError(msg: String,lineNum: Int,importedCount: Int){
        status = msg + " at line " + String(lineNum) + " imported " + String(importedCount)
    }
    private func parseConfig(config: String) -> Bool{
        let template = getWanTemplate()
        
        let tmpCamera = Camera(id: 0)
        
        var lineNum = 0
        var importCounted = 0
        let lines = config.components(separatedBy: .newlines)
        for ln in lines{
            lineNum += 1
            if ln.isEmpty || ln.hasPrefix("#"){
                continue
            }
            let parts = ln.components(separatedBy: ",")
            if parts.count != 2{
                showError(msg: "Invalid format", lineNum: lineNum, importedCount: importCounted)
                return false
            }
            
            let ipa = parts[0];
            let ipap = ipa.components(separatedBy: ":")
            if ipap.count != 2 || ipap[0].isValidIpAddressOrHost == false{
                showError(msg: "Invalid address "+ipa, lineNum: lineNum, importedCount: importCounted)
                return false
            }
            let ipp = ipa.components(separatedBy: ":")
            if ipp.count != 2{
                showError(msg: "Missing port in "+ipa, lineNum: lineNum, importedCount: importCounted)
                return false
            }
            let camName = parts[1];
            let xAddr = "http://" + ipa + "/onvif/device_service";
            
            var discoTemplate = template.replacingOccurrences(of: "_XADDR_",with: xAddr);
            discoTemplate = discoTemplate.replacingOccurrences(of: "_CAM_NAME_",with: camName);
            
            //let tmpCamera = Camera(id: 0)
            tmpCamera.xAddr = xAddr
            let discoXmlFile = tmpCamera.getBaseFileName() + "_disco.xml"
            let discoXmlFilePath = FileHelper.getStorageRoot().appendingPathComponent(discoXmlFile)
            
            do {
                try discoTemplate.write(to: discoXmlFilePath, atomically: true, encoding: String.Encoding.utf8)
                
                AppLog.write("Saved import XML file",discoXmlFile)
                importCounted = importCounted + 1
                
            } catch {
                // failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
                AppLog.write("FAILED TO SAVE IMPORT",discoXmlFile)
            }
            
        }
        status = "Import complete"
        if importCounted == 1{
            cameraEventListener?.onImportConfig(camera: tmpCamera)
        }else{
            cameraEventListener?.onImportConfig(camera: Camera(id: -1))
        }
        RemoteLogging.log(item: "ImportCamerasModel sucess")
        return true
    }
    private func getWanTemplate() -> String{
        let fileName = "wan_disco_template"
        if let filepath = Bundle.main.path(forResource: fileName, ofType: "xml") {
            do {
                let contents = try String(contentsOfFile: filepath)
                return contents
            } catch {
                AppLog.write("Failed to load XML from bundle",fileName)
            }
        }
        return ""
    }
}

struct ImportCamerasSheet: View, PortScannerListener {
    @Environment(\.presentationMode) var presentationMode
    @State var showFilePicker = false
    
    @ObservedObject var model = ImportCamerasModel()
    @State var filePicker =  DocumentPicker()
    
    
    func setListener(listener: CameraEventListener){
        model.cameraEventListener = listener
    }
    
    enum FocusedField {
           case rhost, rport, rpath, ruser, rpass, rcheck
       }
    
    @FocusState private var focusedField: FocusedField?
    
    var scanner = PortScanner()
    
    var body: some View {
        VStack{
            HStack{
                Text(model.title).appFont(.title)
                    //.padding()
                
                Spacer()
                Button(action: {
                    scanner.abort = true
                    presentationMode.wrappedValue.dismiss()
                    RemoteLogging.log(item: "ImportCamerasSheet:close")
                })
                {
                    Image(systemName: "xmark").resizable()
                        .frame(width: 18,height: 18)
                }.foregroundColor(Color.accentColor)
            }.padding()
            if model.netStreamEnabled{
                
                Picker("Video source",selection: $model.selectedOption){
                    ForEach(self.model.options, id: \.self) {
                        Text($0)//.foregroundColor(Color(.labelColor))
                        
                    }
                }.onChange(of: model.selectedOption) { newRes in
                    model.isOnvifMode = (newRes==model.options[0])
                    model.checkIsPro()
                }
                .pickerStyle(.segmented)
                .padding()
            }
            
            
            if model.isOnvifMode{
                List{
                    Section(header: Text("Individual camera").appFont(.sectionHeader)){
                        HStack{
                            TextField("IP Address or Hostname",text: $model.ipAddress)
                                .appFont(.body)
                                .keyboardType(.numbersAndPunctuation).foregroundColor(model.ipAddressColor).autocapitalization(.none).disableAutocorrection(true)
                                .keyboardType(.URL)
                                .disabled(model.txtFieldsDisabled)
                            
                            Button("Scan",action:{
                                //scan known ports grabbed from server
                                model.btnsDisabled = true
                                model.addBtnDisabled = true
                                //model.ipAddressColor = okColor
                                //model.portColor = okColor
                                
                                UIApplication.shared.endEditing()
                                
                                if model.ipAddress.isValidIpAddressOrHost == false{
                                    model.addStatus = "Invalid IP address"
                                    model.btnsDisabled = false
                                    //model.ipAddressColor = errorColor
                                    return
                                }
                                
                                model.importDisabled = true
                                model.addStatus = "Scanning known ports"
                                model.addStatusColor = model.accentColor
                                model.scanBtnDisabled = true
                                model.txtFieldsDisabled = true
                                scanner.initKnownPorts(ipAddress: model.ipAddress)
                                
                            }).foregroundColor(Color.accentColor)
                                .appFont(.body)
                                .disabled(model.scanBtnDisabled)
                        }
                        HStack{
                            TextField("ONVIF Port",text: $model.portNum).appFont(.body)
                                .keyboardType(.numberPad).foregroundColor(model.portColor)
                                .disabled(model.txtFieldsDisabled)
                            Spacer()
                            Button(model.addBtnLabel,action: {
                                
                                if model.isCheckMode == false{
                                    
                                    //add the camera and dismiss
                                    let camConfigStr = model.ipAddress + ":" + model.portNum + "," + Camera.DEFUALT_NEW_CAM_NAME
                                    model.addStatus = "Adding camera...."
                                    model.onDocumentOpened(fileContents: camConfigStr)
                                    model.reset()
                                    presentationMode.wrappedValue.dismiss()
                                    
                                    return
                                }
                                
                                
                                UIApplication.shared.endEditing()
                                
                                if model.ipAddress.isValidIpAddressOrHost == false{
                                    model.addStatus = "Invalid IP address"
                                    model.btnsDisabled = false
                                    // model.ipAddressColor = errorColor
                                    return
                                }
                                
                                guard let iport =  UInt16(model.portNum) else{
                                    model.addStatus = "Invalid port number"
                                    model.btnsDisabled = false
                                    //model.portColor = errorColor
                                    return
                                }
                                if scanner.cameraExists(host: model.ipAddress, port: iport){
                                    model.addStatus = "Camera exists on port " + model.portNum
                                    model.btnsDisabled = false
                                    model.addStatusColor = model.errorColor
                                    return
                                }
                                
                                model.btnsDisabled = true
                                model.addBtnDisabled = true
                                model.importDisabled = true
                                //model.txtFieldsDisabled = true
                                scanner.initAndscan(ipAddress: model.ipAddress, startAt: iport, endAt: iport)
                                
                                //save address for repopulating
                                UserDefaults.standard.set(model.ipAddress,forKey: model.hostKey)
                                
                            }).foregroundColor(Color.accentColor)
                                .appFont(.body)
                                .disabled(model.addBtnDisabled)
                        }
                        
                    }
                    Section(header: Text("Status").appFont(.sectionHeader)){
                        HStack{
                            Text(model.addStatus).fontWeight(.light).appFont(.caption).foregroundColor(model.addStatusColor)
                            Spacer()
                            Button("Reset",action:{
                                scanner.abort = true
                                model.reset()
                            }).foregroundColor(Color.accentColor)
                                .appFont(.body)
                        }
                    }
                }
            }else{
                addNetworkStreamView()
                    .padding()
            }
            Spacer()
        }
        .onAppear(perform: {
            scanner.listener = self
            NXVProxy.downloadOnvifPorts()
            RemoteLogging.log(item: "ImportCamerasSheet:onAppear")
            model.addBtnDisabled = model.portNum.isEmpty
        })
    }
    //MARK: Add Network Stream
    
    var rtspStreamChecker = RtspStreamChecker()
    private func changeFocusTo(fld: FocusedField){
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5){
            focusedField = fld
        }
    }
    private func addNetworkStreamView() -> some View{
        Form{
            if model.canAddStream{
                
                    if model.rtspUrlOK{
                        
                        //VStack(alignment: .center){
                        Text(model.rtspUrl)
                            .appFont(.smallCaption)
                            .multilineTextAlignment(.center)
                            .padding(.bottom,2)
                        
                            Text(model.rtspUrlStatus).appFont(.footnote)
                            .foregroundColor(.accentColor)
                            .multilineTextAlignment(.center)
                            .padding()
                        
                            
                            Button("Create virtual camera"){
                                model.cameraEventListener?.networkStreamAdded(streamnUrl: model.rtspUrl)
                                model.clearRtspFlags()
                                presentationMode.wrappedValue.dismiss()
                            }
                            
                            Button("Cancel"){
                                model.rtspUrlOK = false
                            }
                        
                        //}
                    }else{
                        if model.isChecking == false{
                            //VStack(spacing: 8){
                            Section(header:  Text("Enter individual RTSP URL Parts"),footer: Text("Press enter to complete")){
                                TextField("Host or IP address",text: $model.rtspHost)
                                    .autocorrectionDisabled().autocapitalization(.none)
                                    .onSubmit {
                                        model.validateRtspUrl()
                                        changeFocusTo(fld: .rport)
                                    }
                                TextField("RTSP Port",text: $model.rtspPort)
                                    .focused($focusedField,equals: .rport)
                                    .keyboardType(.numberPad)
                                    .onSubmit {
                                        model.validateRtspUrl()
                                        changeFocusTo(fld: .rpath)
                                    }
                                TextField("Path",text: $model.rtspPath)
                                    .focused($focusedField,equals: .rpath)
                                    .autocorrectionDisabled().autocapitalization(.none)
                                    .onSubmit {
                                        model.validateRtspUrl()
                                        changeFocusTo(fld: .ruser)
                                    }
                                
                                TextField("User (optional)",text: $model.rtspUser)
                                    .focused($focusedField,equals: .ruser)
                                    .autocorrectionDisabled().autocapitalization(.none)
                                    .onSubmit {
                                        model.validateRtspUrl()
                                        changeFocusTo(fld: .rpass)
                                    }
                                TextField("Password (optional)",text: $model.rtspPassword)
                                    .focused($focusedField,equals: .rpass)
                                    .autocorrectionDisabled().autocapitalization(.none)
                                    .onSubmit {
                                        model.validateRtspUrl()
                                        changeFocusTo(fld: .rcheck)
                                    }
                            }
                            /*
                            Section(header: Text("Full RTSP URL"),footer: Text("Use this field to paste a full URL then Enter to complete")){
                                TextField("Paste full RTSP URL",text: $model.rtspUrlFld)
                                    .autocorrectionDisabled().autocapitalization(.none)
                                    .onSubmit {
                                        model.validatePastedUrl()
                                    }
                            }
                             */
                        }
                        if model.rtspUrlStatus.isEmpty == false{
                            Text(model.rtspUrlStatus)
                                .foregroundColor(model.rtspUrlOK ? .accentColor : .red)
                                .padding()
                        }
                        
                        Button("Check URL"){
                            model.validateRtspUrl()
                            model.rtspUrl = model.rtspUrl.trimmingCharacters(in: .whitespacesAndNewlines)
                            
                            if model.streamAlreadyExists(){
                                model.rtspUrlStatus = "Identical Network stream exists"
                                return
                            }
                            model.isChecking = true
                            
                            model.rtspUrlStatus = "Testing URL...."
                            
                            rtspStreamChecker.checkStream(rtspUrl: model.rtspUrl) { result, success in
                                DispatchQueue.main.async{
                                    model.isChecking = false
                                    if result.isValid{
                                        model.rtspUrlStatus = result.data
                                        model.rtspUrlOK = true
                                    }else{
                                        model.rtspUrlStatus = result.error
                                    }
                                }
                                //debugPrint("Check network stream completed",success)
                                debugPrint("Check network stream",result.data)
                            }
                        }
                        .focused($focusedField,equals: .rcheck)
                        .disabled(model.rtspSubmitEnabled==false)
                        .hidden(model.rtspUrlOK || model.isChecking)
                        .keyboardShortcut(.return)
                        
                        
                        
                        if model.rtspUrl.count > 14{
                            Text(model.rtspUrl)
                        }
                    }
                
            }else{
                //Free version only one RTSP stream
                tryProStreamView()
            }
        }
    }
    private func tryProStreamView() -> some View{
       
            VStack(spacing: 15){
                Text("You have already added one RTSP stream").bold()
                
                Text("Upgrade to NX-V PRO to add multiple RTSP streams")
                    .foregroundColor(.accentColor)
                
                Text("TIP: To test a different stream delete your existing network stream")
                    .appFont(.caption)
                
                Button("Upgrade to PRO"){
                    if let url = URL(string: "macappstore://apps.apple.com/us/app/nx-v-pro/id1616437742"){
                        UIApplication.shared.open(url)
                    }
                }.keyboardShortcut(.return)
                
            }.padding()
        
    }
    //MARK: PortScannerListener
    func onPortFound(port: UInt16){
        DispatchQueue.main.async{
            model.portNum = String(port)
            
            model.addStatus = "Found ONVIF port: " + String(port)
            model.addStatusColor = model.accentColor
            model.isCheckMode = false
            model.addBtnDisabled = false
            model.scanBtnDisabled = false
            model.setCheckMode(yes: false)
        }
    }
    func onCompleted(){
        DispatchQueue.main.async{
            model.addStatus = "No ONVIF port found"
            model.btnsDisabled = false
            model.addBtnDisabled = true
            model.scanBtnDisabled = false
            model.importDisabled = false
            model.txtFieldsDisabled = false
            model.addStatusColor = model.errorColor
        }
    }
    func onPortCheckStart(port: UInt16){
        DispatchQueue.main.async{
            model.addStatus = "Testing port: " + String(port)
        }
    }
}

struct ImportCamerasSheet_Previews: PreviewProvider {
    static var previews: some View {
        ImportCamerasSheet()
    }
}
