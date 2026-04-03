import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import {
  adminCreateAd,
  adminDeleteAd,
  adminListAds,
  adminReplaceAdImage,
  adminUpdateAd,
  formatApiError,
  type AdCreative,
} from '../lib/api'

export function AdminAds() {
  const [ads, setAds] = useState<AdCreative[]>([])
  const [error, setError] = useState<string | null>(null)
  const [title, setTitle] = useState('')
  const [sortOrder, setSortOrder] = useState('0')
  const [file, setFile] = useState<File | null>(null)
  const [busy, setBusy] = useState(false)

  async function load() {
    try {
      setAds(await adminListAds())
      setError(null)
    } catch (e) {
      setError(formatApiError(e, 'Failed to load ads.'))
    }
  }

  useEffect(() => {
    load()
  }, [])

  async function create(e: React.FormEvent) {
    e.preventDefault()
    if (!file) {
      setError('Choose an image (JPEG, PNG, WebP, or GIF).')
      return
    }
    setBusy(true)
    try {
      const fd = new FormData()
      fd.append('image', file)
      fd.append('title', title.trim())
      fd.append('sortOrder', sortOrder)
      fd.append('active', 'true')
      await adminCreateAd(fd)
      setTitle('')
      setSortOrder('0')
      setFile(null)
      await load()
      setError(null)
    } catch (e) {
      setError(formatApiError(e, 'Upload failed. Check file type and size (max 8 MB).'))
    } finally {
      setBusy(false)
    }
  }

  async function toggle(a: AdCreative) {
    try {
      await adminUpdateAd(a.id, { active: !a.active })
      await load()
    } catch (e) {
      setError(formatApiError(e, 'Update failed.'))
    }
  }

  async function replaceImage(id: string, f: File) {
    setBusy(true)
    try {
      const fd = new FormData()
      fd.append('image', f)
      await adminReplaceAdImage(id, fd)
      await load()
    } catch (e) {
      setError(formatApiError(e, 'Image replace failed.'))
    } finally {
      setBusy(false)
    }
  }

  async function remove(id: string) {
    if (!confirm('Delete this ad?')) return
    try {
      await adminDeleteAd(id)
      await load()
    } catch (e) {
      setError(formatApiError(e, 'Delete failed.'))
    }
  }

  return (
    <div>
      <div className="mb-6 flex flex-wrap items-center justify-between gap-4">
        <h1 className="text-2xl font-semibold">Admin — Interstitial ads</h1>
        <Link to="/admin" className="text-sm font-medium text-teal-700 hover:underline">
          ← Topics
        </Link>
      </div>
      <p className="mb-6 text-sm text-slate-600">
        Images rotate randomly for free users during PDF/audio breaks. Skip unlocks after 10 seconds in the app.
      </p>

      {error && <p className="mb-4 text-sm text-red-600">{error}</p>}

      <form
        onSubmit={create}
        className="mb-10 space-y-3 rounded-2xl border border-slate-200 bg-white p-6 shadow-sm"
      >
        <h2 className="text-lg font-medium text-slate-900">Upload new ad</h2>
        <label className="block text-sm">
          <span className="text-slate-600">Headline (optional)</span>
          <input
            className="mt-1 w-full rounded-lg border border-slate-200 px-3 py-2"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="Sponsored message"
          />
        </label>
        <label className="block text-sm">
          <span className="text-slate-600">Sort order (lower = preferred in list)</span>
          <input
            type="number"
            className="mt-1 w-full rounded-lg border border-slate-200 px-3 py-2"
            value={sortOrder}
            onChange={(e) => setSortOrder(e.target.value)}
          />
        </label>
        <label className="block text-sm">
          <span className="text-slate-600">Image</span>
          <input
            type="file"
            accept="image/jpeg,image/png,image/webp,image/gif"
            className="mt-1 block w-full text-sm"
            onChange={(e) => setFile(e.target.files?.[0] ?? null)}
          />
        </label>
        <button
          type="submit"
          disabled={busy}
          className="rounded-xl bg-teal-600 px-4 py-2 text-sm font-medium text-white hover:bg-teal-700 disabled:opacity-50"
        >
          {busy ? 'Uploading…' : 'Create ad'}
        </button>
      </form>

      <h2 className="mb-3 text-lg font-medium text-slate-900">Library</h2>
      <ul className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {ads.map((a) => (
          <li key={a.id} className="overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm">
            <div className="aspect-video bg-slate-100">
              {a.imageUrl ? (
                <img src={a.imageUrl} alt="" className="h-full w-full object-contain" />
              ) : (
                <div className="flex h-full items-center justify-center text-sm text-slate-400">No image</div>
              )}
            </div>
            <div className="space-y-2 p-3">
              <p className="text-sm font-medium text-slate-900">{a.title || '(no headline)'}</p>
              <p className="text-xs text-slate-500">
                order {a.sortOrder} · {a.active ? 'Active' : 'Off'}
              </p>
              <div className="flex flex-wrap gap-2">
                <button
                  type="button"
                  onClick={() => toggle(a)}
                  className="rounded-lg border border-slate-200 px-2 py-1 text-xs hover:bg-slate-50"
                >
                  {a.active ? 'Deactivate' : 'Activate'}
                </button>
                <label className="cursor-pointer rounded-lg border border-slate-200 px-2 py-1 text-xs hover:bg-slate-50">
                  Replace image
                  <input
                    type="file"
                    accept="image/*"
                    className="hidden"
                    onChange={(e) => {
                      const f = e.target.files?.[0]
                      if (f) replaceImage(a.id, f)
                      e.target.value = ''
                    }}
                  />
                </label>
                <button
                  type="button"
                  onClick={() => remove(a.id)}
                  className="rounded-lg border border-red-200 px-2 py-1 text-xs text-red-700 hover:bg-red-50"
                >
                  Delete
                </button>
              </div>
            </div>
          </li>
        ))}
      </ul>
      {ads.length === 0 && <p className="text-slate-500">No ads yet — app will show a placeholder.</p>}
    </div>
  )
}
