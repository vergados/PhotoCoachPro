/**
 * Photo Coach Pro — Not Found UI
 * Name: Jason E Alaounis
 * Email: Philotimo71@gmail.com
 * Company: ALÁON
 */

export default function NotFound() {
  return (
    <div className="rounded-2xl border border-zinc-200 p-6 shadow-sm">
      <h2 className="text-base font-semibold">Page not found</h2>
      <p className="mt-2 text-sm text-zinc-600">
        That route doesn’t exist in this app.
      </p>

      <div className="mt-4">
        <a
          href="/"
          className="inline-flex rounded-xl bg-zinc-900 px-4 py-2 text-sm font-medium text-white"
        >
          Go home
        </a>
      </div>
    </div>
  );
}