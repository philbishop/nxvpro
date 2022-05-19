//
//  OnvifSearchView.swift
//  TestMacUI
//
//  Created by Philip Bishop on 22/12/2021.
//

import SwiftUI

protocol OnvifSearchViewListener{
    func cacheUpdated()
}

class OnvifSearchModel : ObservableObject, OnvifSearchListener{
    @Published var date: Date
    @Published var isAM: Bool
    @Published var startDate: Date?
    @Published var endDate: Date
    @Published var searchDisabled = false
    @Published var refreshDisabled = true
    @Published var searchStatus: String
    //@Published var results: [RecordToken]
    @Published var singleCameraMode = false
    @Published var resultsByHour = [RecordingCollection]()
    @Published var recordProfiles = [String]()
    @Published var selectedProfile = ""
    @Published var profilPickerHidden = false
    
    //playback
    @Published var playbackToken: RecordToken?
    @Published var showPlayer = false
    var videoPlayerSheet = VideoPlayerSheet()
    
    var firstTime = true
    var camera: Camera?
    var barchartModel: SDCardBarChartModel?
    
    init(){
        date = Calendar.current.startOfDay(for: Date())
        //time = Calendar.current.startOfDay(for: Date())
        isAM = true
        searchStatus = "Select date and click search button"
        //results = [RecordToken]()
        self.resultsByHour = [RecordingCollection]()
        endDate = Calendar.current.startOfDay(for: Date())
        startDate=getDate(dateString: "2020-01-01")
        if ProcessInfo.processInfo.isiOSAppOnMac{
            profilPickerHidden = true
        }
    }
    func setDateRange(start: Date,end: Date){
        date = endDate
        startDate = start
        endDate = end
    }
    func setProfile(recordProfile: String){
        camera!.recordingProfile!.recordingToken = recordProfile == recordProfiles[0] ? "" : recordProfile
        //refresh outside views
        profileListener?.sdCardProfileChanged(recordProfile: recordProfile)
        //refresh inside views
        doSearch(useCache: true)
        
    }
    var currentResultsDay: Date?
    
    func updateResults(results: [RecordToken],isReset: Bool = false){
        if isReset{
            resultsByHour.removeAll()
        }
        
        
        var hodLookup = [Int:RecordingCollection]()
        
        //insert existing collections
        for rc in resultsByHour{
            hodLookup[rc.orderId] = rc
        }
        guard let rp = camera?.recordingProfile else{
            return 
        }
        
        let tok = camera!.recordingProfile!.recordingToken
        
        for rt in results{
            
            if tok.isEmpty == false && tok != rt.Token{
                print("rt from different profile",tok,rt.toCsv())
                continue
            }
            
            let dt = rt.getTime()
            currentResultsDay = Calendar.current.startOfDay(for: dt!)
            let hod = Calendar.current.component(.hour, from: dt!)
            
            if hodLookup[hod] == nil{
                hodLookup[hod] = RecordingCollection(orderId: hod,label: String(hod))
            }
            hodLookup[hod]!.results.append(rt)
            
            if recordProfiles.contains(rt.Token) == false{
                recordProfiles.append(rt.Token)
            }
            
            if rt.storageType == StorageType.onboard{
                //see if anything is in the sdCard cache folder
                FileHelper.populateOnboardFilePath(token: rt)
            }
        }
        var tmp = [RecordingCollection]()
        for (hr,rc) in hodLookup{
            rc.label = getLabelForHod(rc: rc)
            tmp.append(rc)
        }
        
        resultsByHour = tmp.sorted{
            return $0.orderId < $1.orderId
        }
    
        if firstTime{
            firstTime = false
            selectedProfile = recordProfiles[0]
        }
    }
    private func getLabelForHod(rc: RecordingCollection) ->String{
        let hod = rc.orderId
        let timeRange = String(format: "%02d",hod) + ":00 - " + String(format: "%02d",hod+1) + ":00"
        
        return timeRange// + " [" + String(rc.results.count) + "]"
    }
    private func getDate(dateString: String) -> Date?{
        let frmt = DateFormatter()
        frmt.dateFormat="yyyy-MM-dd"
        return frmt.date(from: dateString)
    }
    //searching using current date & time
    var searchIndex = 0
    var searchStart: Date?
    var searchEnd: Date?
    private var theCamera: Camera?
    var cacheListener: OnvifSearchViewListener?
    var profileListener: SdCardProfileChangeListener?
    
    var isFirtTime = true
    var appendToCache = false
    
    func setCamera(camera: Camera){
        
        self.camera = camera
        self.isFirtTime = true
        self.recordProfiles.removeAll()
        recordProfiles.append("All")
        firstTime = true
    }

    private func setDateRange(){

        let theDate = Calendar.current.startOfDay(for: date)

        var startHr =  0
        var endHr = 23
        appendToCache = false
        
        var sd = Calendar.current.date(bySettingHour: startHr, minute: 0, second: 0, of: theDate)
        let ed = Calendar.current.date(bySettingHour: endHr, minute: 59, second: 59, of: theDate)
        
        searchStart = sd;
        searchEnd = ed
        
        print("OnvidSearchModel:setDateRange",searchStart,searchEnd)
    }
    
