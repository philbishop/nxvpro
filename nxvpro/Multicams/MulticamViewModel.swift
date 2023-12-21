import SwiftUI

class MulticamViewModelExt : ObservableObject {
    @Published var cameras = [Camera]()
    @Published var row1 = [Camera]()
    @Published var row2 = [Camera]()
    @Published var row3 = [Camera]()
    
    @Published var altCamMode: Bool
    
    var listener: MulticamActionListener?
    
    init(){
        row1 = [Camera]()
        row2 = [Camera]()
        row3 = [Camera]()
        altCamMode = false;
        
    }
    
    func reset(cameras: [Camera]){
        self.cameras = cameras
        row1 = [Camera]()
        row2 = [Camera]()
        row3 = [Camera]()
        altCamMode = false;
        
    }
    func setVerticalAltMainCamera(camera: Camera){
        
        if row2.contains(camera) {
        
            print("Move row 2 camera to row 1 pos 1")
        
            let firstCam = row1[0]
            
            var tmp = [Camera]()
            for cam in cameras {
                if cam.getId() != camera.getId()  && cam.getId() != firstCam.getId(){
                    tmp.append(cam)
                }
            }
            
            row1.removeAll()
            row2.removeAll()
            row3.removeAll()
            
            row1.append(firstCam)
            row1.append(camera)
            
            for cam in tmp {
                row2.append(cam)
            }
            
        }
   
    }
    func setDefaultLayout(){
        if cameras.count > 0 {
            let cam = cameras[0]
            row1.append(cam)
            
        }
        if cameras.count > 1 {
            let cam = cameras[1]
            row1.append(cam)
            
        }
        if cameras.count > 2 {
            let cam = cameras[2]
            row2.append(cam)
            
        }
        if cameras.count > 3 {
            let cam = cameras[3]
            row2.append(cam)
            
        }
    }
    func turnAltCamModeOff(){
        row1.removeAll()
        row2.removeAll()
        row3.removeAll()
        
        altCamMode = false
        
        setDefaultLayout()
    }
    func setAltMainCamera(camera: Camera){
        
        row1.removeAll()
        row2.removeAll()
        row3.removeAll()
        
        altCamMode = true
        
        row1.append(camera)
        
        var tmp = [Camera]()
        for cam in cameras {
            if cam.getId() != camera.getId() {
                tmp.append(cam)
            }
        }
        
         
        for cam in tmp {
            if row2.count < 3 {
                row2.append(cam)
                
            }else{
                row3.append(cam)
            
            }
        }
        
        print(">>setAltMainCamera",cameras.count,row1.count,row2.count,row3.count)
        print("<<setAltMainCamera")
        
    }
    //need to pass in CGSize to determine if portrait
    func getWidthForCol(camera: Camera,fullWidth: CGSize,camsPerRow: Int,altMode: Bool,mainCam: Camera?) -> CGFloat {
        let isPortrait = fullWidth.height > fullWidth.width
        
        if altMode && mainCam != nil && mainCam!.getStringUid() == camera.getStringUid() {
            if isPortrait{
                return fullWidth.width
            }
            return fullWidth.width * CGFloat(0.75)
        }
        
        if altMode{
            if isPortrait{
                for cam in row2 {
                    if cam.getId() == camera.getId(){
                        
                        return fullWidth.width * CGFloat(0.33)
                    }
                }
                if row3.count < 3{
                   
                    return fullWidth.width * CGFloat(0.33)
                }
            }
            
            return fullWidth.width * CGFloat(0.25)
        }
        
        return (fullWidth.width / CGFloat(camsPerRow))
        
    }
    
}


