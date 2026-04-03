import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import {
  adminCreatePackage,
  adminDeletePackage,
  adminListPackages,
  adminUpdatePackage,
  formatMinorAmount,
  type AdminPackage,
} from '../lib/api'

export function AdminPackages() {
  const [packages, setPackages] = useState<AdminPackage[]>([])
  const [currency, setCurrency] = useState('KES')
  const [error, setError] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)

  const [form, setForm] = useState({
    key: '',
    displayName: '',
    description: '',
    amountKsh: '',
    intervalMonths: '1',
    active: true,
  })

  async function load() {
    try {
      const data = await adminListPackages()
      setPackages(data.packages)
      setCurrency((data.currency || 'KES').toUpperCase())
      setError(null)
    } catch {
      setError('Failed to load packages.')
    }
  }

  useEffect(() => {
    load()
  }, [])

  async function create(e: React.FormEvent) {
    e.preventDefault()
    const ksh = Number(form.amountKsh)
    if (!form.key.trim() || !form.displayName.trim() || !Number.isFinite(ksh) || ksh <= 0) {
      setError(`Fill key, name, and a valid whole amount (${currency === 'NGN' ? 'NGN' : 'Ksh'}).`)
      return
    }
    setSaving(true)
    try {
      await adminCreatePackage({
        key: form.key.trim(),
        displayName: form.displayName.trim(),
        description: form.description.trim(),
        amountKobo: Math.round(ksh * 100),
        intervalMonths: Number(form.intervalMonths) || 1,
        active: form.active,
      })
      setForm({
        key: '',
        displayName: '',
        description: '',
        amountKsh: '',
        intervalMonths: '1',
        active: true,
      })
      await load()
      setError(null)
    } catch {
      setError('Could not create package (duplicate key?).')
    } finally {
      setSaving(false)
    }
  }

  async function toggleActive(p: AdminPackage) {
    try {
      await adminUpdatePackage(p.id, { active: !p.active })
      await load()
    } catch {
      setError('Update failed.')
    }
  }

  async function remove(id: string) {
    if (!confirm('Delete this package? Students can no longer buy it.')) return
    try {
      await adminDeletePackage(id)
      await load()
    } catch {
      setError('Delete failed.')
    }
  }

  return (
    <div>
      <div className="mb-6 flex flex-wrap items-center justify-between gap-4">
        <h1 className="text-2xl font-semibold">Admin — Subscription packages</h1>
        <Link to="/admin" className="text-sm font-medium text-teal-700 hover:underline">
          ← Topics
        </Link>
      </div>

      {error && <p className="mb-4 text-sm text-red-600">{error}</p>}

      <form
        onSubmit={create}
        className="mb-10 space-y-3 rounded-2xl border border-slate-200 bg-white p-6 shadow-sm"
      >
        <h2 className="text-lg font-medium text-slate-900">New package</h2>
        <div className="grid gap-3 sm:grid-cols-2">
          <label className="block text-sm">
            <span className="text-slate-600">Key (unique id)</span>
            <input
              className="mt-1 w-full rounded-lg border border-slate-200 px-3 py-2"
              value={form.key}
              onChange={(e) => setForm((f) => ({ ...f, key: e.target.value }))}
              placeholder="e.g. premium_monthly"
              required
            />
          </label>
          <label className="block text-sm">
            <span className="text-slate-600">Display name</span>
            <input
              className="mt-1 w-full rounded-lg border border-slate-200 px-3 py-2"
              value={form.displayName}
              onChange={(e) => setForm((f) => ({ ...f, displayName: e.target.value }))}
              placeholder="Premium — 1 month"
              required
            />
          </label>
        </div>
        <label className="block text-sm">
          <span className="text-slate-600">Description</span>
          <textarea
            className="mt-1 w-full rounded-lg border border-slate-200 px-3 py-2"
            rows={2}
            value={form.description}
            onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))}
          />
        </label>
        <div className="grid gap-3 sm:grid-cols-3">
          <label className="block text-sm">
            <span className="text-slate-600">Price (whole {currency === 'NGN' ? 'NGN' : 'Ksh'})</span>
            <input
              type="number"
              min={1}
              step={1}
              className="mt-1 w-full rounded-lg border border-slate-200 px-3 py-2"
              value={form.amountKsh}
              onChange={(e) => setForm((f) => ({ ...f, amountKsh: e.target.value }))}
              required
            />
          </label>
          <label className="block text-sm">
            <span className="text-slate-600">Interval (months)</span>
            <input
              type="number"
              min={1}
              className="mt-1 w-full rounded-lg border border-slate-200 px-3 py-2"
              value={form.intervalMonths}
              onChange={(e) => setForm((f) => ({ ...f, intervalMonths: e.target.value }))}
              required
            />
          </label>
          <label className="mt-6 flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={form.active}
              onChange={(e) => setForm((f) => ({ ...f, active: e.target.checked }))}
            />
            Active (visible on /subscribe)
          </label>
        </div>
        <button
          type="submit"
          disabled={saving}
          className="rounded-xl bg-teal-600 px-4 py-2 text-sm font-medium text-white hover:bg-teal-700 disabled:opacity-50"
        >
          {saving ? 'Saving…' : 'Create package'}
        </button>
      </form>

      <h2 className="mb-3 text-lg font-medium text-slate-900">Existing packages</h2>
      <ul className="space-y-3">
        {packages.map((p) => (
          <li
            key={p.id}
            className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-slate-200 bg-white p-4"
          >
            <div>
              <p className="font-medium text-slate-900">{p.displayName}</p>
              <p className="text-xs text-slate-500">
                {p.key} · {formatMinorAmount(p.amountKobo, currency)} / {p.intervalMonths} mo ·{' '}
                {p.active ? 'Active' : 'Hidden'}
              </p>
            </div>
            <div className="flex gap-2">
              <button
                type="button"
                onClick={() => toggleActive(p)}
                className="rounded-lg border border-slate-200 px-3 py-1.5 text-sm hover:bg-slate-50"
              >
                {p.active ? 'Deactivate' : 'Activate'}
              </button>
              <button
                type="button"
                onClick={() => remove(p.id)}
                className="rounded-lg border border-red-200 px-3 py-1.5 text-sm text-red-700 hover:bg-red-50"
              >
                Delete
              </button>
            </div>
          </li>
        ))}
      </ul>
      {packages.length === 0 && <p className="text-slate-500">No packages yet.</p>}
    </div>
  )
}
