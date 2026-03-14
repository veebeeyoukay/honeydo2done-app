'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'

export default function Sidebar() {
  const pathname = usePathname()

  const links = [
    { href: '/', label: 'Dashboard', icon: '📊' },
    { href: '/tasks', label: 'Tasks', icon: '📋' },
    { href: '/partners', label: 'Partners', icon: '👥' },
    { href: '/users', label: 'Users', icon: '🏠' },
    { href: '/analytics', label: 'Analytics', icon: '📈' },
  ]

  return (
    <div className="w-64 bg-white shadow-lg">
      <div className="p-6 border-b">
        <h1 className="text-xl font-bold text-gray-800">HoneyDo2Done</h1>
        <p className="text-sm text-gray-600">Admin Panel</p>
      </div>

      <nav className="p-4">
        {links.map((link) => {
          const isActive = pathname === link.href

          return (
            <Link
              key={link.href}
              href={link.href}
              className={`flex items-center gap-3 px-4 py-3 rounded-lg mb-2 transition ${
                isActive
                  ? 'bg-blue-50 text-blue-700 font-semibold'
                  : 'text-gray-700 hover:bg-gray-50'
              }`}
            >
              <span className="text-xl">{link.icon}</span>
              <span>{link.label}</span>
            </Link>
          )
        })}
      </nav>

      <div className="absolute bottom-0 w-64 p-4 border-t">
        <button className="w-full text-left px-4 py-3 text-red-600 hover:bg-red-50 rounded-lg transition">
          🚪 Sign Out
        </button>
      </div>
    </div>
  )
}
