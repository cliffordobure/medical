import { useCallback, useEffect, useRef, useState } from 'react'
import { AdInterstitial } from './AdInterstitial'

const FIRST_AD_AFTER_SEC = 60
const AD_EVERY_SEC = 180

type Props = {
  src: string | null
  premium: boolean
  title: string
}

export function AudioWithAds({ src, premium, title }: Props) {
  const ref = useRef<HTMLAudioElement>(null)
  const [adOpen, setAdOpen] = useState(false)
  const playedSinceLastAdRef = useRef(0)
  const nextThresholdRef = useRef(FIRST_AD_AFTER_SEC)
  const lastTimeRef = useRef(0)
  const pendingRef = useRef(false)

  const checkThreshold = useCallback(() => {
    if (premium || !src) return
    if (playedSinceLastAdRef.current >= nextThresholdRef.current) {
      pendingRef.current = true
      const el = ref.current
      if (el && !el.paused) el.pause()
      setAdOpen(true)
    }
  }, [premium, src])

  useEffect(() => {
    playedSinceLastAdRef.current = 0
    nextThresholdRef.current = FIRST_AD_AFTER_SEC
    lastTimeRef.current = 0
  }, [src, premium])

  useEffect(() => {
    const el = ref.current
    if (!el || premium || !src) return

    const onTime = () => {
      const t = el.currentTime
      const prev = lastTimeRef.current
      if (t > prev && !adOpen) {
        playedSinceLastAdRef.current += t - prev
      }
      lastTimeRef.current = t
      checkThreshold()
    }

    const onPlay = () => {
      lastTimeRef.current = el.currentTime
    }

    el.addEventListener('timeupdate', onTime)
    el.addEventListener('play', onPlay)
    return () => {
      el.removeEventListener('timeupdate', onTime)
      el.removeEventListener('play', onPlay)
    }
  }, [src, premium, adOpen, checkThreshold])

  const closeAd = () => {
    setAdOpen(false)
    playedSinceLastAdRef.current = 0
    nextThresholdRef.current = AD_EVERY_SEC
    pendingRef.current = false
    const el = ref.current
    if (el) void el.play().catch(() => {})
  }

  if (!src) {
    return <p className="text-sm text-slate-500">No audio uploaded for this topic yet.</p>
  }

  return (
    <div className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
      <p className="text-sm font-medium text-slate-800">{title}</p>
      {!premium && (
        <p className="mt-1 text-xs text-slate-500">
          Free: short ads after 1 min, then every 3 min of listening. Premium removes ads.
        </p>
      )}
      <audio ref={ref} className="mt-3 w-full" controls src={src} preload="metadata">
        <track kind="captions" />
      </audio>
      <AdInterstitial open={adOpen} title="Audio break" onClose={closeAd} />
    </div>
  )
}
