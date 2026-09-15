//
//  VisualEffectView.swift
//  RunProcess
//
//  Created by Haoran on 2026/8/21.
//

import SwiftUI
internal import AppKit

/// 传统毛玻璃视图（macOS 12.4+ 可用）
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.wantsLayer = true
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
    }
}

/// 自适应背景，根据外观风格渲染
///
/// - `.none`：系统窗口背景色（不透明）
/// - `.frostedGlass`：NSVisualEffectView 毛玻璃
/// - `.liquidGlass`：macOS 26+ 使用 Liquid Glass，否则回退到毛玻璃
struct AdaptiveGlassBackground: View {
    let style: AppearanceStyle
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    let cornerRadius: CGFloat
    
    var body: some View {
        switch style {
        case .none:
            Color(NSColor.windowBackgroundColor)
                .cornerRadius(cornerRadius)
        case .frostedGlass:
            frostedGlass
        case .liquidGlass:
            liquidGlass
        }
    }
    
    private var frostedGlass: some View {
        VisualEffectView(material: material, blendingMode: blendingMode)
            .cornerRadius(cornerRadius)
    }
    
    @ViewBuilder
    private var liquidGlass: some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            Color.clear
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            frostedGlass
        }
        #else
        frostedGlass
        #endif
    }
}

/// 无圆角版本（用于全窗口背景）
struct AdaptiveWindowBackground: View {
    let style: AppearanceStyle
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    var body: some View {
        switch style {
        case .none:
            Color(NSColor.windowBackgroundColor)
        case .frostedGlass:
            VisualEffectView(material: material, blendingMode: blendingMode)
        case .liquidGlass:
            #if compiler(>=6.2)
            if #available(macOS 26.0, *) {
                Color.clear
                    .glassEffect(.regular, in: .rect(cornerRadius: 0))
            } else {
                VisualEffectView(material: material, blendingMode: blendingMode)
            }
            #else
            VisualEffectView(material: material, blendingMode: blendingMode)
            #endif
        }
    }
}
