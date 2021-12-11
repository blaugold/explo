import { Event } from 'vscode'

export function waitForEvent<T>(
  event: Event<T>,
  predicate: (event: T) => boolean
): Promise<T> {
  return new Promise<T>((resolve) => {
    const disposable = event((e) => {
      if (predicate(e)) {
        disposable.dispose()
        resolve(e)
      }
    })
  })
}
