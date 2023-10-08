//
//  GlobalMapPropertiesPanel.swift
//  NX-V
//
//  Created by Philip Bishop on 15/01/2022.
//

import SwiftUI

protocol GlobalMapPropertiesListener{
    func onPropertiesHidden()
}


class GlobalMapPropertiesModel : ObservableObject{
    var camera: Camera?
    
    @Published var name = ""
    @Published var angle = ""
    @Published var visible = false
    @Published var recodingEvents = [String:[RecordToken]]()
    @Published var recentAlerts = [RecordToken]()
    @Published var playerHidden = true
    @Published var playerWidth = CGFloat(245)
    @Published var playerStatus = "Connecting to camera...."
    
    @Published var cardinalPoints = ["N","NNE","NE","ENE","E","ESE","SE","SSE","S","SSW","SW","WSW","W","WNW","NW","NNW"]
    @Published var cardinalSelected = "N"
    
    @Published var cameraAuthenticated = false
    @Published var isGlobalMap = false
    
    @Published var hasLocation = false
    @Published var locationHelp = ""
    @Published var searchText = ""
    
    @Published var rightToggleColor: Color = .accentColor
    @Published var isCollapsed = false
    
    @Published var address = ""
    @Published var showPlayerSheet = false
    var videoPlayerSheet = VideoPlayerSheet()
    
    var listener: MapViewEventListener?
    var closeListener: GlobalMapPropertiesListener?
    
    var formFont = AppFont.TextStyle.caption
    
    init(){
        if ProcessInfo.processInfo.isiOSAppOnMac{
            formFont = .helpLabel
        }
    }
    
    func setAddress(addr: String){
        address = addr
        if let cam = camera{
            cam.locationAddress = addr
        }
    }
    
    func setTextForResource(res: String){
        if let filepath = Bundle.main.path(forResource: res, ofType: "txt") {
            do {
                let contents = try String(contentsOfFile: filepath)
                //AppLog.write(contents)
                locationHelp = contents
                
            } catch {
                AppLog.write("Location help: \(error)")
            }
        }else{
            AppLog.write("Location help: Can't find",res)
        }
    }
    
    func setCamera(camera: Camera,isGlobalMap: Bool){
        self.camera = camera
        self.isGlobalMap = isGlobalMap
        visible = true
        address = ""
        if ProcessInfo.processInfo.isiOSAppOnMac{
            setTextForResource(res: "map_set_location_mac")
        }else{
            setTextForResource(res: "map_set_location")
        }
        hasLocation = camera.location != nil
        cameraAuthenticated = camera.isAuthenticated()
        playerWidth = CGFloat(245)
        playerHidden = true
        address = camera.locationAddress
        
        name = camera.getDisplayName()
        angle = String(camera.beamAngle)
        
        let inc = 22.5 // degrees
        var selPoint = 0
        let dangle = Double(angle)!
        var cangle = 0.0
        for i in 0...cardinalPoints.count-1{
            
            if dangle >= cangle{
                selPoint = i
            }
            
            cangle += inc
        }
        
        cardinalSelected = cardinalPoints[selPoint]
        
    }
    func cardinalChanged(){
        
        let inc = 22.5 // degrees
        var cangle = 0.0
        for i in 0...cardinalPoints.count-1{
            
            if cardinalSelected == cardinalPoints[i]{
                angle = String(cangle)
                setBeamAngle(beam: cangle)
                break
            }
            cangle += inc
        }
    }
    func setBeamAngle(beam: Double){
        camera!.beamAngle = beam
        camera!.saveLocation()
        DispatchQueue.main.async {
            
            self.listener?.cameraMapPropertyChanged(camera: self.camera!)
        }
    }
    
    func handleEvent(camera: Camera,token: RecordToken){
        
        let key = camera.getStringUid()
        if recodingEvents[key] == nil{
            recodingEvents[key] = [RecordToken]()
        }
        var exists = false
        if let items = recodingEvents[key]{
            for item in items{
                if item.Time == token.Time{
                    exists = true
                    break
                }
            }
        }
        if !exists{
            recodingEvents[key]!.insert(token, at: 0)
            
            let ne = recodingEvents[key]!.count
            if ne > 5 {
                
                recodingEvents[key]!.remove(at: ne-1)
            }
        }
    }
    func getRecentEvents() -> [RecordToken]?{
        if camera != nil{
            return recodingEvents[camera!.getStringUid()]
        }
        return nil
    }
}

struct GlobalMapPropertiesPanel : View, VideoPlayerDimissListener{
    
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var iconModel = AppIconModel()
    
    @ObservedObject var model = GlobalMapPropertiesModel()
    
    //Works but popups keypad = irratating
    //@FocusState private var isFocused: Bool
    
    init(){
        AppLog.write("GlobalMapPropertiesPanel:init")
    }
    
    //MARK: VideoPlayerDimissListener
    func dimissPlayer() {
        model.showPlayerSheet = false
    }
    func dismissAndShare(localPath: URL) {
        
    }
    func changeCamera(camera: Camera){
        model.setCamera(camera: camera,isGlobalMap: model.isGlobalMap)
       
    }
   
