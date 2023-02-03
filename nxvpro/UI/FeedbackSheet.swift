//
//  FeedbackSheet.swift
//  NXV-IOS
//
//  Created by Philip Bishop on 07/10/2021.
//

import SwiftUI

struct FeedbackSheet: View {
    @Environment(\.presentationMode) var presentationMode
    
    @State var email: String = ""
    @State var comments: String = ""
    @State var incLogs: Bool = true
    @State var status: String = "Please enter your comments or bug report below"
    @State var appVer: String = "NX-V"
    @State var ifr = true
    @State var placeHolder = "Enter your comments"
    @State var sendDisabled: Bool = false
    @State var cancelText: String = "Cancel"
    @State var errorStatus: String = ""
    @State var commentsFirstTime = true
    @State var commentsOpacity = 0.3
    
    var body: some View {
        List(){
            HStack{
                Text("Feedback").appFont(.title)
                    .padding()
                
                Spacer()
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                })
                {
                    Image(systemName: "xmark").resizable()
                        .frame(width: 18,height: 18)
                }.foregroundColor(Color.accentColor)
            }
            Text(status).appFont(.caption)
            
            Section(header: Text("Comments").appFont(.sectionHeader)){
                ZStack{
                    TextEditor(text: $comments).appFont(.body).onTapGesture {
                        if commentsFirstTime{
                            commentsFirstTime = false
                            comments = ""
                            commentsOpacity = 1.0
                        }
                    }.opacity(commentsOpacity)
                        .appFont(.body)
                }.frame(height: 150)
            }
            
            //status section here
            Section(header: Text("Email address (optional)").appFont(.sectionHeader)){
                TextField("email address",text: $email, onEditingChanged: { (isChanged) in
                    if !isChanged {
                        if self.email.isEmpty || self.textFieldValidatorEmail(self.email) {
                            self.sendDisabled = false
                            self.errorStatus = ""
                        } else {
                            self.sendDisabled = true
                            self.errorStatus = "Invalid email address"
                        }
                    }
                })//.appFont(.body)
                    .background(Color(UIColor.systemBackground))
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    
            }
            HStack{
                Text(errorStatus).foregroundColor(Color(UIColor.systemRed)).appFont(.caption)
                Spacer()
                Button("Send"){
                    
                    UIApplication.shared.endEditing()
                    
                    
                    var textToSend = comments
                    if textToSend.count == 0{
                        let logenabled = AppSettings.isLoggingEnabled()
                        if logenabled{
                            textToSend = "LOG FILE ONLY"
                        }else{
                            errorStatus = "Please enter your comments above\nTo include a debug log, first enable loggig via the About menu and then refresh discovery."
                            return
                        }
                    }
                    
                    sendDisabled = true
                    errorStatus = ""
                    status = "Sending, please wait...."
                    
                    let q = DispatchQueue(label: "feedback")
                    q.async {
                        
                        NXVProxy.sendFeedback(comments: textToSend, email: email, isFeedback: true,callback: handleSendFeedback)
                    }
                    
                }.appFont(.body)
                .foregroundColor(Color.accentColor)
                .disabled(sendDisabled)
            }.onAppear{
                let logenabled = AppSettings.isLoggingEnabled()
                if logenabled{
                    comments = "Tap to edit or leave blank to send Log file"
                }else{
                    comments = ""
                }
            }
            
        }
    }
    func textFieldValidatorEmail(_ string: String) -> Bool {
        if string.count > 100 {
            return false
        }
        let emailFormat = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}" // short format
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailFormat)
        return emailPredicate.evaluate(with: string)
    }
    func handleSendFeedback(ok: Bool){
        DispatchQueue.main.async {
            if ok {
                status = "Thank you, your feedback has been sent"
                comments = ""
                cancelText = "Close"
            }else{
                sendDisabled = false
                status = "Sorry, failed to send, please try again later"
            }
        }
    }
}

struct FeedbackSheet_Previews: PreviewProvider {
    static var previews: some View {
        FeedbackSheet()
    }
}
