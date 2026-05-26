import { describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import OnboardBillingPage from './onboard-billing-page'

vi.mock('@paddle/paddle-js', () => ({
  initializePaddle: vi.fn().mockResolvedValue(undefined),
}))

vi.mock('../api/queries', () => ({
  useOnboardingStatus: () => ({
    data: { enabled: true, next_step: 'billing' },
    isLoading: false,
  }),
  useBillingStatus: () => ({
    data: { tier: 'free', active: false, trial_days_remaining: 0, subscription: null },
    isLoading: false,
  }),
  useBillingConfig: () => ({
    data: {
      client_token: 'test_token',
      environment: 'sandbox',
      price_ids: { starter: 'pri_starter', pro: 'pri_pro' },
      customer_email: 'a@b.com',
      custom_data: { user_id: 1 },
    },
  }),
}))

function renderPage() {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  return render(
    <QueryClientProvider client={qc}>
      <MemoryRouter>
        <OnboardBillingPage />
      </MemoryRouter>
    </QueryClientProvider>,
  )
}

describe('OnboardBillingPage', () => {
  it('shows plan selection and a Free badge for a free-tier user', () => {
    renderPage()
    expect(screen.getByText('Free')).toBeInTheDocument()
    expect(screen.getByRole('heading', { name: /choose a plan/i })).toBeInTheDocument()
    expect(screen.getAllByRole('button', { name: /start free trial/i })).toHaveLength(2)
  })
})
