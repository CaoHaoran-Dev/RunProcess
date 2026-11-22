//
//  ScrollViewStyler.swift
//  RunProcess
//

import SwiftUI
internal import AppKit

/// 把所在窗口里的滚动视图调成「叠加式自动隐藏滚动条 + 透明底色」。
///
/// SwiftUI 的滚动视图底层是 `NSScrollView`，默认会带一条常驻滚动条和一块
/// 浅色轨道底色；在透明窗口 + 毛玻璃背景上会露出刺眼的白边。
///
/// 注意：不能只沿父链向上找。`ScrollView.background(...)` 里的视图是滚动视图的
/// 兄弟节点，向上找不到 `NSScrollView`，所以这里从窗口的整个视图树里查找。
struct ScrollViewStyler: NSViewRepresentable {

    func makeNSView(context: Context) -> NSView { StylerView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? StylerView)?.apply()
    }

    /// 遍历窗口内所有滚动视图并修正样式。幂等，可重复调用。
    static func styleAll(in window: NSWindow) {
        guard let root = window.contentView else { return }
        walk(root)
    }

    private static func walk(_ view: NSView) {
        if let scrollView = view as? NSScrollView {
            configure(scrollView)
        }
        for subview in view.subviews {
            walk(subview)
        }
    }

    private static func configure(_ scrollView: NSScrollView) {
        if scrollView.drawsBackground { scrollView.drawsBackground = false }
        if scrollView.scrollerStyle != .overlay { scrollView.scrollerStyle = .overlay }
        if !scrollView.autohidesScrollers { scrollView.autohidesScrollers = true }
        if !scrollView.hasVerticalScroller { scrollView.hasVerticalScroller = true }
        if scrollView.backgroundColor != .clear { scrollView.backgroundColor = .clear }

        // 轨道底色来自 clip view，一并清掉才不会透白。
        let clipView = scrollView.contentView
        if clipView.drawsBackground { clipView.drawsBackground = false }
    }

    private final class StylerView: NSView {

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            apply()
            // 刚挂载时滚动视图可能还没建好，补几次。
            for delay in [0.0, 0.05, 0.2] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    self?.apply()
                }
            }
        }

        override func layout() {
            super.layout()
            apply()
        }

        func apply() {
            guard let window = self.window else { return }
            ScrollViewStyler.styleAll(in: window)
        }
    }
}
