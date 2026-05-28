import SwiftUI
import UIKit

/// UITextView 기반 텍스트 뷰.
/// SwiftUI Text와 달리 시스템 번역 메뉴(Translate)를 포함한 전체 선택 메뉴를 지원한다.
///
/// tapPassthrough: true이면 UITextView의 탭 제스처를 비활성화해서
/// 부모 SwiftUI 뷰의 onTapGesture가 정상 동작한다 (플래시 카드 flip 등).
struct SelectableText: UIViewRepresentable {
    let text: String
    var font: UIFont
    var color: UIColor
    var alignment: NSTextAlignment
    var lineSpacing: CGFloat
    var tapPassthrough: Bool

    init(_ text: String,
         font: UIFont = .preferredFont(forTextStyle: .body),
         color: UIColor = .white,
         alignment: NSTextAlignment = .natural,
         lineSpacing: CGFloat = 0,
         tapPassthrough: Bool = false) {
        self.text = text
        self.font = font
        self.color = color
        self.alignment = alignment
        self.lineSpacing = lineSpacing
        self.tapPassthrough = tapPassthrough
    }

    func makeUIView(context: Context) -> UITextView {
        let tv: UITextView = tapPassthrough ? PassthroughTapTextView() : UITextView()
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
        let para = NSMutableParagraphStyle()
        para.lineSpacing = lineSpacing
        para.alignment = alignment
        tv.attributedText = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: para
        ])
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        return uiView.sizeThatFits(CGSize(width: width, height: .infinity))
    }
}

// UITextView의 탭 제스처 인식기를 무효화해 SwiftUI 부모 뷰의 탭이 통과하도록 함.
// 롱프레스 기반의 텍스트 선택은 그대로 동작.
private final class PassthroughTapTextView: UITextView {
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer is UITapGestureRecognizer { return false }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }
}
