import { ExtensionContext } from 'vscode'
import { exploViewCommandsSymbol } from './api'
import { ExploDebugSessionsCoordinator } from './explo_debug_session'
import { ExploViewCommands } from './explo_view_commands'
import { consoleLogging, Logger, LogLevel, outputLogging } from './logging'
import { isDevMode } from './utils/env'

export function activate(context: ExtensionContext) {
  const logger = new Logger()

  context.subscriptions.push(outputLogging('explo', logger, LogLevel.info))

  if (isDevMode) {
    context.subscriptions.push(consoleLogging(logger))
  }

  const debugSessionCoordinator = new ExploDebugSessionsCoordinator(logger)
  context.subscriptions.push(debugSessionCoordinator)

  const exploViewCommands = new ExploViewCommands(
    logger,
    context,
    debugSessionCoordinator
  )
  context.subscriptions.push(exploViewCommands)

  return {
    // Private API exports
    [exploViewCommandsSymbol]: exploViewCommands,
  }
}

export function deactivate() {}
