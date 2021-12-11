import { runTests } from '@vscode/test-electron'
import * as path from 'path'

async function main() {
  try {
    const extensionDevelopmentPath = path.resolve(__dirname, '../../')
    const extensionTestsPath = path.resolve(__dirname, './suite/index')
    const workspacePath = path.resolve(
      __dirname,
      '../../src/test/workspaces/hello_flutter'
    )

    await runTests({
      extensionDevelopmentPath,
      extensionTestsPath,
      launchArgs: [workspacePath],
      extensionTestsEnv: {
        // eslint-disable-next-line @typescript-eslint/naming-convention
        EXPLO_CODE_DEV_MODE: 'true',
        ...process.env,
      },
    })
  } catch (err) {
    console.error('Failed to run tests')
    process.exit(1)
  }
}

main()
