//
//  HelperViews.swift
//  DropLeT
//
//  Created by Aniket Kumar on 24/12/24.
//

import Foundation
import SwiftUI
import Charts
import WidgetKit

struct RecentDrink: View{
    let recentRecords: DrinkRecord
    var body: some View {
        VStack(alignment: .center){
            Image(systemName: recentRecords.type.icon)
                .font(.title2)
                .foregroundColor(recentRecords.type.color)
                .frame(width: 40, height: 40)
                .background {
                    Circle()
                        .fill(.blue.opacity(0.1))
                }
            
            
                Text("\(Int(recentRecords.amount)) ml")
                    .font(.body)
                    .fontWeight(.medium)
                
             
            
        }
    }
}

struct WaterWave: Shape {
    var progress: CGFloat
    var waveHeight: CGFloat
    var offset: CGFloat
    
    var animatableData: CGFloat {
        get { offset }
        set { offset = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        return Path { path in
            path.move(to: .zero)
            
            let progressHeight: CGFloat = (1 - progress) * rect.height
            let height = waveHeight * rect.height
            
            for value in stride(from: 0, to: rect.width, by: 2) {
                let x: CGFloat = value
                let sine: CGFloat = sin(Angle(degrees: value + offset).radians)
                let y: CGFloat = progressHeight + (height * sine)
                path.addLine(to: CGPoint(x: x, y: y))
            }
            
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .foregroundColor(.secondary)
            }
            .font(.subheadline)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(color.opacity(0.1))
        }
    }
}

struct BubblesOverlay: View {
    var body: some View {
        ZStack {
            ForEach(0..<6) { i in
                Circle()
                    .fill(.white.opacity(0.1))
                    .frame(width: [15, 15, 25, 25, 10, 10][i],
                          height: [15, 15, 25, 25, 10, 10][i])
                    .offset(x: [-20, 40, -30, 50, 40, -40][i],
                           y: [0, 30, 80, 70, 100, 50][i])
            }
        }
    }
}
