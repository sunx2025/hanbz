//
//  BrandLogo.swift
//  hangulblitz
//

import SwiftUI

struct BrandLogo: View {
    var body: some View {
        Image("HB Logo")
            .resizable()
            .scaledToFit()
            .frame(width: 121)
            .accessibilityLabel("Hangul Blitz")
    }
}
