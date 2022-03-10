//
//  VideoItemsView.swift
//  NXV-IOS
//
//  Created by Philip Bishop on 30/06/2021.
//

import SwiftUI
/*
struct VideoItem : View {
    
    @Environment(\.colorScheme) var colorScheme
    var iconModel = AppIconModel()
    
    var card: CardData
    init(card: CardData){
        self.card = card
    }
    
    var body: some View {
        HStack{
            Image(uiImage: card.nsImage).resizable().frame(width: 120,height: 73).padding(0)
                .cornerRadius(5)
            
            VStack(alignment: .leading){
                Text(card.name).appFont(.body).frame(alignment: .leading)
                Text(card.dateString()).appFont(.body).frame(alignment: .leading)
                Text(card.fileSizeString).appFont(.body).frame(alignment: .leading)
            }
            
            Spacer()
            
            if card.isEvent {
                Image(iconModel.vmdAlertIcon).resizable().opacity(0.7)
                    .frame(width: iconModel.largeIconSize,height: iconModel.largeIconSize)
            }
            
        }.onAppear(){
            iconModel.initIcons(isDark: colorScheme == .dark)
        }
    }
}
 */
class SimpleVideoItemModel : ObservableObject{
    @Published var showPlayer = false
    @Published var thumb: UIImage
    @Published var thumbLoaded = false
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
            Text(card.dateString()).appFont(.caption).frame(alignment: .leading)
            Text(card.fileSizeString).appFont(.caption).frame(alignment: .leading)
            
            
            
            if card.isEvent {
                Image(iconModel.vmdAlertIcon).resizable().opacity(0.7)
                    .frame(width: 22,height: 22)
            }
            
            Spacer()
            
            Button(action:{
                model.videoPlayerSheet = VideoPlayerSheet()
                model.showPlayer = true
                model.videoPlayerSheet.doInit(video: card,listener: self)
            }){
                Image(systemName: "play").resizable().frame(width: 14,height: 14)
            }.sheet(isPresented: $model.showPlayer) {
                model.showPlayer = false
            } content: {
                //player
                model.videoPlayerSheet
            }
            
        }.padding(.trailing,25)
        .onAppear(){
            iconModel.initIcons(isDark: colorScheme == .dark)
            model.loadThumb()
        }
    }
}
protocol SimpleVideoDayListener{
    func onDayDelete(day: Date)
}
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
}
struct SimpleDayVideoItems : View{
    
    @ObservedObject var model = SimpleDayVideoModel()
    
    
    init(day: Date,videos: [CardData],listener: SimpleVideoDayListener){
        model.day = day
        model.videos = videos
        model.listener = listener
        model.label = dayString(day: day)
        model.sizeLabel = sizeString(day: day)
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
                    
                }){
                    Text(">")
                        .padding(0)
                        .font(.system(size: 12))
                        .font(.title)
                        .rotationEffect(Angle.degrees(model.rotation))
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
                        print("Delete videos "+self.dayString(day: model.day))
                        FileHelper.deleteMedia(cards: model.videos)
                        model.listener?.onDayDelete(day: model.day)
                    },
                          secondaryButton: .cancel() {
                        model.showAlert = false
                    }
                    )
                }.padding(.trailing,10)
            }.padding()
            if model.collapsed == false{
                
                ForEach(model.videos, id: \.self) { video in
                    SimpleVideoItem(card: video).padding(.leading)
                    
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
    func refresh(camera: Camera?) -> Int {
        model.reset()
        dataSrc.setCamera(camera: camera)
        return dataSrc.populateVideos(model: model)
        
    }
    
}

struct VideoItemsView_Previews: PreviewProvider {
    static var previews: some View {
        OnDeviceVideoItemsView()
    }
}
