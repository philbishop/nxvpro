//
//  OnDeviceStorage.swift
//  nxvpro
//
//  Created by Philip Bishop on 14/02/2022.
//

import SwiftUI


struct OnDeviceStorageView : View,OnDeviceSearchListener{
    
    
    @ObservedObject var model = SdCardModel()
    @ObservedObject var emodel = EventsAndVideosModel()
    let dataSrc = EventsAndVideosDataSource()
    
    var rightPaneWidth = CGFloat(410.0)
    
    var rangeView = SdCardRangeView()
    var searchView = OnDeviceSearchView()
    var statsView = SDCardStatsView()
    
    //MARK: OnDeviceSearchListener
    func onSearchComplete(ds: EventsAndVideosDataSource) {
        let cards = ds.getCardsForDay(day: searchView.model.date)
        print("OnDeviceearchView:cards count",cards.count)
        searchView.thumbsView.setCards(cards: cards)
        //model.thumbsHidden = false
    }
    
    func setCamera(camera: Camera){
        dataSrc.setCamera(camera: camera)
        model.cameras.removeAll()
        model.cameras.append(camera)
        populateData()
    }
    func setCameras(cameras: [Camera]){
        dataSrc.setCameras(cameras: cameras)
        model.cameras.removeAll()
        model.cameras.append(contentsOf: cameras)
        populateData()
    }
    private func populateData(){
        dataSrc.populateVideos(model: emodel)
        rangeView.setRecordRange(recordRange: dataSrc.recordRange)
        
        
        model.status = "Reading local data..."
        
        searchView.model.listener = self
        searchView.model.singleCameraMode = true
        searchView.resetThumbs()
        
        rangeView.reset()
        
        let recordRange = dataSrc.recordRange
        if recordRange.isValid(){
            model.recordRange = recordRange
            rangeView.setRecordRange(recordRange: recordRange)
            
            if let fd = recordRange.firstDate{
               
            
                searchView.setDateRange(start: fd, end: recordRange.lastDate!,ds: dataSrc)
            }
        }else{
            
        }
        
        if let cameras = dataSrc.cameras{
        
            let camera = cameras[0]
            statsView.setCamera(camera: camera)
        
            searchView.setCamera(camera: camera,doSearch: recordRange != nil,dataSrc: dataSrc)
            
            statsView.refreshStatsFrom(tokens:  dataSrc.recordTokens)
            
            if camera.isVirtual{
                model.status = "Storage interface available at NVR level"
            }
            else if camera.searchXAddr.isEmpty{
                model.status = "Camera storage interface not found"
            }
        }
    }
    
    func refresh(){
        //doessn't called?
        //dataSrc.populateVideos(model: emodel)
    }
    var body: some View {
        VStack{
            GeometryReader { fullView in
                let isLanscape = fullView.size.width - 400 > 600
                HStack{
                    VStack{
                        rangeView
                        Divider()
                        searchView
                        Spacer()
                    }
                    if isLanscape{
                    Divider()
                    VStack{
                        Text("Statistics").appFont(.smallTitle)
                        statsView
                        Spacer()
                        // player.frame(height: CGFloat(rightPaneWidth / 1.66)).hidden(model.playerVisible==false)
                    }
                    .frame(width: rightPaneWidth)
                    }
                    
                }
            }
        }.background(Color(uiColor: .secondarySystemBackground))
    }
}
