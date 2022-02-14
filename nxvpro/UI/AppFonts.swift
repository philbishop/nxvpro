//
//  AppFonts.swift
//  iosTestApp
//
//  Created by Philip Bishop on 25/10/2021.
//

import Foundation
import SwiftUI

struct AppFont: ViewModifier {
    
    @Environment(\.sizeCategory) var sizeCategory
    
    public enum TextStyle {
        case title
        case smallTitle
        case titleBar
        case body
        case helpLabel
        case sectionHeader
        case caption
        case smallCaption
        case footnote
        case smallFootnote
    }
    
    var textStyle: TextStyle

    func body(content: Content) -> some View {
       //let scaledSize = UIFontMetrics.default.scaledValue(for: size)
        return content.font(.system(size: size))
    }
    
    private var size: CGFloat {
        switch textStyle {
        case .title:
            return 26
        case .smallTitle:
            return 22
        case .titleBar:
            return 17
        case .body:
            return 16
        case .helpLabel:
            return 15
        case .sectionHeader:
            return 14;
        case .caption:
            return 14
        case .smallCaption:
            return 13
        case .footnote:
            return 12
        case .smallFootnote:
            return 11
        }
    }
    
}
extension View {
    
    func appFont(_ textStyle: AppFont.TextStyle) -> some View {
        self.modifier(AppFont(textStyle: textStyle))
    }
}
