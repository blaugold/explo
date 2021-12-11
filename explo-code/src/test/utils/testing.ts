export const isCI = process.env.CI !== undefined

export async function sleep(timeout: number) {
  return new Promise((resolve) => setTimeout(resolve, timeout))
}

export async function waitForResult<T = unknown>(
  block: () => Promise<T> | T | undefined,
  timeout: number = 2000,
  waitTime: number = 100
): Promise<T> {
  const start = Date.now()

  while (true) {
    if (Date.now() - start > timeout) {
      throw new Error(`Timed out after ${timeout}ms`)
    }

    const result = await block()
    if (result) {
      return result
    }

    await sleep(waitTime)
  }
}

/**
 * Retry an action, if it does not succeed within a certain time,
 * until a total timeout is reached.
 **/
export async function retryAfterTimeout<T = unknown>(
  options: { timeout: number; delay: number; totalTimeout: number },
  action: () => Thenable<T>,
  cleanup?: (result: T) => void
) {
  const { timeout, delay, totalTimeout } = options
  const start = Date.now()

  while (true) {
    if (Date.now() - start > totalTimeout) {
      throw new Error(`Timed out after ${totalTimeout}ms`)
    }

    let result: T | undefined
    let timedOut = false

    await new Promise<void>((resolve, reject) => {
      const timer = setTimeout(() => {
        timedOut = true
        resolve()
      }, timeout)

      ;(async () => action())().then(
        (value) => {
          if (!timedOut) {
            clearTimeout(timer)
            result = value
            resolve()
          } else {
            cleanup?.(value)
          }
        },
        (error) => {
          if (!timedOut) {
            clearTimeout(timer)
            reject(error)
          }
        }
      )
    })

    if (!timedOut) {
      return result!
    }

    await sleep(delay)
  }
}
