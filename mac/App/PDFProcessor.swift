import Foundation
import PDFKit
import CoreGraphics

enum PDFProcessorError: LocalizedError {
    case cannotOpenPDF
    case emptyPDF
    case cannotCreateOutput

    var errorDescription: String? {
        switch self {
        case .cannotOpenPDF: return NSLocalizedString("Cannot open the PDF file.", comment: "")
        case .emptyPDF: return NSLocalizedString("The PDF file contains no pages.", comment: "")
        case .cannotCreateOutput: return NSLocalizedString("Cannot create the output file.", comment: "")
        }
    }
}

struct ProcessingResult {
    let outputURL: URL
    let pageCount: Int
    let targetWidth: CGFloat
    let pagesScaled: Int
}

struct PDFProcessor {

    static func process(
        inputURL: URL,
        replaceOriginal: Bool = false,
        progressCallback: @escaping @Sendable (String) -> Void
    ) throws -> ProcessingResult {

        // Step 1: Load the PDF
        guard let document = PDFDocument(url: inputURL) else {
            throw PDFProcessorError.cannotOpenPDF
        }
        let pageCount = document.pageCount
        guard pageCount > 0 else {
            throw PDFProcessorError.emptyPDF
        }

        // Step 2: Find the minimum width across all pages
        // (accounting for page rotation)
        var minWidth = CGFloat.greatestFiniteMagnitude

        for i in 0..<pageCount {
            guard let page = document.page(at: i) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let rotation = page.rotation
            let effectiveWidth: CGFloat
            if rotation == 90 || rotation == 270 {
                effectiveWidth = bounds.height
            } else {
                effectiveWidth = bounds.width
            }
            minWidth = min(minWidth, effectiveWidth)
        }

        // Step 3: Create output PDF
        let tempURL: URL
        let finalURL: URL
        if replaceOriginal {
            tempURL = inputURL.deletingLastPathComponent()
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("pdf")
            finalURL = inputURL
        } else {
            tempURL = Self.outputURL(for: inputURL)
            finalURL = tempURL
        }

        guard let pdfContext = CGContext(tempURL as CFURL, mediaBox: nil, nil) else {
            throw PDFProcessorError.cannotCreateOutput
        }

        var pagesScaled = 0

        // Step 4: Process each page
        for i in 0..<pageCount {
            progressCallback(String(format: NSLocalizedString("Processing page %d of %d...", comment: ""), i + 1, pageCount))

            guard let page = document.page(at: i),
                  let cgPage = page.pageRef else { continue }

            let bounds = page.bounds(for: .mediaBox)
            let rotation = page.rotation

            let effectiveWidth: CGFloat
            let effectiveHeight: CGFloat
            if rotation == 90 || rotation == 270 {
                effectiveWidth = bounds.height
                effectiveHeight = bounds.width
            } else {
                effectiveWidth = bounds.width
                effectiveHeight = bounds.height
            }

            // Calculate scale factor based on width only
            let scale: CGFloat
            if effectiveWidth > minWidth + 0.5 {
                scale = minWidth / effectiveWidth
                pagesScaled += 1
            } else {
                scale = 1.0
            }

            // New page dimensions: width = minWidth, height proportional
            let newWidth = effectiveWidth * scale
            let newHeight = effectiveHeight * scale

            var mediaBox = CGRect(x: 0, y: 0, width: newWidth, height: newHeight)
            pdfContext.beginPage(mediaBox: &mediaBox)
            pdfContext.saveGState()

            // Use getDrawingTransform to handle rotation and fitting
            let targetRect = CGRect(x: 0, y: 0, width: newWidth, height: newHeight)
            let transform = cgPage.getDrawingTransform(
                .mediaBox,
                rect: targetRect,
                rotate: 0,
                preserveAspectRatio: true
            )
            pdfContext.concatenate(transform)
            pdfContext.drawPDFPage(cgPage)

            pdfContext.restoreGState()
            pdfContext.endPage()
        }

        pdfContext.closePDF()

        if replaceOriginal {
            let fm = FileManager.default
            try fm.removeItem(at: inputURL)
            try fm.moveItem(at: tempURL, to: finalURL)
        }

        return ProcessingResult(
            outputURL: finalURL,
            pageCount: pageCount,
            targetWidth: minWidth,
            pagesScaled: pagesScaled
        )
    }

    // MARK: - Output URL

    private static func outputURL(for inputURL: URL) -> URL {
        let directory = inputURL.deletingLastPathComponent()
        let stem = inputURL.deletingPathExtension().lastPathComponent
        let ext = "pdf"
        let baseName = "\(stem)_equalized"

        var outputURL = directory.appendingPathComponent(baseName).appendingPathExtension(ext)

        var counter = 2
        while FileManager.default.fileExists(atPath: outputURL.path) {
            let numberedName = "\(baseName)_\(counter)"
            outputURL = directory.appendingPathComponent(numberedName).appendingPathExtension(ext)
            counter += 1
        }

        return outputURL
    }
}
