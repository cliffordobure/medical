import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { fetchPackages, initializePayment, type PackageInfo } from '../lib/api'
import { useAuth } from '../context/AuthContext'

export function Subscribe() {
  const { user } = useAuth()
  const [packages, setPackages] = useState<PackageInfo[]>([])
  const [error, setError] = useState<string | null>(null)
  const [busyId, setBusyId] = useState<string | null>(null)

  useEffect(() => {
    fetchPackages()
      .then((d) => setPackages(d.packages))
      .catch(() => setError('Could not load packages.'))
  }, [])

  async function pay(pkg: PackageInfo) {
    if (!user) {
      setError('Log in as a student to subscribe.')
      return
    }
    if (user.role !== 'student') {
      setError('Only student accounts can purchase Premium.')
      return
    }
    setBusyId(pkg.id)
    setError(null)
    try {
      const { authorizationUrl } = await initializePayment(pkg.id)
      window.location.href = authorizationUrl
    } catch {
      setError('Could not start payment. Check Paystack keys on the server.')
    } finally {
      setBusyId(null)
    }
  }

  if (!user) {
    return (
      <div className="rounded-xl border border-slate-200 bg-white p-6 text-center">
        <p className="text-slate-700">Log in to upgrade to Premium.</p>
        <Link to="/login" className="mt-4 inline-block font-medium text-teal-700">
          Log in
        </Link>
      </div>
    )
  }

  if (user.isPremium) {
    return (
      <div className="rounded-xl border border-teal-200 bg-teal-50 p-6">
        <h1 className="text-xl font-semibold text-teal-900">You have Premium</h1>
        <p className="mt-2 text-sm text-teal-800">
          Expires:{' '}
          {user.premiumExpiresAt
            ? new Date(user.premiumExpiresAt).toLocaleString()
            : 'Active'}
        </p>
        <Link to="/" className="mt-4 inline-block text-sm font-medium text-teal-800 underline">
          Back to topics
        </Link>
      </div>
    )
  }

  return (
    <div>
      <h1 className="text-2xl font-semibold">Premium</h1>
      <p className="mt-2 max-w-xl text-slate-600">
        Remove ads while reading and listening. Pay securely with Paystack (NGN). Amounts are seeded on the server —
        adjust in MongoDB if needed.
      </p>
      {error && <p className="mt-4 text-sm text-red-600">{error}</p>}
      <ul className="mt-8 grid gap-4 sm:grid-cols-2">
        {packages.map((p) => (
          <li key={p.id} className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
            <h2 className="font-semibold text-slate-900">{p.displayName}</h2>
            {p.description && <p className="mt-2 text-sm text-slate-600">{p.description}</p>}
            <p className="mt-4 text-lg font-medium text-slate-900">
              ₦{(p.amountKobo / 100).toLocaleString()}
              <span className="text-sm font-normal text-slate-500">
                {' '}
                / {p.intervalMonths === 12 ? 'year' : `${p.intervalMonths} mo`}
              </span>
            </p>
            <button
              type="button"
              disabled={busyId === p.id || user.role !== 'student'}
              onClick={() => pay(p)}
              className="mt-4 w-full rounded-xl bg-teal-600 py-3 text-sm font-medium text-white hover:bg-teal-700 disabled:opacity-50"
            >
              {busyId === p.id ? 'Redirecting…' : 'Pay with Paystack'}
            </button>
          </li>
        ))}
      </ul>
    </div>
  )
}
