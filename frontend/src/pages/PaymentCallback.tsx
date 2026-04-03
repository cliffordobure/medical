import { useEffect, useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { verifyPayment } from '../lib/api'
import { useAuth } from '../context/AuthContext'

export function PaymentCallback() {
  const [params] = useSearchParams()
  const reference = params.get('reference') || params.get('trxref')
  const { refreshUser } = useAuth()
  const [status, setStatus] = useState<'loading' | 'ok' | 'err'>('loading')
  const [message, setMessage] = useState('')

  useEffect(() => {
    if (!reference) {
      setStatus('err')
      setMessage('Missing payment reference.')
      return
    }
    ;(async () => {
      try {
        await verifyPayment(reference)
        await refreshUser()
        setStatus('ok')
        setMessage('Payment successful. Premium is now active.')
      } catch {
        setStatus('err')
        setMessage('Could not verify payment. If you were charged, contact support with your reference.')
      }
    })()
  }, [reference, refreshUser])

  return (
    <div className="mx-auto max-w-md rounded-2xl border border-slate-200 bg-white p-8 text-center shadow-sm">
      {status === 'loading' && <p className="text-slate-600">Verifying payment…</p>}
      {status === 'ok' && (
        <>
          <p className="font-medium text-teal-800">{message}</p>
          <Link to="/" className="mt-6 inline-block font-medium text-teal-700 underline">
            Continue to topics
          </Link>
        </>
      )}
      {status === 'err' && (
        <>
          <p className="text-red-700">{message}</p>
          <Link to="/subscribe" className="mt-6 inline-block font-medium text-teal-700 underline">
            Back to Premium
          </Link>
        </>
      )}
    </div>
  )
}
