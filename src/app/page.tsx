"use client";

/**
 * Photo Coach Pro — Main Page
 * Name: Jason E Alaounis
 * Email: Philotimo71@gmail.com
 * Company: ALÁON
 */

import { useState, useCallback } from "react";
import { UploadCard } from "@/components/uploadcard";
import { ResultCard } from "@/components/resultcard";
import { postCritique } from "@/lib/api";
import type { CritiqueResponse } from "@/lib/api";

export default function Page() {
  const [file, setFile] = useState<File | null>(null);
  const [preview, setPreview] = useState<string | null>(null);
  const [result, setResult] = useState<CritiqueResponse | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleFileChange = useCallback(
    (f: File | null, prev: string | null) => {
      setFile(f);
      setPreview(prev);
      setResult(null);
      setError(null);
    },
    []
  );

  const handleRun = async () => {
    if (!file) return;
    setBusy(true);
    setError(null);
    setResult(null);
    try {
      const data = await postCritique(file);
      setResult(data);
    } catch (e) {
      setError(
        e instanceof Error ? e.message : "Something went wrong. Try again."
      );
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="grid grid-cols-1 gap-10 lg:grid-cols-2">
      {/* Upload column */}
      <section>
        <h2 className="mb-4 text-xs font-semibold uppercase tracking-widest text-zinc-400">
          Upload
        </h2>
        <UploadCard
          file={file}
          preview={preview}
          onFileChange={handleFileChange}
          busy={busy}
          onRun={handleRun}
          error={error}
        />
      </section>

      {/* Results column */}
      <section>
        <h2 className="mb-4 text-xs font-semibold uppercase tracking-widest text-zinc-400">
          Analysis
        </h2>
        <ResultCard data={result} />
      </section>
    </div>
  );
}
