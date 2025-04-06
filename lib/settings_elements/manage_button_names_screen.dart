import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/button_config.dart';
import '../providers/button_configs_provider.dart';

class ManageButtonNamesScreen extends ConsumerStatefulWidget {
  const ManageButtonNamesScreen({super.key});

  @override
  _ManageButtonNamesScreenState createState() => _ManageButtonNamesScreenState();
}

class _ManageButtonNamesScreenState extends ConsumerState<ManageButtonNamesScreen> {
  final TextEditingController _controller = TextEditingController();
  Color _selectedColor = Colors.teal;

  void _addButtonConfig() {
    if (_controller.text.isNotEmpty) {
      ref.read(buttonConfigsProvider.notifier).addButton(_controller.text, _selectedColor);
      _controller.clear();
      setState(() {
        _selectedColor = Colors.teal; // Reset to default color
      });
    }
  }

  void _showColorPicker(int index, ButtonConfig config) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Button Color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: config.color,
              onColorChanged: (Color color) {
                setState(() {
                  _selectedColor = color;
                });
              },
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () {
                ref.read(buttonConfigsProvider.notifier).updateButtonColor(index, _selectedColor);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final buttonConfigs = ref.watch(buttonConfigsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Button Names'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'Button Name',
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.color_lens, color: _selectedColor),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Select Button Color'),
                          content: SingleChildScrollView(
                            child: ColorPicker(
                              pickerColor: _selectedColor,
                              onColorChanged: (Color color) {
                                setState(() {
                                  _selectedColor = color;
                                });
                              },
                              pickerAreaHeightPercent: 0.8,
                            ),
                          ),
                          actions: <Widget>[
                            TextButton(
                              child: const Text('OK'),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addButtonConfig,
                ),
              ],
            ),
          ),
          Expanded(
            child: ReorderableListView(
              onReorder: (oldIndex, newIndex) {
                ref.read(buttonConfigsProvider.notifier).reorderButtons(oldIndex, newIndex);
              },
              children: [
                for (int index = 0; index < buttonConfigs.length; index++)
                  ListTile(
                    key: ValueKey(buttonConfigs[index].name + index.toString()),
                    leading: const MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Icon(Icons.drag_handle),
                    ),
                    title: Text(buttonConfigs[index].name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.color_lens, color: buttonConfigs[index].color),
                          onPressed: () => _showColorPicker(index, buttonConfigs[index]),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            ref.read(buttonConfigsProvider.notifier).removeButton(index);
                          },
                        ),
                      ],
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
