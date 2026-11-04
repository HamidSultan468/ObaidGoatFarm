import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_controller.dart';
import 'mfa_models.dart';

sealed class MfaSetupState {
  const MfaSetupState();
}

class MfaSetupIdle extends MfaSetupState {
  const MfaSetupIdle();
}

class MfaSetupInProgress extends MfaSetupState {
  const MfaSetupInProgress(this.setup, {this.errorMessage, this.isSubmitting = false});
  final MfaSetup setup;
  final String? errorMessage;
  final bool isSubmitting;
}

class MfaSetupError extends MfaSetupState {
  const MfaSetupError(this.message);
  final String message;
}

final mfaSetupControllerProvider = NotifierProvider<MfaSetupController, MfaSetupState>(MfaSetupController.new);

class MfaSetupController extends Notifier<MfaSetupState> {
  @override
  MfaSetupState build() => const MfaSetupIdle();

  Future<void> start() async {
    try {
      final setup = await ref.read(authRepositoryProvider).beginMfaSetup();
      state = MfaSetupInProgress(setup);
    } on DioException catch (error) {
      state = MfaSetupError(_messageFor(error));
    }
  }

  Future<bool> confirm(String code) async {
    final current = state;
    if (current is! MfaSetupInProgress) return false;

    state = MfaSetupInProgress(current.setup, isSubmitting: true);
    try {
      await ref.read(authRepositoryProvider).confirmMfaSetup(code);
      await ref.read(authControllerProvider.notifier).refreshProfile();
      state = const MfaSetupIdle();
      return true;
    } on DioException catch (error) {
      state = MfaSetupInProgress(current.setup, errorMessage: _messageFor(error));
      return false;
    }
  }

  void cancel() {
    state = const MfaSetupIdle();
  }

  String _messageFor(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return 'Something went wrong. Please try again.';
  }
}
