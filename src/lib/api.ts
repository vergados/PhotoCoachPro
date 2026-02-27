/**
 * Photo Coach Pro — API Client
 * Name: Jason E Alaounis
 * Email: Philotimo71@gmail.com
 * Company: ALÁON
 */

export interface ExifSummary {
  available: boolean;
  has_exif?: boolean;
  error?: string;
  summary?: {
    make?: string | null;
    model?: string | null;
    lens_model?: string | null;
    datetime_original?: string | null;
    iso?: number | null;
    f_number?: number | null;
    exposure_time?: number | null;
    focal_length?: number | null;
    width_px?: number | null;
    height_px?: number | null;
    has_gps?: boolean;
  };
}

export interface MetricResult {
  available?: boolean;
  score_0_100?: number;
  notes?: string[];
  // Exposure
  brightness_mean_0_255?: number;
  brightness_p05_0_255?: number;
  brightness_p95_0_255?: number;
  dynamic_range_0_255?: number;
  clipped_shadows_pct?: number;
  clipped_highlights_pct?: number;
  // Sharpness
  laplacian_stddev?: number;
  laplacian_variance?: number;
  // Color
  mean_rgb?: number[];
  saturation_mean_0_1?: number;
  saturation_p95_0_1?: number;
  warmth_r_minus_b?: number;
  green_magenta_g_minus_avg_rb?: number;
}

export interface ScoreResult {
  overall_0_100: number;
  grade: "A" | "B" | "C" | "D" | "F";
  weights: { exposure: number; sharpness: number; color: number };
  subscores_0_100: { exposure: number; sharpness: number; color: number };
  explain: string[];
}

export interface CritiqueResponse {
  ok: boolean;
  used_core: boolean;
  filename?: string;
  exif?: ExifSummary;
  metrics?: {
    exposure: MetricResult;
    sharpness: MetricResult;
    color: MetricResult;
  };
  score?: ScoreResult;
  // Lightweight fallback shape (when core engine isn't available)
  result?: {
    fallback?: boolean;
    image?: { width: number; height: number; mode?: string };
    exposure?: { brightness_mean_0_255: number; contrast_stddev: number };
    color?: { mean_rgb: number[]; warmth_r_minus_b?: number };
    note?: string;
  };
  detail?: string;
  error?: string;
}

/**
 * POST /api/v1/critique
 *
 * Sends an image file to the backend and returns the full critique result.
 * Always uses a relative URL so it works in both local dev (proxied by Next.js)
 * and production (routed by Vercel to the Python serverless function).
 */
export async function postCritique(file: File): Promise<CritiqueResponse> {
  const form = new FormData();
  form.append("file", file);

  const res = await fetch("/api/v1/critique", {
    method: "POST",
    body: form,
  });

  const json = (await res.json().catch(() => null)) as CritiqueResponse | null;

  if (!res.ok) {
    const msg =
      json?.detail ||
      json?.error ||
      `Request failed: ${res.status} ${res.statusText}`;
    throw new Error(msg);
  }

  return json ?? { ok: false, used_core: false };
}
