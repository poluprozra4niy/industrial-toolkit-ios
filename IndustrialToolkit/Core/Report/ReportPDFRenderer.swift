import UIKit

/// Draws a `ReportDocument` onto A4 pages with page breaks, a running footer and signature lines.
enum ReportPDFRenderer {
    static let pageSize = CGSize(width: 595.2, height: 841.8)
    static let margin: CGFloat = 40
    private static let footerHeight: CGFloat = 24
    private static let photoGap: CGFloat = 8
    private static let photosPerRow = 3
    private static let maxPhotoHeight: CGFloat = 150

    static func render(_ document: ReportDocument) -> Data {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: document.title,
            kCGPDFContextCreator as String: "Инженер АСУ ТП",
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize), format: format)
        return renderer.pdfData { context in
            let page = PageCursor(context: context, footer: document.title)
            page.drawTitle(document.title)
            for line in document.headerLines {
                page.drawText(line, style: .body)
            }
            page.space(10)
            for section in document.sections {
                page.drawSectionTitle(section.title)
                for row in section.rows {
                    page.drawRow(row)
                }
                page.space(6)
            }
            page.drawSectionTitle("Итог")
            for line in document.summaryLines {
                page.drawText(line, style: .body)
            }
            page.space(24)
            page.drawSignatures(document.signatures)
        }
    }

    enum TextStyle {
        case title
        case section
        case body
        case detail

        var font: UIFont {
            switch self {
            case .title: .systemFont(ofSize: 17, weight: .bold)
            case .section: .systemFont(ofSize: 12, weight: .semibold)
            case .body: .systemFont(ofSize: 10.5)
            case .detail: .systemFont(ofSize: 9)
            }
        }

        var color: UIColor {
            switch self {
            case .title, .section, .body: .black
            case .detail: .darkGray
            }
        }
    }

    private final class PageCursor {
        let context: UIGraphicsPDFRendererContext
        let footer: String
        var y: CGFloat = 0
        var pageNumber = 0

        var left: CGFloat { ReportPDFRenderer.margin }
        var width: CGFloat { ReportPDFRenderer.pageSize.width - 2 * ReportPDFRenderer.margin }
        var bottom: CGFloat { ReportPDFRenderer.pageSize.height - ReportPDFRenderer.margin - ReportPDFRenderer.footerHeight }

        init(context: UIGraphicsPDFRendererContext, footer: String) {
            self.context = context
            self.footer = footer
            newPage()
        }

        func newPage() {
            context.beginPage()
            pageNumber += 1
            y = ReportPDFRenderer.margin
            let footerText = "\(footer) · стр. \(pageNumber)"
            let attributes = Self.attributes(.detail)
            let footerY = ReportPDFRenderer.pageSize.height - ReportPDFRenderer.margin - 10
            (footerText as NSString).draw(
                with: CGRect(x: left, y: footerY, width: width, height: 14),
                options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                attributes: attributes,
                context: nil
            )
        }

        /// Starts a new page when the block would cross the footer; oversized blocks get a page of their own.
        func ensureSpace(_ height: CGFloat) {
            if y + height > bottom && y > ReportPDFRenderer.margin {
                newPage()
            }
        }

        func space(_ height: CGFloat) {
            y += height
        }

        static func attributes(_ style: TextStyle) -> [NSAttributedString.Key: Any] {
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byWordWrapping
            return [.font: style.font, .foregroundColor: style.color, .paragraphStyle: paragraph]
        }

        func height(of text: String, style: TextStyle, width: CGFloat) -> CGFloat {
            let bounds = (text as NSString).boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: Self.attributes(style),
                context: nil
            )
            return ceil(bounds.height)
        }

        func draw(_ text: String, style: TextStyle, x: CGFloat, width: CGFloat) -> CGFloat {
            let textHeight = height(of: text, style: style, width: width)
            (text as NSString).draw(
                with: CGRect(x: x, y: y, width: width, height: textHeight),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: Self.attributes(style),
                context: nil
            )
            return textHeight
        }

        func drawTitle(_ text: String) {
            y += draw(text, style: .title, x: left, width: width) + 8
        }

        func drawText(_ text: String, style: TextStyle) {
            ensureSpace(height(of: text, style: style, width: width))
            y += draw(text, style: style, x: left, width: width) + 2
        }

        func drawSectionTitle(_ text: String) {
            ensureSpace(height(of: text, style: .section, width: width) + 40)
            y += 4
            y += draw(text.uppercased(), style: .section, x: left, width: width) + 3
            let line = UIBezierPath()
            line.move(to: CGPoint(x: left, y: y))
            line.addLine(to: CGPoint(x: left + width, y: y))
            UIColor.lightGray.setStroke()
            line.lineWidth = 0.5
            line.stroke()
            y += 5
        }

        func drawRow(_ row: ReportRow) {
            let markWidth: CGFloat = 18
            let textX = left + markWidth
            let textWidth = width - markWidth
            let label = "\(row.text)  [\(row.status.title)]"
            let detailText = row.details.joined(separator: "\n")
            let textHeight = height(of: label, style: .body, width: textWidth)
            let detailHeight = detailText.isEmpty ? 0 : height(of: detailText, style: .detail, width: textWidth) + 1
            ensureSpace(textHeight + detailHeight + 4)
            let markColor: UIColor = switch row.status {
            case .passed: UIColor(red: 0.12, green: 0.5, blue: 0.29, alpha: 1)
            case .failed: UIColor(red: 0.78, green: 0.16, blue: 0.16, alpha: 1)
            case .pending: .gray
            }
            (row.status.mark as NSString).draw(
                at: CGPoint(x: left, y: y),
                withAttributes: [.font: UIFont.systemFont(ofSize: 11, weight: .bold), .foregroundColor: markColor]
            )
            y += draw(label, style: .body, x: textX, width: textWidth) + 1
            if !detailText.isEmpty {
                y += draw(detailText, style: .detail, x: textX, width: textWidth) + 1
            }
            drawPhotos(row.images, x: textX, width: textWidth)
            y += 4
        }

        private func drawPhotos(_ images: [Data], x: CGFloat, width: CGFloat) {
            let photos = images.compactMap(UIImage.init(data:))
            guard !photos.isEmpty else { return }
            let columns = CGFloat(ReportPDFRenderer.photosPerRow)
            let cellWidth = (width - (columns - 1) * ReportPDFRenderer.photoGap) / columns
            var index = 0
            while index < photos.count {
                let rowPhotos = Array(photos[index..<min(index + ReportPDFRenderer.photosPerRow, photos.count)])
                let rowHeight = rowPhotos.map { fittedSize($0, width: cellWidth).height }.max() ?? 0
                ensureSpace(rowHeight + ReportPDFRenderer.photoGap)
                y += 2
                for (column, photo) in rowPhotos.enumerated() {
                    let size = fittedSize(photo, width: cellWidth)
                    let origin = CGPoint(x: x + CGFloat(column) * (cellWidth + ReportPDFRenderer.photoGap), y: y)
                    photo.draw(in: CGRect(origin: origin, size: size))
                }
                y += rowHeight + ReportPDFRenderer.photoGap
                index += ReportPDFRenderer.photosPerRow
            }
        }

        private func fittedSize(_ image: UIImage, width: CGFloat) -> CGSize {
            guard image.size.width > 0, image.size.height > 0 else { return .zero }
            let scale = min(width / image.size.width, ReportPDFRenderer.maxPhotoHeight / image.size.height)
            return CGSize(width: image.size.width * scale, height: image.size.height * scale)
        }

        func drawSignatures(_ signatures: [ReportSignature]) {
            for signature in signatures {
                ensureSpace(46)
                let name = signature.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let label = "\(signature.role):"
                _ = draw(label, style: .body, x: left, width: 170)
                let lineStart = left + 175
                let lineEnd = left + width - 110
                let path = UIBezierPath()
                path.move(to: CGPoint(x: lineStart, y: y + 13))
                path.addLine(to: CGPoint(x: lineEnd, y: y + 13))
                path.move(to: CGPoint(x: lineEnd + 20, y: y + 13))
                path.addLine(to: CGPoint(x: left + width, y: y + 13))
                UIColor.black.setStroke()
                path.lineWidth = 0.5
                path.stroke()
                y += 15
                _ = draw(name.isEmpty ? "подпись / ФИО" : "подпись / \(name)", style: .detail, x: lineStart, width: lineEnd - lineStart)
                _ = draw("дата", style: .detail, x: lineEnd + 20, width: 90)
                y += 26
            }
        }
    }
}
