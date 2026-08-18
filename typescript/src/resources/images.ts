import type { BlogApiClient } from "./client.js";

export type ImageSize = "1024x1024" | "1792x1024" | "1024x1792";

export interface GeneratedImage {
  url: string;
  size?: string;
  [key: string]: unknown;
}

export interface UploadedImage {
  url: string;
  [key: string]: unknown;
}

export class ImagesResource {
  constructor(private readonly client: BlogApiClient) {}

  /**
   * POST /images/generate
   *
   * Generate a cover image via AI and upload it to the CDN. Spends image
   * credits, so a plan without an allowance rejects the call with a
   * {@link PlanLimitError}.
   */
  generate(prompt: string, size?: ImageSize): Promise<GeneratedImage> {
    return this.client.post<GeneratedImage>("/images/generate", {
      prompt,
      ...(size ? { size } : {}),
    });
  }

  /**
   * POST /images/upload
   *
   * Upload an image to the CDN. The API accepts either a JSON payload with a
   * base64 `data` field or a multipart body; this method sends JSON.
   */
  upload(payload: Record<string, unknown>): Promise<UploadedImage> {
    return this.client.post<UploadedImage>("/images/upload", payload);
  }
}
