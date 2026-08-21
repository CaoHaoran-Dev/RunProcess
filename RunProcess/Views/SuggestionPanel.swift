//
//  SuggestionPanel.swift
//  RunProcess
//
//  Created by Haoran on 2026/8/21.
//

import SwiftUI

/// 独立候选列表浮窗
class SuggestionPanel {
    static let shared = SuggestionPanel()
    
    private var panel: NSPanel?
    private var hostingController: NSHostingController<SuggestionPanelContent>?
    
    private init() {}
    
    func show(with viewModel: CommandViewModel, relativeTo positioningView: NSView) {
        // 如果面板已存在，更新内容
        if let panel = panel, panel.isVisible {
            updateContent(viewModel)
            return
        }
        
        // 创建内容视图
        let contentView = SuggestionPanelContent(viewModel: viewModel)
        hostingController = NSHostingController(rootView: contentView)
        
        // 创建 NSPanel
        panel = NSPanel(contentViewController: hostingController!)
        panel?.styleMask = [.nonactivatingPanel, .fullSizeContentView]
        panel?.isFloatingPanel = true
        panel?.level = .floating
        panel?.hasShadow = true
        panel?.isOpaque = false
        panel?.backgroundColor = .clear
        panel?.titlebarAppearsTransparent = true
        panel?.titleVisibility = .hidden
        
        // 设置尺寸
        let panelSize = calculatePanelSize(for: viewModel.suggestions)
        panel?.setContentSize(panelSize)
        
        // 定位到输入框下方
        positionPanel(relativeTo: positioningView)
        
        // 显示
        panel?.orderFront(nil)
    }
    
    func updateContent(_ viewModel: CommandViewModel) {
        let contentView = SuggestionPanelContent(viewModel: viewModel)
        hostingController?.rootView = contentView
        
        // 更新尺寸
        let newSize = calculatePanelSize(for: viewModel.suggestions)
        panel?.setContentSize(newSize)
    }
    
    func hide() {
        panel?.orderOut(nil)
    }
    
    func isVisible() -> Bool {
        return panel?.isVisible ?? false
    }
    
    // MARK: - 定位
    
    private func positionPanel(relativeTo view: NSView) {
        guard let panel = panel else { return }
        
        // 获取输入框在屏幕上的位置
        let window = view.window
        let viewRect = view.convert(view.bounds, to: nil)
        let screenRect = window?.convertToScreen(viewRect) ?? .zero
        
        // 面板位置：输入框下方，左对齐
        let _: CGFloat = 480
        let panelHeight = panel.frame.height
        let x = screenRect.minX
        let y = screenRect.minY - panelHeight - 4  // 4px 间距
        
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    private func calculatePanelSize(for suggestions: [Suggestion]) -> NSSize {
        let width: CGFloat = 480
        let rowHeight: CGFloat = 38
        let headerHeight: CGFloat = 32
        let padding: CGFloat = 12
        let visibleCount = min(suggestions.count, 5)
        let height = headerHeight + CGFloat(visibleCount) * rowHeight + padding
        return NSSize(width: width, height: max(height, 60))
    }
}

// MARK: - SwiftUI 内容

struct SuggestionPanelContent: View {
    @ObservedObject var viewModel: CommandViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 计数（只有数字，没文字）
            HStack {
                Spacer()
                Text("\(viewModel.selectedIndex + 1)/\(viewModel.suggestions.count)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
            
            Divider()
            
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(viewModel.suggestions.enumerated()), id: \.element.id) { index, suggestion in
                        SuggestionRow(
                            suggestion: suggestion,
                            isSelected: index == viewModel.selectedIndex
                        )
                        .onTapGesture {
                            viewModel.selectedIndex = index
                            viewModel.confirmSelection()
                        }
                        .onHover { hovering in
                            if hovering {
                                viewModel.selectedIndex = index
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
        }
        .frame(width: 480)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .cornerRadius(10)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
    }
}
