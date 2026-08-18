import type { BlogApiClient } from "./client.js";

export interface AnalyticsSummary {
  period_days: number;
  views: number;
  revenue_cents: number;
  revenue_net_cents: number;
  active_subscribers: number;
}

export class AnalyticsResource {
  constructor(private readonly client: BlogApiClient) {}

  summary(days = 30): Promise<AnalyticsSummary> {
    return this.client.get<AnalyticsSummary>(`/analytics?days=${days}`);
  }
}
