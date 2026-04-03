import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { fetchInterstitialAd } from '../lib/api'

const AD_SECONDS = 30
const SKIP_AFTER_SEC = 10

type Props = {
  open: boolean
  title?: string
  onClose: () => void
}

export function AdInterstitial({ open, title = 'Sponsored', onClose }: Props) {
  const navigate = useNavigate()
  const [left, setLeft] = useState(AD_SECONDS)
  const [elapsed, setElapsed] = useState(0)
  const [imageUrl, setImageUrl] = useState<string | null>(null)
  const [adTitle, setAdTitle] = useState<string | null>(null)

  useEffect(() => {
    if (!open) {
      setLeft(AD_SECONDS)
      setElapsed(0)
      return
    }
    setLeft(AD_SECONDS)
    setElapsed(0)
    let cancelled = false
    fetchInterstitialAd()
      .then((ad) => {
        if (cancelled) return
        setImageUrl(ad?.imageUrl ?? null)
        setAdTitle(ad?.title?.trim() ? ad.title : null)
      })
      .catch(() => {
        if (!cancelled) {
          setImageUrl(null)
          setAdTitle(null)
        }
      })
    const t = setInterval(() => {
      setElapsed((e) => e + 1)
      setLeft((s) => {
        if (s <= 1) {
          clearInterval(t)
          return 0
        }
        return s - 1
      })
    }, 1000)
    return () => {
      cancelled = true
      clearInterval(t)
    }
  }, [open])

  if (!open) return null

  const canSkip = elapsed >= SKIP_AFTER_SEC
  const skipIn = Math.max(0, SKIP_AFTER_SEC - elapsed)

  function goSubscribe() {
    onClose()
    navigate('/subscribe')
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/70 p-4 backdrop-blur-sm">
      <div className="w-full max-w-md rounded-2xl border border-slate-200 bg-white p-6 shadow-xl">
        <p className="text-xs font-semibold uppercase tracking-wide text-teal-600">{title}</p>
        {adTitle && <p className="mt-1 text-sm font-medium text-slate-800">{adTitle}</p>}
        <div className="mt-4 flex h-40 items-center justify-center overflow-hidden rounded-xl bg-gradient-to-br from-teal-50 to-cyan-100">
          {imageUrl ? (
            <img src={imageUrl} alt="" className="max-h-full max-w-full object-contain" />
          ) : (
            <span className="px-4 text-center text-sm text-slate-600">
              House promo
              <br />
              <span className="text-xs text-slate-500">Add images in Admin → Ads</span>
            </span>
          )}
        </div>
        <p className="mt-4 text-center text-sm text-slate-600">
          {canSkip ? (
            <>
              You can skip now · <span className="font-semibold text-slate-900">{left}</span>s left on timer
            </>
          ) : (
            <>
              Skip in <span className="font-semibold text-slate-900">{skipIn}</span>s
            </>
          )}
        </p>
        <button
          type="button"
          onClick={goSubscribe}
          className="mt-4 w-full rounded-xl border-2 border-teal-600 py-3 text-sm font-semibold text-teal-700 hover:bg-teal-50"
        >
          Subscribe — remove ads
        </button>
        {canSkip ? (
          <button
            type="button"
            onClick={onClose}
            className="mt-3 w-full rounded-xl bg-slate-900 py-3 text-sm font-medium text-white hover:bg-slate-800"
          >
            Skip ad
          </button>
        ) : (
          <p className="mt-3 text-center text-xs text-slate-400">Skip appears after {SKIP_AFTER_SEC} seconds</p>
        )}
      </div>
    </div>
  )
}
