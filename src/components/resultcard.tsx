"use client";

/**
 * Photo Coach Pro — Result Card
 * Name: Jason E Alaounis
 * Email: Philotimo71@gmail.com
 * Company: ALÁON
 *
 * Full-featured results display: score ring, grade badge, three metric cards
 * with progress bars + notes, collapsible EXIF panel, and lightweight fallback.
 */

import { useState } from "react";
import type {
  CritiqueResponse,
  ExifSummary,
  MetricResult,
  ScoreResult,
} from "@/lib/api";

// ─────────────────────────────────────────────
// Color helpers
// ─────────────────────────────────────────────

function scoreColor(score: number): string {
  if (score >= 80) return "#22c55e"; // green
  if (score >= 65) return "#3b82f6"; // blue
  if (score >= 50) return "#eab308"; // yellow
  if (score >= 35) return "#f97316"; // orange
  return "#ef4444";                  // red
}

function gradeBadgeClass(grade: string): string {
  switch (grade) {
    case "A": return "bg-green-50 text-green-700 border-green-200";
    case "B": return "bg-blue-50 text-blue-700 border-blue-200";
    case "C": return "bg-yellow-50 text-yellow-700 border-yellow-200";
    case "D": return "bg-orange-50 text-orange-700 border-orange-200";
    default:  return "bg-red-50 text-red-700 border-red-200";
  }
}

function scoreLabel(score: number): string {
  if (score >= 93) return "Outstanding — publication quality.";
  if (score >= 85) return "Great shot — strong technical execution.";
  if (score >= 75) return "Solid image — minor improvements available.";
  if (score >= 65) return "Good effort — some technical issues to address.";
  if (score >= 50) return "Needs work — review the notes below.";
  return "Significant issues — consider a reshoot.";
}

// ─────────────────────────────────────────────
// Score Ring (SVG)
// ─────────────────────────────────────────────

function ScoreRing({ score, size = 120 }: { score: number; size?: number }) {
  const cx = size / 2;
  const cy = size / 2;
  const r = size / 2 - 10;
  const circumference = 2 * Math.PI * r;
  const clamped = Math.min(100, Math.max(0, score));
  const offset = circumference - (clamped / 100) * circumference;
  const color = scoreColor(score);

  return (
    <svg
      width={size}
      height={size}
      viewBox={`0 0 ${size} ${size}`}
      aria-label={`Score ${Math.round(score)} out of 100`}
    >
      {/* Track */}
      <circle
        cx={cx}
        cy={cy}
        r={r}
        fill="none"
        stroke="#e4e4e7"
        strokeWidth="9"
      />
      {/* Fill */}
      <circle
        cx={cx}
        cy={cy}
        r={r}
        fill="none"
        stroke={color}
        strokeWidth="9"
        strokeDasharray={circumference}
        strokeDashoffset={offset}
        strokeLinecap="round"
        transform={`rotate(-90 ${cx} ${cy})`}
        style={{ transition: "stroke-dashoffset 0.7s cubic-bezier(0.4,0,0.2,1)" }}
      />
      {/* Score number */}
      <text
        x={cx}
        y={cy - 7}
        textAnchor="middle"
        fill="#18181b"
        fontSize="24"
        fontWeight="700"
        fontFamily="system-ui, sans-serif"
      >
        {Math.round(score)}
      </text>
      {/* Label */}
      <text
        x={cx}
        y={cy + 13}
        textAnchor="middle"
        fill="#a1a1aa"
        fontSize="11"
        fontFamily="system-ui, sans-serif"
      >
        / 100
      </text>
    </svg>
  );
}

// ─────────────────────────────────────────────
// Score Bar
// ─────────────────────────────────────────────

function ScoreBar({ score }: { score: number }) {
  return (
    <div className="mt-2 h-1.5 w-full overflow-hidden rounded-full bg-zinc-100">
      <div
        className="h-1.5 rounded-full transition-all duration-700"
        style={{
          width: `${Math.max(2, Math.min(100, score))}%`,
          backgroundColor: scoreColor(score),
        }}
      />
    </div>
  );
}

// ─────────────────────────────────────────────
// Metric Card
// ─────────────────────────────────────────────

