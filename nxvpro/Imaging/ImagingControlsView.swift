//
//  ImagingControlsView.swift
//  NXV-OSX
//
//  Created by Philip Bishop on 28/12/2021.
//

import SwiftUI

protocol ImagingItemChangeHandler{
    func register(optName: String,imagingView: RefreshableImagingView)
}

protocol RefreshableImagingView{
    func updateView(opt: ImagingType)
}
protocol ImagingActionListener{
    func applyImagingChanges(camera: Camera)
    func closeImagingView()
    func applyEncoderChanges(camera: Camera,success: Bool)
    func imagingItemChanged()
    func encoderItemChanged()
    
}

class ImagingControlsModel : ObservableObject, ImagingItemChangeHandler{
    //@Published var items = [ImagingType]()
    @Published var basicItems = [ImagingType]()
    @Published var advancedItems = [ImagingType]()
    
    @Published var advancedEnabled = false
    @Published var isUpdating = false
    
    var camera: Camera?
    var lock = NSLock()
    var listener: ImagingActionListener?
    
    var viewResistry = [String: RefreshableImagingView]()
    func register(optName: String,imagingView: RefreshableImagingView) {
        lock.lock()
        viewResistry[optName] = imagingView
        lock.unlock()
    }
    func cameraUpdated(camera: Camera){
        if camera.imagingOpts == nil{
            return
        }
        lock.lock()
        for opt in camera.imagingOpts!{
            if let view = viewResistry[opt.name]{
                view.updateView(opt: opt)
            }
        }
        lock.unlock()
    }
  
    func reset(){
        basicItems.removeAll()
        advancedItems.removeAll()
        
        viewResistry.removeAll()
    }
    func setCamera(camera: Camera){
        lock.lock()
        isUpdating = true
        
        print("!$$$>>>ImagingControlsModel:setCamera START")
        
        reset()
        
        //Log if change of camera
        if self.camera != nil{
            if self.camera?.getStringUid() != camera.getStringUid(){
                print("!$$$>>>ImagingControlsModel:setCamera changed")
            }
        }
        
        self.camera = camera
        
        advancedEnabled = false
        
        if let iops = camera.imagingOpts{
            for opt in iops{
        
                opt.dump()
                
                if opt is MinMaxImagingType{
                    basicItems.append(opt)
                }else{
                    advancedItems.append(opt)
                    advancedEnabled = true
                }
                 
            }
        }
        print("!$$$>>>ImagingControlsModel:setCamera END")
        isUpdating = false
        
        lock.unlock()
    }
}



struct ImagingControlsView: View {
    @ObservedObject var model = ImagingControlsModel()
    
    func cameraUpdated(camera: Camera){
        model.cameraUpdated(camera: camera)
    }
    
    func setCamera(camera: Camera){
        model.setCamera(camera: camera)
        
        
    }
    
    func reset(){
        model.reset()
    }
    func applyChanges(){
        print("ImagingControlsView:applyChanges start")
        if let camera = model.camera{
            
            model.listener?.applyImagingChanges(camera: camera)
        }
        print("ImagingControlsView:applyChanges end")
        
        
    }
    var body: some View {
        ScrollView(.vertical){
            VStack{
                if model.isUpdating == false{
                    ForEach(model.basicItems, id: \.self) { opt in
                        if opt is MinMaxImagingType{
                            MinMaxImagingView(opt: opt as! MinMaxImagingType,handler: model,listener: model.listener).padding(.trailing)
                            Divider()
                        }
                    }
                }
                if model.isUpdating == false{
                    ForEach(model.advancedItems, id: \.self) {opt in
                        if opt is ModeImagingType{
                            ModeImagingView(opt: opt as! ModeImagingType,handler: model,listener: model.listener).padding(.trailing)
                        } else if opt is WhiteBalanceImagingType{
                            WhiteBalanceImagingView(opt: opt as! WhiteBalanceImagingType,handler: model,listener: model.listener).padding(.trailing)
                        } else if opt is WideDynamicRangeImagingType{
                            WideDynamicRangeImagingView(opt: opt as! WideDynamicRangeImagingType,handler: model,listener: model.listener).padding(.trailing)
                        } else if opt is ExposureImagingType{
                            ExposureImagingView(opt: opt as! ExposureImagingType,handler: model,listener: model.listener).padding(.trailing)
                        }else if opt is FocusImagingType{
                            FocusImagingView(opt: opt as! FocusImagingType,handler: model).padding(.trailing)
                        }
                        Divider()
                    }
                }
            }.onAppear(){
                print(">>>>ImagingControlsView:onAppear basic items",model.basicItems.count)
            }
        }
        
    }
}

