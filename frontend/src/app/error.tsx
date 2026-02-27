"use client";

import { useEffect } from "react";

export default function ErrorPage(props: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error(props.error);
  }, [props.error]);

  return (
    <div className="rounded-2xl border border-zinc-200 p-6 shadow-sm">
      <h2 className="text-base font-semibold text-red-700">Something went wrong</h2>
      <p className="mt-2 text-sm text-zinc-700">
        The UI hit an error while rendering. You can try again.
      </p>

      <pre className="mt-4 max-h-[240px] overflow-auto rounded-xl bg-zinc-950 p-4 text-xs text-zinc-100">
        {String(props.error?.message || "Unknown error")}
      </pre>

      <div className="mt-4 flex gap-3">
        <button
          onClick={props.reset}
          className="rounded-xl bg-zinc-900 px-4 py-2 text-sm font-medium text-white"
        >
          Try again
        </button>
      </div>
    </div>
  );
}