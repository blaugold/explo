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

export async function sleep(timeout: number) {
  return new Promise((resolve) => setTimeout(resolve, timeout))
}
