import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { AuthProvider, useAuth } from './context/AuthContext'
import { Layout } from './pages/Layout'
import { Home } from './pages/Home'
import { Login } from './pages/Login'
import { Register } from './pages/Register'
import { TopicDetailPage } from './pages/TopicDetailPage'
import { AdminDashboard } from './pages/AdminDashboard'
import { AdminTopicForm } from './pages/AdminTopicForm'
import { AdminPackages } from './pages/AdminPackages'
import { AdminAds } from './pages/AdminAds'
import { Subscribe } from './pages/Subscribe'
import { PaymentCallback } from './pages/PaymentCallback'

function AdminRoute({ children }: { children: React.ReactNode }) {
  const { user, loading } = useAuth()
  if (loading) return <p className="p-8 text-slate-500">Loading…</p>
  if (!user || user.role !== 'admin') return <Navigate to="/login" replace />
  return <>{children}</>
}

function AppRoutes() {
  return (
    <Routes>
      <Route element={<Layout />}>
        <Route path="/" element={<Home />} />
        <Route path="/topics/:slug" element={<TopicDetailPage />} />
        <Route path="/login" element={<Login />} />
        <Route path="/register" element={<Register />} />
        <Route path="/subscribe" element={<Subscribe />} />
        <Route path="/subscribe/callback" element={<PaymentCallback />} />
        <Route
          path="/admin"
          element={
            <AdminRoute>
              <AdminDashboard />
            </AdminRoute>
          }
        />
        <Route
          path="/admin/new"
          element={
            <AdminRoute>
              <AdminTopicForm />
            </AdminRoute>
          }
        />
        <Route
          path="/admin/edit/:id"
          element={
            <AdminRoute>
              <AdminTopicForm />
            </AdminRoute>
          }
        />
        <Route
          path="/admin/packages"
          element={
            <AdminRoute>
              <AdminPackages />
            </AdminRoute>
          }
        />
        <Route
          path="/admin/ads"
          element={
            <AdminRoute>
              <AdminAds />
            </AdminRoute>
          }
        />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Route>
    </Routes>
  )
}

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <AppRoutes />
      </AuthProvider>
    </BrowserRouter>
  )
}
