import { ExtensionContext } from 'vscode'
import { ExploDebugSessionsCoordinator } from './explo_debug_session'
import { Logger, LogLevel, outputLogging } from './logging'

export function activate(context: ExtensionContext) {
  const logger = new Logger()

  context.subscriptions.push(outputLogging('explo', logger, LogLevel.info))

  //   context.subscriptions.push(consoleLogging(logger))

  const debugSessionCoordinator = new ExploDebugSessionsCoordinator(logger)
  context.subscriptions.push(debugSessionCoordinator)
}

export function deactivate() {}
