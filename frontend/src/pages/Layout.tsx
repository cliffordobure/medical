import { Link, Outlet, useNavigate } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'

export function Layout() {
  const { user, setSession } = useAuth()
  const navigate = useNavigate()

  return (
    <div className="min-h-screen bg-slate-50 text-slate-900">
      <header className="border-b border-slate-200 bg-white">
        <div className="mx-auto flex max-w-5xl flex-wrap items-center justify-between gap-3 px-4 py-4">
          <Link to="/" className="text-lg font-semibold text-teal-700">
            MedStudy
          </Link>
          <nav className="flex flex-wrap items-center gap-3 text-sm">
            <Link to="/" className="text-slate-600 hover:text-slate-900">
              Topics
            </Link>
            {user?.role === 'student' && (
              <Link to="/subscribe" className="text-slate-600 hover:text-slate-900">
                Premium
              </Link>
            )}
            {user?.role === 'admin' && (
              <Link to="/admin" className="font-medium text-teal-700 hover:text-teal-800">
                Admin
              </Link>
            )}
            {user ? (
              <>
                <span className="text-slate-400">|</span>
                <span className="text-slate-500">{user.email}</span>
                {user.isPremium && (
                  <span className="rounded-full bg-teal-100 px-2 py-0.5 text-xs font-medium text-teal-800">
                    Premium
                  </span>
                )}
                <button
                  type="button"
                  onClick={() => {
                    setSession(null)
                    navigate('/login')
                  }}
                  className="rounded-lg border border-slate-200 px-3 py-1 hover:bg-slate-50"
                >
                  Log out
                </button>
              </>
            ) : (
              <>
                <Link to="/login" className="rounded-lg border border-slate-200 px-3 py-1 hover:bg-slate-50">
                  Log in
                </Link>
                <Link
                  to="/register"
                  className="rounded-lg bg-teal-600 px-3 py-1 font-medium text-white hover:bg-teal-700"
                >
                  Sign up
                </Link>
              </>
            )}
          </nav>
        </div>
      </header>
      <main className="mx-auto max-w-5xl px-4 py-8">
        <Outlet />
      </main>
    </div>
  )
}
