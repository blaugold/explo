import * as assert from 'assert'
import * as vscode from 'vscode'
import { exploViewCommandsSymbol } from '../../api'
import { ExploViewCommands } from '../../explo_view_commands'
import { getPrivateExtensionApi } from '../utils/extension'
import { sleep, waitForResult } from '../utils/testing'

suite('Explo view', () => {
  test('open with command', async () => {
    // Wait for dart extension to discover devices, so it wont show the device
    // picker when starting debugging.
    await sleep(5000)

    // Start debugging.
    await vscode.debug.startDebugging(
      vscode.workspace.workspaceFolders![0],
      'hello_flutter'
    )

    // Open the explo view.
    await vscode.commands.executeCommand('explo.openView')

    // Verify the explo view was opened.
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

    // Wait for explo view to be closed after the debug session is stopped.
    await waitForResult(() => {
      return openViewPanels.size === 0 ? true : undefined
    })
  })
})
