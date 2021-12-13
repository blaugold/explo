import {
  ColorThemeKind,
  commands,
  Disposable,
  ExtensionContext,
  ProgressLocation,
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
import { waitForEvent } from './utils/events'
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

        if (!exploSession.isReady) {
          const sessionIsReady = waitForEvent(
            debugSessionCoordinator.onDidMakeSessionReady,
            (session) => session === exploSession
          )

          let canceled = false
          await window.withProgress(
            {
              title: 'Waiting for debug session to become ready',
              location: ProgressLocation.Notification,
              cancellable: true,
            },
            async (_, cancellation) => {
              cancellation.onCancellationRequested(() => {
                canceled = true
              })
              await sessionIsReady
            }
          )
          if (canceled) {
            return
          }
        }

        this.openExploView(exploSession)

        waitForEvent(
          debugSessionCoordinator.didTerminateSession,
          (session) => session === exploSession
        ).then(() => this.closeExploView(exploSession))
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
      themeMode: vscodeColorThemeKindToExploThemeMode(
        window.activeColorTheme.kind
      ),
    })

    this.openViewPanels.set(session, panel)
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

enum ExploThemeMode {
  light = 'light',
  dark = 'dark',
}

function vscodeColorThemeKindToExploThemeMode(kind: ColorThemeKind) {
  switch (kind) {
    case ColorThemeKind.HighContrast:
    case ColorThemeKind.Dark:
      return ExploThemeMode.dark
    case ColorThemeKind.Light:
      return ExploThemeMode.light
  }
}

function exploWebviewContent({
  baseUri,
  vmServiceUri,
  themeMode,
}: {
  baseUri: string
  vmServiceUri: string
  themeMode: 'light' | 'dark'
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
                vmServiceUri: '${vmServiceUri}',
                themeMode: '${themeMode}'
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
