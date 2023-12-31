//
//  VideoPlayerControls.swift
//  DesignIdeas
//
//  Created by Philip Bishop on 06/06/2021.
//

import SwiftUI

class VideoComtrolsModel : ObservableObject{
    @Published var elaspsedTime: String = "00:00"
    @Published var remainingTime: String = "--:--"
    @Published var position: Double = 0.0
    @Published var volumeOn: Bool = true
    var duration: Double = 0.0
    var globalVideoPlayer: BaseVideoPlayer?
}

struct VideoPlayerControls: View, NxvSliderListener {
    
    
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var iconModel = AppIconModel()
    @ObservedObject var model = VideoComtrolsModel()
    @State var position: Double = 0.0
    @State var duration: Double = 100.0
    
    @State var slider = NxvSlider()
    
    func nxvSliderChanged(percent: Float,source: NxvSlider) {
        let posRel = Double(percent) / Double(100)
        let vidPos = model.duration * posRel
        model.globalVideoPlayer?.moveTo(position: vidPos)
        /*
        if model.globalVideoPlayer?.isPlaying() == false {
            model.globalVideoPlayer?.play()
        }
         */
    }
    func nxvSliderChangeEnded(source: NxvSlider) {
       
    }
    func setPlayer(player: BaseVideoPlayer){
        model.globalVideoPlayer = player
    }
    
    
    var body: some View {
        let videoPlayerView = model.globalVideoPlayer
        
        ZStack(alignment: .top){
            GeometryReader { fullView in
                let isSmallScreen = UIDevice.current.userInterfaceIdiom == .phone
                let srubberWidth = fullView.size.width - ( isSmallScreen ? 170 : 210)
                HStack{
                    
                    Button(action: {
                        if videoPlayerView!.isPlaying() {
                            videoPlayerView!.pause()
                            iconModel.playStatusChange(playing: false)
                        }else{
                            videoPlayerView!.resume()
                            iconModel.playStatusChange(playing: true)
                        }
                    }){
                        Image(iconModel.activePlayIcon).resizable().frame(width: 24,height: 24)
                    }
                    
                    slider.frame(width: srubberWidth,height: 22)
                    
                    Text(model.elaspsedTime).appFont(.footnote)//.foregroundColor(Color.accentColor)
                    if !isSmallScreen{
                        Text(model.remainingTime).appFont(.footnote).opacity(0.7)
                    }
                    //MUTE
                    Button(action: {
                        model.volumeOn = !model.volumeOn
                        iconModel.volumeStatusChange(on: model.volumeOn)
                        if let vpv = videoPlayerView{
                            vpv.setMuted(muted: model.volumeOn == false)
                        }
                        //videoPlayerView?.mediaPlayer!.audio.volume = model.volumeOn ? 100 : 0
                    }){
                        Image(iconModel.activeVolumeIcon).resizable().frame(width: 32,height: 32)
                    }
                    
                    //ROTATE
                    Button(action: {
                        videoPlayerView?.rotateNext()
                    }){
                        
                        Image(iconModel.rotateIcon).resizable().frame(width: 30, height: 30)
                    }
 
                }.onAppear{
                    AppLog.write("VieoControls:body",fullView.size)
                }
            }.padding(4).frame(height: 38).background(Color(UIColor.systemGroupedBackground)).cornerRadius(25)
                
        }.padding().onAppear(){
            iconModel.initIcons(isDark: colorScheme == .dark)
            slider.listener = self
        }
    }
    
    func playerStarted(playing: Bool){
        iconModel.playStatusChange(playing: playing)
    }
    func timeChanged(time: String,remaining: String,position: Int,duration: Int){
        model.elaspsedTime = time
        model.remainingTime = remaining
        model.duration = Double(duration)
        let relPos = (Double(position) / Double(duration)) * 100.0
       
        model.position = relPos
        
        slider.setPercentage(pc: Float(relPos))
        if model.position == model.duration{
            iconModel.playStatusChange(playing: false)
        }
       
    }
    func changeVideoPosition(){
        let posRel = Double(model.position) / Double(100)
        let vidPos = model.duration * posRel
        model.globalVideoPlayer?.moveTo(position: vidPos)
    }
}

struct VideoPlayerControls_Previews: PreviewProvider {
    static var previews: some View {
        VideoPlayerControls()
    }
}
