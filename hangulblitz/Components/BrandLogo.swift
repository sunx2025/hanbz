//
//  BrandLogo.swift
//  hangulblitz
//

import SwiftUI

struct BrandLogo: View {
    var width: CGFloat = 121

    var body: some View {
        Image("HB Logo")
            .resizable()
            .scaledToFit()
            .frame(width: width)
            .accessibilityLabel("Hangul Blitz")
    }
}
