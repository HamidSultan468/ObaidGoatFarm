import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/accounting/accounting_controller.dart';
import '../../../../core/api/api_error.dart';
import '../../../../core/documents/documents.dart';
import '../../../../core/farm/farm_controller.dart';
import '../../../../core/farm/farm_models.dart';
import '../../../documents/presentation/widgets/attachments_card.dart';

/// Circular profile photo for an animal: tap to change it (upload a new
/// image, then set it as the animal's `photoAttachmentId`). Reuses the
/// existing encrypted attachment storage — no separate photo pipeline.
class AnimalPhotoAvatar extends ConsumerWidget {
  const AnimalPhotoAvatar({super.key, required this.animal, this.radius = 36});

  final Animal animal;
  final double radius;

  Future<void> _changePhoto(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final attachment = await pickAndUploadDocument(
      context,
      ref,
      module: 'ANIMAL',
      recordId: animal.id,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
    );
    if (attachment == null) return;
    try {
      await ref
          .read(farmRepositoryProvider)
          .updateAnimal(requireWorkspaceIdFromWidget(ref), animal.id, {'photoAttachmentId': attachment.id}, ifMatch: animal.updatedAt);
      invalidateFarm(ref, animalId: animal.id);
    } on DioException catch (error) {
      if (!context.mounted) return;
      invalidateFarm(ref, animalId: animal.id);
      final message = error.response?.statusCode == 412
          ? 'Someone else updated this animal just now. Reloaded the latest — please try again.'
          : apiErrorMessage(error, 'Could not set the photo.');
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(error, 'Could not set the photo.'))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photoId = animal.photoAttachmentId;
    final avatar = photoId == null
        ? CircleAvatar(
            radius: radius,
            child: Icon(animal.sex == 'MALE' ? Icons.male_rounded : Icons.female_rounded, size: radius),
          )
        : ref
              .watch(attachmentBytesProvider(photoId))
              .when(
                loading: () => CircleAvatar(radius: radius, child: SizedBox(width: radius, height: radius, child: const CircularProgressIndicator(strokeWidth: 2))),
                error: (_, _) => CircleAvatar(radius: radius, child: const Icon(Icons.broken_image_outlined)),
                data: (bytes) => CircleAvatar(radius: radius, backgroundImage: MemoryImage(bytes)),
              );
    if (!animal.isActive) return avatar;
    return Stack(
      children: [
        avatar,
        Positioned(
          right: -4,
          bottom: -4,
          child: Material(
            color: Theme.of(context).colorScheme.primary,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _changePhoto(context, ref),
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Icon(Icons.camera_alt_rounded, size: 14, color: Theme.of(context).colorScheme.onPrimary),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Small thumbnail for herd list rows; falls back to a sex icon when there's no photo.
class AnimalThumbnail extends ConsumerWidget {
  const AnimalThumbnail({super.key, required this.animal, this.radius = 20});

  final Animal animal;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photoId = animal.photoAttachmentId;
    if (photoId == null) {
      return CircleAvatar(radius: radius, child: Icon(animal.sex == 'MALE' ? Icons.male_rounded : Icons.female_rounded, size: radius));
    }
    return ref
        .watch(attachmentBytesProvider(photoId))
        .when(
          loading: () => CircleAvatar(radius: radius),
          error: (_, _) => CircleAvatar(radius: radius, child: const Icon(Icons.broken_image_outlined, size: 16)),
          data: (bytes) => CircleAvatar(radius: radius, backgroundImage: MemoryImage(bytes)),
        );
  }
}
