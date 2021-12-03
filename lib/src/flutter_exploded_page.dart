import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart' as vms;
import 'package:vm_service/vm_service_io.dart';

import 'client.dart';
import 'exploded_tree_viewer.dart';
import 'render_object_info.dart';

class _ExplodedAppManager extends ChangeNotifier {
  bool _isConnecting = false;

  bool get isConnection => _isConnecting;

  vms.VmService? _vmService;

  bool get isConnected => _vmService != null;

  RenderObjectInfo? _tree;

  RenderObjectInfo? get tree => _tree;

  List<String> _allTypes = [];

  List<String> get allTypes => List.unmodifiable(_allTypes);

  Timer? _pollingTimer;

  bool get isPolling => _pollingTimer != null;

  Future<void> connectToClient(String uri) async {
    if (_isConnecting) return;

    setState(() {
      _isConnecting = true;
    });

    try {
      _vmService = await vmServiceConnectUri(uri);
      await loadTree();
    } catch (e) {
      print(e);
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  void disconnect() {
    if (isConnected)
      setState(() {
        stopPollingTree();
        _vmService!.dispose();
        _vmService = null;
        _tree = null;
        _allTypes.clear();
      });
  }

  Future<void> loadTree() async {
    _tree = await _vmService!.getRenderObjectInfoTree();

    final nodes = <RenderObjectInfo>[];
    void collectNode(RenderObjectInfo node) {
      nodes.add(node);
      node.children.forEach(collectNode);
    }

    collectNode(_tree!);
    _allTypes = nodes.map((e) => e.type).toSet().toList()..sort();

    notifyListeners();
  }

  void startPollingTree() {
    if (!isPolling)
      setState(() {
        _pollingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
          loadTree();
        });
      });
  }

  void stopPollingTree() {
    if (isPolling)
      setState(() {
        _pollingTimer?.cancel();
        _pollingTimer = null;
      });
  }

  void setState(void Function() cb) {
    cb();
    notifyListeners();
  }
}

class FlutterExplodedPage extends StatefulWidget {
  @override
  _FlutterExplodedPageState createState() => _FlutterExplodedPageState();
}

class _FlutterExplodedPageState extends State<FlutterExplodedPage> {
  @override
  Widget build(BuildContext context) => _ConnectToVmPage();
}

class _ConnectToVmPage extends StatefulWidget {
  @override
  _ConnectToVmPageState createState() => _ConnectToVmPageState();
}

class _ConnectToVmPageState extends State<_ConnectToVmPage> {
  final _appManager = _ExplodedAppManager();
  String? _uri;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _appManager,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text('Connect to App'),
          ),
          body: Stack(
            children: [
              Center(
                child: Container(
                  padding: EdgeInsets.all(20),
                  constraints: BoxConstraints(maxWidth: 500),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: TextFormField(
                          decoration: InputDecoration(
                            labelText: 'VM Service URI',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (uri) => setState(() => _uri = uri),
                        ),
                      ),
                      SizedBox(width: 20),
                      ElevatedButton(
                        child: Text('Connect'),
                        onPressed:
                            (_uri?.isNotEmpty ?? false) ? _connect : null,
                      ),
                    ],
                  ),
                ),
              ),
              if (_appManager.isConnected)
                Center(child: CircularProgressIndicator())
            ],
          ),
        );
      },
    );
  }

  void _connect() async {
    await _appManager.connectToClient(_uri!);

    await Navigator.push(context, MaterialPageRoute(builder: (_) {
      return ExplodedTreeViewerPage(appManager: _appManager);
    }));

    _appManager.disconnect();
  }
}

class ExplodedTreeViewerPage extends StatefulWidget {
  const ExplodedTreeViewerPage({
    required this.appManager,
  });

  final _ExplodedAppManager appManager;

  @override
  ExplodedTreeViewerPageState createState() => ExplodedTreeViewerPageState();
}

class ExplodedTreeViewerPageState extends State<ExplodedTreeViewerPage> {
  static const kDefaultIncludedTypes = [
    'RenderCustomPaint',
    'RenderDecoratedBox',
    'RenderImage',
    'RenderParagraph',
    'RenderPhysicalModel',
    'RenderPhysicalShape',
    'RenderPhysicalShape',
  ];

  List<String> _includedTypes = [];

  @override
  void initState() {
    super.initState();
    _includedTypes.addAll(kDefaultIncludedTypes);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.appManager,
      builder: (context, _) {
        final allTypes = widget.appManager.allTypes;
        return Scaffold(
          appBar: AppBar(
            actions: [
              IconButton(
                icon: Icon(Icons.refresh),
                onPressed: () => widget.appManager.loadTree(),
              ),
              IconButton(
                icon: Icon(
                  widget.appManager.isPolling ? Icons.stop : Icons.play_arrow,
                ),
                onPressed: _toggleAutoRefresh,
              )
            ],
          ),
          body: widget.appManager.tree == null
              ? Center(child: CircularProgressIndicator())
              : Row(
                  children: [
                    Expanded(
                      child: ExplodedTreeViewer(
                        root: widget.appManager.tree!,
                        includedTypes: _includedTypes,
                      ),
                    ),
                    SizedBox(
                      width: 250,
                      child: Column(
                        children: [
                          CheckboxListTile(
                            value: allTypes.length == _includedTypes.length,
                            title: Text('All'),
                            dense: true,
                            onChanged: (all) {
                              setState(() {
                                _includedTypes.clear();

                                if (all!) {
                                  _includedTypes.addAll(allTypes);
                                }
                              });
                            },
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: allTypes.length,
                              itemBuilder: (context, i) {
                                final type = allTypes[i];
                                return CheckboxListTile(
                                  dense: true,
                                  title: Text(
                                    type,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  value: _includedTypes.contains(type),
                                  onChanged: (included) {
                                    setState(() {
                                      if (included!)
                                        _includedTypes.add(type);
                                      else
                                        _includedTypes.remove(type);
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  void _toggleAutoRefresh() {
    if (!widget.appManager.isPolling)
      widget.appManager.startPollingTree();
    else
      widget.appManager.stopPollingTree();
  }
}
