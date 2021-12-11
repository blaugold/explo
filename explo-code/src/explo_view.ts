import {
  commands,
  Disposable,
  ExtensionContext,
  Uri,
  ViewColumn,
  WebviewPanel,
  window,
} from 'vscode'
import {
  ExploDebugSession,
  ExploDebugSessionsCoordinator,
} from './explo_debug_session'
import { Logger } from './logging'
import { selectExploDebugSession } from './user_prompts'
import { disposeAll } from './utils/resources'

export class ExploViewCommands implements Disposable {
  constructor(
    private logger: Logger,
    private context: ExtensionContext,
    debugSessionCoordinator: ExploDebugSessionsCoordinator
  ) {
    this.disposables.push(
      commands.registerCommand('explo.openView', async () => {
        this.logger.debug('command:explo.openView')

        const exploSession = await selectExploDebugSession(
          debugSessionCoordinator
        )
        if (!exploSession) {
          return
        }

        const panel = this.openExploView(exploSession)

        const disposable = debugSessionCoordinator.didTerminateSession(
          (session) => {
            if (session === exploSession) {
              disposable.dispose()
              this.closeExploView(exploSession)
            }
          }
        )
      })
    )
  }

  private readonly disposables: Disposable[] = []

  readonly openViewPanels = new Map<ExploDebugSession, WebviewPanel>()

  private openExploView(session: ExploDebugSession) {
    this.logger.debug(`openExploView: ${session.label}`)

    const panel = window.createWebviewPanel(
      'explo',
      'Explo',
      ViewColumn.Beside,
      {
        enableScripts: true,
      }
    )

    const baseUri = panel.webview.asWebviewUri(
      Uri.joinPath(this.context.extensionUri, 'dist/explo_ide_view/')
    )

    panel.webview.html = exploWebviewContent({
      baseUri: baseUri.toString(),
      vmServiceUri: session.vmServiceUri!,
    })

    this.openViewPanels.set(session, panel)

    return panel
  }

  private closeExploView(session: ExploDebugSession) {
    this.logger.debug(`closeExploView: ${session.label}`)

    const panel = this.openViewPanels.get(session)
    if (panel) {
      this.openViewPanels.delete(session)
      panel.dispose()
    }
  }

  dispose() {
    disposeAll(this.disposables)
  }
}

function exploWebviewContent({
  baseUri,
  vmServiceUri,
}: {
  baseUri: string
  vmServiceUri: string
}): string {
  return `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
    <base href="${baseUri}">
</head>
<body>
    <script>
        // Prepare browser environment for the view.
        window.explo = {
            config: {
                vmServiceUri: '${vmServiceUri}'
            }
        }

        // Load the Flutter app to start showing the view.
        const scriptTag = document.createElement('script')
        scriptTag.src = 'main.dart.js'
        scriptTag.type = 'application/javascript'
        document.body.append(scriptTag)
    </script>
</body>
</html>
`
}
