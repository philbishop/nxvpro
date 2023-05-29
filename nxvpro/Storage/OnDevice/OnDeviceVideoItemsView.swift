//
//  VideoItemsView.swift
//  NXV-IOS
//
//  Created by Philip Bishop on 30/06/2021.
//

import SwiftUI

class SimpleVideoItemFactory{
    var items = [CardData:SimpleVideoItem]()
    
    func getItem(card: CardData) -> SimpleVideoItem{
        for (item,view) in items{
            if item.id == card.id{
                view.model.loadThumb()
                return view
            }
                
        }
        let item = SimpleVideoItem(card: card)
        items[card] = item
        item.model.loadThumb()
        return item
    }
}
class SimpleVideoItemModel : ObservableObject{
    @Published var showPlayer = false
    @Published var thumb: UIImage
    @Published var thumbLoaded = false
    @Published var seen = false
    
    var videoPlayerSheet = VideoPlayerSheet()
    var thumbPath: String?
    
    init(){
        thumb = UIImage(named: "no_video_thumb")!
    }
    func loadThumb(){
        
        guard let path = thumbPath else{
            return
        }
        if path.isEmpty || thumbLoaded{
            return
        }
        DispatchQueue.main.async {
            if let iThumb = UIImage(contentsOfFile: path){
                self.thumb = iThumb
                self.thumbLoaded = true
            }
        }
    }
    
}

struct SimpleVideoItem : View, VideoPlayerDimissListener  {
    
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var iconModel = AppIconModel()
    @ObservedObject var model = SimpleVideoItemModel()
    
    var card: CardData
    init(card: CardData){
        self.card = card
        model.thumbPath = card.imagePath
    }
    
    func dimissPlayer() {
        DispatchQueue.main.async{
            model.showPlayer = false
        }
    }
    func dismissAndShare(localPath: URL) {
        model.showPlayer = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5,execute:{
            showShareSheet(with: [localPath])
        })
    }
    
    var body: some View {
        HStack{
            
            Image(uiImage: model.thumb).resizable().frame(width: 90,height: 50)
            HStack{
                Text(card.timeString()).appFont(.helpLabel)
                    
                    .frame(alignment: .leading)
                Text(card.fileSizeString).appFont(.caption).frame(alignment: .leading)
                
                if card.isEvent {
                    Image(iconModel.vmdAlertIcon).resizable().opacity(0.7)
                        .frame(width: 22,height: 22)
                }
            }.foregroundColor(model.seen ? Color(UIColor.secondaryLabel) : Color(UIColor.label))
            
            Spacer()
            
            Button(action:{
                model.seen = true
                model.videoPlayerSheet = VideoPlayerSheet()
                model.showPlayer = true
                model.videoPlayerSheet.doInit(video: card,listener: self)
            }){
                Image(systemName: "play").resizable().frame(width: 14,height: 14)
            }.buttonStyle(PlainButtonStyle())
            .fullScreenCover(isPresented: $model.showPlayer) {
                model.showPlayer = false
            } content: {
                //player
                model.videoPlayerSheet
            }
            
        }
        .padding(.trailing,25)
        .onAppear(){
            iconModel.initIcons(isDark: colorScheme == .dark)
            //model.loadThumb()
        }
    }
}
protocol SimpleVideoDayListener{
    func onDayDelete(day: Date)
}

var expandedDays = [Date:Double]()

class SimpleDayVideoModel : ObservableObject{
    @Published var collapsed = true
    @Published var rotation: Double = 0
    @Published var label = ""
    @Published var sizeLabel = ""
    @Published var showAlert = false
    
    var videos = [CardData]()
    var day: Date!
    var daysToVideoData: [Date: [CardData]]?
    var listener: SimpleVideoDayListener?
    
    var isPad: Bool
    init(){
        isPad = UIDevice.current.userInterfaceIdiom == .pad
    }
}
struct SimpleDayVideoItems : View{
    
    @ObservedObject var model = SimpleDayVideoModel()
   
