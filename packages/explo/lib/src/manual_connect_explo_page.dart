import 'package:flutter/material.dart';

import 'explo_page.dart';
import 'theming_utils.dart';
import 'viewer_service_extensions.dart';

/// A widget that presents the [ExploPage] after collecting the VM Service URI
/// of the target app from the user.
class ManualConnectExploPage extends StatefulWidget {
  const ManualConnectExploPage({Key? key}) : super(key: key);

  @override
  _ManualConnectExploPageState createState() => _ManualConnectExploPageState();
}

class _ManualConnectExploPageState extends State<ManualConnectExploPage> {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to App'),
      ),
      body: Center(
        child: Container(
          padding: ThemingConstants.spacingPadding,
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Target apps
              if (targetApps.isNotEmpty) ...[
                const Text('Select an app to connect to:'),
                ThemingConstants.spacer,
                for (final targetApp in targetApps) ...[
                  ElevatedButton(
                    child: Text(targetApp.label),
                    onPressed: () => _connect(targetApp.vmServiceUri),
                  ),
                  ThemingConstants.spacer,
                ],
                ThemingConstants.spacer,
              ],

              // VM Service URI input.
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
                      onChanged: (uri) => setState(() => _uri = uri),
                    ),
                  ),
                  ThemingConstants.spacer,
                  ElevatedButton(
                    child: const Text('Connect'),
                    onPressed: _isValidUri(_uri)
                        ? () => _connect(Uri.parse(_uri!))
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _connect(Uri vmServiceUri) {
    Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (context) {
        return ExploPage(
          vmServiceUri: vmServiceUri,
          onFailedToConnect: () {
            Navigator.of(context).pop();

            ScaffoldMessenger.of(this.context).showSnackBar(
              const SnackBar(
                content: Text('Failed to connect to App'),
                duration: Duration(seconds: 10),
              ),
            );
          },
        );
      },
    ));
  }

  bool _isValidUri(String? uri) {
    if (uri == null) {
      return false;
    }

    try {
      Uri.parse(uri);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _onTargetAppsChanged() {
    setState(() {
      // Rebuild to show the changed list of target apps.
    });
  }
}
