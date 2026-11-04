import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_error.dart';
import '../../../core/documents/documents.dart';
import 'widgets/attachments_card.dart';

/// "My Records": every document in the workspace, filterable by module and searchable.
class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  final _search = TextEditingController();
  String? _module;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final documents = ref.watch(documentLibraryProvider((module: _module, search: _query)));
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('My Records', style: Theme.of(context).textTheme.headlineSmall),
              FilledButton.icon(
                onPressed: () => pickAndUploadDocument(context, ref, module: 'GENERAL'),
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('Upload document'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Photos and documents from every module, encrypted at rest. Attach files to an animal or land record from its page.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search title or file name', isDense: true),
                  onSubmitted: (value) => setState(() => _query = value.trim()),
                ),
              ),
              DropdownButton<String?>(
                value: _module,
                hint: const Text('All modules'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All modules')),
                  DropdownMenuItem(value: 'ANIMAL', child: Text('Goat Farm')),
                  DropdownMenuItem(value: 'LAND', child: Text('Land')),
                  DropdownMenuItem(value: 'TRANSACTION', child: Text('Transactions')),
                  DropdownMenuItem(value: 'CONTACT', child: Text('Contacts')),
                  DropdownMenuItem(value: 'GENERAL', child: Text('General')),
                ],
                onChanged: (value) => setState(() => _module = value),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: documents.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text(apiErrorMessage(error, 'Could not load documents.'))),
              data: (list) => list.isEmpty
                  ? const Center(child: Text('No documents found.'))
                  : ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) => AttachmentTile(attachment: list[index], showModule: true),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
