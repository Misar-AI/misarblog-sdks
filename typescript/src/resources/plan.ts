import type { BlogApiClient } from "./client.js";

export interface PlanUsage {
  used?: number;
  limit?: number | null;
  remaining?: number | null;
  resets_at?: string | null;
  [key: string]: unknown;
}

export interface Plan {
  slug: string;
  name?: string;
  usage?: Record<string, PlanUsage>;
  [key: string]: unknown;
}

export interface TrialStatus {
  active?: boolean;
  feature?: string | null;
  expires_at?: string | null;
  [key: string]: unknown;
}

export interface StartTrialOptions {
  /** The feature to start a trial for. */
  feature?: string;
  /** Attribution reference for the upsell funnel. */
  ref?: string;
}

/**
 * The subscription attached to the API key: live plan and quota state, plus
 * the self-serve trial. Read these before an expensive call to avoid a
 * {@link PlanLimitError} round-trip.
 */
export class PlanResource {
  constructor(private readonly client: BlogApiClient) {}

  /** GET /plan — the caller's current plan and per-feature allowances. */
  get(): Promise<Plan> {
    return this.client.get<Plan>("/plan");
  }

  /** GET /trial — whether a self-serve trial is active on this account. */
  trialStatus(): Promise<TrialStatus> {
    return this.client.get<TrialStatus>("/trial");
  }

  /** POST /trial — start a self-serve trial. */
  startTrial(options: StartTrialOptions = {}): Promise<Record<string, unknown>> {
    return this.client.post<Record<string, unknown>>("/trial", options);
  }
}

/**
 * GET /upsell-funnel — per-feature upsell conversion funnel.
 *
 * Platform-admin only; an ordinary creator key receives 403.
 */
export class UpsellResource {
  constructor(private readonly client: BlogApiClient) {}

  funnel(options: { days?: number; feature?: string } = {}): Promise<Record<string, unknown>> {
    const qs = new URLSearchParams();
    if (options.days !== undefined) qs.set("days", String(options.days));
    if (options.feature) qs.set("feature", options.feature);
    const query = qs.toString() ? `?${qs}` : "";
    return this.client.get<Record<string, unknown>>(`/upsell-funnel${query}`);
  }
}
