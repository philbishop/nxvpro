//
//  VideoEncoderView.swift
//  NX-V
//
//  Created by Philip Bishop on 21/01/2022.
//

import SwiftUI

class VideoEncoderModel : ObservableObject, OnvifVideoEncoderListener{
    var camera: Camera?
    var onvifEncoder: OnvifVideoEncoder!
    
    @Published var ready = false
    @Published var status = "Loading..."
    @Published var resolutions = [String]()
    @Published var fpsRange = [String]()
    @Published var bitRateEditable = false
    @Published var govLengthRange = [String]()
    @Published var intervalRange = [String]()
    @Published var qualityRange = [String]()
    @Published var selectedRes = ""
    @Published var selectedFps = ""
    @Published var selectedBitrate = ""
    @Published var selectedGovLength = ""
    @Published var selectedInterval = ""
    @Published var selectedQuality = ""
    @Published var selectedH264Profile = ""
    @Published var resColor = Color(UIColor.label)
    @Published var fpsColor = Color(UIColor.label)
    @Published var qualColor = Color(UIColor.label)
    @Published var govColor = Color(UIColor.label)
    @Published var encColor = Color(UIColor.label)
    
    var nLabels = 5
    var xmlTemplate = ""
    var currentVideoProfile: VideoProfile!
    
    var listener: ImagingActionListener?
    
    func reset(){
        DispatchQueue.main.async{
            self.ready = false
            self.status = "Loading..."
            self.resolutions.removeAll()
            self.fpsRange.removeAll()
            self.intervalRange.removeAll()
            self.qualityRange.removeAll()
            self.bitRateEditable = false
            self.govLengthRange.removeAll()
            self.selectedH264Profile = ""
            
            self.resColor = Color(UIColor.label)
            self.fpsColor = Color(UIColor.label)
            self.qualColor = Color(UIColor.label)
            self.govColor = Color(UIColor.label)
            self.encColor = Color(UIColor.label)
        }
    }
    
    func initCamera(camera: Camera){
        self.camera = camera
        reset()
        
        onvifEncoder = OnvifVideoEncoder()
        
        xmlTemplate = onvifEncoder.setEncoderTemplate
        
        onvifEncoder.listener = self
        onvifEncoder.getVideoProfiles(camera: camera)
    }
    
    //MARK: OnvifVideoEncoderListener
    func onError(camera: Camera, error: String) {
        DispatchQueue.main.async {
            self.status = error
        }
    }
    func onComplete(camera: Camera) {
        if self.camera!.getStringUid() == camera.getStringUid(){
            self.camera = camera
            self.reset() 
            print("VideoEncoderModel:onComplete",camera.videoProfiles.count)
            if let cp = camera.selectedProfile(){
                let vps = camera.videoProfiles
                for vp in vps{
                    if vp.profileToken == cp.token{
                        currentVideoProfile = vp
                        DispatchQueue.main.async{
                            self.selectedRes = cp.resolution
                            self.populate(vp: vp)
                        }
                        return
                    }
                }
            }
        }
        DispatchQueue.main.async{
            self.status = "No H264 codec found"
        }
    }
    private func populate(vp: VideoProfile){
    
        
        let nr = vp.options.resWidths.count
        let opts = vp.options
        for i in 0...nr-1{
            let resW = opts.resWidths[i]
            if let irw = Int(resW){
                if irw > 240{
                    let strRes = resW + "x" + opts.resHeights[i]
                    if !resolutions.contains(strRes){
                        resolutions.append(strRes)
                    }
                }
            }
        }
       
        selectedFps = vp.frameRateRateLimit
        if opts.frameRateRange.count==2{
            if let minFps = Int(opts.frameRateRange[0]){
                if let maxFps = Int(opts.frameRateRange[1]){
                    for i in minFps...maxFps{
                        fpsRange.append(String(i))
                    }
                }
            }
        }else{
            fpsRange.append(selectedFps)
        }
        selectedBitrate = vp.bitRateLimit
        bitRateEditable = opts.bitRateRange.count == 2
        
        selectedGovLength = vp.govLength
        if opts.govLengthRange.count == 2{
            if let minVal = Int(opts.govLengthRange[0]){
                if let maxVal = Int(opts.govLengthRange[1]){
                    for i in minVal...maxVal{
                        govLengthRange.append(String(i))
                    }
                }
            }
        }
        
        selectedInterval = vp.encodingInterval
        if opts.intervalRange.count == 2{
            if let minVal = Int(opts.intervalRange[0]){
                if let maxVal = Int(opts.intervalRange[1]){
                    for i in minVal...maxVal{
                        intervalRange.append(String(i))
                    }
                }
            }
        }
        selectedQuality = vp.quality
        let qp = vp.quality.components(separatedBy: ".")
        if qp.count > 1{
            selectedQuality = qp[0]
        }
        if opts.qualityRange.count == 2{
            if let minVal = Int(opts.qualityRange[0]){
                if let maxVal = Int(opts.qualityRange[1]){
                    for i in minVal...maxVal{
                        qualityRange.append(String(i))
                    }
                }
            }
        }
        
        selectedH264Profile = vp.h264Profile
        ready = true
    }
    
