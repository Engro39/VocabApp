import SwiftUI
import UIKit

/// UITextView 기반 텍스트 뷰.
/// SwiftUI Text와 달리 시스템 번역 메뉴(Translate)를 포함한 전체 선택 메뉴를 지원한다.
struct SelectableText: UIViewRepresentable {
    let text: String
    var font: UIFont
    var color: UIColor
    var alignment: NSTextAlignment

    init(_ text: String,
         font: UIFont = .preferredFont(forTextStyle: .body),
         color: UIColor = .white,
         alignment: NSTextAlignment = .natural) {
        self.text = text
        self.font = font
        self.color = color
        self.alignment = alignment
    }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.isScrollEnabled = false
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.setContentHuggingPriority(.defaultHigh, for: .vertical)
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        if tv.text != text { tv.text = text }
        tv.font = font
        tv.textColor = color
        tv.textAlignment = alignment
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        return uiView.sizeThatFits(CGSize(width: width, height: .infinity))
    }
}