    private var _onvifSearch: OnvifSearch?
    
    func doSearch(useCache: Bool = false){
        DispatchQueue.main.async{
            self.doSearchImpl(useCache: useCache)
        }
    }
    private func doSearchImpl(useCache: Bool){
        searchStatus = "Starting new search"
        searchDisabled = true
        setDateRange()
        barchartModel?.reset()
        
        if let cam = camera{
            cam.tmpSearchResults = nil
            
            let onvifSearch = OnvifSearch()
            onvifSearch.listener = self
            if useCache == false{
                if let resumeDate = onvifSearch.getResumeDateFromCache(camera: cam, date: searchStart!){
                    searchStart = resumeDate
                    onvifSearch.appendToCache = true
                }else{
                    
                    self.resultsByHour.removeAll()
                    
                }
            }else{
                self.resultsByHour.removeAll()
            }
            _onvifSearch = onvifSearch
            
            
            DispatchQueue(label: "do_search").async{
                onvifSearch.doSearchForEvents(camera: cam, sdate: self.searchStart!, edate: self.searchEnd!,useCache: useCache,checkCacheOnly: self.isFirtTime)
                self.isFirtTime = false
            }
        
        }
            
    }
    func isSameDayAsCache(another: Date) -> Bool{
        return Calendar.current.isDate(another, inSameDayAs: searchStart!)
    }
    //MARK: OnvifSearchListener
    func onTokensUpdated(camera: Camera, results: [RecordToken]) {
        //refresh collection
        DispatchQueue.main.async{
            self.updateResults(results: results)
            self.profileListener?.sdCardResultsChanged()
            
            if results.count > 0{
                RemoteLogging.log(item: "OnvifSearchListener:onTokensUpdated " + String(results.count))
            }
        }
    }
    func onSearchStateChanged(camera: Camera,status: String){
        if camera.getStringUid() != self.camera!.getStringUid(){
            print("OnvifSeachView:onSearchStateChanged different camera",camera.getStringUid(),self.camera!.getStringUid())
            return
        }
        updateSearchStatus(status: status)
    }
    func onPartialResults(camera: Camera,partialResults: [RecordToken]){
        if camera.getStringUid() != self.camera!.getStringUid(){
            print("OnvifSeachView:onPartialResults different camera",camera.getStringUid(),self.camera!.getStringUid())
            return
        }
        //check this search is for the same day as the visible results
        if partialResults.count > 0 && isSameDayAsCache(another: partialResults[0].getTime()!) == false{
            print("OnvifSeachView:onPartialResults different date than current",partialResults[0].Time)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5,execute: {
            
            //self.results.append(contentsOf: partialResults)
            self.updateResults(results: partialResults)
            
            //calculate bar heights based on all results
            self.calculatBarchartStats()
            
            
        })
    }
    func onSearchComplete(camera: Camera,allResults: [RecordToken],success: Bool,anyError: String){
        if camera.getStringUid() != self.camera!.getStringUid(){
            print("OnvifSeachView:onSearchComplete different camera",camera.getStringUid(),self.camera!.getStringUid())
            return
        }
        DispatchQueue.main.async{
            self.searchDisabled = false
            self.refreshDisabled = success
            
            self.searchStatus = success ? "Search complete" : anyError
            
            //check this search is for the same day as the visible results
            if allResults.count > 0 && self.isSameDayAsCache(another: allResults[0].getTime()!) == false{
                print("OnvifSeachView:onSearchComplete different date than current",allResults[0].Time)
                return
            }
            if anyError == OnvifSearch.CACHED_FLAG{
                
                //self.results.removeAll()
                //self.results.append(contentsOf: allResults)
                self.updateResults(results: allResults,isReset: true)
                self.refreshDisabled = false
                //calculate bar heights based on all results
                self.calculatBarchartStats()
                
                self.searchStatus = "Cached results, click refresh button to resume"
            }else{
                self.refreshDisabled = true
                self.cacheListener?.cacheUpdated()
                
                if anyError == "TIMEOUT"{
                    self.searchStatus = "Timeout, resuming..."
                    self.doSearch(useCache: false)
                }
                
            }
            
           
        }
        
    }
    
    func updateSearchStatus(status: String) {
        DispatchQueue.main.async{
            if self.singleCameraMode{
                self.searchStatus  = status
            }else{
                self.searchStatus = self.searchStatus + "\n" + status
            }
        }
    }
    private func calculatBarchartStats(){
        var counts = [Int]()
        for i in 0...24{
            counts.append(0)
        }
        for results in resultsByHour{
            for rt in results.results{
                let dt = rt.getTime()
                let hod = Calendar.current.component(.hour, from: dt!)
                
                counts[hod] = counts[hod] + 1
            }
        }
        
        var maxCount = 0.0
        for count in counts{
            maxCount = max(maxCount,Double(count))
        }
        
        var barLevels = [Double]()
        
        for i in 0...barchartModel!.bars.count-1{
            let relVal = (Double(counts[i]) / maxCount )
            let barHeight = 24.0 * relVal
            barLevels.append(barHeight.isNaN ? 0.0 : barHeight)
        }
        
        barchartModel!.setBarLevels(levels: barLevels)
        
        self.profileListener?.sdCardResultsChanged()
    }
}

