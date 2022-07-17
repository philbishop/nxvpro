//
//  SdCardView.swift
//  NX-V
//
//  Created by Philip Bishop on 31/12/2021.
//

import SwiftUI

protocol SdCardPlayerListemer {
    func positionChanged(time: Int32, remaining: Int32)
    func playerStarted()
    func playerPaused()
    func playerReady()
    func hasDuration(duration: Double)
}

class SdCardModel : ObservableObject, SdCardPlayerListemer{
    
    @Published var cameras = [Camera]()
    @Published var recordRange: RecordProfileToken?
    @Published var status = ""
    @Published var playerVisible = false
    
    //MARK: SdCardPlayerListemer
    func positionChanged(time: Int32, remaining: Int32) {
        
    }
    
    func playerStarted() {
        playerVisible = true
    }
    
    func playerPaused() {
        
    }
    
    func playerReady() {
        
    }
    
    func hasDuration(duration: Double) {
        print("SdCardModel:hasDuration",duration)
    }
    
}

protocol SdCardProfileChangeListener{
    func sdCardProfileChanged(recordProfile: String)
    func sdCardResultsChanged()
}
struct SdCardRangeView : View{
    @ObservedObject var model = CameraPropertiesModel()
    @ObservedObject var allProps = CameraProperies()
 
    func reset(){
        allProps.props = [CameraProperty]()
        model.recordRange = nil
        model.recordingResults = nil
        
    }
    func itemDeleted(){
        if model.recordRange != nil{
            model.recordRange!.recordingImages -= 1
        }
    }
    func setRecordRange(recordRange: RecordProfileToken?){
        allProps.props = [CameraProperty]()
       
        model.recordRange = recordRange
        if model.recordRange != nil{
            let nextId = 0
            addRecordProfile(rp: model.recordRange!,maxId: nextId)
        }
    }
    func addRecordProfile(rp: RecordProfileToken,maxId: Int){
        var nextId = maxId+1
        
        var earliestDate = rp.earliestRecording
        var latestDate = rp.latestRecording
        
        if !rp.isValid(){
            earliestDate = ""
            latestDate = ""
        }
        
        allProps.props.append(CameraProperty(id: nextId,name: "Earliest recording",val: earliestDate,editable: false))
        nextId += 1
        allProps.props.append(CameraProperty(id: nextId,name: "Latest recording",val: latestDate,editable: false))
        
        nextId += 1
        allProps.props.append(CameraProperty(id: nextId,name: "Storage images",val: String(rp.recordingImages),editable: false))
        
        
        if let results = model.recordingResults{
            let fmt = DateFormatter()
            fmt.dateFormat = "dd MMM yyyy"
            
            for rt in results{
                nextId += 1
                let dstr = fmt.string(from: rt.date)
                let vstr = String(rt.results.count)
                allProps.props.append(CameraProperty(id: nextId,name: dstr,val: vstr,editable: false))
                
            }
        }
        
    }
    var body: some View {
       
        HStack{
            VStack(alignment: .leading,spacing: 5){
                //Text("Recording range")
                
                ForEach(allProps.props, id: \.self) { prop in
                    HStack{
                        Text(prop.name).fontWeight(prop.val.isEmpty ? .none : /*@START_MENU_TOKEN@*/.bold/*@END_MENU_TOKEN@*/).appFont(.caption)
                            .frame(width: 150,alignment: .leading)
                        Text(prop.val).appFont(.caption)
                        
                    }.frame(alignment: .leading)
                    
                }
            }
            Spacer()
        }.padding(.leading,10)
    }
}

struct SdCardView: View, OnvifSearchViewListener,SdCardProfileChangeListener {
    @ObservedObject var model = SdCardModel()
    
    var rightPaneWidth = CGFloat(410.0)
    
    var rangeView = SdCardRangeView()
    var searchView = OnvifSearchView()
    var statsView = SDCardStatsView()
    
    
    //MARK: SdCardProfileChangeListener
    func sdCardResultsChanged(){
        statsView.refreshStats()
    }
    func sdCardProfileChanged(recordProfile: String) {
        statsView.refreshStats()
    }
    func setStatus(status: String){
        
        print("SdcardView:setStatus")
        
        DispatchQueue.main.async {
            model.status = status
        }
    }
    
   
    func cacheUpdated() {
        print("SdcardView:cacheUpdated")
        //update statsView
        DispatchQueue.main.async{
            statsView.refreshStats()
        }
    }
    
    func reset(){
        
    }
    
    func setCamera(camera: Camera,recordRange: RecordProfileToken?){
        print("SdcardView:setCamera")
        
        model.cameras.removeAll()
        model.cameras.append(camera)
        model.status = "Loading event data..."
        
        searchView.model.singleCameraMode = true
        searchView.model.cacheListener = self
        searchView.model.profileListener = self
        rangeView.reset()
        
        if let rr = recordRange{
            if rr.isValid(){
                model.recordRange = recordRange
                rangeView.setRecordRange(recordRange: recordRange)
                if recordRange != nil && recordRange!.isValid(){
                    if let startAt = recordRange!.getEarliestDate(){
                        
                        if let endAt = recordRange!.getLatestDate(){
                            searchView.setDateRange(start: startAt, end: endAt)
                        }
                    }
                    
                }
            }else{
                model.recordRange = nil
            }
        }
        
        statsView.setCamera(camera: camera)
        searchView.setCamera(camera: camera,doSearch: recordRange != nil)
        
        if camera.isVirtual{
            model.status = "Storage interface available at NVR level"
        }
        else if camera.searchXAddr.isEmpty{
            model.status = "Camera storage interface not found"
        }
    }
    
    var body: some View {
        ZStack(){
            GeometryReader { fullView in
                let isLanscape = fullView.size.width - 320 > 600
                HStack{
                    VStack{
                        rangeView
                        Divider()
                        searchView
                        Spacer()
                    }.hidden(model.recordRange ==  nil)
                    
                    if isLanscape{
                        Divider().hidden(model.recordRange == nil)
                        VStack{
                            Text("Statistics").appFont(.smallTitle)
                            statsView
                            Spacer()
                           // player.frame(height: CGFloat(rightPaneWidth / 1.66)).hidden(model.playerVisible==false)
                        }.hidden(model.recordRange ==  nil)
                        .frame(width: rightPaneWidth)
                        
                    }
                }.hidden(model.recordRange==nil)
            }
            Text(model.status).hidden(model.status.isEmpty || model.recordRange != nil)
            Text("Camera storage interface not found")
                .fontWeight(.light)
                .appFont(.body)
                .hidden(model.recordRange != nil || model.status.isEmpty == false)
        }.onAppear{
            //player.setListener(listener: model)
        }
    }
}

struct SdCardView_Previews: PreviewProvider {
    static var previews: some View {
        SdCardView()
    }
}