function MetricCard({
  label,
  icon,
  metric,
}: {
  label: string;
  icon: React.ReactNode;
  metric: MetricResult;
}) {
  const score = metric.score_0_100 ?? 0;

  return (
    <div className="rounded-xl border border-zinc-100 bg-white p-4 shadow-sm">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2 text-sm font-semibold text-zinc-700">
          {icon}
          {label}
        </div>
        <span
          className="text-sm font-bold tabular-nums"
          style={{ color: scoreColor(score) }}
        >
          {Math.round(score)}
        </span>
      </div>

      <ScoreBar score={score} />

      {metric.notes && metric.notes.length > 0 && (
        <ul className="mt-3 space-y-1.5">
          {metric.notes.map((note, i) => (
            <li key={i} className="flex items-start gap-2 text-xs text-zinc-600">
              <span
                className="mt-1.5 h-1 w-1 shrink-0 rounded-full bg-zinc-300"
                aria-hidden="true"
              />
              {note}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

// ─────────────────────────────────────────────
// EXIF Panel
// ─────────────────────────────────────────────

function formatShutter(v: number): string {
  if (v >= 1) return `${v}s`;
  const denom = Math.round(1 / v);
  return `1/${denom}s`;
}

function ExifPanel({ exif }: { exif: ExifSummary }) {
  const [open, setOpen] = useState(false);

  if (!exif.available || !exif.has_exif || !exif.summary) return null;

  const s = exif.summary;

  const rows: [string, string | null | undefined][] = [
    [
      "Camera",
      s.make && s.model
        ? `${s.make} ${s.model}`
        : s.model ?? s.make ?? null,
    ],
    ["Lens", s.lens_model ?? null],
    [
      "Focal Length",
      s.focal_length != null ? `${Number(s.focal_length).toFixed(0)} mm` : null,
    ],
    [
      "Aperture",
      s.f_number != null ? `ƒ/${Number(s.f_number).toFixed(1)}` : null,
    ],
    [
      "Shutter",
      s.exposure_time != null
        ? formatShutter(Number(s.exposure_time))
        : null,
    ],
    ["ISO", s.iso != null ? String(s.iso) : null],
    [
      "Resolution",
      s.width_px && s.height_px
        ? `${s.width_px} × ${s.height_px} px`
        : null,
    ],
    ["Captured", s.datetime_original ?? null],
    ["GPS", s.has_gps ? "Yes" : null],
  ].filter((r): r is [string, string] => !!r[1]);

  if (rows.length === 0) return null;

  return (
    <div className="overflow-hidden rounded-xl border border-zinc-100 bg-white shadow-sm">
      <button
        className="flex w-full items-center justify-between px-4 py-3 text-sm font-semibold text-zinc-700 transition-colors hover:bg-zinc-50"
        onClick={() => setOpen((o) => !o)}
      >
        <span className="flex items-center gap-2">
          <svg
            className="h-4 w-4 text-zinc-400"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M3 9a2 2 0 012-2h.93a2 2 0 001.664-.89l.812-1.22A2 2 0 0110.07 4h3.86a2 2 0 011.664.89l.812 1.22A2 2 0 0018.07 7H19a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V9z"
            />
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M15 13a3 3 0 11-6 0 3 3 0 016 0z"
            />
          </svg>
          Camera Data
        </span>
        <svg
          className={`h-4 w-4 text-zinc-400 transition-transform duration-200 ${
            open ? "rotate-180" : ""
          }`}
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M19 9l-7 7-7-7"
          />
        </svg>
      </button>

      {open && (
        <div className="border-t border-zinc-100 px-4 py-4">
          <dl className="grid grid-cols-2 gap-x-6 gap-y-3">
            {rows.map(([label, value]) => (
              <div key={label}>
                <dt className="text-xs text-zinc-400">{label}</dt>
                <dd className="mt-0.5 text-xs font-semibold text-zinc-800">
                  {value}
                </dd>
              </div>
            ))}
          </dl>
        </div>
      )}
    </div>
  );
}

// ─────────────────────────────────────────────
// Fallback Result (lightweight mode)
// ─────────────────────────────────────────────

function FallbackResult({ data }: { data: CritiqueResponse }) {
  const r = data.result;

  return (
    <div className="space-y-3">
      <div className="flex items-start gap-3 rounded-xl border border-amber-200 bg-amber-50 px-4 py-3">
        <svg
          className="mt-0.5 h-4 w-4 shrink-0 text-amber-500"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
          />
        </svg>
        <p className="text-sm text-amber-800">
          Running in lightweight mode — full core engine unavailable. Basic
          pixel-level metrics shown below.
        </p>
      </div>

      {r?.image && (
        <div className="rounded-xl border border-zinc-100 bg-white p-4 shadow-sm">
          <p className="text-xs font-semibold uppercase tracking-wide text-zinc-400">
            Image
          </p>
          <p className="mt-1 text-sm text-zinc-800">
            {r.image.width} × {r.image.height} px
          </p>
        </div>
      )}

      {r?.exposure && (
        <div className="rounded-xl border border-zinc-100 bg-white p-4 shadow-sm">
          <p className="text-xs font-semibold uppercase tracking-wide text-zinc-400">
            Exposure
          </p>
          <p className="mt-1 text-sm text-zinc-800">
            Brightness: {r.exposure.brightness_mean_0_255} / 255
          </p>
          <p className="text-sm text-zinc-800">
            Contrast (std dev): {r.exposure.contrast_stddev}
          </p>
        </div>
      )}

      {r?.color && (
        <div className="rounded-xl border border-zinc-100 bg-white p-4 shadow-sm">
          <p className="text-xs font-semibold uppercase tracking-wide text-zinc-400">
            Color
          </p>
          {r.color.mean_rgb && (
            <p className="mt-1 text-sm text-zinc-800">
              Mean RGB — R {r.color.mean_rgb[0]} · G {r.color.mean_rgb[1]} · B{" "}
              {r.color.mean_rgb[2]}
            </p>
          )}
          {r.color.warmth_r_minus_b != null && (
            <p className="text-sm text-zinc-800">
              Warmth (R−B): {r.color.warmth_r_minus_b}
            </p>
          )}
        </div>
      )}
    </div>
  );
}

// ─────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────

function EmptyState() {
  return (
    <div className="flex min-h-52 flex-col items-center justify-center rounded-2xl border-2 border-dashed border-zinc-200 p-8 text-center">
      <svg
        className="mb-3 h-10 w-10 text-zinc-200"
        fill="none"
        viewBox="0 0 24 24"
        stroke="currentColor"
      >
        <path
          strokeLinecap="round"
          strokeLinejoin="round"
          strokeWidth={1.5}
          d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"
        />
      </svg>
      <p className="text-sm font-semibold text-zinc-400">
        Analysis will appear here
      </p>
      <p className="mt-1 text-xs text-zinc-300">
        Upload a photo and click Analyze Photo
      </p>
    </div>
  );
}

// ─────────────────────────────────────────────
// Icons
// ─────────────────────────────────────────────

function SunIcon() {
  return (
    <svg
      className="h-4 w-4 text-amber-400"
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
    >
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={2}
        d="M12 3v1m0 16v1m8.66-9h-1M4.34 12h-1m15.07-6.07l-.71.71M6.34 17.66l-.71.71m12.73 0l-.71-.71M6.34 6.34l-.71-.71M12 8a4 4 0 100 8 4 4 0 000-8z"
      />
    </svg>
  );
}

function FocusIcon() {
  return (
    <svg
      className="h-4 w-4 text-blue-400"
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
    >
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={2}
        d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
      />
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={2}
        d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"
      />
    </svg>
  );
}

function PaletteIcon() {
  return (
    <svg
      className="h-4 w-4 text-purple-400"
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
    >
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={2}
        d="M7 21a4 4 0 01-4-4V5a2 2 0 012-2h4a2 2 0 012 2v12a4 4 0 01-4 4zm0 0h12a2 2 0 002-2v-4a2 2 0 00-2-2h-2.343M11 7.343l1.657-1.657a2 2 0 012.828 0l2.829 2.829a2 2 0 010 2.828l-8.486 8.485M7 17h.01"
      />
    </svg>
  );
}

// ─────────────────────────────────────────────
// Main Export
// ─────────────────────────────────────────────

export function ResultCard({ data }: { data: CritiqueResponse | null }) {
  if (!data) return <EmptyState />;

  // Lightweight fallback mode (core engine unavailable)
  if (!data.used_core) return <FallbackResult data={data} />;

  const { score, metrics, exif } = data;

  // If core said used_core but something is missing, render fallback
  if (!score || !metrics) return <FallbackResult data={data} />;

  return (
    <div className="space-y-4">
      {/* ── Overall Score ── */}
      <div className="rounded-2xl border border-zinc-100 bg-white p-6 shadow-sm">
        <div className="flex items-center gap-6">
          <ScoreRing score={score.overall_0_100} />

          <div className="min-w-0 flex-1">
            <div className="flex items-center gap-2">
              <span
                className={`inline-flex items-center rounded-lg border px-3 py-1 text-xl font-bold ${gradeBadgeClass(
                  score.grade
                )}`}
              >
                {score.grade}
              </span>
              <span className="text-sm text-zinc-400">Overall Grade</span>
            </div>

            <p className="mt-2 text-sm text-zinc-600">
              {scoreLabel(score.overall_0_100)}
            </p>

            <div className="mt-3 flex flex-wrap gap-x-4 gap-y-1 text-xs text-zinc-400">
              <span>
                Exposure{" "}
                <strong className="text-zinc-600">
                  {Math.round(score.subscores_0_100.exposure)}
                </strong>
              </span>
              <span aria-hidden="true">·</span>
              <span>
                Sharpness{" "}
                <strong className="text-zinc-600">
                  {Math.round(score.subscores_0_100.sharpness)}
                </strong>
              </span>
              <span aria-hidden="true">·</span>
              <span>
                Color{" "}
                <strong className="text-zinc-600">
                  {Math.round(score.subscores_0_100.color)}
                </strong>
              </span>
            </div>
          </div>
        </div>
      </div>

      {/* ── Metric Cards ── */}
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
        <MetricCard
          label="Exposure"
          icon={<SunIcon />}
          metric={metrics.exposure}
        />
        <MetricCard
          label="Sharpness"
          icon={<FocusIcon />}
          metric={metrics.sharpness}
        />
        <MetricCard
          label="Color"
          icon={<PaletteIcon />}
          metric={metrics.color}
        />
      </div>

      {/* ── EXIF ── */}
      {exif && <ExifPanel exif={exif} />}

      {/* ── File name ── */}
      {data.filename && (
        <p className="text-xs text-zinc-300">{data.filename}</p>
      )}
    </div>
  );
}
