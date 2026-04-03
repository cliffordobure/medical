import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { fetchTopics, type TopicList } from '../lib/api'

export function Home() {
  const [topics, setTopics] = useState<TopicList[]>([])
  const [err, setErr] = useState<string | null>(null)

  useEffect(() => {
    fetchTopics()
      .then(setTopics)
      .catch(() => setErr('Could not load topics. Is the API running?'))
  }, [])

  if (err) {
    return (
      <div className="rounded-xl border border-amber-200 bg-amber-50 p-4 text-amber-900">
        {err}
      </div>
    )
  }

  return (
    <div>
      <h1 className="text-2xl font-semibold text-slate-900">Study topics</h1>
      <p className="mt-2 max-w-xl text-slate-600">
        Choose a topic to read PDF notes and listen to audio. Students should log in for payments and
        personalized access.
      </p>
      <ul className="mt-8 grid gap-4 sm:grid-cols-2">
        {topics.map((t) => (
          <li key={t.id}>
            <Link
              to={`/topics/${t.slug}`}
              className="block rounded-2xl border border-slate-200 bg-white p-5 shadow-sm transition hover:border-teal-200 hover:shadow-md"
            >
              <h2 className="font-medium text-slate-900">{t.title}</h2>
              {t.description && <p className="mt-2 line-clamp-2 text-sm text-slate-600">{t.description}</p>}
              <p className="mt-3 flex gap-2 text-xs text-slate-500">
                {t.hasPdf && (
                  <span className="rounded bg-slate-100 px-2 py-0.5">PDF</span>
                )}
                {t.hasAudio && (
                  <span className="rounded bg-slate-100 px-2 py-0.5">Audio</span>
                )}
              </p>
            </Link>
          </li>
        ))}
      </ul>
      {topics.length === 0 && <p className="mt-8 text-slate-500">No published topics yet.</p>}
    </div>
  )
}
