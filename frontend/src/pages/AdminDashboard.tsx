import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { adminDeleteTopic, adminListTopics, type TopicDetail } from '../lib/api'

export function AdminDashboard() {
  const [topics, setTopics] = useState<TopicDetail[]>([])
  const [error, setError] = useState<string | null>(null)

  async function load() {
    try {
      const list = await adminListTopics()
      setTopics(list)
      setError(null)
    } catch {
      setError('Failed to load topics.')
    }
  }

  useEffect(() => {
    load()
  }, [])

  async function remove(id: string) {
    if (!confirm('Delete this topic?')) return
    try {
      await adminDeleteTopic(id)
      await load()
    } catch {
      setError('Delete failed.')
    }
  }

  return (
    <div>
      <div className="flex flex-wrap items-center justify-between gap-4">
        <h1 className="text-2xl font-semibold">Admin — Topics</h1>
        <Link
          to="/admin/new"
          className="rounded-xl bg-teal-600 px-4 py-2 text-sm font-medium text-white hover:bg-teal-700"
        >
          New topic
        </Link>
      </div>
      {error && <p className="mt-4 text-sm text-red-600">{error}</p>}
      <ul className="mt-8 space-y-3">
        {topics.map((t) => (
          <li
            key={t.id}
            className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-slate-200 bg-white p-4"
          >
            <div>
              <p className="font-medium text-slate-900">{t.title}</p>
              <p className="text-xs text-slate-500">
                /topics/{t.slug} · {t.isPublished ? 'Published' : 'Draft'}
              </p>
            </div>
            <div className="flex gap-2">
              <Link
                to={`/admin/edit/${t.id}`}
                className="rounded-lg border border-slate-200 px-3 py-1.5 text-sm hover:bg-slate-50"
              >
                Edit
              </Link>
              <button
                type="button"
                onClick={() => remove(t.id)}
                className="rounded-lg border border-red-200 px-3 py-1.5 text-sm text-red-700 hover:bg-red-50"
              >
                Delete
              </button>
            </div>
          </li>
        ))}
      </ul>
      {topics.length === 0 && !error && (
        <p className="mt-8 text-slate-500">No topics yet. Create one with PDF (required) and optional audio.</p>
      )}
    </div>
  )
}
