import {
  downloadAndUnzipVSCode,
  resolveCliPathFromVSCodeExecutablePath,
  runTests,
} from '@vscode/test-electron'
import { execSync } from 'child_process'
import * as path from 'path'

const packageJson = require('../../package.json')
const extensionDependencies = packageJson.extensionDependencies as string[]

async function main() {
  try {
    const vscodeVersion = process.env.VSCODE_VERSION ?? 'stable'

    const vscodeExecutablePath = await downloadAndUnzipVSCode(vscodeVersion)
    const vscodeCliPath =
      resolveCliPathFromVSCodeExecutablePath(vscodeExecutablePath)

    for (const dep of extensionDependencies) {
      execSync(`"${vscodeCliPath}" --force --install-extension ${dep}`)
    }

    const extensionDevelopmentPath = path.resolve(__dirname, '../../')
    const extensionTestsPath = path.resolve(__dirname, './suite/index')
    const workspacePath = path.resolve(
      __dirname,
      '../../src/test/workspaces/hello_flutter'
    )

    await runTests({
      version: vscodeVersion,
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
