import {
  debug,
  DebugSession,
  DebugSessionCustomEvent,
  Disposable,
  EventEmitter,
  workspace,
} from 'vscode'
import { isFlutterDebugSession } from './dart_debug_session'
import { Logger } from './logging'
import { disposeAll } from './utils/resources'

/**
 * Coordinates debug sessions between apps that are capturing render tree data
 * (target apps) and viewer apps. Viewer apps get notified when the list of
 * target apps changes.
 */
export class ExploDebugSessionsCoordinator implements Disposable {
  constructor(private logger: Logger) {
    this.subscriptions.push(
      debug.onDidStartDebugSession(this.handleSessionStart, this)
    )
    this.subscriptions.push(
      debug.onDidTerminateDebugSession(this.handleSessionEnd, this)
    )
    this.subscriptions.push(
      debug.onDidReceiveDebugSessionCustomEvent(this.handleCustomEvent, this)
    )

    this.subscriptions.push(this.didTerminateSessionEmitter)
  }

  private readonly subscriptions: Disposable[] = []

  readonly activeSession: ExploDebugSession[] = []

  get viewerSessions(): ExploDebugSession[] {
    return this.activeSession.filter((session) => session.isViewerApp)
  }

  get nonViewerSessions(): ExploDebugSession[] {
    return this.activeSession.filter((session) => !session.isViewerApp)
  }

  private onDidMakeSessionReadyEmitter = new EventEmitter<ExploDebugSession>()
  onDidMakeSessionReady = this.onDidMakeSessionReadyEmitter.event

  private didTerminateSessionEmitter = new EventEmitter<ExploDebugSession>()
  didTerminateSession = this.didTerminateSessionEmitter.event

  private handleSessionStart(session: DebugSession) {
    if (!isFlutterDebugSession(session)) {
      return
    }

    const exploSession = new ExploDebugSession(session)
    this.activeSession.push(exploSession)

    this.logger.info(`Debug session started: ${exploSession.label}`)
  }

  private handleSessionEnd(session: DebugSession) {
    const exploSession = this.findExploSession(session)
    if (!exploSession) {
      return
    }

    this.logger.info(`Debug session ended: ${exploSession.label}`)

    this.activeSession.splice(this.activeSession.indexOf(exploSession), 1)

    this.handleExploSessionEnd(exploSession)
    this.didTerminateSessionEmitter.fire(exploSession)
  }

  private handleCustomEvent(event: DebugSessionCustomEvent) {
    const exploSession = this.findExploSession(event.session)
    if (!exploSession) {
      return
    }

    if (event.event === 'dart.debuggerUris') {
      this.logger.info(`Debug session ready: ${exploSession.label}`)

      exploSession.vmServiceUri = event.body.vmServiceUri

      this.handleExploSessionReady(exploSession)
      this.onDidMakeSessionReadyEmitter.fire(exploSession)
    } else if (
      event.event === 'dart.serviceExtensionAdded' &&
      event.body.extensionRPC === 'ext.explo.removeTargetApp'
    ) {
      this.logger.info(`Viewer debug session ready: ${exploSession.label}`)

      exploSession.isolateId = event.body.isolateId
      exploSession.isViewerApp = true

      this.handleViewerSessionReady(exploSession)
    }
  }

  private handleExploSessionReady(session: ExploDebugSession) {
    // Tell viewers that a target app has been added.
    const targetApp = session.targetApp
    for (const viewerSession of this.viewerSessions) {
      if (viewerSession === session) {
        continue
      }

      this.logger.debug(
        `Adding target ${targetApp.label} to ${viewerSession.label}`
      )
      viewerSession.addTargetApp(targetApp)
    }
  }

  private handleExploSessionEnd(session: ExploDebugSession) {
    // Tell viewers that a target app has been removed.
    const targetApp = session.targetApp
    for (const viewerSession of this.viewerSessions) {
      this.logger.debug(
        `Removing target ${targetApp.label} from ${viewerSession.label}`
      )
      viewerSession.removeTargetApp(targetApp)
    }
  }

  private handleViewerSessionReady(session: ExploDebugSession) {
    // Tell other viewers that this is not a target app
    const viewerTargetApp = session.targetApp
    for (const viewerSession of this.viewerSessions) {
      if (viewerSession === session) {
        continue
      }

      this.logger.debug(
        `Removing target ${viewerTargetApp.label} from ${viewerSession.label}`
      )
      viewerSession.removeTargetApp(viewerTargetApp)
    }

    // Send all nonViewerSessions to this new viewer
    for (const nonViewerSession of this.nonViewerSessions) {
      session.addTargetApp(nonViewerSession.targetApp)
    }
  }

  private findExploSession(
    session: DebugSession
  ): ExploDebugSession | undefined {
    return this.activeSession.find((s) => s.session === session)
  }

  dispose() {
    disposeAll(this.subscriptions)
  }
}

export interface TargetApp {
  id: string
  label: string
  vmServiceUri: string
}

export class ExploDebugSession {
  constructor(public readonly session: DebugSession) {
    const program = this.session.configuration.program as string
    this.label = workspace
      .asRelativePath(program)
      .replace(/\/lib\/.*\.dart/g, '')
  }

  readonly label: string

  vmServiceUri?: string

  isolateId?: string

  get isReady(): boolean {
    return this.vmServiceUri !== undefined
  }

  isViewerApp?: boolean

  get targetApp(): TargetApp {
    return {
      id: this.session.id,
      label: this.label,
      vmServiceUri: this.vmServiceUri!,
    }
  }

  addTargetApp(app: TargetApp) {
    return this.makeServiceCall('ext.explo.addTargetApp', {
      app: JSON.stringify(app),
    })
  }

  removeTargetApp(app: TargetApp) {
    return this.makeServiceCall('ext.explo.removeTargetApp', {
      id: app.id,
    })
  }

  private makeServiceCall(method: string, params?: any) {
    params = params || {}
    params.isolateId = this.isolateId
    return this.session.customRequest('callService', { method, params })
  }
}
