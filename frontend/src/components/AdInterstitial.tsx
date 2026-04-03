import { useEffect, useState } from 'react'

const AD_SECONDS = 30

type Props = {
  open: boolean
  title?: string
  onClose: () => void
}

export function AdInterstitial({ open, title = 'Sponsored', onClose }: Props) {
  const [left, setLeft] = useState(AD_SECONDS)

  useEffect(() => {
    if (!open) {
      setLeft(AD_SECONDS)
      return
    }
    setLeft(AD_SECONDS)
    const t = setInterval(() => {
      setLeft((s) => {
        if (s <= 1) {
          clearInterval(t)
          return 0
        }
        return s - 1
      })
    }, 1000)
    return () => clearInterval(t)
  }, [open])

  if (!open) return null

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/70 p-4 backdrop-blur-sm">
      <div className="w-full max-w-md rounded-2xl border border-slate-200 bg-white p-6 shadow-xl">
        <p className="text-xs font-semibold uppercase tracking-wide text-teal-600">{title}</p>
        <div className="mt-4 flex h-36 items-center justify-center rounded-xl bg-gradient-to-br from-teal-50 to-cyan-100 text-slate-600">
          <span className="text-center text-sm">
            Demo ad placement
            <br />
            <span className="text-xs text-slate-500">Replace with your ad SDK or house promo</span>
          </span>
        </div>
        <p className="mt-4 text-center text-sm text-slate-600">
          Continue in <span className="font-semibold text-slate-900">{left}</span>s or skip now
        </p>
        <button
          type="button"
          onClick={onClose}
          className="mt-4 w-full rounded-xl bg-slate-900 py-3 text-sm font-medium text-white hover:bg-slate-800"
        >
          Skip ad
        </button>
      </div>
    </div>
  )
}
