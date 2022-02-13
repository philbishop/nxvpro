//
//  WideDynamicRangeImagingView.swift
//  TestMacUI
//
//  Created by Philip Bishop on 04/01/2022.
//

import SwiftUI

class WideDynamicRangeImagingViewModel : ObservableObject, NxvSliderListener{
    @Published var name = ""
    @Published var modes = [String]()
    @Published var selectedMode = ""
    @Published var valueString = ""
    @Published var showSlider = true
    @Published var labelColor = Color(UIColor.label)
    @Published var sLabelColor = Color(UIColor.label)
    var initialMode = ""
    var initialValue = ""
    
    func flagChanged(){
        if initialMode != selectedMode || initialValue != valueString{
            labelColor = .accentColor
        }else{
           labelColor = Color(UIColor.label)
        }
    }
    var opt: WideDynamicRangeImagingType?
    var listener: ImagingActionListener?
    
    func setOption(opt: WideDynamicRangeImagingType,listener: ImagingActionListener?){
        self.opt = opt
        self.name = opt.name.camelCaseToWords()
        self.listener = listener
        self.modes.removeAll()
        for mode in opt.modes{
            self.modes.append(mode)
        }
        self.selectedMode = opt.mode
        self.showSlider = opt.mode == "ON" && opt.hasRange()
        
        self.valueString = String(opt.level)
        
        self.initialMode = opt.mode
        self.initialValue = self.valueString
        self.labelColor = Color(UIColor.label)
        self.sLabelColor = Color(UIColor.label)
        
    }
    func getSliderValue() -> Float{
       
        if opt!.maxLevel - opt!.minLevel == 0{
            //showSlider = false
        }
        
        let pcval =  (opt!.level/(opt!.maxLevel-opt!.minLevel)) * 100
        return Float(pcval)
       
    }
    func nxvSliderChanged(percent: Float,source: NxvSlider) {
        let actual =  opt!.minLevel + (Double(percent) * (opt!.maxLevel-opt!.minLevel))/100.0
        opt!.level = round(actual)
        valueString = String(round(actual))
        
        listener?.imagingItemChanged()
        flagChanged()
    }
}

struct WideDynamicRangeImagingView : View, RefreshableImagingView{
    
    @ObservedObject var model = WideDynamicRangeImagingViewModel()
    
    @State var slider = NxvSlider()
    var listener: ImagingActionListener?
    
    init(opt: WideDynamicRangeImagingType,handler: ImagingItemChangeHandler,listener: ImagingActionListener?){
        self.listener = listener
        model.setOption(opt: opt,listener: listener)
        slider.setPercentage(pc: model.getSliderValue())
        handler.register(optName: opt.name, imagingView: self)
    }
    
    func updateView(opt: ImagingType) {
        model.setOption(opt: opt as! WideDynamicRangeImagingType,listener: listener)
        slider.setPercentage(pc: model.getSliderValue())
    }
    
    var body: some View {
        VStack(alignment: .leading){
            HStack{
                Text(model.name).foregroundColor(model.labelColor).appFont(.caption)
                Spacer()
            }
            
            Picker("", selection: $model.selectedMode) {
                ForEach(self.model.modes, id: \.self) {
                    Text($0).foregroundColor(Color(UIColor.label)).appFont(.caption)
                        
                }
            }.onChange(of: model.selectedMode) { newMode in
                model.opt!.mode = newMode
                listener?.imagingItemChanged()
                model.flagChanged()
                print("Imaging mode changed",newMode)
                
            }.frame(width: 120)
            
            if model.showSlider{
                HStack{
                    slider
                    Text(model.valueString).foregroundColor(model.sLabelColor).appFont(.smallCaption).padding(.trailing)
                }.frame(height: 16)
            }
        }.onAppear{
            slider.listener = model
            
        }
    }
}
