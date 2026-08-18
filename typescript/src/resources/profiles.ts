import type { BlogApiClient } from "./client.js";

export interface Profile {
  id: string;
  username: string;
  display_name: string | null;
  bio: string | null;
  avatar_url: string | null;
  stripe_connected: boolean;
  profile_url: string;
  created_at: string;
}

export class ProfilesResource {
  constructor(private readonly client: BlogApiClient) {}

  me(): Promise<Profile> {
    return this.client.get<Profile>("/me");
  }
}