struct OnvifSearchView: View ,RemoteStorageTransferListener,VideoPlayerDimissListener{
    
    @ObservedObject var model = OnvifSearchModel()
    
    
    
    var barChart = SDCardBarChart()
    //MARK: VideoPlayerDimissListener
    func dimissPlayer() {
        model.showPlayer = false
    }
    
    func dismissAndShare(localPath: URL) {
        model.showPlayer = false
        //this is called from rtsp capture
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5,execute:{
            showShareSheet(with: [localPath])
        })
    }
    
    //MARK: RemoteStorageTransferListener
    func doPlay(token: RecordToken) {
        let camera = model.camera!
        
        token.storageType = .onboard
        //calculate start time
        
        if let earliest = model.camera!.recordingProfile?.getEarliestDate(){
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year], from: earliest)
            if components.year! > 2020{
                
                let diff = token.getTime()!.timeIntervalSince(earliest)
                 
                //calc pc for changing position
                let imageEndTime = model.camera!.recordingProfile?.getLatestDate()
                let totalDuration = imageEndTime!.timeIntervalSince(earliest)
                
                let df = Float(diff)
                let tf = Float(totalDuration)
                var startOffset = df / tf
                if startOffset > 1{
                    startOffset = Float(0.95)
                }
                    
                token.startOffsetPc = startOffset
            }
        }
        
        model.playbackToken = token
        model.videoPlayerSheet = VideoPlayerSheet()
        model.videoPlayerSheet.doInit(camera: model.camera!,token: model.playbackToken!,listener: self)
        model.showPlayer = true
    }
    func doDownload(token: RecordToken) {
        //RTSP Share captured video
        let sdDir = FileHelper.getSdCardStorageRoot()
        let uri = sdDir.appendingPathComponent(token.localRtspFilePath)
        
        showShareSheet(with: [uri])
    }
    func setCamera(camera: Camera,doSearch: Bool = false){
        print("OnvifSearchView:setCamera")
        model.setCamera(camera: camera)
        model.date = Date()
        model.resultsByHour.removeAll()
        model.searchDisabled = false
        model.barchartModel = barChart.model
        barChart.reset()
        if doSearch{
            print("OnvifSearchView:modelDoSearch")
            model.doSearch(useCache: true)
        }
    }
    func setDateRange(start: Date,end: Date){
        print("OnvifSearchView:setDateRange")
        model.setDateRange(start: start, end: end)
    }
    var body: some View {
        VStack{
            HStack{
                
                Text("Date").appFont(.caption)
                DatePicker("", selection: $model.date, displayedComponents: .date)
                    .appFont(.caption).appFont(.smallCaption).disabled(model.searchDisabled)
                    .frame(width: 150)
                
                Button(action: {
                    print("Search date",model.date)
                    model.doSearch(useCache: true)
                }){
                    Image(systemName: "magnifyingglass").resizable().frame(width: 18,height: 18)
                }.buttonStyle(PlainButtonStyle()).disabled(model.searchDisabled)

                
                
                if model.recordProfiles.count > 1{
                    ScrollView(.horizontal){
                    Picker("", selection: $model.selectedProfile) {
                        ForEach(self.model.recordProfiles, id: \.self) {
                            let str = $0
                            Text(str).appFont(.caption)
                                
                        }
                    }.onChange(of: model.selectedProfile) { newRes in
                        print("Record Profile changed",newRes,model.selectedProfile)
                        model.setProfile(recordProfile: newRes)
                        
                    }.pickerStyle(.menu)
                    }.frame(width: 85)
                }
                Button(action: {
                    print("REFRESH date",model.date)
                    model.doSearch(useCache: false)
                }){
                    Image(systemName: "arrow.triangle.2.circlepath").resizable().frame(width: 20,height: 18)
                }.buttonStyle(PlainButtonStyle()).disabled(model.refreshDisabled || model.searchDisabled)
                    
                
                Spacer()
                Text(model.searchStatus).appFont(.smallCaption).lineLimit(1)
                    .padding(.trailing,25)
                
            
            }.padding(5)
            
            //results
            List{
                ForEach(model.resultsByHour){ rc in
                    RecordCollectionView(rc: rc,camera: model.camera!,transferListener: self)
                }
            }.padding(5)
                .listStyle(.plain)
            Spacer()
            HStack{
                barChart.frame(height: 24,alignment: .center)
            }.padding()
            
        }.sheet(isPresented: $model.showPlayer) {
            model.showPlayer = false
        } content: {
            //player
            model.videoPlayerSheet
        }
    }
}

struct OnvifSearchView_Previews: PreviewProvider {
    static var previews: some View {
        OnvifSearchView()
    }
}
