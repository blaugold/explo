import 'package:flutter/material.dart';

import 'explo_view.dart';
import 'theming_.dart';
import 'viewer_service_extensions.dart';

/// A widget that presents the [ExploView] after collecting the VM Service URI
/// of the target app from the user.
class ManualConnectExploView extends StatefulWidget {
  const ManualConnectExploView({Key? key, this.themeMode}) : super(key: key);

  final ThemeMode? themeMode;

  @override
  _ManualConnectExploViewState createState() => _ManualConnectExploViewState();
}

class _ManualConnectExploViewState extends State<ManualConnectExploView> {
  Uri? _vmServiceUri;

  @override
  Widget build(BuildContext context) {
    return ExploTheme(
      themeMode: widget.themeMode,
      child: Scaffold(
        body: Builder(builder: (context) {
          final vmServiceUri = _vmServiceUri;
          if (vmServiceUri != null) {
            return ExploView(
              themeMode: widget.themeMode,
              vmServiceUri: vmServiceUri,
              onBack: () => setState(() => _vmServiceUri = null),
              onFailedToConnect: () {
                setState(() => _vmServiceUri = null);

                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to connect to App'),
                    duration: Duration(seconds: 10),
                  ),
                );
              },
            );
          }

          return _ConnectForm(
            onConnect: (uri) => setState(() => _vmServiceUri = uri),
          );
        }),
      ),
    );
  }
}

class _ConnectForm extends StatefulWidget {
  const _ConnectForm({
    Key? key,
    required this.onConnect,
  }) : super(key: key);

  final ValueChanged<Uri> onConnect;

  @override
  __ConnectFormState createState() => __ConnectFormState();
}

class __ConnectFormState extends State<_ConnectForm> {
  String? _uri;

  @override
  void initState() {
    super.initState();
    ensureViewerServiceExtensionsAreRegistered();
    addTargetAppsListener(_onTargetAppsChanged);
  }

  @override
  void dispose() {
    removeTargetAppsListener(_onTargetAppsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        padding: ThemingUtils.spacingPadding,
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ThemingUtils.spacerX(8),
            Text(
              'Connect to app',
              style: Theme.of(context).textTheme.headline4,
            ),

            // VM Service URI input.
            ThemingUtils.spacerX(4),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'VM Service URI',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (uri) => setState(() {
                      _uri = uri.isEmpty ? null : uri;
                    }),
                  ),
                ),
                ThemingUtils.spacer,
                ElevatedButton(
                  child: const Text('Connect'),
                  onPressed: _isValidUri(_uri)
                      ? () => widget.onConnect(Uri.parse(_uri!))
                      : null,
                ),
              ],
            ),

            // Discovered target apps
            ThemingUtils.spacerX(2),
            Text(
              'Discovered apps',
              style: Theme.of(context).textTheme.headline6,
            ),

            ThemingUtils.spacer,
            if (targetApps.isEmpty) const Text('No apps discovered'),

            for (final targetApp in targetApps) ...[
              ElevatedButton(
                child: Text(targetApp.label),
                onPressed: () => widget.onConnect(targetApp.vmServiceUri),
              ),
              ThemingUtils.spacer,
            ],
            ThemingUtils.spacer,
          ],
        ),
      ),
    );
  }

  void _onTargetAppsChanged() {
    setState(() {
      // Rebuild to show the changed list of discovered target apps.
    });
  }
}

bool _isValidUri(String? uri) {
  if (uri == null) {
    return false;
  }

  try {
    final parsedUri = Uri.parse(uri);

    return (parsedUri.scheme == 'http' ||
            parsedUri.scheme == 'https' ||
            parsedUri.scheme == 'ws' ||
            parsedUri.scheme == 'wss') &&
        parsedUri.host.isNotEmpty;
  } catch (_) {
    return false;
  }
}
