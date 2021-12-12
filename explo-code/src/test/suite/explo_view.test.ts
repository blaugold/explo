import * as assert from 'assert'
import * as vscode from 'vscode'
import { exploViewCommandsSymbol } from '../../api'
import { ExploViewCommands } from '../../explo_view_commands'
import { getPrivateExtensionApi } from '../utils/extension'
import { isCI, retryAfterTimeout, waitForResult } from '../utils/testing'

suite('Explo view', () => {
  test('open with command', async function () {
    if (isCI) {
      this.skip()
    }

    // Start debugging.
    // Retry to start debugging until the chrom target devices has been discovered
    // and the device picker does not show up anymore.
    await retryAfterTimeout(
      { timeout: 2000, delay: 0, totalTimeout: 20000 },
      () => {
        console.log('Attempting to start debugging')
        return vscode.debug.startDebugging(
          vscode.workspace.workspaceFolders![0],
          'hello_flutter'
        )
      }
    )

    // Open the Explo view.
    await vscode.commands.executeCommand('explo.openView')

    // Verify the Explo view was opened.
    const exploViewCommands = await getPrivateExtensionApi<ExploViewCommands>(
      exploViewCommandsSymbol
    )
    assert.ok(exploViewCommands)

    const openViewPanels = exploViewCommands.openViewPanels

    assert.strictEqual(openViewPanels.size, 1)

    const panel = openViewPanels.values().next().value
    assert.strictEqual(panel.viewType, 'explo')
    assert.strictEqual(panel.title, 'Explo')
    assert.strictEqual(panel.visible, true)

    // Stop debugging.
    await vscode.debug.stopDebugging()

    // Wait for Explo view to be closed after the debug session is stopped.
    await waitForResult(() => {
      return openViewPanels.size === 0 ? true : undefined
    })
  })
})