    var thumbsView = EventsUIView()
    
    var factory = SimpleVideoItemFactory()
    
    init(day: Date,videos: [CardData],listener: SimpleVideoDayListener){
        model.day = day
        model.videos = videos
        model.listener = listener
        model.label = dayString(day: day)
        model.sizeLabel = sizeString(day: day)
        
        if let rotation =  expandedDays[day]{
            model.rotation = rotation
        }
        if model.isPad{
            thumbsView.setCards(cards: videos)
        }
    }
    
    
    func dayTitle(day: Date) -> String{
        return dayString(day: day) + " " + sizeString(day: day)
    }
    func dayString(day: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM dd yyyy"
        return fmt.string(from: day)
    }
    func sizeString(day: Date) -> String{
        var total = UInt64(0)
        let cards = model.videos
        for card in model.videos {
            total += card.fileSize
        }
        return ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file)
    }
    
    var body: some View {
        VStack{
            HStack{
                Button(action: {
                    if model.rotation == 0{
                        model.rotation = 90
                        model.collapsed = false
                    }else{
                        model.rotation = 0
                        model.collapsed = true
                    }
                    expandedDays[model.day] = model.rotation
                }){
                    Image(systemName: (model.rotation==0 ? "arrow.right.circle" : "arrow.down.circle")).resizable().frame(width: 18,height: 18)
                }.padding(0).background(Color.clear).buttonStyle(PlainButtonStyle())
                Text(model.label).fontWeight(.semibold).appFont(.sectionHeader)
                
                Spacer()
                
                Text(model.sizeLabel).appFont(.caption)
                Button(action: {
                    model.showAlert = true
                }){
                    Image(systemName: "trash").resizable().frame(width: 18,height:18)
                }
                .alert(isPresented: $model.showAlert) {
                    
                    Alert(title: Text("Delete videos")
                          , message: Text(model.label),
                          primaryButton: .default (Text("OK")) {
                        model.showAlert = false
                        AppLog.write("Delete videos "+self.dayString(day: model.day))
                        FileHelper.deleteMedia(cards: model.videos)
                        model.listener?.onDayDelete(day: model.day)
                    },
                          secondaryButton: .cancel() {
                        model.showAlert = false
                    }
                    )
                }.padding(.trailing,10)
            }//.padding()
            if model.rotation==90{//collapsed == false{
                
                //if iPad need to use grid of thumbs instead
                if model.isPad{
                    thumbsView
                }else{
                    ForEach(model.videos, id: \.self) { video in
                        
                        factory.getItem(card: video).padding(.leading)
                            
                    }
                }
            }
        }
        .background(Color(UIColor.systemBackground))
            
    }
}
struct OnDeviceVideoItemsView: View, SimpleVideoDayListener {
    @ObservedObject var model = EventsAndVideosModel()
    let dataSrc = EventsAndVideosDataSource()
    @State var showAlert = false
    
    func onDayDelete(day: Date) {
        DispatchQueue.main.async{
            model.reset()
            dataSrc.populateVideos(model: model)
        }
    }
    
    var body: some View {
        ZStack(alignment: .topLeading){
           
                ScrollView(.vertical){
                    VStack{
                        ForEach(model.daysWithVideos, id: \.self) { day in
                            
                            let videos = model.daysToVideoData[day]!
                            SimpleDayVideoItems(day: day,videos: videos,listener: self)
                            
                        }
                        
                        if model.daysWithVideos.count == 0 {
                            HStack{
                                Text("No videos captured with NX-V found").appFont(.caption)
                            }
                        }
                    }.padding()
                }
            }
            
            
        //}
    }
  
    func refresh(cameras: [Camera]) -> Int {
        model.reset()
        dataSrc.setCameras(cameras: cameras)
        let allCards = dataSrc.populateVideos(model: model)
        return allCards.count
    }
   
}

struct VideoItemsView_Previews: PreviewProvider {
    static var previews: some View {
        OnDeviceVideoItemsView()
    }
}
