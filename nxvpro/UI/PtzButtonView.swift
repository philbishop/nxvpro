//
//  PtzButton.swift
//  DesignIdeas
//
//  Created by Philip Bishop on 31/05/2021.
//

import SwiftUI
class PtzButton : UIButton{
    
    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
    
    var ptzAction: PtzAction?
    var handler: PtzActionHandler?
    
    init(){
        super.init(frame: CGRect.zero)
       
    }
    
    var isPressed = false
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        isPressed = true
        handler?.onActionStart(action: ptzAction!)
        backgroundColor = UIColor.secondarySystemFill
        superview?.touchesBegan(touches, with: event)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isPressed {
            handler?.onActionEnd(action: ptzAction!)
        }
        backgroundColor = UIColor.clear
        superview?.touchesEnded(touches, with: event)
    }
    
}

struct PtzButtonView: UIViewRepresentable {
    let iconSize = 28
    var btn = PtzButton()
    init(){
        
        let image =  UIImage(named: "ptz_left_light")
        
        let btnImage = Helpers.resizeImage(image:image!,newSize: CGSize(width: iconSize, height: iconSize))
        
        //print("PTZ btnImage size",btnImage.size)
        //let uiv =  UIImageView(image: btnImage)
        
        btn.setImage(btnImage, for: .normal)
        //btn.image = btnImage
    }
    init(icon: String,action: PtzAction,handler: PtzActionHandler?){
        
       
        if action == PtzAction.help {
            //iconSize = 36
        }
        let image =  UIImage(named: icon)
        
        //print("PTZ image size",image?.size)
        
        let btnImage = Helpers.resizeImage(image:image!,newSize: CGSize(width: iconSize, height: iconSize))
        
        //print("PTZ btnImage size",btnImage.size)
        
        btn.setImage(btnImage,for: .normal)
        
        btn.ptzAction = action
        btn.handler = handler
    }
    
    func makeUIView(context: Context) -> UIView {
    
        //btn.isBordered = false
        return btn
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        
    }

}



struct PtzButtonTest: View{
    var body: some View {
        
        PtzButtonView()
    }

}

struct PtzButtonText_Previews: PreviewProvider {
    static var previews: some View {
        //PtzButtonTest()
        Group{
        //Image( "ptz_left_light").resizable().frame(width: 32,height: 32)
            PtzButtonView().frame(width:32,height:32)
        }
    }
}
