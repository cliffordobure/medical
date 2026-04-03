import axios from 'axios'

const api = axios.create({
  baseURL: '/api',
  headers: { 'Content-Type': 'application/json' },
})

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

export async function fetchPackages() {
  const { data } = await api.get<{
    paystackPublicKey: string
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

export { api }
