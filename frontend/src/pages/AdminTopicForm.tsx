import { useEffect, useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { adminCreateTopic, adminListTopics, adminUpdateTopic } from '../lib/api'

function topicYear(t: { yearOfStudy?: number }) {
  const y = t.yearOfStudy
  return typeof y === 'number' && y >= 1 && y <= 6 ? y : 1
}

function topicModule(t: { topic?: string }) {
  return (t.topic && t.topic.trim()) || 'General'
}

export function AdminTopicForm() {
  const { id } = useParams<{ id?: string }>()
  const navigate = useNavigate()
  const isEdit = Boolean(id)

  const [yearOfStudy, setYearOfStudy] = useState('1')
  const [topic, setTopic] = useState('General')
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [sortOrder, setSortOrder] = useState('0')
  const [isPublished, setIsPublished] = useState(true)
  const [pdfFile, setPdfFile] = useState<File | null>(null)
  const [audioFile, setAudioFile] = useState<File | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  useEffect(() => {
    if (!id) return
    ;(async () => {
      try {
        const list = await adminListTopics()
        const t = list.find((x) => x.id === id)
        if (!t) {
          setError('Topic not found')
          return
        }
        setYearOfStudy(String(topicYear(t)))
        setTopic(topicModule(t))
        setTitle(t.title)
        setDescription(t.description || '')
        setSortOrder(String(t.sortOrder))
        setIsPublished(t.isPublished)
      } catch {
        setError('Failed to load topic')
      }
    })()
  }, [id])

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError(null)
    setBusy(true)
    try {
      const fd = new FormData()
      fd.append('yearOfStudy', yearOfStudy)
      fd.append('topic', topic.trim() || 'General')
      fd.append('title', title)
      fd.append('description', description)
      fd.append('sortOrder', sortOrder)
      fd.append('isPublished', String(isPublished))
      if (pdfFile) fd.append('pdf', pdfFile)
      if (audioFile) fd.append('audio', audioFile)

      if (isEdit && id) {
        await adminUpdateTopic(id, fd)
      } else {
        if (!pdfFile) {
          setError('PDF file is required for new topics.')
          setBusy(false)
          return
        }
        await adminCreateTopic(fd)
      }
      navigate('/admin')
    } catch (ex: unknown) {
      const msg =
        typeof ex === 'object' && ex && 'response' in ex
          ? (ex as { response?: { data?: { error?: string } } }).response?.data?.error
          : null
      setError(msg || 'Save failed.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="mx-auto max-w-lg">
      <Link to="/admin" className="text-sm font-medium text-teal-700 hover:underline">
        ← Admin
      </Link>
      <h1 className="mt-2 text-2xl font-semibold">{isEdit ? 'Edit lesson' : 'New lesson'}</h1>
      <p className="mt-1 text-sm text-slate-600">
        Order: year of study → topic (subject) → subtopic (this lesson).
      </p>
      <form onSubmit={onSubmit} className="mt-6 space-y-4 rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
        <div>
          <label className="block text-sm font-medium text-slate-700">Year of study</label>
          <select
            value={yearOfStudy}
            onChange={(e) => setYearOfStudy(e.target.value)}
            className="mt-1 w-full rounded-lg border border-slate-200 px-3 py-2"
          >
            {[1, 2, 3, 4, 5, 6].map((y) => (
              <option key={y} value={String(y)}>
                Year {y}
              </option>
            ))}
          </select>
        </div>
        <div>
          <label className="block text-sm font-medium text-slate-700">Topic (subject / module)</label>
          <input
            required
            value={topic}
            onChange={(e) => setTopic(e.target.value)}
            placeholder="e.g. Cardiology"
            className="mt-1 w-full rounded-lg border border-slate-200 px-3 py-2"
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-slate-700">Subtopic (lesson title)</label>
          <input
            required
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            className="mt-1 w-full rounded-lg border border-slate-200 px-3 py-2"
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-slate-700">Description</label>
          <textarea
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            rows={3}
            className="mt-1 w-full rounded-lg border border-slate-200 px-3 py-2"
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-slate-700">Sort order</label>
          <input
            type="number"
            value={sortOrder}
            onChange={(e) => setSortOrder(e.target.value)}
            className="mt-1 w-full rounded-lg border border-slate-200 px-3 py-2"
          />
        </div>
        <label className="flex items-center gap-2 text-sm">
          <input type="checkbox" checked={isPublished} onChange={(e) => setIsPublished(e.target.checked)} />
          Published (visible to students)
        </label>
        <div>
          <label className="block text-sm font-medium text-slate-700">
            PDF {!isEdit && <span className="text-red-600">*</span>}
          </label>
          <input
            type="file"
            accept="application/pdf,.pdf"
            onChange={(e) => setPdfFile(e.target.files?.[0] ?? null)}
            className="mt-1 w-full text-sm"
          />
          {isEdit && <p className="mt-1 text-xs text-slate-500">Leave empty to keep current PDF.</p>}
        </div>
        <div>
          <label className="block text-sm font-medium text-slate-700">Audio (optional)</label>
          <input
            type="file"
            accept="audio/*,.mp3,.wav,.m4a"
            onChange={(e) => setAudioFile(e.target.files?.[0] ?? null)}
            className="mt-1 w-full text-sm"
          />
          {isEdit && <p className="mt-1 text-xs text-slate-500">Leave empty to keep current audio.</p>}
        </div>
        {error && <p className="text-sm text-red-600">{error}</p>}
        <button
          type="submit"
          disabled={busy}
          className="w-full rounded-xl bg-teal-600 py-3 font-medium text-white hover:bg-teal-700 disabled:opacity-60"
        >
          {busy ? 'Saving…' : 'Save'}
        </button>
      </form>
    </div>
  )
}
