//
//  DocumentPicker.swift
//  NXV-IOS
//
//  Created by Philip Bishop on 01/10/2021.
//

import SwiftUI

protocol DocumentPickerListener{
    func onDocumentOpened(fileContents: String) -> Bool
    func onError(error: String)
}

var documentPickerLister: DocumentPickerListener?

struct DocumentPicker: UIViewControllerRepresentable {
    
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let documentPicker =
        UIDocumentPickerViewController(forOpeningContentTypes: [.text])
        documentPicker.delegate = context.coordinator
        return documentPicker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            print(urls[0])
            let url = urls[0]
            do {
                // Start accessing a security-scoped resource.
                guard url.startAccessingSecurityScopedResource() else {
                    // Handle the failure here.
                    return
                }
                
                // Make sure you release the security-scoped resource when you finish.
                defer { url.stopAccessingSecurityScopedResource() }
                
                //copy the data to loca to extract
                let txt = try String(contentsOf: url)
                
                documentPickerLister?.onDocumentOpened(fileContents: txt)
                
            }
            catch {
                // Handle the error here.
                documentPickerLister?.onError(error: "Failed to access document")
                print("DocumentPicker:Error accessing file")
            }
        }
    }
}
