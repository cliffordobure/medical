import { useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { fetchTopics, type TopicList } from '../lib/api'

function topicYear(t: TopicList): number {
  const y = t.yearOfStudy
  return typeof y === 'number' && y >= 1 && y <= 6 ? y : 1
}

function topicModule(t: TopicList): string {
  return (t.topic && t.topic.trim()) || 'General'
}

function sortTopics(list: TopicList[]): TopicList[] {
  return [...list].sort((a, b) => {
    if (topicYear(a) !== topicYear(b)) return topicYear(a) - topicYear(b)
    const m = topicModule(a).localeCompare(topicModule(b))
    if (m !== 0) return m
    if (a.sortOrder !== b.sortOrder) return a.sortOrder - b.sortOrder
    return a.title.localeCompare(b.title)
  })
}

type YearSection = {
  year: number
  modules: { name: string; items: TopicList[] }[]
}

function buildYearSections(list: TopicList[]): YearSection[] {
  const sorted = sortTopics(list)
  const years: YearSection[] = []
  for (const t of sorted) {
    const y = topicYear(t)
    const modName = topicModule(t)
    let ys = years.find((x) => x.year === y)
    if (!ys) {
      ys = { year: y, modules: [] }
      years.push(ys)
    }
    let mod = ys.modules.find((x) => x.name === modName)
    if (!mod) {
      mod = { name: modName, items: [] }
      ys.modules.push(mod)
    }
    mod.items.push(t)
  }
  return years
}

export function Home() {
  const [topics, setTopics] = useState<TopicList[]>([])
  const [err, setErr] = useState<string | null>(null)

  useEffect(() => {
    fetchTopics()
      .then(setTopics)
      .catch(() => setErr('Could not load topics. Is the API running?'))
  }, [])

  const sections = useMemo(() => buildYearSections(topics), [topics])

  if (err) {
    return (
      <div className="rounded-xl border border-amber-200 bg-amber-50 p-4 text-amber-900">
        {err}
      </div>
    )
  }

  return (
    <div>
      <h1 className="text-2xl font-semibold tracking-tight text-slate-900">Library</h1>
      <p className="mt-2 max-w-lg text-slate-600">
        PDF notes and audio by year, topic, and subtopic. Sign in for Premium and your account.
      </p>
      <div className="mt-12 space-y-14">
        {sections.map((ys) => (
          <section key={ys.year}>
            <p className="text-xs font-bold uppercase tracking-[0.2em] text-teal-700">Year {ys.year}</p>
            <div className="mt-6 space-y-10">
              {ys.modules.map((mod) => (
                <div key={`${ys.year}-${mod.name}`}>
                  <h2 className="text-lg font-semibold text-slate-900">{mod.name}</h2>
                  <ul className="mt-4 grid gap-4 sm:grid-cols-2">
                    {mod.items.map((t) => (
                      <li key={t.id}>
                        <Link
                          to={`/topics/${t.slug}`}
                          className="block h-full rounded-2xl border border-slate-200 bg-white p-5 shadow-sm transition hover:border-teal-300 hover:shadow-md"
                        >
                          <h3 className="font-medium text-slate-900">{t.title}</h3>
                          {t.description && (
                            <p className="mt-2 line-clamp-2 text-sm text-slate-600">{t.description}</p>
                          )}
                          <p className="mt-3 flex gap-2 text-xs text-slate-500">
                            {t.hasPdf && (
                              <span className="rounded-md bg-slate-100 px-2 py-0.5">PDF</span>
                            )}
                            {t.hasAudio && (
                              <span className="rounded-md bg-slate-100 px-2 py-0.5">Audio</span>
                            )}
                          </p>
                        </Link>
                      </li>
                    ))}
                  </ul>
                </div>
              ))}
            </div>
          </section>
        ))}
      </div>
      {topics.length === 0 && <p className="mt-10 text-slate-500">No published lessons yet.</p>}
    </div>
  )
}
