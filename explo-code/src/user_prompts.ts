import { window } from 'vscode'
import {
  ExploDebugSession,
  ExploDebugSessionsCoordinator,
} from './explo_debug_session'

export async function selectExploDebugSession(
  debugSessionCoordinator: ExploDebugSessionsCoordinator
): Promise<ExploDebugSession | undefined> {
  const sessions = debugSessionCoordinator.nonViewerSessions
  if (sessions.length === 0) {
    window.showInformationMessage(
      'Explo: No appropriate debug sessions available'
    )
    return
  }

  if (sessions.length === 1) {
    return sessions[0]
  }

  return window
    .showQuickPick(
      sessions.map((session) => ({
        label: session.label,
        session,
      })),
      {
        title: 'Select debug session',
      }
    )
    .then((selection) => selection && selection.session)
}
