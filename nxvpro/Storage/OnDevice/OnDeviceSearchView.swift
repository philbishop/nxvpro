//
//  OnDeviceSearchView.swift
//  NX-V PRO
//
//  Created by Philip Bishop on 19/03/2022.
//

import SwiftUI

protocol OnDeviceSearchListener{
    func onSearchComplete(ds: EventsAndVideosDataSource)
    func onItemDeleted(token: RecordToken)
}

class OnDeviceSearchModel : OnvifSearchModel{
    
    var dataSrc: EventsAndVideosDataSource?
    var listener: OnDeviceSearchListener?
    
    
    @Published var showDelete = false
    var tokenToDelete: RecordToken?
    @Published var tokenDeleteLabel = ""
    
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
            self.dataSrc?.refresh()
            self._doSearchImpl(useCache: useCache)
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

struct OnDeviceSearchView: View ,RemoteStorageTransferListener, VideoPlayerDimissListener{
    
    @Environment(\.dynamicTypeSize) var sizeCategory
    @ObservedObject var model = OnDeviceSearchModel()
    
    var barChart = SDCardBarChart()
    var thumbsView = EventsUIView()
    
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
    
    func doPlay(token: RecordToken) {
        if let video = token.card{
            //let replayTokens = model.getTokens()
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
                    
                    
                    if model.isPad{
                        Toggle(isOn: $model.listHidden) {
                            Text("Show as thumbnails").appFont(.caption)
                        }.toggleStyle(CheckBoxToggleStyle())
                    }
                    
                    Spacer()
                    Text(model.searchStatus).appFont(.smallCaption)
                        .foregroundColor(model.statusColor)
                        .padding(.trailing,25)
                    
                    
                }.padding(5)
                    .fullScreenCover(isPresented: $model.showPlayer, onDismiss: {
                        model.showPlayer = false
                    },content: {
                        //player
                        model.videoPlayerSheet
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
