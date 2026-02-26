////
////  PDFExporter.swift
////  LectureCaptions
////
//
//import Foundation
//import PDFKit
//import AppKit
//
//struct PDFExporter {
//
//    static func makePDF(
//        summary: SummaryResult,
//        transcript: [(date: Date, text: String)],
//        title: String = "Lecture Notes"
//    ) -> PDFDocument {
//
//        let pageSize = NSSize(width: 612, height: 792) // US Letter
//        let margin: CGFloat = 48
//
//        let attributed = buildAttributed(
//            summary: summary,
//            transcript: transcript,
//            title: title,
//            pageSize: pageSize,
//            margin: margin
//        )
//
//        let docAttrs: [NSAttributedString.DocumentAttributeKey: Any] = [
//            .documentType: NSAttributedString.DocumentType.pdf,
//            .paperSize: pageSize
//        ]
//
//        do {
//            let data = try attributed.data(
//                from: NSRange(location: 0, length: attributed.length),
//                documentAttributes: docAttrs
//            )
//            if let pdf = PDFDocument(data: data) {
//                return pdf
//            }
//        } catch {
//            print("PDF export failed:", error.localizedDescription)
//        }
//
//        // Fallback: minimal PDF
//        let fallback = PDFDocument()
//        fallback.insert(PDFPage(), at: 0)
//        return fallback
//    }
//
//    // MARK: - Build attributed content
//
//    private static func buildAttributed(
//        summary: SummaryResult,
//        transcript: [(date: Date, text: String)],
//        title: String,
//        pageSize: NSSize,
//        margin: CGFloat
//    ) -> NSAttributedString {
//
//        let result = NSMutableAttributedString()
//
//        let titleFont = NSFont.systemFont(ofSize: 20, weight: .bold)
//        let hFont = NSFont.systemFont(ofSize: 14, weight: .semibold)
//        let bodyFont = NSFont.systemFont(ofSize: 12, weight: .regular)
//        let monoFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
//
//        // Paragraph styles with real page margins
//        let bodyPara = makeParagraph(pageWidth: pageSize.width, margin: margin, spacing: 6)
//        let sectionPara = makeParagraph(pageWidth: pageSize.width, margin: margin, spacing: 10)
//
//        func appendLine(_ s: String, font: NSFont, para: NSParagraphStyle = bodyPara) {
//            result.append(NSAttributedString(string: s + "\n", attributes: [
//                .font: font,
//                .paragraphStyle: para
//            ]))
//        }
//
//        func appendBlank(_ count: Int = 1) {
//            for _ in 0..<count { result.append(NSAttributedString(string: "\n", attributes: [.paragraphStyle: bodyPara])) }
//        }
//
//        // Title
//        appendLine(title, font: titleFont, para: sectionPara)
//        appendBlank()
//
//        // Summary
//        appendLine("SUMMARY", font: hFont, para: sectionPara)
//        for b in summary.bullets {
//            appendLine("• \(b)", font: bodyFont)
//        }
//
//        if !summary.keywords.isEmpty {
//            appendBlank()
//            appendLine("KEYWORDS", font: hFont, para: sectionPara)
//            appendLine(summary.keywords.joined(separator: ", "), font: bodyFont)
//        }
//
//        if !summary.questions.isEmpty {
//            appendBlank()
//            appendLine("QUESTIONS", font: hFont, para: sectionPara)
//            for q in summary.questions {
//                appendLine("• \(q)", font: bodyFont)
//            }
//        }
//
//        appendBlank()
//        appendLine("TRANSCRIPT", font: hFont, para: sectionPara)
//
//        let f = ISO8601DateFormatter()
//        f.formatOptions = [.withInternetDateTime]
//
//        for item in transcript {
//            appendLine("\(f.string(from: item.date))  \(item.text)", font: monoFont)
//        }
//
//        return result
//    }
//
//    private static func makeParagraph(pageWidth: CGFloat, margin: CGFloat, spacing: CGFloat) -> NSParagraphStyle {
//        let p = NSMutableParagraphStyle()
//        p.alignment = .left
//        p.lineBreakMode = .byWordWrapping
//        p.paragraphSpacing = spacing
//
//        // Left margin
//        p.firstLineHeadIndent = margin
//        p.headIndent = margin
//
//        // Right margin: tailIndent is measured from the leading edge when positive.
//        // Setting it to (pageWidth - margin) effectively creates a right margin.
//        p.tailIndent = pageWidth - margin
//
//        return p
//    }
//}
