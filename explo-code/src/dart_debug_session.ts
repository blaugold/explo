import { DebugSession } from 'vscode'

/* eslint-disable @typescript-eslint/naming-convention */

// Taken from
// https://github.com/Dart-Code/Dart-Code/blob/6ff314fb7c5d9e440573f1ac636dfd4a42ac52e0/src/shared/enums.ts#L1:13
export enum DebuggerType {
  Dart,
  DartTest,
  Flutter,
  FlutterTest,
  Web,
  WebTest,
}

/* eslint-enable @typescript-eslint/naming-convention */

export function isFlutterDebugSession(session: DebugSession): boolean {
  return (
    session.type === 'dart' &&
    session.configuration.debuggerType === DebuggerType.Flutter
  )
}
