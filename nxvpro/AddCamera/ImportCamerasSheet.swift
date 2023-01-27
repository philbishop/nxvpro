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
    
    
    var scanner = PortScanner()
    
    var body: some View {
        List(){
            HStack{
                Text(model.title).appFont(.title)
                    .padding()
                
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
            }
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
            /*
            if model.isNxvPro{
                Section(header: Text("Advanced").appFont(.sectionHeader)){
                    //Text("Tap the files button and then select your camera config text file")
                    
                    
                    Button(action: {
                        showFilePicker = true
                    }){
                        HStack{
                            
                            Image(systemName: "doc.text").resizable()
                                .frame(width: 18,height: 18)
                            
                            Text("Import camera configuration file").appFont(.body)
                        }
                    }.foregroundColor(Color.accentColor).appFont(.body)
                    .disabled(model.importDisabled)
                    .sheet(isPresented: $showFilePicker, content: {
                        filePicker
                    })
                }
                
                Section(header: Text("Advanced status").appFont(.sectionHeader)){
                    Text(model.status).fontWeight(.light).appFont(.caption)
                }
                
                Section(header: Text("File format comma-separated").appFont(.sectionHeader)){
                    VStack{
                        ImportItem(label: "#EXAMPLE")
                        //  ImportItem(label: "#ADDRESS:PORT,Camera name")
                        Spacer()
                        ImportItem(label: "198,105.24.178:8080,Front west")
                        ImportItem(label: "198,104.16.35:2020,Front east")
                        ImportItem(label: "198,105.24.123:80,Rear 1")
                        ImportItem(label: "198,104.16.35:80,Rear 2")
                        
                    }
                }
            }else{
                Section(header: Text("Usage").appFont(.sectionHeader)){
                    Text(model.info).frame(height: 222).appFont(.body)
                }
            }
             */
        }
        .onAppear(perform: {
            scanner.listener = self
            NXVProxy.downloadOnvifPorts()
            RemoteLogging.log(item: "ImportCamerasSheet:onAppear")
            model.addBtnDisabled = model.portNum.isEmpty
        })
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
