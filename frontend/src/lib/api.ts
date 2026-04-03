import axios from 'axios'

/** Public origin of the Express API, no trailing slash (e.g. https://api.example.com). Set in frontend/.env as VITE_API_URL. */
function apiBasePath(): string {
  const raw = import.meta.env.VITE_API_URL?.trim()
  if (raw) return `${raw.replace(/\/$/, '')}/api`
  return '/api'
}

const api = axios.create({
  baseURL: apiBasePath(),
  headers: { 'Content-Type': 'application/json' },
})

/** User-visible message for failed admin / API calls (avoids blaming “file size” on 404, etc.). */
export function formatApiError(error: unknown, fallback: string): string {
  if (!axios.isAxiosError(error)) return fallback
  const status = error.response?.status
  const body = error.response?.data as { error?: string } | undefined
  if (status === 404) {
    return 'Not found (404). The server you are calling does not expose this route yet — push the latest API code and redeploy (e.g. Render), or fix VITE_API_URL.'
  }
  if (body?.error && typeof body.error === 'string') return body.error
  if (status != null) return `Request failed (HTTP ${status}).`
  return error.message || fallback
}

export function setAuthToken(token: string | null) {
  if (token) {
    api.defaults.headers.common.Authorization = `Bearer ${token}`
  } else {
    delete api.defaults.headers.common.Authorization
  }
}

export type User = {
  id: string
  email: string
  role: 'admin' | 'student'
  isPremium: boolean
  premiumExpiresAt: string | null
}

export type TopicList = {
  id: string
  yearOfStudy?: number
  topic?: string
  title: string
  description: string
  slug: string
  sortOrder: number
  isPublished: boolean
  hasPdf: boolean
  hasAudio: boolean
  updatedAt: string
}

export type TopicDetail = TopicList & {
  pdfUrl: string | null
  audioUrl: string | null
}

export async function login(email: string, password: string) {
  const { data } = await api.post<{ token: string; user: User }>('/auth/login', { email, password })
  return data
}

export async function register(email: string, password: string) {
  const { data } = await api.post<{ token: string; user: User }>('/auth/register', { email, password })
  return data
}

export async function me() {
  const { data } = await api.get<{ user: User }>('/auth/me')
  return data.user
}

export async function fetchTopics() {
  const { data } = await api.get<{ topics: TopicList[] }>('/topics')
  return data.topics
}

export async function fetchTopic(slug: string) {
  const { data } = await api.get<{ topic: TopicDetail }>(`/topics/${slug}`)
  return data.topic
}

export async function adminListTopics() {
  const { data } = await api.get<{ topics: TopicDetail[] }>('/admin/topics')
  return data.topics
}

export async function adminCreateTopic(form: FormData) {
  const { data } = await api.post<{ topic: TopicDetail }>('/admin/topics', form, {
    headers: { 'Content-Type': 'multipart/form-data' },
  })
  return data.topic
}

export async function adminUpdateTopic(id: string, form: FormData) {
  const { data } = await api.patch<{ topic: TopicDetail }>(`/admin/topics/${id}`, form, {
    headers: { 'Content-Type': 'multipart/form-data' },
  })
  return data.topic
}

export async function adminDeleteTopic(id: string) {
  await api.delete(`/admin/topics/${id}`)
}

export type PackageInfo = {
  id: string
  key: string
  displayName: string
  description: string
  amountKobo: number
  intervalMonths: number
}

/** [amountKobo] = Paystack minor units (KES cents or NGN kobo). */
export function formatMinorAmount(minor: number, currency: string): string {
  const major = minor / 100
  const c = (currency || 'KES').toUpperCase()
  if (c === 'KES') return `Ksh ${major.toLocaleString(undefined, { maximumFractionDigits: 0 })}`
  if (c === 'NGN') return `₦${major.toLocaleString(undefined, { maximumFractionDigits: 0 })}`
  return `${c} ${major.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
}

export async function fetchPackages() {
  const { data } = await api.get<{
    paystackPublicKey: string
    currency: string
    packages: PackageInfo[]
  }>('/packages')
  return data
}

export async function initializePayment(packageId: string) {
  const { data } = await api.post<{ authorizationUrl: string; reference: string }>(
    '/payments/initialize',
    { packageId }
  )
  return data
}

export async function verifyPayment(reference: string) {
  const { data } = await api.get<{ ok: boolean; user: User }>(`/payments/verify/${encodeURIComponent(reference)}`)
  return data
}

export type AdminPackage = {
  id: string
  key: string
  displayName: string
  description: string
  amountKobo: number
  intervalMonths: number
  paystackPlanCode: string | null
  active: boolean
}

export async function adminListPackages() {
  const { data } = await api.get<{ packages: AdminPackage[]; currency: string }>('/admin/packages')
  return data
}

export async function adminCreatePackage(body: {
  key: string
  displayName: string
  description?: string
  amountKobo: number
  intervalMonths: number
  paystackPlanCode?: string | null
  active?: boolean
}) {
  const { data } = await api.post<{ package: AdminPackage }>('/admin/packages', body)
  return data.package
}

export async function adminUpdatePackage(
  id: string,
  body: Partial<{
    key: string
    displayName: string
    description: string
    amountKobo: number
    intervalMonths: number
    paystackPlanCode: string | null
    active: boolean
  }>
) {
  const { data } = await api.patch<{ package: AdminPackage }>(`/admin/packages/${id}`, body)
  return data.package
}

export async function adminDeletePackage(id: string) {
  await api.delete(`/admin/packages/${id}`)
}

export type AdCreative = {
  id: string
  title: string
  imageUrl: string | null
  sortOrder: number
  active: boolean
}

export async function fetchInterstitialAd() {
  const { data } = await api.get<{ ad: { imageUrl: string | null; title: string } | null }>('/ads/interstitial')
  return data.ad
}

export async function adminListAds() {
  const { data } = await api.get<{ ads: AdCreative[] }>('/admin/ads')
  return data.ads
}

export async function adminCreateAd(form: FormData) {
  const { data } = await api.post<{ ad: AdCreative }>('/admin/ads', form, {
    headers: { 'Content-Type': 'multipart/form-data' },
  })
  return data.ad
}

export async function adminUpdateAd(
  id: string,
  body: { title?: string; sortOrder?: number; active?: boolean }
) {
  const { data } = await api.patch<{ ad: AdCreative }>(`/admin/ads/${id}`, body)
  return data.ad
}

export async function adminReplaceAdImage(id: string, form: FormData) {
  const { data } = await api.post<{ ad: AdCreative }>(`/admin/ads/${id}/image`, form, {
    headers: { 'Content-Type': 'multipart/form-data' },
  })
  return data.ad
}

export async function adminDeleteAd(id: string) {
  await api.delete(`/admin/ads/${id}`)
}

export { api }
