'use client'

import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase'
import Link from 'next/link'

interface Stats {
  totalTasks: number
  activeTasks: number
  proRequested: number
  completedToday: number
  totalPartners: number
  activePartners: number
}

export default function Dashboard() {
  const [stats, setStats] = useState<Stats | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    loadStats()
  }, [])

  async function loadStats() {
    const supabase = createClient()

    // Get task counts
    const { count: totalTasks } = await supabase
      .from('tasks')
      .select('*', { count: 'exact', head: true })

    const { count: activeTasks } = await supabase
      .from('tasks')
      .select('*', { count: 'exact', head: true })
      .in('status', ['triaging', 'awaiting_decision', 'diy_in_progress', 'pro_requested', 'scheduled'])

    const { count: proRequested } = await supabase
      .from('tasks')
      .select('*', { count: 'exact', head: true })
      .eq('status', 'pro_requested')

    const { count: completedToday } = await supabase
      .from('tasks')
      .select('*', { count: 'exact', head: true })
      .eq('status', 'completed')
      .gte('completed_at', new Date(new Date().setHours(0, 0, 0, 0)).toISOString())

    const { count: totalPartners } = await supabase
      .from('partners')
      .select('*', { count: 'exact', head: true })

    const { count: activePartners } = await supabase
      .from('partners')
      .select('*', { count: 'exact', head: true })
      .eq('is_active', true)

    setStats({
      totalTasks: totalTasks || 0,
      activeTasks: activeTasks || 0,
      proRequested: proRequested || 0,
      completedToday: completedToday || 0,
      totalPartners: totalPartners || 0,
      activePartners: activePartners || 0,
    })

    setLoading(false)
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center h-screen">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    )
  }

  return (
    <div className="p-8">
      <h1 className="text-3xl font-bold mb-8">Dashboard</h1>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mb-8">
        <StatCard
          title="Total Tasks"
          value={stats?.totalTasks || 0}
          icon="📋"
          color="blue"
        />
        <StatCard
          title="Active Tasks"
          value={stats?.activeTasks || 0}
          icon="⚡"
          color="green"
        />
        <StatCard
          title="Pro Requested"
          value={stats?.proRequested || 0}
          icon="👨‍🔧"
          color="orange"
          link="/tasks?status=pro_requested"
        />
        <StatCard
          title="Completed Today"
          value={stats?.completedToday || 0}
          icon="✅"
          color="green"
        />
        <StatCard
          title="Total Partners"
          value={stats?.totalPartners || 0}
          icon="🏢"
          color="purple"
          link="/partners"
        />
        <StatCard
          title="Active Partners"
          value={stats?.activePartners || 0}
          icon="✨"
          color="purple"
        />
      </div>

      {/* Quick Actions */}
      <div className="bg-white rounded-lg shadow p-6">
        <h2 className="text-xl font-semibold mb-4">Quick Actions</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <Link
            href="/tasks?status=pro_requested"
            className="p-4 border-2 border-orange-200 rounded-lg hover:border-orange-400 transition"
          >
            <div className="text-2xl mb-2">🔔</div>
            <div className="font-semibold">Assign Partners</div>
            <div className="text-sm text-gray-600">Review pro requests</div>
          </Link>

          <Link
            href="/partners/new"
            className="p-4 border-2 border-blue-200 rounded-lg hover:border-blue-400 transition"
          >
            <div className="text-2xl mb-2">➕</div>
            <div className="font-semibold">Add Partner</div>
            <div className="text-sm text-gray-600">Onboard new pro</div>
          </Link>

          <Link
            href="/tasks"
            className="p-4 border-2 border-green-200 rounded-lg hover:border-green-400 transition"
          >
            <div className="text-2xl mb-2">📊</div>
            <div className="font-semibold">View All Tasks</div>
            <div className="text-sm text-gray-600">Browse task list</div>
          </Link>

          <Link
            href="/analytics"
            className="p-4 border-2 border-purple-200 rounded-lg hover:border-purple-400 transition"
          >
            <div className="text-2xl mb-2">📈</div>
            <div className="font-semibold">Analytics</div>
            <div className="text-sm text-gray-600">View metrics</div>
          </Link>
        </div>
      </div>
    </div>
  )
}

function StatCard({
  title,
  value,
  icon,
  color,
  link,
}: {
  title: string
  value: number
  icon: string
  color: string
  link?: string
}) {
  const colors = {
    blue: 'bg-blue-50 border-blue-200',
    green: 'bg-green-50 border-green-200',
    orange: 'bg-orange-50 border-orange-200',
    purple: 'bg-purple-50 border-purple-200',
  }

  const card = (
    <div className={`p-6 rounded-lg border-2 ${colors[color as keyof typeof colors]}`}>
      <div className="flex items-center justify-between mb-2">
        <div className="text-2xl">{icon}</div>
        <div className="text-3xl font-bold">{value}</div>
      </div>
      <div className="text-sm font-medium text-gray-700">{title}</div>
    </div>
  )

  if (link) {
    return <Link href={link}>{card}</Link>
  }

  return card
}
