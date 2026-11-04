import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/accounting/accounting_controller.dart';
import '../../../../core/api/api_error.dart';
import '../../../../core/documents/documents.dart';
import '../../../../core/farm/farm_format.dart';

/// Picks a file, checks its size/type client-side, and uploads it.
/// Returns the uploaded attachment, or null if nothing was uploaded. The
/// server re-checks everything.
Future<Attachment?> pickAndUploadDocument(BuildContext context, WidgetRef ref, {required String module, String? recordId, List<String> allowedExtensions = allowedDocumentExtensions}) async {
  final messenger = ScaffoldMessenger.of(context);
  final picked = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: allowedExtensions);
  if (picked == null) return null;
  try {
    final size = await picked.length();
    if (size != null && size > maxUploadBytes) {
      messenger.showSnackBar(const SnackBar(content: Text('Files may be at most 10 MB.')));
      return null;
    }
    final bytes = await picked.readAsBytes();
    final attachment = await ref.read(documentsRepositoryProvider).upload(
      requireWorkspaceIdFromWidget(ref),
      module: module,
      recordId: recordId,
      fileName: picked.name,
      bytes: bytes,
    );
    ref.invalidate(recordAttachmentsProvider);
    ref.invalidate(documentLibraryProvider);
    messenger.showSnackBar(SnackBar(content: Text('Uploaded ${picked.name}')));
    return attachment;
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(error, 'Could not upload the file.'))));
    return null;
  }
}

/// Opens an image in a preview dialog; saves/downloads anything else.
Future<void> openDocument(BuildContext context, WidgetRef ref, Attachment attachment) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final bytes = await ref.read(documentsRepositoryProvider).download(requireWorkspaceIdFromWidget(ref), attachment.id);
    if (!context.mounted) return;
    if (attachment.isImage) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(attachment.title),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
            child: InteractiveViewer(child: Image.memory(bytes, fit: BoxFit.contain)),
          ),
          actions: [
            TextButton(
              onPressed: () => FilePicker.saveFile(fileName: attachment.fileName, bytes: bytes, mimeType: attachment.mimeType),
              child: const Text('Download'),
            ),
            FilledButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Close')),
          ],
        ),
      );
    } else {
      await FilePicker.saveFile(fileName: attachment.fileName, bytes: bytes, mimeType: attachment.mimeType);
    }
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(error, 'Could not open the document.'))));
  }
}

Future<void> confirmDeleteDocument(BuildContext context, WidgetRef ref, Attachment attachment) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete document?'),
      content: Text('"${attachment.title}" will be permanently deleted.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Delete')),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(documentsRepositoryProvider).delete(requireWorkspaceIdFromWidget(ref), attachment.id);
    ref.invalidate(recordAttachmentsProvider);
    ref.invalidate(documentLibraryProvider);
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(error, 'Could not delete the document.'))));
  }
}

class AttachmentTile extends ConsumerWidget {
  const AttachmentTile({super.key, required this.attachment, this.showModule = false});
  final Attachment attachment;
  final bool showModule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(attachment.isImage ? Icons.image_outlined : Icons.picture_as_pdf_outlined),
      title: Text(attachment.title, overflow: TextOverflow.ellipsis),
      subtitle: Text([
        if (showModule) humanizeEnum(attachment.module),
        formatFileSize(attachment.sizeBytes),
        formatDate(attachment.createdAt),
      ].join(' · ')),
      onTap: () => openDocument(context, ref, attachment),
      trailing: PopupMenuButton<String>(
        tooltip: 'Document actions',
        onSelected: (action) => switch (action) {
          'open' => openDocument(context, ref, attachment),
          'delete' => confirmDeleteDocument(context, ref, attachment),
          _ => null,
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'open', child: Text(attachment.isImage ? 'View' : 'Download')),
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }
}

/// Photos & documents section for any record (animal, land parcel, ...).
class AttachmentsCard extends ConsumerWidget {
  const AttachmentsCard({super.key, required this.module, required this.recordId, this.canUpload = true});

  final String module;
  final String recordId;
  final bool canUpload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attachments = ref.watch(recordAttachmentsProvider((module: module, recordId: recordId)));
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('Photos & documents', style: Theme.of(context).textTheme.titleMedium)),
                if (canUpload)
                  TextButton.icon(
                    onPressed: () => pickAndUploadDocument(context, ref, module: module, recordId: recordId),
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('Upload'),
                  ),
              ],
            ),
            attachments.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text(apiErrorMessage(error, 'Could not load documents.')),
              data: (list) => list.isEmpty
                  ? Text('No photos or documents yet. JPEG, PNG, WEBP or PDF up to 10 MB.', style: Theme.of(context).textTheme.bodySmall)
                  : Column(children: [for (final a in list) AttachmentTile(attachment: a)]),
            ),
          ],
        ),
      ),
    );
  }
}
