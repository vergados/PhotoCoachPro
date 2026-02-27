"use client";

/**
 * Photo Coach Pro — Upload Card
 * Name: Jason E Alaounis
 * Email: Philotimo71@gmail.com
 * Company: ALÁON
 *
 * Drag-and-drop or click-to-browse photo upload with image preview.
 */

import { useRef, useState, useCallback } from "react";

interface UploadCardProps {
  file: File | null;
  preview: string | null;
  onFileChange: (f: File | null, preview: string | null) => void;
  busy: boolean;
  onRun: () => void;
  error?: string | null;
}

export function UploadCard({
  file,
  preview,
  onFileChange,
  busy,
  onRun,
  error,
}: UploadCardProps) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [dragging, setDragging] = useState(false);

  const handleFile = useCallback(
    (f: File | null) => {
      if (!f) {
        onFileChange(null, null);
        return;
      }
      const url = URL.createObjectURL(f);
      onFileChange(f, url);
    },
    [onFileChange]
  );

  const handleDrop = useCallback(
    (e: React.DragEvent) => {
      e.preventDefault();
      setDragging(false);
      const f = e.dataTransfer.files[0];
      if (f && f.type.startsWith("image/")) handleFile(f);
    },
    [handleFile]
  );

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault();
    setDragging(true);
  };

  const handleDragLeave = () => setDragging(false);

  const handleClear = (e: React.MouseEvent) => {
    e.stopPropagation();
    if (preview) URL.revokeObjectURL(preview);
    handleFile(null);
    if (inputRef.current) inputRef.current.value = "";
  };

  const canSubmit = !!file && !busy;

  return (
    <div className="space-y-4">
      {/* Drop zone */}
      <div
        onDrop={handleDrop}
        onDragOver={handleDragOver}
        onDragLeave={handleDragLeave}
        onClick={() => !file && inputRef.current?.click()}
        className={[
          "relative flex flex-col items-center justify-center overflow-hidden rounded-2xl border-2 border-dashed transition-all duration-200",
          file
            ? "cursor-default border-zinc-200 bg-zinc-50"
            : "cursor-pointer hover:border-zinc-400 hover:bg-zinc-50",
          dragging
            ? "scale-[1.01] border-zinc-600 bg-zinc-100"
            : "border-zinc-300",
          preview ? "min-h-56" : "min-h-48",
        ].join(" ")}
      >
        <input
          ref={inputRef}
          type="file"
          accept="image/*"
          className="sr-only"
          onChange={(e) => handleFile(e.target.files?.[0] ?? null)}
        />

        {preview ? (
          <img
            src={preview}
            alt="Preview"
            className="max-h-72 w-full object-contain p-2"
          />
        ) : (
          <div className="flex flex-col items-center gap-3 p-8 text-zinc-400">
            <svg
              className="h-12 w-12 text-zinc-200"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={1.5}
                d="M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.409a2.25 2.25 0 013.182 0l2.909 2.909M3 3h18M3 21h18"
              />
            </svg>
            <div className="text-center">
              <p className="text-sm font-semibold text-zinc-500">
                Drop a photo here
              </p>
              <p className="mt-0.5 text-xs text-zinc-400">
                or click to browse — JPG, PNG, HEIC, WebP
              </p>
            </div>
          </div>
        )}

        {/* Clear button */}
        {file && (
          <button
            className="absolute right-3 top-3 flex h-7 w-7 items-center justify-center rounded-full bg-white/90 text-zinc-500 shadow-sm backdrop-blur-sm transition-colors hover:bg-white hover:text-zinc-900"
            onClick={handleClear}
            title="Remove photo"
          >
            <svg
              className="h-3.5 w-3.5"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2.5}
                d="M6 18L18 6M6 6l12 12"
              />
            </svg>
          </button>
        )}
      </div>

      {/* File info */}
      {file && (
        <p className="text-xs text-zinc-400">
          {file.name}
          <span className="mx-1 text-zinc-300">·</span>
          {(file.size / 1024).toFixed(0)} KB
        </p>
      )}

      {/* Analyze button */}
      <button
        onClick={onRun}
        disabled={!canSubmit}
        className="w-full rounded-xl bg-zinc-900 px-4 py-3 text-sm font-semibold text-white transition-all disabled:cursor-not-allowed disabled:opacity-40 hover:enabled:bg-zinc-700 active:enabled:scale-[0.99]"
      >
        {busy ? (
          <span className="flex items-center justify-center gap-2">
            <svg
              className="h-4 w-4 animate-spin"
              fill="none"
              viewBox="0 0 24 24"
            >
              <circle
                className="opacity-25"
                cx="12"
                cy="12"
                r="10"
                stroke="currentColor"
                strokeWidth="4"
              />
              <path
                className="opacity-75"
                fill="currentColor"
                d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"
              />
            </svg>
            Analyzing…
          </span>
        ) : (
          "Analyze Photo"
        )}
      </button>

      {/* Error */}
      {error && (
        <div className="flex items-start gap-3 rounded-xl border border-red-200 bg-red-50 px-4 py-3">
          <svg
            className="mt-0.5 h-4 w-4 shrink-0 text-red-500"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z"
            />
          </svg>
          <p className="text-sm text-red-700">{error}</p>
        </div>
      )}
    </div>
  );
}
