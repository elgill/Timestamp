import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/custom_button_names_provider.dart';

class ManageButtonNamesScreen extends ConsumerStatefulWidget {
  const ManageButtonNamesScreen({super.key});

  @override
  _ManageButtonNamesScreenState createState() => _ManageButtonNamesScreenState();
}

class _ManageButtonNamesScreenState extends ConsumerState<ManageButtonNamesScreen> {
  final TextEditingController _controller = TextEditingController();

  void _addButtonName() {
    final List<String> currentNames = ref.read(customButtonNamesProvider);
    if (_controller.text.isNotEmpty) {
      setState(() {
        currentNames.add(_controller.text);
        ref.read(customButtonNamesProvider.notifier).setCustomButtonNameList(currentNames);
      });
      _controller.clear();
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    final List<String> currentNames = ref.read(customButtonNamesProvider);
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = currentNames.removeAt(oldIndex);
    currentNames.insert(newIndex, item);
    setState(() {
      ref.read(customButtonNamesProvider.notifier).setCustomButtonNameList(currentNames);
    });
  }

  @override
  Widget build(BuildContext context) {
    final buttonNames = ref.watch(customButtonNamesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Button Names'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Button Name',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addButtonName,
                ),
              ),
            ),
          ),
          Expanded(
            child: ReorderableListView(
              onReorder: _onReorder,
              children: [
                for (int index = 0; index < buttonNames.length; index++)
                  ListTile(
                    key: ValueKey(buttonNames[index]),
                    leading: const MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Icon(Icons.drag_handle),
                    ),
                    title: Text(buttonNames[index]),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        setState(() {
                          buttonNames.removeAt(index);
                          ref.read(customButtonNamesProvider.notifier).setCustomButtonNameList(buttonNames);
                        });
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
