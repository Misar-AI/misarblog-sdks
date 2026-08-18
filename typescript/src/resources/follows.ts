import type { BlogApiClient } from "./client.js";

export interface FollowStatus {
  /** Whether the key's owner follows this profile. */
  isFollowing: boolean;
  followerCount: number;
  followingCount: number;
}

export class FollowsResource {
  constructor(private readonly client: BlogApiClient) {}

  /**
   * GET /follows?user_id=
   *
   * A profile's follower/following counts plus whether the key's owner
   * follows it.
   *
   * Requires an API key like every other operation here — the request is
   * metered against the key's plan and rate-limited to 100 req/min.
   */
  status(userId: string): Promise<FollowStatus> {
    return this.client.get<FollowStatus>(
      `/follows?user_id=${encodeURIComponent(userId)}`
    );
  }
}
