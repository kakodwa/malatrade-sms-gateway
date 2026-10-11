import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CodeDocTile extends StatelessWidget {
  final String language;
  final String codeSnippet;

  const CodeDocTile({super.key, required this.language, required this.codeSnippet});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(language, style: const TextStyle(color: Color(0xFFFF8C00), fontWeight: FontWeight.bold, fontSize: 12.5)),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.white70),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: codeSnippet));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$language snippet copied!")));
                  },
                )
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
            ),
            child: SelectableText(
              codeSnippet.trim(),
              style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF38BDF8), fontSize: 11.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}