//
//  OnDeviceSearchView.swift
//  NX-V PRO
//
//  Created by Philip Bishop on 19/03/2022.
//

import SwiftUI

protocol OnDeviceSearchListener{
    func onSearchComplete(ds: EventsAndVideosDataSource)
}

class OnDeviceSearchModel : OnvifSearchModel{
    
    var dataSrc: EventsAndVideosDataSource?
    var listener: OnDeviceSearchListener?
    @Published var listHidden = false
    
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
            let tokens = ds.getTokensFor(day: searchStart!)
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
            let tokens = ds.getTokensFor(day: searchStart!)
            if tokens.count > 0{
                for i in 0...tokens.count-1{
                    replayTokens.append(ReplayToken(id: i,token: tokens[i]))
                }
            }
        }
        return replayTokens
    }
}

struct OnDeviceSearchView: View ,RemoteStorageTransferListener{
    
    
    @ObservedObject var model = OnDeviceSearchModel()
    
    var barChart = SDCardBarChart()
    var thumbsView = EventsUIView()
    
   
    //MARK: RemoteStorageTransferListener
    
    func doDownload(token: RecordToken) {
        
        if let card = token.card{
         
            appDelegate?.showSaveDialog(localPath: card.filePath) { saved in
                //do something here
            }
            
        }
        /*
        appDelegate?.showDownloadPrompt(token: token,callback: { rc, ok in
            if let card = token.card{
                
                if let exportPath = FileHelper.getUserDownloadsPathFor(fileName: card.filePath.lastPathComponent){
                    if FileManager.default.fileExists(atPath: exportPath.path){
                        model.updateDownloadStatus(status: "Download complete")
                        
                    }else{
                        print("doDownload",exportPath)
                        model.updateDownloadStatus(status: "Downloading...")
                        do{
                            try FileManager.default.copyItem(at: card.filePath, to: exportPath)
                            print("doDownload OK")
                            model.updateDownloadStatus(status: "Download complete")
                           
                        }catch{
                            print("doDownload failed")
                            model.updateDownloadStatus(status: "Download failed",true)
                        }
                    }
                }
                
            }
        })
         */
    }
    
    func doPlay(token: RecordToken) {
        if let video = token.card{
            let replayTokens = model.getTokens()
            appDelegate?.showReplayLocalWindow(card: video,tokens: replayTokens,barLevels: barChart.getBarLevels())
        }
    }
    func resetThumbs(){
        thumbsView.reset()
    }
    func setCamera(camera: Camera,doSearch: Bool,dataSrc: EventsAndVideosDataSource){
        print("OnvifSearchView:setCamera")
        model.setCamera(camera: camera)
        model.isLocalStorage = true
        model.dataSrc = dataSrc
        model.date = Date()
        model.resultsByHour.removeAll()
        model.searchDisabled = false
        model.barchartModel = barChart.model
        barChart.reset()
        
        if doSearch{
            print("OnvifSearchView:modelDoSearch")
            model.doSearch(useCache: true)
        }else{
            model.searchDisabled = true
        }
    }
    func setDateRange(start: Date,end: Date,ds: EventsAndVideosDataSource){
        print("OnDeviceearchView:setDateRange")
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
                    .toolTip("Search")
                
               
                /*
                Button(action: {
                    print("REFRESH date",model.date)
                    model.doSearch(useCache: false)
                }){
                    Image(systemName: "arrow.triangle.2.circlepath").resizable().frame(width: 20,height: 18)
                }.buttonStyle(PlainButtonStyle()).disabled(model.refreshDisabled || model.searchDisabled)
                    .toolTip("Refresh results")
                
                 */
                Toggle(isOn: $model.listHidden) {
                    Text("Show as thumbnails")
                }
                
                Spacer()
                Text(model.searchStatus).appFont(.smallCaption)
                    .foregroundColor(model.statusColor)
                    .padding(.trailing,25)
                
            
            }.padding()
            
            //results
            if model.listHidden == false{
                List{
                    
                    ForEach(model.resultsByHour){ rc in
                        RecordCollectionView(rc: rc,camera: model.camera!,transferListener: self)
                    }
                }
            }else{
                thumbsView
            }
            Spacer()
            HStack{
                barChart.frame(height: 24,alignment: .center)
            }.padding()
            
        }.onAppear{
            thumbsView.model.listener = self
        }
    }
}

struct OnDeviceSearchView_Previews: PreviewProvider {
    static var previews: some View {
        OnDeviceSearchView()
    }
}
