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
            child: ListView.builder(
              itemCount: buttonNames.length,
              itemBuilder: (context, index) {
                return ListTile(
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
