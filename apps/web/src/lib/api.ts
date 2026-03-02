/**
 * Shared API fetch utility
 */
export async function apiFetch<T>(
  url: string,
  options?: RequestInit
): Promise<T> {
  const { headers, ...restOptions } = options || {}
  const res = await fetch(url, {
    ...restOptions,
    headers: { "Content-Type": "application/json", ...headers },
  })

  if (!res.ok) {
    const error = await res.json().catch(() => ({ error: "Unknown error" }))
    throw new Error(error.error || `API error: ${res.status}`)
  }

  return res.json()
}
