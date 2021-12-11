import { Disposable, Event, EventEmitter, window } from 'vscode'

export enum LogLevel {
  error = 'error',
  warn = 'warn',
  info = 'info',
  debug = 'debug',
}

const logLevelOrder = [
  LogLevel.error,
  LogLevel.warn,
  LogLevel.info,
  LogLevel.debug,
]

function shouldLogLevel(level: LogLevel, targetLevel: LogLevel) {
  return logLevelOrder.indexOf(level) <= logLevelOrder.indexOf(targetLevel)
}

export interface LogMessage {
  date: Date
  level: LogLevel
  message: string
}

export class Logger {
  private onLogMessageEmitter = new EventEmitter<LogMessage>()

  readonly onLogMessage: Event<LogMessage> = this.onLogMessageEmitter.event

  error(message: string, error?: any) {
    this.log(message, LogLevel.error)
    if (error) {
      this.log(error.message, LogLevel.error)
      if (error.stack) {
        this.log(error.stack, LogLevel.error)
      }
    }
  }

  warn(message: string) {
    this.log(message, LogLevel.warn)
  }

  info(message: string) {
    this.log(message, LogLevel.info)
  }

  debug(message: string) {
    this.log(message, LogLevel.debug)
  }

  private log(message: string, level: LogLevel) {
    this.onLogMessageEmitter.fire({
      date: new Date(),
      level,
      message,
    })
  }
}

export function outputLogging(
  name: string,
  logger: Logger,
  targetLevel: LogLevel
) {
  const outputChannel = window.createOutputChannel(name)

  const loggerDisposable = logger.onLogMessage((logMessage) => {
    if (!shouldLogLevel(logMessage.level, targetLevel)) {
      return
    }

    const message = `${logMessage.date.toLocaleTimeString()} ${formatLogLevel(
      logMessage.level
    )} ${logMessage.message}`
    outputChannel.appendLine(message)
  })

  return Disposable.from(outputChannel, loggerDisposable)
}

export function consoleLogging(logger: Logger) {
  return logger.onLogMessage((message) => {
    console.log(`${formatLogLevel(message.level)} ${message.message}`)
  })
}

function formatLogLevel(level: LogLevel) {
  return `[${level}]`.padEnd(7)
}
