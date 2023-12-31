//
//  SystemLogView.swift
//  NX-V
//
//  Created by Philip Bishop on 05/01/2022.
//

import SwiftUI

class SystemLogViewModel : ObservableObject{
    
    @Published var supportsLogging = false
    @Published var currentLog = [String]()
    @Published var logType = "System"
    @Published var status = "Waiting for logging data..."
    @Published var allProps = CameraProperies()
    @Published var canSetTime = false
    @Published var frameWidth =  CGFloat(360)
    var camera: Camera?
    let onvif = OnvifDisco()
    
    
    func setCamera(camera: Camera){
        self.camera = camera
        self.supportsLogging = camera.systemLogging
        self.currentLog.removeAll()
        self.allProps.props.removeAll()
        self.canSetTime = camera.systemTimetype == "Manual"
        if UIScreen.main.bounds.width == 320{
            frameWidth = CGFloat(300)
        }
        loadData()
    }
    func loadData(){
        
        
        if self.camera!.isNetworkStream(){
            self.status = "Logging not available for network stream"
            return
        }
        
        status = "Loading device capabilties..."
        
        
        if let cam = self.camera{
            onvif.prepare()
            
            onvif.getSystemCapabilites(camera: cam,callback: handleGetSystenCapabilities)
            
        }else{
            status = "Missing camera details"
        }
        
    }
    
    func handleGetSystenCapabilities(camera: Camera,xPaths: [String],data: Data?){
        DispatchQueue.main.async{
            self.handleGetSystenCapabilitiesImpl(camera: camera,xPaths: xPaths,data: data)

        }
    }
    private func handleGetSystenCapabilitiesImpl(camera: Camera,xPaths: [String],data: Data?){
        if let xml = data{
      
            let xmlParser = XmlAttribsParser(tag: "System")
            xmlParser.parseRespose(xml: xml)
            
            DispatchQueue.main.async{
                
                var pid = 0
                for (key,val) in xmlParser.attribs{
                    self.allProps.props.append(CameraProperty(id: pid,name: key.camelCaseToWords(),val: val,editable: false))
                    pid += 1
                }
                
                self.status = "Got capabilities, waiting for log...."
                
                AppLog.write("SystemLogView attributes",xmlParser.attribs.count)
                
                self.supportsLogging = false
                self.currentLog.removeAll()
            }
            let dq = DispatchQueue(label: "syslog")
            dq.asyncAfter(deadline: .now() + 0.5,execute:{
                self.getLog()
            })
        
        }else{
            self.status = "No cabilities found"
            
        }
    }
    func getLog(){
        
        onvif.getSystemLog(camera: camera!, logType: logType) { cam, logLines, error, ok in
            AppLog.write("SystemLogViewModel:getSystemLog",logLines.count,error,ok)
           
            var buf = [String]()
            var itemCount = 0
            if ok{
                for line in logLines{
                    if line.hasPrefix("<"){
                        continue
                    }
                    buf.append(line)
                    
                    itemCount += 1
                    if itemCount > 50{
                        break
                    }
                }
                DispatchQueue.main.async{
                    self.supportsLogging = true
                   
                    self.status = ""
                    if buf.count == 0{
                        self.status = "No logging data returned by device"
                    }else{
                        self.currentLog = buf
                    }
                }
            }else{
                DispatchQueue.main.async{
                    self.status = error
                }
            }
        
        }
        
    }
}

struct SystemLogView: View {
    @ObservedObject var model = SystemLogViewModel()
    
    @State var showRebootAlert = false
    @State var showSetTimeAlert = false
    
    func setCamera(camera: Camera){
        model.setCamera(camera: camera)
    }
    
    var body: some View {
        ZStack(alignment: .topLeading){
            GeometryReader { fullView in
                let isLanscape = fullView.size.width > 600
                
                VStack{
                    HStack{
                        VStack{
                            Text("System info").appFont(.titleBar)
                            
                            List(){
                                Section(header: Text("Capabilities")){
                                    ForEach(model.allProps.props, id: \.self) { prop in
                                        HStack{
                                            Text(prop.name).fontWeight(prop.val.isEmpty ? .none : /*@START_MENU_TOKEN@*/.bold/*@END_MENU_TOKEN@*/)
                                                .appFont(.caption)
                                                .frame(alignment: .leading)
                                            Spacer()
                                            Text(prop.val).appFont(.caption)
                                                .frame(alignment: .trailing)
                                            
                                        }.frame(alignment: .leading)
                                    }
                                }
                            }.listStyle(PlainListStyle())
                            Spacer()
                        }.frame(width: model.frameWidth)
                        if isLanscape{
                            Divider()
                            VStack(alignment: .leading){
                                Text("System log").appFont(.titleBar)
                                if model.supportsLogging == false{
                                    Text(model.status).appFont(.caption)
                                        .padding()
                                }else{
                                    Text(model.status).appFont(.sectionHeader).foregroundColor(.accentColor)
                                        .appFont(.caption)
                                }
                                ScrollView(.vertical){
                                    VStack(alignment: .leading){
                                        ForEach(model.currentLog,id: \.self) {line in
                                            HStack{
                                                Text(line).font(.system(.caption, design: .monospaced))
                                                
                                                    .frame(alignment: .leading)
                                                Spacer()
                                            }
                                        }
                                        
                                    }
                                }
                            }
                        }
                        Spacer()
                    }.frame(alignment: .leading)
                    HStack(spacing: 15){
                        
                        Button("Set time",action:{
                            showSetTimeAlert = true
                        }).disabled(model.canSetTime==false)
                            .alert(isPresented: $showSetTimeAlert) {
                                
                                Alert(title: Text("System time"), message: Text("Set camera date & time to current time\n" + "\n"
                                                                                + model.camera!.getDisplayAddr()
                                                                                + "\n" + model.camera!.getDisplayName()),
                                      primaryButton: .default (Text("Set time")) {
                                    showSetTimeAlert = false
                                    
                                    globalCameraEventListener?.setSystemTime(camera: model.camera!)
                                },
                                      secondaryButton: .cancel() {
                                        showSetTimeAlert = false
                                    }
                                )
                            }
                        
                        Button("Reboot",action:{
                            showRebootAlert = true
                        }).alert(isPresented: $showRebootAlert) {
                            
                            Alert(title: Text("REBOOT"), message: Text("Confirm device reboot\n" + "\n" + model.camera!.getDisplayAddr()
                                                                       + "\n" + model.camera!.getDisplayName()),
                                  primaryButton: .default (Text("Reboot")) {
                                showRebootAlert = false
                                
                                globalCameraEventListener?.rebootDevice(camera: model.camera!)
                            },
                                  secondaryButton: .cancel() {
                                showRebootAlert = false
                            }
                            )
                        }
                       
                    }.padding()
                    
                }.background(Color(uiColor: .secondarySystemBackground))
                    .frame(width: fullView.size.width,height: fullView.size.height)
                    
            }
        }
    }
}

struct SystemLogView_Previews: PreviewProvider {
    static var previews: some View {
        SystemLogView()
    }
}
