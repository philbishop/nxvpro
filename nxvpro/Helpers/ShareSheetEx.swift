//
//  ShareSheetEx.swift
//  NXV-IOS
//
//  Created by Philip Bishop on 02/07/2021.
//
import SwiftUI

extension View {
  /// Show the classic Apple share sheet on iPhone and iPad.
  ///
  func showShareSheet(with activityItems: [Any]) {
    guard let source = UIApplication.shared.windows.first?.rootViewController else {
        AppLog.write("Unabled to showShareSheet")
      return
    }

    let activityVC = UIActivityViewController(
      activityItems: activityItems,
      applicationActivities: nil)

    if let popoverController = activityVC.popoverPresentationController {
      popoverController.sourceView = source.view
      popoverController.sourceRect = CGRect(x: source.view.bounds.midX,
                                            y: source.view.bounds.midY,
                                            width: .zero, height: .zero)
      popoverController.permittedArrowDirections = []
    }
    source.present(activityVC, animated: true, completion: nil)
  }
}
