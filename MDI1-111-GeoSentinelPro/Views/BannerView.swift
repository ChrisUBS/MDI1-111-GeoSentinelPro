//
//  BannerView.swift
//  GeoSentinelPro
//
//  Created by Christian Bonilla on 21/11/25.
//

import SwiftUI

struct BannerView: View {
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "location.fill")
                .foregroundColor(.white)

            Text(message)
                .foregroundColor(.white)
                .font(.footnote)
                .multilineTextAlignment(.leading)

            Spacer()
        }
        .padding()
        .background(.blue.opacity(0.95))
        .cornerRadius(14)
        .shadow(radius: 5)
        .padding(.horizontal)
    }
}