    func setCamera(camera: Camera,isGlobalMap: Bool,listener: MapViewEventListener,closeListener: GlobalMapPropertiesListener){
        model.setCamera(camera: camera,isGlobalMap: isGlobalMap)
        self.model.listener = listener
        self.model.closeListener = closeListener
        AppLog.write("GlobalMapPropertiesPanel:setCamera isGlobal",isGlobalMap)
        
    }
    func hide(){
        model.visible = false
        model.playerHidden = true
        
        //borderlessPlayer.stop()
    }
    func show(){
        model.visible = true
    }
   
    var body: some View {
        VStack(alignment: .leading){
            HStack(alignment: .center,spacing: 3){
               
                Text(model.name).appFont(.body).lineLimit(1)
                Spacer()
               
                Button(action: {
                    //show streamin view
                    //AppDelegate.Instance.showCameraWindow(camera: model.camera!)
                    model.videoPlayerSheet = VideoPlayerSheet()
                    model.showPlayerSheet = true
                    model.videoPlayerSheet.doInit(camera: model.camera!,listener: self)
                }){
                 
                    Image(systemName: "play")
                        //.resizable()
                       // .frame(width: 24, height: 26)
                    
                }.hidden(model.cameraAuthenticated==false || model.isGlobalMap==false)
                    .buttonStyle(PlainButtonStyle())
                    .padding(.trailing)
                    .disabled(model.showPlayerSheet)
                
                
                Image(systemName: "sidebar.right").frame(width: 32,height: 28).onTapGesture {
                    //model.closeListener?.onPropertiesHidden()
                    model.isCollapsed = !model.isCollapsed
                }.foregroundColor(model.rightToggleColor)
                
            }.appFont(.body)
            .padding(.top,5)
               
            
            if model.isCollapsed == false{
            
            Divider()
            
            if model.hasLocation{
               // Text("Properties").appFont(.sectionHeader).frame(alignment: .leading)
                
                HStack{
                    Text("Direction")
                        .fontWeight(.semibold).appFont(.caption)
                    
                    Menu{
                        Picker("",selection: $model.cardinalSelected){
                            ForEach(model.cardinalPoints, id: \.self) {
                                Text($0)
                            }
                        }.onChange(of: model.cardinalSelected) { newCardinal in
                            model.cardinalChanged()
                        }
                    } label:{
                        Text(model.cardinalSelected).foregroundColor(.accentColor)
                    }.appFont(.caption)
                    
                    .frame(width: 120)
                    
                    Spacer()
                }
                
                if model.address.isEmpty == false{
                    Text("Address").fontWeight(.semibold)
                        .appFont(model.formFont)
                    HStack{
                        Text(model.address).appFont(model.formFont)
                        Spacer()
                    }.frame(height: 80,alignment: .leading)
                    
                    HStack{
                        Button(action: {
                            model.camera!.location = nil
                            model.camera?.locationAddress = ""
                            model.camera!.saveLocation()
                            model.listener?.removeCameraFromMap(camera: model.camera!)
                        }){
                            Text("Change").appFont(.caption)
                        }.buttonStyle(.bordered)
                        
                        
                        Button(action:{
                            model.listener?.zoomToCamera(camera: model.camera!)
                        }){
                            Text("Zoom to").appFont(.caption)
                        }.buttonStyle(.bordered)
                    } .padding(.bottom)
                }
                /*
                Divider()
                Text("Tip: You can close this panel then tap on a camera map location to reopen").fontWeight(.light).appFont(.caption).frame(alignment: .leading)
                */
                 /*
                if let recentEvents = model.getRecentEvents(){
                    ScrollView(.vertical){
                        VStack{
                            ForEach(recentEvents) { alert in
                                Text(alert.Time).appFont(.smallCaption)
                            }
                        }
                    }.frame(height: 150)
                }
                 */
                
            }else{
                
                VStack(alignment: .leading){
                    Text("Find location").fontWeight(.semibold)
                        .appFont(model.formFont)
                    TextEditor(text: $model.searchText).appFont(model.formFont)
                        .textFieldStyle(.roundedBorder)
                        //.focused($isFocused)
                        .padding(.trailing)
                        
                    
                    Button(action: {
                        UIApplication.shared.endEditing()
                        model.listener?.doSearch(poi: model.searchText)
                        
                    }){
                        Text("Search").appFont(.helpLabel)
                    }.buttonStyle(.bordered).disabled(model.searchText.count<5)
                    
                    Divider()
                    
                    Text("Set camera location").fontWeight(.semibold).appFont(.sectionHeader)
                        .padding()
                    
                    Text(model.locationHelp)
                        .fixedSize(horizontal: false, vertical: true)
                        .appFont(.sectionHeader)
                        .padding(.trailing)
                    
                   
                    
                }.padding(3)
                    .onAppear{
                        //isFocused = true
                    }
                    .frame(height: 400,alignment: .leading)
                
            }
            
            }
            
        }.hidden(model.visible == false)
            .onAppear{
                recordingEventMonitor.cameraPropsModel = model
                iconModel.initIcons(isDark: colorScheme == .dark )
            }
            .fullScreenCover(isPresented: $model.showPlayerSheet){
                model.videoPlayerSheet
            }
    }
}

