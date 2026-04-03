import { useCallback, useState } from 'react'
import { Document, Page, pdfjs } from 'react-pdf'
import { AdInterstitial } from './AdInterstitial'
import 'react-pdf/dist/Page/AnnotationLayer.css'
import 'react-pdf/dist/Page/TextLayer.css'

pdfjs.GlobalWorkerOptions.workerSrc = new URL(
  'pdfjs-dist/build/pdf.worker.min.mjs',
  import.meta.url
).toString()

type Props = {
  url: string | null
  premium: boolean
}

export function PdfWithAds({ url, premium }: Props) {
  const [numPages, setNumPages] = useState<number | null>(null)
  const [page, setPage] = useState(1)
  const [adOpen, setAdOpen] = useState(false)
  const [blockedPage, setBlockedPage] = useState<number | null>(null)

  const onLoadSuccess = useCallback(({ numPages: n }: { numPages: number }) => {
    setNumPages(n)
  }, [])

  const go = useCallback(
    (next: number) => {
      if (!numPages) return
      const clamped = Math.min(Math.max(1, next), numPages)
      if (!premium && clamped > 0 && clamped % 3 === 0 && clamped !== blockedPage) {
        setBlockedPage(clamped)
        setAdOpen(true)
        return
      }
      setPage(clamped)
    },
    [numPages, premium, blockedPage]
  )

  const closeAd = () => {
    setAdOpen(false)
    if (blockedPage != null) {
      setPage(blockedPage)
      setBlockedPage(null)
    }
  }

  if (!url) {
    return <p className="text-sm text-slate-500">No PDF for this topic yet.</p>
  }

  return (
    <div className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
      {!premium && (
        <p className="mb-3 text-xs text-slate-500">
          Free: a short ad appears when you open page 3, 6, 9, … Premium removes ads.
        </p>
      )}
      <div className="flex flex-wrap items-center gap-2 border-b border-slate-100 pb-3">
        <button
          type="button"
          disabled={page <= 1}
          onClick={() => go(page - 1)}
          className="rounded-lg border border-slate-200 px-3 py-1.5 text-sm disabled:opacity-40"
        >
          Previous
        </button>
        <button
          type="button"
          disabled={!numPages || page >= numPages}
          onClick={() => go(page + 1)}
          className="rounded-lg border border-slate-200 px-3 py-1.5 text-sm disabled:opacity-40"
        >
          Next
        </button>
        <span className="text-sm text-slate-600">
          Page {page}
          {numPages != null ? ` / ${numPages}` : ''}
        </span>
      </div>
      <div className="mt-4 max-h-[70vh] overflow-auto rounded-lg bg-slate-50">
        <Document
          file={url}
          onLoadSuccess={onLoadSuccess}
          loading={<p className="p-4 text-sm text-slate-500">Loading PDF…</p>}
          error={<p className="p-4 text-sm text-red-600">Could not load PDF.</p>}
        >
          <Page
            pageNumber={page}
            width={Math.min(900, typeof window !== 'undefined' ? window.innerWidth - 48 : 800)}
            renderTextLayer
            renderAnnotationLayer
          />
        </Document>
      </div>
      <AdInterstitial open={adOpen} title="Reading break" onClose={closeAd} />
    </div>
  )
}
