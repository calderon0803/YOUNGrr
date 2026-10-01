/**
 * Gets the newest version of the app and reloads into it: looks for a new
 * service worker, lets it take over and reloads (also after a few seconds in
 * any case, so the page never stays stuck on the old version).
 */
export const reloadToLatestVersion = async ({ waitMs = 4000 } = {}) => {
  let done = false
  const reload = () => {
    if (done) return
    done = true
    window.location.reload()
  }
  setTimeout(reload, waitMs)
  try {
    const registration = await navigator.serviceWorker?.getRegistration()
    if (!registration) return reload()
    navigator.serviceWorker.addEventListener('controllerchange', reload, { once: true })
    await registration.update()
    const worker = registration.waiting ?? registration.installing
    if (!worker) return reload()
    // A worker still installing is told once it has finished.
    if (worker.state === 'installed') worker.postMessage({ type: 'SKIP_WAITING' })
    else worker.addEventListener('statechange', () => worker.state === 'installed' && worker.postMessage({ type: 'SKIP_WAITING' }))
  } catch {
    reload()
  }
}
