import { extensions } from 'vscode'

const exploCodeExtensionIdentifier = 'blaugold.explo-code'

export function getExtension() {
  return extensions.getExtension(exploCodeExtensionIdentifier)!
}

export async function getExtensionApi() {
  const ext = getExtension()
  await ext.activate()
  return ext.exports
}

export async function getPrivateExtensionApi<T>(symbol: any) {
  const exports = await getExtensionApi()
  const api = exports[symbol]
  if (!api) {
    throw new Error(`Could not find private API for ${symbol.description}`)
  }
  return api as T
}
