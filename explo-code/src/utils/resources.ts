import { Disposable } from 'vscode'

export function disposeAll(disposables: Disposable[]) {
  Disposable.from(...disposables).dispose()
}