class ImagingControlsContainerModel : ObservableObject{
    @Published var showImagingTab = false
    @Published var canApply = false
    //@Published var error = ""
    @Published var status = ""

    @Published var imagingDirty = false
    @Published var encoderDirty = false
 
    @Published var encoderViewEnabled = true
    @Published var showEncoderSheet = false
    
    var listener: ImagingActionListener?
}

struct ImagingControlsContainer: View {
    
    @ObservedObject var model = ImagingControlsContainerModel()
    
    @State var imagingView = ImagingControlsView()
   
    let encoderView = VideoEncoderView()
   
    
    @State var camera: Camera?
    @State var selectedTab = 0
    
    func setCamera(camera: Camera,listener: ImagingActionListener,isEncoderUpdate: Bool = false){
        reset()
        self.camera = camera
        self.model.listener = listener
        imagingView.model.listener = listener
        model.showImagingTab = camera.hasImaging()
        
        encoderView.model.listener = listener
        
        if !model.showImagingTab{
            selectedTab = 1
        }
        model.imagingDirty = false
        model.encoderDirty = false
        imagingView.setCamera(camera: camera)
        if isEncoderUpdate && model.encoderViewEnabled{
            encoderView.setCamera(camera: camera)
        }
    }
    func setStatus(_ status: String){
        model.status = status
    }
    func reset(){
        imagingView.reset()
        encoderView.reset()
        //model.error = ""
        model.status = ""
    }
    
    func imagingItemChanged() {
        model.imagingDirty = true
        model.canApply = true
    }
    func encoderItemChanged() {
        model.encoderDirty = true
        model.canApply = true
    }
    var body: some View {
        ZStack(alignment: .top){
            Color(UIColor.secondarySystemBackground)
            VStack{
                TabView(selection: $selectedTab){
                    if model.showImagingTab{
                        imagingView
                        .tabItem{
                            Text("Image")
                        }.tag(0)
                    }
                    
                    ZStack{
                        encoderView
                    }.tabItem{
                        Text("Video")
                    }.tag(1)
                    
                }.onChange(of: selectedTab, perform: { index in
                    //model.error = ""
                    model.status = ""
                })
                
                
                //imagingView
                //Text(model.error).appFont(.caption).foregroundColor(.pink)
                //    .frame(height: model.error.isEmpty ? 0.0 : 30)
                
                HStack{
                    Text(model.status).appFont(.caption).foregroundColor(.accentColor).padding()
                   
                   
                    
                    Button(action:{
                        //model.error = ""
                        model.status = "Saving..."
                        if model.imagingDirty{
                            imagingView.applyChanges()
                        }
                        if model.encoderDirty{
                            encoderView.applyChanges()
                        }
                        model.canApply = false
                    }){
                        Text("Apply changes").appFont(.helpLabel).foregroundColor(.accentColor)
                    }.buttonStyle(PlainButtonStyle())
                    .hidden(model.canApply == false).padding(.trailing)
                    
                    Spacer()
                    
                    Button(action:{
                        model.listener?.closeImagingView()
                    }){
                        Text("Close").appFont(.caption).foregroundColor(model.canApply ? Color(UIColor.label) : .accentColor)
                    }.buttonStyle(PlainButtonStyle())
                }
               
            }.padding()
        }.cornerRadius(15)
        .frame(width: 270,height: 375)
    }
}

struct ImagingControlsView_Previews: PreviewProvider {
    static var previews: some View {
        ImagingControlsView()
    }
}