    func applyChanges(){
        let resParts = selectedRes.components(separatedBy: "x")
        currentVideoProfile.resWidth = resParts[0]
        currentVideoProfile.resHeight = resParts[1]
        
        currentVideoProfile.quality = selectedQuality
        currentVideoProfile.encodingInterval = selectedInterval
        currentVideoProfile.bitRateLimit = selectedBitrate
        currentVideoProfile.govLength = selectedGovLength
        currentVideoProfile.frameRateRateLimit = selectedFps
    
        var soapPacket = currentVideoProfile.populateXmlTemplate(soapPacket: xmlTemplate)
        
        #if DEBUG
        //let toRemove = " xmlns=\"http://www.onvif.org/ver10/schema\""
        //soapPacket = soapPacket.replacingOccurrences(of: toRemove, with: "")
        #endif
        
        print("VideoEncoderModel:applyChanges")
        print(soapPacket)
        
        let onvifEncoder = OnvifVideoEncoder()
        onvifEncoder.updateVideoEncoder(camera: camera!, xmlPacket: soapPacket) { status, success in
            if !success{
                print("VideoEncoderModel:updateVideoEncoder FAILED",status)
            }else{
                if let cp = self.camera!.selectedProfile(){
                    cp.resolution = self.selectedRes
                    self.camera!.flagChanged()
                }
                print("VideoEncoderModel:updateVideoEncoder OK",success)
            }
            
            self.listener?.applyEncoderChanges(camera: self.camera!,success: success)
        }
        
        
    }
}



struct VideoEncoderView : View{
    @ObservedObject var model = VideoEncoderModel()
    
    func reset(){
        model.reset()
    }
    
    func setCamera(camera: Camera){
        model.initCamera(camera: camera)
    }
    func applyChanges(){
       // print("VideoEncoderView:applyChanged -> NOT IMPLEMENTED")
        model.applyChanges()
        
    }
    var labelWidth = CGFloat(90)
    var body: some View {
        
            VStack{
                
                //Resolution picker
                HStack{
                    Text("Resolution").foregroundColor(model.resColor).appFont(.caption)
                        .frame(width: labelWidth,alignment: .leading)
                    Spacer()
                    Picker("",selection: $model.selectedRes){
                        ForEach(model.resolutions, id: \.self) {
                            Text($0)
                        }
                    }.onChange(of: model.selectedRes) { newSize in
                        print("VideoEncoderView:res",newSize)
                        model.resColor = Color.accentColor
                        model.listener?.encoderItemChanged()
                    }.pickerStyle(.menu)
                    
                }
                //TextField("H264 profile",text: $model.selectedH264Profile).disabled(true)
                
                //FPS
                HStack{
                    Text("Frame rate").foregroundColor(model.fpsColor).appFont(.caption)
                        .frame(width: labelWidth,alignment: .leading)
                    Spacer()
                    Picker("",selection: $model.selectedFps){
                        ForEach(model.fpsRange, id: \.self) {
                            Text($0)
                        }
                    }.onChange(of: model.selectedFps) { newFps in
                        print("VideoEncoderView:fps",newFps)
                        model.fpsColor = Color.accentColor
                        model.listener?.encoderItemChanged()
                    }.pickerStyle(.menu)
                }
                //Bitrate
               /* Text("Bit rate")
                TextField("Bit rate",text: $model.selectedBitrate)
                    .onChange(of: model.selectedBitrate){
                        let change = String($0)
                        model.listener?.encoderItemChanged()
                    }.disabled(model.bitRateEditable==false)
                 */
                
                //Quality range
                HStack{
                    Text("Quality").foregroundColor(model.qualColor).appFont(.caption)
                        .frame(width: labelWidth,alignment: .leading)
                    Spacer()
                    Picker("",selection: $model.selectedQuality){
                        ForEach(model.qualityRange, id: \.self) {
                            Text($0)
                        }
                    }.onChange(of: model.selectedQuality){  newValue in
                        print("VideoEncoderView:quality",newValue)
                        model.qualColor = Color.accentColor
                        model.listener?.encoderItemChanged()
                    }.pickerStyle(.menu)
                }
                //GOV Length
                HStack{
                    Text("GOV length").foregroundColor(model.govColor).appFont(.caption)
                        .frame(width: labelWidth,alignment: .leading)
                    Spacer()
                
                    Picker("",selection: $model.selectedGovLength){
                        ForEach(model.govLengthRange, id: \.self) {
                            Text($0)
                        }
                    }.onChange(of: model.selectedGovLength) { newLength in
                        print("VideoEncoderView:gov",newLength)
                        model.govColor = Color.accentColor
                        model.listener?.encoderItemChanged()
                    }.pickerStyle(.menu)
                }
                //Interval range
                HStack{
                    Text("Encoding interval").foregroundColor(model.encColor).appFont(.caption)
                        .frame(width: labelWidth,alignment: .leading)
                    Spacer()
                    Picker("",selection: $model.selectedInterval){
                        ForEach(model.intervalRange, id: \.self) {
                            Text($0)
                        }
                    }.onChange(of: model.selectedInterval){  newValue in
                        print("VideoEncoderView:interval",newValue)
                        model.encColor = Color.accentColor
                        model.listener?.encoderItemChanged()
                    }.pickerStyle(.menu)
                }
                Spacer()
                
            }.hidden(model.ready==false)
                .padding(5)
            
            HStack{
                Text(model.status)
            }.hidden(model.ready)
    
    }
}

struct VideoEncoderSheet : View{
    @Environment(\.presentationMode) var presentationMode
    
    var encoderView = VideoEncoderView()
    
    func setCamera(camera: Camera){
        encoderView.setCamera(camera: camera)
    }
    
    var body: some View {
        VStack{
        
            HStack{
                Text("Video encoder").appFont(.title)
                    .padding()
                
                Spacer()
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                })
                {
                    Image(systemName: "xmark").resizable()
                        .frame(width: 18,height: 18)
                }
            }.padding()
            encoderView
        }
            .frame(alignment: .leading)
    }
}
