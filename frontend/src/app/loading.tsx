/**
 * Photo Coach Pro — Loading UI
 * Name: Jason E Alaounis
 * Email: Philotimo71@gmail.com
 * Company: ALÁON
 */

export default function Loading() {
  return (
    <div className="rounded-2xl border border-zinc-200 p-6 shadow-sm">
      <div className="flex items-center gap-3">
        <div className="h-4 w-4 animate-spin rounded-full border-2 border-zinc-300 border-t-zinc-900" />
        <div className="text-sm text-zinc-700">Loading…</div>
      </div>
    </div>
  );
}