//
//  ModeImagingView.swift
//  TestMacUI
//
//  Created by Philip Bishop on 04/01/2022.
//

import SwiftUI

class ModeImagingViewModel : ObservableObject {
    @Published var name = ""
    @Published var modes = [String]()
    @Published var selectedMode = ""
    @Published var labelColor = Color(UIColor.label)
    
    var initialMode = ""
    
    func flagChanged(){
        if initialMode != selectedMode{
            labelColor = .accentColor
        }else{
           labelColor = Color(UIColor.label)
        }
    }
    var opt: ModeImagingType?
    
    func setOption(opt: ModeImagingType){
        self.opt = opt
        self.name = opt.name.camelCaseToWords()
        self.modes.removeAll()
        for mode in opt.modes{
            self.modes.append(mode)
        }
        self.selectedMode = opt.mode
        self.initialMode = opt.mode
        self.labelColor  = Color(UIColor.label)
    }
    
}

struct ModeImagingView : View, RefreshableImagingView{
    
    @ObservedObject var model = ModeImagingViewModel()
    
    var listener: ImagingActionListener?
    
    init(opt: ModeImagingType,handler: ImagingItemChangeHandler,listener: ImagingActionListener?){
        self.listener = listener
        model.setOption(opt: opt)
        handler.register(optName: opt.name, imagingView: self)
    }
    
    func updateView(opt: ImagingType) {
        model.setOption(opt: opt as! ModeImagingType)
    }
    
    var body: some View {
        VStack(alignment: .leading){
            HStack{
                Text(model.name).foregroundColor(model.labelColor).appFont(.caption)
                if model.modes.count == 0{
                    Text("Read only").appFont(.smallCaption)
                }
                Spacer()
            }
            Menu{
                Picker("", selection: $model.selectedMode) {
                    ForEach(self.model.modes, id: \.self) {
                        Text($0).foregroundColor(Color(UIColor.label)).appFont(.caption)
                        
                    }
                }.onChange(of: model.selectedMode) { newMode in
                    model.opt!.mode = newMode
                    listener?.imagingItemChanged()
                    model.flagChanged()
                    AppLog.write("Imaging mode changed",newMode)
                    
                }
            }label:{
                Text(model.selectedMode).foregroundColor(.accentColor)
            }.appFont(.caption)
            
            .disabled(model.modes.count<2)
            .hidden(model.modes.count==0)
            .frame(width: 120)
        }
        
    }
}


