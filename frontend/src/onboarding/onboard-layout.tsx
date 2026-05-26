import { Outlet, useLocation } from 'react-router'
import { useAuthAdapter } from '../auth/use-auth-adapter'
import ThemeToggle from '../theme/theme-toggle'

export default function OnboardLayout() {
  const { logout } = useAuthAdapter()
  const { pathname } = useLocation()

  const stepNumber = pathname.endsWith('/billing') ? 2 : 1

  return (
    <main className="flex h-screen flex-col bg-background text-foreground">
      <header className="flex items-center justify-between border-b border-border bg-card px-4 py-2">
        <span className="text-lg font-semibold text-foreground">Engram</span>
        <nav className="flex items-center gap-3" aria-label="Onboarding">
          <p className="text-sm text-muted-foreground">Step {stepNumber} of 2</p>
          <ThemeToggle />
          <button
            type="button"
            onClick={() => logout()}
            className="text-sm text-muted-foreground transition hover:text-foreground"
          >
            Sign out
          </button>
        </nav>
      </header>
      <section className="flex-1 overflow-y-auto">
        <Outlet />
      </section>
    </main>
  )
}
