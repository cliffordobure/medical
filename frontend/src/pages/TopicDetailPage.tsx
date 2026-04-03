import { useEffect, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { fetchTopic, type TopicDetail } from '../lib/api'
import { useAuth } from '../context/AuthContext'
import { PdfWithAds } from '../components/PdfWithAds'
import { AudioWithAds } from '../components/AudioWithAds'

function lessonYear(t: TopicDetail): number {
  const y = t.yearOfStudy
  return typeof y === 'number' && y >= 1 && y <= 6 ? y : 1
}

function lessonTopic(t: TopicDetail): string {
  return (t.topic && t.topic.trim()) || 'General'
}

export function TopicDetailPage() {
  const { slug } = useParams<{ slug: string }>()
  const { user } = useAuth()
  const [topic, setTopic] = useState<TopicDetail | null>(null)
  const [error, setError] = useState<string | null>(null)

  const premium = Boolean(user?.isPremium)

  useEffect(() => {
    if (!slug) return
    fetchTopic(slug)
      .then(setTopic)
      .catch(() => setError('Topic not found or not published.'))
  }, [slug])

  if (error) {
    return (
      <div className="rounded-xl border border-red-200 bg-red-50 p-4 text-red-800">
        {error}{' '}
        <Link to="/" className="font-medium underline">
          Back to library
        </Link>
      </div>
    )
  }

  if (!topic) {
    return <p className="text-slate-500">Loading…</p>
  }

  return (
    <div className="space-y-8">
      <div>
        <Link to="/" className="text-sm font-medium text-teal-700 hover:underline">
          ← Library
        </Link>
        <p className="mt-3 text-xs font-semibold uppercase tracking-wider text-teal-700">
          Year {lessonYear(topic)} · {lessonTopic(topic)}
        </p>
        <h1 className="mt-1 text-2xl font-semibold tracking-tight text-slate-900">{topic.title}</h1>
        {topic.description && <p className="mt-2 text-slate-600">{topic.description}</p>}
      </div>
      <section>
        <h2 className="mb-3 text-lg font-medium text-slate-800">Notes (PDF)</h2>
        <PdfWithAds url={topic.pdfUrl} premium={premium} />
      </section>
      <section>
        <h2 className="mb-3 text-lg font-medium text-slate-800">Audio</h2>
        <AudioWithAds src={topic.audioUrl} premium={premium} title={topic.title} />
      </section>
    </div>
  )
}
