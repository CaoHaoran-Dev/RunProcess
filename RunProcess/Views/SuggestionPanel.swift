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
    private weak var parentWindow: NSWindow?
    
    private init() {}
    
    func show(with viewModel: CommandViewModel, relativeTo positioningView: NSView) {
        guard let window = positioningView.window else { return }
        self.parentWindow = window
        
        if let panel = panel, panel.isVisible {
            updateContent(viewModel)
            return
        }
        
        let contentView = SuggestionPanelContent(viewModel: viewModel)
        hostingController = NSHostingController(rootView: contentView)
        
        panel = NSPanel(contentViewController: hostingController!)
        panel?.styleMask = [.nonactivatingPanel, .fullSizeContentView]
        panel?.isFloatingPanel = true
        panel?.level = .floating
        panel?.hasShadow = true
        panel?.isOpaque = false
        panel?.backgroundColor = .clear
        panel?.titlebarAppearsTransparent = true
        panel?.titleVisibility = .hidden
        
        let panelSize = calculatePanelSize(for: viewModel.suggestions)
        panel?.setContentSize(panelSize)
        
        if let panel = panel {
            window.addChildWindow(panel, ordered: .above)
            DispatchQueue.main.async {
                self.positionPanel(relativeTo: positioningView)
            }
        }
        
        panel?.orderFront(nil)
    }
    
    func updateContent(_ viewModel: CommandViewModel) {
        let contentView = SuggestionPanelContent(viewModel: viewModel)
        hostingController?.rootView = contentView
        
        let newSize = calculatePanelSize(for: viewModel.suggestions)
        panel?.setContentSize(newSize)
        
        if let positioningView = findPositioningView() {
            positionPanel(relativeTo: positioningView)
        }
    }
    
    func hide() {
        guard let panel = panel else { return }
        
        if let parent = panel.parent {
            parent.removeChildWindow(panel)
        }
        panel.orderOut(nil)
        parentWindow = nil
    }
    
    func isVisible() -> Bool {
        return panel?.isVisible ?? false
    }
    
    // MARK: - 定位
    
    private func findPositioningView() -> NSView? {
        guard let window = parentWindow,
              let contentView = window.contentView else { return nil }
        return findTextField(in: contentView)
    }
    
    private func findTextField(in view: NSView) -> NSView? {
        if view is RunTextField.NSViewType {
            return view
        }
        for subview in view.subviews {
            if let found = findTextField(in: subview) {
                return found
            }
        }
        return nil
    }
    
    private func positionPanel(relativeTo view: NSView) {
        guard let panel = panel, let window = view.window else { return }
        
        let viewRectInWindow = view.convert(view.bounds, to: nil)
        let windowRect = window.frame
        let contentRect = window.contentLayoutRect
        let titleBarHeight = window.frame.height - contentRect.height
        
        let screenX = windowRect.origin.x + viewRectInWindow.minX
        let screenY = windowRect.origin.y + viewRectInWindow.minY - panel.frame.height - 4 - titleBarHeight
        
        panel.setFrameOrigin(NSPoint(x: screenX, y: screenY))
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
            AdaptiveGlassBackground(
                style: AppSettings.resolvedAppearanceStyle,
                material: .hudWindow,
                blendingMode: .behindWindow,
                cornerRadius: 10
            )
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
    }
}
