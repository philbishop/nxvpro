//
//  OnDeviceSearchView.swift
//  NX-V PRO
//
//  Created by Philip Bishop on 19/03/2022.
//

import SwiftUI
struct ThumbnailToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            Label {
                configuration.label
            } icon: {
                Image(systemName: configuration.isOn ? "list.dash" : "square.grid.2x2")
                    .resizable().frame(width: 18,height: 18)
                    .accessibility(label: Text(configuration.isOn ? "Thumbnails" : "List"))
                    .appFont(.smallTitle)
                    .toolTip(configuration.isOn ? "Show as list" : "Show as thumbnails")
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

protocol OnDeviceSearchListener{
    func onSearchComplete(ds: EventsAndVideosDataSource)
    func onItemDeleted(token: RecordToken)
}

class OnDeviceSearchModel : OnvifSearchModel{
    
    var dataSrc: EventsAndVideosDataSource?
    var listener: OnDeviceSearchListener?
    var currentResults = [RecordToken]()
    
    @Published var showDelete = false
    var tokenToDelete: RecordToken?
    @Published var tokenDeleteLabel = ""
    
    func getSelectedDateStr() -> String{
        let frmt = DateFormatter()
        frmt.dateFormat="yyyy-MM-dd"
        return frmt.string(from: date)
    }
    
    
    func getTokenFor(filePath: URL) -> RecordToken?{
        if let ds = dataSrc{
            for rt in ds.recordTokens{
                if let card = rt.card{
                    if card.filePath == filePath{
                        return rt
                    }
                }
            }
        }
        return nil
    }
    
    func removeDeletedItem() -> Bool{
        if let ttd = tokenToDelete{
            
            for rph in resultsByHour{
                var di = -1
                var index = 0
                for rt in rph.results{
                    if rt.localFilePath == ttd.localFilePath{
                        di = index
                        break
                    }
                    index += 1
                    
                }
                
                if di != -1{
                    rph.results.remove(at: di)
                    listener?.onItemDeleted(token: ttd)
                    return true
                }
            }
        }
        return false
    }
    
    override func doSearch(useCache: Bool = false){
        DispatchQueue.main.async {
            self.dataSrc?.refresh(callback: {
                self._doSearchImpl(useCache: useCache)
            })
           
        }
    }
    func _doSearchImpl(useCache: Bool) {
        searchStatus = "Starting new search"
        searchDisabled = true
        setDateRange()
        barchartModel?.reset()
        resultsByHour.removeAll()
        
        if let ds = dataSrc{
            let tokens = ds.getTokensFor(day: searchStart!,includeCloud: false)
            currentResults = tokens
            onPartialResults(camera: camera!, partialResults: tokens)
            onSearchComplete(camera: camera!, allResults: tokens, success: true, anyError: "")
            
            //to update thumbs
            if let ds = dataSrc{
                listener?.onSearchComplete(ds: ds)
            }
        }
    }
    func getTokens() -> [ReplayToken]{
        var replayTokens = [ReplayToken]()
        if let ds = dataSrc{
            let tokens = ds.getTokensFor(day: searchStart!,includeCloud: false)
            if tokens.count > 0{
                for i in 0...tokens.count-1{
                    replayTokens.append(ReplayToken(id: i,token: tokens[i]))
                }
            }
        }
        return replayTokens
    }
}

struct OnDeviceSearchView: View ,RemoteStorageTransferListener, VideoPlayerDimissListener, ProVideoPlayerChangeListener{
    
    @Environment(\.dynamicTypeSize) var sizeCategory
    @ObservedObject var model = OnDeviceSearchModel()
    
    var barChart = SDCardBarChart()
    var thumbsView = EventsUIView()
    
    func prepare(){
        model.listHidden = AppSettings.isThumbsEnabled()
    }
    //MARK: ProVideoPlayerChangeListener
    func getNextVideo(current: URL)  -> RecordToken? {
        let cr = model.currentResults
       
        if cr.count > 1{
            debugPrint("getNextVideo",cr.count,current.lastPathComponent)
            for i in 0...cr.count-1{
                let rt = cr[i]
                debugPrint("getNextVideo",i,rt.getTime())
                if rt.sameReplayUrlAs(other: current){
                    if i+1 < cr.count{
                    
                        let nt = cr[i+1]
                        return nt
                    }
                }
            }
        }
        return nil
    }
    func getPreviousVideo(current: URL)  -> RecordToken?{
        let cr = model.currentResults
        if cr.count > 1{
            for i in 1...cr.count-1{
                let rt = cr[i]
                if rt.sameReplayUrlAs(other: current){
                    let nt = cr[i-1]
                     return nt
                
                }
            }
        }
        return nil
    }
    //MARK: VideoPlayerDimissListener
    func dismissAndShare(localPath: URL) {
        
        model.showPlayer  = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5,execute:{
            showShareSheet(with: [localPath])
        })
    }
    func dimissPlayer(){
        model.showPlayer  = false
        if model.videoPlayerSheet.model.isDeleted{
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5,execute:{
                if let tok = model.tokenToDelete{
                    doDelete(token: tok)
                }
                
            })
        }
    }
    //MARK: Delete helper
    func doDeleteVideo(videoUrl: URL){
        if let rt = model.getTokenFor(filePath: videoUrl){
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5){
                self.doDelete(token: rt)
            }
        }
    }
    //MARK: RemoteStorageTransferListener
    func doDelete(token: RecordToken) {
        
        if let card = token.card{
            model.tokenToDelete = token
            model.showDelete = true
            model.tokenDeleteLabel = card.timeString() + "\n" + card.name
        }
    }
    func doDownload(token: RecordToken) {
        let localPath = URL(fileURLWithPath: token.localFilePath)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5,execute:{
            showShareSheet(with: [localPath])
        })
        
    }
    func doPlay(token: RecordToken){
        
        if let video = token.card{
            //let replayTokens = model.getTokens()
            model.playbackToken = token
            model.videoPlayerSheet = VideoPlayerSheet()
            model.videoPlayerSheet.doInit(video: video, listener: self)
            model.showPlayer = true
            
            model.tokenToDelete = token
            
        }
    }
    func resetThumbs(){
        thumbsView.reset()
    }
    func setCamera(camera: Camera,doSearch: Bool,dataSrc: EventsAndVideosDataSource){
        AppLog.write("OnvifSearchView:setCamera")
        model.setCamera(camera: camera)
        model.isLocalStorage = true
        model.dataSrc = dataSrc
        model.date = Date()
        model.resultsByHour.removeAll()
        model.searchDisabled = false
        model.barchartModel = barChart.model
        barChart.reset()
        
        if doSearch{
            AppLog.write("OnvifSearchView:modelDoSearch")
            model.doSearch(useCache: true)
        }else{
            model.searchDisabled = true
        }
    }
    func setDateRange(start: Date,end: Date,ds: EventsAndVideosDataSource){
        AppLog.write("OnDeviceearchView:setDateRange")
        model.setDateRange(start: start, end: end)
        
    }
    var body: some View {
        ZStack{
            Color(uiColor: .secondarySystemBackground)
            VStack(alignment: .leading){
                HStack{
                    
                   if model.canShowThumbs{
                        Toggle(isOn: $model.listHidden) {
                           // Text("Show as thumbnails").appFont(.caption)
                        }.onChange(of: model.listHidden) { listHidden in
                            AppSettings.setThumbsEnabled(enabled: listHidden)
                        }.toggleStyle(ThumbnailToggleStyle())
                            .padding(.leading,8)
                    }
                    
                    DatePicker("", selection: $model.date, displayedComponents: .date)
                        .appFont(.caption).disabled(model.searchDisabled)
                        .scaleEffect(model.dateScale)
                        .frame(width: 150)
                    
                    Button(action: {
                        AppLog.write("Search date",model.date)
                        
                        model.doSearch(useCache: true)
                    }){
                        Image(systemName: "magnifyingglass").resizable().frame(width: 18,height: 18)
                    }.buttonStyle(PlainButtonStyle()).disabled(model.searchDisabled)
                    
                    
                    
                    
                    Spacer()
                    Text(model.searchStatus).appFont(.smallCaption)
                        .foregroundColor(model.statusColor)
                        .padding(.trailing,25)
                    
                    
                }.padding(5)
                    .fullScreenCover(isPresented: $model.showPlayer, onDismiss: {
                        model.showPlayer = false
                    },content: {
                        //player
                        if UIDevice.current.userInterfaceIdiom == .pad{
                            if let tok = model.playbackToken{
                                if let card = tok.card{
                                    ProVideoPlayer(videoUrl: card.filePath, title: card.getTitle())
                                }
                            }
                        }else{
                            model.videoPlayerSheet
                        }
                    })
                //results
                if model.listHidden == false{
                    List{
                        
                        ForEach(model.resultsByHour){ rc in
                            RecordCollectionView(rc: rc,camera: model.camera!,transferListener: self)
                        }
                    }.padding(5)
                        .listStyle(.plain)
                }else{
                    thumbsView
                }
                Spacer()
                HStack{
                    barChart.frame(height: 24,alignment: .center)
                }.padding()
            }.alert(isPresented: $model.showDelete) {
                
                Alert(title: Text("Delete video")
                      , message: Text(model.tokenDeleteLabel),
                      primaryButton: .default (Text("OK")) {
                    model.showDelete = false
                    if let rt = model.tokenToDelete{
                        if let card = rt.card{
                            FileHelper.deleteMedia(cards: [card])
                            if model.removeDeletedItem(){
                                
                                //barChart.itemRemovedAt(hour: hourOfDay)
                            }
                        }
                    }
                },
                      secondaryButton: .cancel() {
                    model.showDelete = false
                }
                )
            }
            
        }.onAppear{
            prepare()
            thumbsView.model.listener = self
            model.checkDynamicTypeSize(sizeCategory: sizeCategory)
        }
    }
}

struct OnDeviceSearchView_Previews: PreviewProvider {
    static var previews: some View {
        OnDeviceSearchView()
    }
}
