//
//  VideoItemsView.swift
//  NXV-IOS
//
//  Created by Philip Bishop on 30/06/2021.
//

import SwiftUI

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
class SimpleVideoItemModel : ObservableObject{
    @Published var showPlayer = false
    var videoPlayerSheet = VideoPlayerSheet()
}
struct SimpleVideoItem : View, VideoPlayerDimissListener  {
    
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var iconModel = AppIconModel()
    @ObservedObject var model = SimpleVideoItemModel()
    
    var card: CardData
    init(card: CardData){
        self.card = card
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
            
                //Text(card.name).appFont(.caption).frame(alignment: .leading)
                Text(card.dateString()).appFont(.caption).frame(alignment: .leading)
                Text(card.fileSizeString).appFont(.caption).frame(alignment: .leading)
            
           
            
            if card.isEvent {
                Image(iconModel.vmdAlertIcon).resizable().opacity(0.7)
                    .frame(width: 18,height: 18)
            }
 
            Spacer()
            
            Button(action:{
                model.videoPlayerSheet = VideoPlayerSheet()
                model.showPlayer = true
                model.videoPlayerSheet.doInit(video: card,listener: self)
            }){
                Image(systemName: "play").resizable().frame(width: 14,height: 14)
            }.fullScreenCover(isPresented: $model.showPlayer) {
                model.showPlayer = false
            } content: {
                //player
                model.videoPlayerSheet
            }
            
        }.onAppear(){
            iconModel.initIcons(isDark: colorScheme == .dark)
        }
    }
}
struct OnDeviceVideoItemsView: View {
    var model = EventsAndVideosModel()
    let dataSrc = EventsAndVideosDataSource()
    @State var showAlert = false
    
    var body: some View {
        ZStack(alignment: .topLeading){
            
            List(){
                ForEach(model.daysWithVideos, id: \.self) { day in
                    let videos = model.daysToVideoData[day]!
                    Section(header:
                        HStack{
                            Text(self.dayString(day: day)).appFont(.body)
                            Spacer()
                            Text(self.sizeString(day: day)).appFont(.body)
                            Button(action: {
                                showAlert = true
                            }){
                                Image(systemName: "trash").resizable().frame(width: 18,height:18)
                            }
                            .alert(isPresented: $showAlert) {
                                
                                Alert(title: Text("Delete videos")
                                      , message: Text(self.dayTitle(day: day)),
                                      primaryButton: .default (Text("OK")) {
                                        showAlert = false
                                        print("Delete videos "+self.dayString(day: day))
                                        FileHelper.deleteMedia(cards: model.daysToVideoData[day]!)
                                        self.refresh(camera: dataSrc.camera)
                                        
                                      },
                                      secondaryButton: .cancel() {
                                        showAlert = false
                                      }
                                  )
                              }
                        }
                     ){
                    
                        ForEach(videos, id: \.self) { video in
                            
                                SimpleVideoItem(card: video)
                            
                        }
                        
                    }
                }
                if model.daysWithVideos.count == 0 {
                    Text("No captured videos found")
                }
               
            }.listStyle(PlainListStyle())
                

           
        
        }
        .background(Color(UIColor.systemBackground))
        .onAppear(){
            print("VideoItemsView:onAppear")
            
        }
    }
    func refresh(camera: Camera?) -> Int {
        model.reset()
        dataSrc.setCamera(camera: camera)
        return dataSrc.populateVideos(model: model)
        
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
        let cards = model.daysToVideoData[day]
        for card in cards! {
            total += card.fileSize
        }
        return ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file)
    }
}

struct VideoItemsView_Previews: PreviewProvider {
    static var previews: some View {
        OnDeviceVideoItemsView()
    }
}
