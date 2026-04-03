import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react'
import { me, setAuthToken, type User } from '../lib/api'

const STORAGE_KEY = 'medstudy_token'

type AuthState = {
  user: User | null
  token: string | null
  loading: boolean
  setSession: (token: string | null, user?: User | null) => void
  refreshUser: () => Promise<void>
}

const AuthContext = createContext<AuthState | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null)
  const [token, setToken] = useState<string | null>(() => localStorage.getItem(STORAGE_KEY))
  const [loading, setLoading] = useState(true)

  const refreshUser = useCallback(async () => {
    const t = localStorage.getItem(STORAGE_KEY)
    if (!t) {
      setUser(null)
      setToken(null)
      setAuthToken(null)
      return
    }
    setAuthToken(t)
    try {
      const u = await me()
      setUser(u)
    } catch {
      localStorage.removeItem(STORAGE_KEY)
      setAuthToken(null)
      setUser(null)
      setToken(null)
    }
  }, [])

  useEffect(() => {
    ;(async () => {
      if (token) {
        setAuthToken(token)
        try {
          const u = await me()
          setUser(u)
        } catch {
          localStorage.removeItem(STORAGE_KEY)
          setAuthToken(null)
          setToken(null)
          setUser(null)
        }
      }
      setLoading(false)
    })()
  }, [token])

  const setSession = useCallback((newToken: string | null, u?: User | null) => {
    if (newToken) {
      localStorage.setItem(STORAGE_KEY, newToken)
      setToken(newToken)
      setAuthToken(newToken)
      if (u) setUser(u)
    } else {
      localStorage.removeItem(STORAGE_KEY)
      setToken(null)
      setAuthToken(null)
      setUser(null)
    }
  }, [])

  const value = useMemo(
    () => ({ user, token, loading, setSession, refreshUser }),
    [user, token, loading, setSession, refreshUser]
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth outside AuthProvider')
  return ctx
}
