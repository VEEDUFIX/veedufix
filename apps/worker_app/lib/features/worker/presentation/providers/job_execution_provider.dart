import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

enum JobExecutionStep {
  arrival,
  arrivalOtp,
  beforePhotos,
  checklist,
  afterPhotos,
  completionRequest,
  completionOtp,
}

enum JobExecutionPhotoType {
  before,
  after,
}

enum JobExecutionErrorKind {
  unknown,
  network,
  location,
  otpInvalid,
  otpExpired,
  incompleteJob,
  validation,
  unauthorized,
}

class JobExecutionBooking {
  const JobExecutionBooking({
    required this.bookingId,
    required this.bookingCode,
    required this.serviceId,
    required this.serviceName,
    required this.customerName,
    required this.locationLabel,
    required this.earningsLabel,
    required this.summary,
    required this.accentColor,
  });

  final String bookingId;
  final String bookingCode;
  final String serviceId;
  final String serviceName;
  final String customerName;
  final String locationLabel;
  final String earningsLabel;
  final String summary;
  final Color accentColor;
}

class JobExecutionChecklistItem {
  const JobExecutionChecklistItem({
    required this.id,
    required this.label,
    required this.order,
    required this.requiresPhoto,
    required this.required,
    required this.completed,
  });

  final String id;
  final String label;
  final int order;
  final bool requiresPhoto;
  final bool required;
  final bool completed;

  JobExecutionChecklistItem copyWith({
    String? id,
    String? label,
    int? order,
    bool? requiresPhoto,
    bool? required,
    bool? completed,
  }) {
    return JobExecutionChecklistItem(
      id: id ?? this.id,
      label: label ?? this.label,
      order: order ?? this.order,
      requiresPhoto: requiresPhoto ?? this.requiresPhoto,
      required: required ?? this.required,
      completed: completed ?? this.completed,
    );
  }

  Map<String, dynamic> toPayload() {
    return {
      'id': id,
      'label': label,
      'order': order,
      'requiresPhoto': requiresPhoto,
      'required': required,
      'completed': completed,
    };
  }
}

class JobExecutionPhotoDraft {
  const JobExecutionPhotoDraft({
    required this.id,
    required this.file,
    this.remoteUrl,
    this.uploading = false,
    this.errorMessage,
  });

  final String id;
  final XFile file;
  final String? remoteUrl;
  final bool uploading;
  final String? errorMessage;

  bool get isUploaded => remoteUrl != null && errorMessage == null;
  bool get hasFailed => errorMessage != null;

  JobExecutionPhotoDraft copyWith({
    String? id,
    XFile? file,
    String? remoteUrl,
    bool? uploading,
    String? errorMessage,
    bool clearRemoteUrl = false,
    bool clearErrorMessage = false,
  }) {
    return JobExecutionPhotoDraft(
      id: id ?? this.id,
      file: file ?? this.file,
      remoteUrl: clearRemoteUrl ? null : remoteUrl ?? this.remoteUrl,
      uploading: uploading ?? this.uploading,
      errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class JobExecutionStepError {
  const JobExecutionStepError({
    required this.kind,
    required this.message,
    this.missingItems = const <String>[],
    this.missingPhotos = false,
  });

  final JobExecutionErrorKind kind;
  final String message;
  final List<String> missingItems;
  final bool missingPhotos;
}

class JobExecutionSummary {
  const JobExecutionSummary({
    required this.title,
    required this.subtitle,
    required this.earningsLabel,
    required this.completedAtLabel,
  });

  final String title;
  final String subtitle;
  final String earningsLabel;
  final String completedAtLabel;
}

class JobExecutionState {
  const JobExecutionState({
    this.booking,
    this.currentStep = 1,
    this.loadingSteps = const <JobExecutionStep>{},
    this.stepErrors = const <JobExecutionStep, JobExecutionStepError>{},
    this.currentPosition,
    this.beforePhotos = const <JobExecutionPhotoDraft>[],
    this.afterPhotos = const <JobExecutionPhotoDraft>[],
    this.checklistItems = const <JobExecutionChecklistItem>[],
    this.checklistLoaded = false,
    this.completionBlocker,
    this.summary,
  });

  final JobExecutionBooking? booking;
  final int currentStep;
  final Set<JobExecutionStep> loadingSteps;
  final Map<JobExecutionStep, JobExecutionStepError> stepErrors;
  final Position? currentPosition;
  final List<JobExecutionPhotoDraft> beforePhotos;
  final List<JobExecutionPhotoDraft> afterPhotos;
  final List<JobExecutionChecklistItem> checklistItems;
  final bool checklistLoaded;
  final JobExecutionStepError? completionBlocker;
  final JobExecutionSummary? summary;

  bool get hasBooking => booking != null;

  bool get beforePhotosComplete =>
      beforePhotos.isNotEmpty && beforePhotos.every((draft) => draft.isUploaded);

  bool get afterPhotosComplete =>
      afterPhotos.isNotEmpty && afterPhotos.every((draft) => draft.isUploaded);

  bool get allRequiredChecklistComplete =>
      checklistItems.where((item) => item.required).every((item) => item.completed);

  bool get canRequestCompletionOtp =>
      beforePhotosComplete && afterPhotosComplete && allRequiredChecklistComplete;

  bool isLoading(JobExecutionStep step) => loadingSteps.contains(step);

  JobExecutionStepError? errorFor(JobExecutionStep step) => stepErrors[step];

  JobExecutionState copyWith({
    Object? booking = _unset,
    int? currentStep,
    Set<JobExecutionStep>? loadingSteps,
    Map<JobExecutionStep, JobExecutionStepError>? stepErrors,
    Object? currentPosition = _unset,
    List<JobExecutionPhotoDraft>? beforePhotos,
    List<JobExecutionPhotoDraft>? afterPhotos,
    List<JobExecutionChecklistItem>? checklistItems,
    bool? checklistLoaded,
    Object? completionBlocker = _unset,
    Object? summary = _unset,
  }) {
    return JobExecutionState(
      booking: identical(booking, _unset) ? this.booking : booking as JobExecutionBooking?,
      currentStep: currentStep ?? this.currentStep,
      loadingSteps: loadingSteps ?? this.loadingSteps,
      stepErrors: stepErrors ?? this.stepErrors,
      currentPosition: identical(currentPosition, _unset)
          ? this.currentPosition
          : currentPosition as Position?,
      beforePhotos: beforePhotos ?? this.beforePhotos,
      afterPhotos: afterPhotos ?? this.afterPhotos,
      checklistItems: checklistItems ?? this.checklistItems,
      checklistLoaded: checklistLoaded ?? this.checklistLoaded,
      completionBlocker: identical(completionBlocker, _unset)
          ? this.completionBlocker
          : completionBlocker as JobExecutionStepError?,
      summary: identical(summary, _unset) ? this.summary : summary as JobExecutionSummary?,
    );
  }
}

const Object _unset = Object();

final jobExecutionProvider =
    StateNotifierProvider<JobExecutionNotifier, JobExecutionState>((ref) {
  return JobExecutionNotifier(ref);
});

class JobExecutionNotifier extends StateNotifier<JobExecutionState> {
  JobExecutionNotifier(this.ref) : super(const JobExecutionState());

  final Ref ref;
  final ImagePicker _imagePicker = ImagePicker();
  final Dio _uploadDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
    ),
  );

  Dio get _dio => ref.read(apiClientProvider).dio;

  JobExecutionBooking get _booking {
    final booking = state.booking;
    if (booking == null) {
      throw StateError('Job execution booking has not been initialised.');
    }
    return booking;
  }

  void start(JobExecutionBooking booking) {
    state = JobExecutionState(booking: booking);
  }

  void clearStepError(JobExecutionStep step) {
    if (!state.stepErrors.containsKey(step)) {
      return;
    }
    final nextErrors = Map<JobExecutionStep, JobExecutionStepError>.from(state.stepErrors)..remove(step);
    state = state.copyWith(stepErrors: nextErrors);
  }

  void _clearStepError(JobExecutionStep step) {
    clearStepError(step);
  }

  Future<void> pickAndUploadPhotos(JobExecutionPhotoType type) async {
    final booking = _booking;
    final currentPhotos = type == JobExecutionPhotoType.before ? state.beforePhotos : state.afterPhotos;
    final remainingSlots = max(0, 5 - currentPhotos.length);
    if (remainingSlots == 0) {
      _setStepError(
        _photoStepFor(type),
        const JobExecutionStepError(
          kind: JobExecutionErrorKind.validation,
          message: 'You can upload at most 5 photos for this step.',
        ),
      );
      return;
    }

    final picked = await _imagePicker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) {
      return;
    }

    final files = picked.take(remainingSlots).toList(growable: false);
    if (files.isEmpty) {
      return;
    }

    final newDrafts = files
        .map(
          (file) => JobExecutionPhotoDraft(
            id: '${type.name}-${DateTime.now().microsecondsSinceEpoch}-${file.name}',
            file: file,
          ),
        )
        .toList(growable: false);

    state = _replaceDrafts(type, [...currentPhotos, ...newDrafts]);
    await _uploadPhotos(type, newDrafts.map((draft) => draft.id).toSet(), booking);
  }

  Future<void> retryPhoto(JobExecutionPhotoType type, String draftId) async {
    final booking = _booking;
    await _uploadPhotos(type, {draftId}, booking);
  }

  Future<void> markArrived() async {
    final booking = _booking;
    const step = JobExecutionStep.arrival;
    _setLoading(step, true);
    _clearStepError(step);

    try {
      final position = await _resolvePosition();
      await _dio.post<Map<String, dynamic>>(
        '/bookings/${booking.bookingId}/arrive',
        data: {
          'workerLat': position.latitude,
          'workerLng': position.longitude,
        },
      );
      state = state.copyWith(
        currentPosition: position,
        currentStep: 2,
      );
    } on JobExecutionStepError catch (error) {
      _setStepError(step, error);
    } catch (error) {
      _setStepError(
        step,
        JobExecutionStepError(
          kind: JobExecutionErrorKind.network,
          message: _readErrorMessage(error),
        ),
      );
    } finally {
      _setLoading(step, false);
    }
  }

  Future<void> verifyArrivalOtp(String otpInput) async {
    final booking = _booking;
    const step = JobExecutionStep.arrivalOtp;
    _setLoading(step, true);
    _clearStepError(step);

    try {
      await _dio.post<Map<String, dynamic>>(
        '/bookings/${booking.bookingId}/verify-arrival-otp',
        data: {'otpInput': otpInput},
      );
      state = state.copyWith(currentStep: 3);
    } on JobExecutionStepError catch (error) {
      _setStepError(step, error);
    } catch (error) {
      _setStepError(
        step,
        JobExecutionStepError(
          kind: JobExecutionErrorKind.network,
          message: _readErrorMessage(error),
        ),
      );
    } finally {
      _setLoading(step, false);
    }
  }

  Future<void> loadChecklistTemplate() async {
    final booking = _booking;
    const step = JobExecutionStep.checklist;
    if (state.checklistLoaded) {
      state = state.copyWith(currentStep: max(state.currentStep, 4));
      return;
    }

    _setLoading(step, true);
    _clearStepError(step);

    try {
      final response = await _dio.get<dynamic>('/services/${booking.serviceId}/checklist-template');
      final items = _parseChecklistItems(response.data);
      state = state.copyWith(
        currentStep: max(state.currentStep, 4),
        checklistLoaded: true,
        checklistItems: items,
      );
    } on JobExecutionStepError catch (error) {
      _setStepError(step, error);
    } catch (error) {
      _setStepError(
        step,
        JobExecutionStepError(
          kind: JobExecutionErrorKind.network,
          message: _readErrorMessage(error),
        ),
      );
    } finally {
      _setLoading(step, false);
    }
  }

  Future<void> toggleChecklistItem(String itemId, bool completed) async {
    final booking = _booking;
    const step = JobExecutionStep.checklist;
    final previousItems = state.checklistItems;
    final nextItems = state.checklistItems
        .map((item) => item.id == itemId ? item.copyWith(completed: completed) : item)
        .toList(growable: false);

    state = state.copyWith(checklistItems: nextItems, currentStep: max(state.currentStep, 4));
    _setLoading(step, true);
    _clearStepError(step);

    try {
      await _dio.patch<Map<String, dynamic>>(
        '/bookings/${booking.bookingId}/checklist',
        data: {
          'items': nextItems.map((item) => item.toPayload()).toList(growable: false),
        },
      );
      if (state.allRequiredChecklistComplete) {
        state = state.copyWith(currentStep: max(state.currentStep, 5));
      }
    } on JobExecutionStepError catch (error) {
      state = state.copyWith(checklistItems: previousItems);
      _setStepError(step, error);
    } catch (error) {
      state = state.copyWith(checklistItems: previousItems);
      _setStepError(
        step,
        JobExecutionStepError(
          kind: JobExecutionErrorKind.network,
          message: _readErrorMessage(error),
        ),
      );
    } finally {
      _setLoading(step, false);
    }
  }

  Future<void> requestCompletionOtp() async {
    final booking = _booking;
    const step = JobExecutionStep.completionRequest;
    _setLoading(step, true);
    _clearStepError(step);
    state = state.copyWith(completionBlocker: null);

    try {
      await _dio.post<Map<String, dynamic>>(
        '/bookings/${booking.bookingId}/request-completion-otp',
        data: const <String, dynamic>{},
      );
      state = state.copyWith(currentStep: 7);
    } on DioException catch (error) {
      final parsed = _parseStepError(error);
      if (parsed.kind == JobExecutionErrorKind.incompleteJob) {
        state = state.copyWith(completionBlocker: parsed);
      }
      _setStepError(step, parsed);
    } catch (error) {
      _setStepError(
        step,
        JobExecutionStepError(
          kind: JobExecutionErrorKind.network,
          message: _readErrorMessage(error),
        ),
      );
    } finally {
      _setLoading(step, false);
    }
  }

  Future<void> verifyCompletionOtp(String otpInput) async {
    final booking = _booking;
    const step = JobExecutionStep.completionOtp;
    _setLoading(step, true);
    _clearStepError(step);

    try {
      await _dio.post<Map<String, dynamic>>(
        '/bookings/${booking.bookingId}/verify-completion-otp',
        data: {'otpInput': otpInput},
      );
      state = state.copyWith(
        currentStep: 7,
        summary: JobExecutionSummary(
          title: 'Job completed successfully',
          subtitle: '${booking.serviceName} for ${booking.customerName} is complete.',
          earningsLabel: booking.earningsLabel,
          completedAtLabel: 'Completed just now',
        ),
      );
    } on JobExecutionStepError catch (error) {
      _setStepError(step, error);
    } catch (error) {
      _setStepError(
        step,
        JobExecutionStepError(
          kind: JobExecutionErrorKind.network,
          message: _readErrorMessage(error),
        ),
      );
    } finally {
      _setLoading(step, false);
    }
  }

  Future<void> _uploadPhotos(
    JobExecutionPhotoType type,
    Set<String> draftIds,
    JobExecutionBooking booking,
  ) async {
    final step = _photoStepFor(type);
    _setLoading(step, true);
    _clearStepError(step);

    final currentPhotos = type == JobExecutionPhotoType.before ? state.beforePhotos : state.afterPhotos;
    final selectedDrafts = currentPhotos.where((draft) => draftIds.contains(draft.id)).toList(growable: false);
    if (selectedDrafts.isEmpty) {
      _setLoading(step, false);
      return;
    }

    var nextPhotos = List<JobExecutionPhotoDraft>.from(currentPhotos);
    try {
      final signature = await _dio.post<Map<String, dynamic>>(
        '/uploads/signature',
        data: {
          'bookingId': booking.bookingId,
          'type': type.name,
        },
      );
      final payload = signature.data ?? <String, dynamic>{};
      final uploadUrl = payload['uploadUrl'] as String? ?? '';
      final folder = payload['folder'] as String? ?? '';
      final apiKey = payload['apiKey'] as String? ?? '';
      final timestamp = payload['timestamp'];
      final cloudSignature = payload['signature'] as String? ?? '';

      final successfulUrls = <String>[];
      for (final draft in selectedDrafts) {
        try {
          final uploaded = await _uploadSinglePhoto(
            uploadUrl: uploadUrl,
            apiKey: apiKey,
            folder: folder,
            timestamp: timestamp,
            signature: cloudSignature,
            file: draft.file,
          );
          successfulUrls.add(uploaded);
          nextPhotos = nextPhotos
              .map(
                (item) => item.id == draft.id
                    ? item.copyWith(
                        remoteUrl: uploaded,
                        uploading: false,
                        clearErrorMessage: true,
                      )
                    : item,
              )
              .toList(growable: false);
          state = _replaceDrafts(type, nextPhotos);
        } catch (error) {
          final message = _readErrorMessage(error);
          nextPhotos = nextPhotos
              .map(
                (item) => item.id == draft.id
                    ? item.copyWith(
                        uploading: false,
                        errorMessage: message,
                      )
                    : item,
              )
              .toList(growable: false);
          state = _replaceDrafts(type, nextPhotos);
          _setStepError(
            step,
            JobExecutionStepError(
              kind: JobExecutionErrorKind.network,
              message: message,
            ),
          );
        }
      }

      if (successfulUrls.isNotEmpty) {
        await _dio.post<Map<String, dynamic>>(
          '/bookings/${booking.bookingId}/photos',
          data: {
            'photoUrls': successfulUrls,
            'type': type.name,
          },
        );
      }

      nextPhotos = nextPhotos
          .map(
            (item) => draftIds.contains(item.id)
                ? item.copyWith(uploading: false, clearErrorMessage: true)
                : item,
          )
          .toList(growable: false);
      state = _replaceDrafts(type, nextPhotos);

      if (type == JobExecutionPhotoType.before && nextPhotos.every((draft) => draft.isUploaded)) {
        await loadChecklistTemplate();
        state = state.copyWith(currentStep: max(state.currentStep, 4));
      } else if (type == JobExecutionPhotoType.after && nextPhotos.every((draft) => draft.isUploaded)) {
        state = state.copyWith(currentStep: max(state.currentStep, 6));
      }
    } catch (error) {
      final message = _readErrorMessage(error);
      _setStepError(
        step,
        JobExecutionStepError(
          kind: JobExecutionErrorKind.network,
          message: message,
        ),
      );
    } finally {
      _setLoading(step, false);
    }
  }

  Future<Position> _resolvePosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const JobExecutionStepError(
        kind: JobExecutionErrorKind.location,
        message: 'Turn on location services to mark your arrival.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const JobExecutionStepError(
        kind: JobExecutionErrorKind.location,
        message: 'Location permission is required to mark your arrival.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw const JobExecutionStepError(
        kind: JobExecutionErrorKind.location,
        message: 'Location permission is permanently denied. Open settings to continue.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  JobExecutionStepError _parseStepError(DioException error) {
    final status = error.response?.statusCode;
    final data = error.response?.data;
    final extractedMessage = _extractResponseMessage(data);
    final message = extractedMessage.isNotEmpty
        ? extractedMessage
        : (error.message != null && error.message!.trim().isNotEmpty
            ? error.message!
            : 'Something went wrong.');

    if (status == 410) {
      return JobExecutionStepError(
        kind: JobExecutionErrorKind.otpExpired,
        message: message,
      );
    }

    if (status == 400) {
      return JobExecutionStepError(
        kind: JobExecutionErrorKind.otpInvalid,
        message: message,
      );
    }

    if (status == 409) {
      final missingItems = _extractMissingItems(data);
      final missingPhotos = _extractMissingPhotos(data);
      return JobExecutionStepError(
        kind: JobExecutionErrorKind.incompleteJob,
        message: message,
        missingItems: missingItems,
        missingPhotos: missingPhotos,
      );
    }

    if (status == 403) {
      return JobExecutionStepError(
        kind: JobExecutionErrorKind.unauthorized,
        message: message,
      );
    }

    return JobExecutionStepError(
      kind: JobExecutionErrorKind.network,
      message: message,
    );
  }

  String _extractResponseMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }
    return '';
  }

  List<String> _extractMissingItems(dynamic data) {
    if (data is Map<String, dynamic>) {
      final missingItems = data['missingItems'];
      if (missingItems is List) {
        return missingItems.whereType<String>().toList(growable: false);
      }
    }
    return const <String>[];
  }

  bool _extractMissingPhotos(dynamic data) {
    if (data is Map<String, dynamic>) {
      final missingPhotos = data['missingPhotos'];
      if (missingPhotos is bool) {
        return missingPhotos;
      }
    }
    return false;
  }

  List<JobExecutionChecklistItem> _parseChecklistItems(dynamic data) {
    final rawItems = <dynamic>[];
    if (data is List) {
      rawItems.addAll(data);
    } else if (data is Map<String, dynamic>) {
      final items = data['items'] ?? data['checklist'] ?? data['data'];
      if (items is List) {
        rawItems.addAll(items);
      } else if (items is Map<String, dynamic>) {
        rawItems.addAll(items.entries.map((entry) => {'label': entry.key, 'completed': entry.value}));
      }
    }

    final parsed = rawItems.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      if (item is Map<String, dynamic>) {
        final label = _stringValue(item['label']) ??
            _stringValue(item['name']) ??
            _stringValue(item['title']) ??
            'Item ${index + 1}';
        final order = _intValue(item['order']) ?? _intValue(item['sortOrder']) ?? index;
        final requiresPhoto = _boolValue(item['requiresPhoto']) ?? _boolValue(item['photoRequired']) ?? false;
        final required = _boolValue(item['required']) ?? true;
        final completed = _boolValue(item['completed']) ??
            _boolValue(item['checked']) ??
            _boolValue(item['done']) ??
            _boolValue(item['isComplete']) ??
            false;
        final id = _stringValue(item['id']) ??
            _stringValue(item['key']) ??
            '$label-$order';
        return JobExecutionChecklistItem(
          id: id,
          label: label,
          order: order,
          requiresPhoto: requiresPhoto,
          required: required,
          completed: completed,
        );
      }
      final label = item?.toString() ?? 'Item ${index + 1}';
      return JobExecutionChecklistItem(
        id: '$label-$index',
        label: label,
        order: index,
        requiresPhoto: false,
        required: true,
        completed: false,
      );
    }).toList(growable: false);

    parsed.sort((left, right) => left.order.compareTo(right.order));
    return parsed;
  }

  String? _stringValue(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  int? _intValue(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  bool? _boolValue(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is String) {
      final normalized = value.toLowerCase().trim();
      if (normalized == 'true' || normalized == 'yes' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' || normalized == 'no' || normalized == '0') {
        return false;
      }
    }
    return null;
  }

  String _readErrorMessage(Object error) {
    if (error is DioException) {
      final responseMessage = _extractResponseMessage(error.response?.data);
      if (responseMessage.isNotEmpty) {
        return responseMessage;
      }
      final message = error.message;
      if (message != null && message.trim().isNotEmpty) {
        return message;
      }
    }
    return error.toString();
  }

  Future<String> _uploadSinglePhoto({
    required String uploadUrl,
    required String apiKey,
    required String folder,
    required dynamic timestamp,
    required String signature,
    required XFile file,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: file.name),
      'api_key': apiKey,
      'folder': folder,
      'timestamp': timestamp.toString(),
      'signature': signature,
    });

    final response = await _uploadDio.post<Map<String, dynamic>>(
      uploadUrl,
      data: formData,
      options: Options(
        contentType: Headers.multipartFormDataContentType,
        responseType: ResponseType.json,
      ),
    );

    final data = response.data ?? <String, dynamic>{};
    final secureUrl = data['secure_url'] as String?;
    if (secureUrl == null || secureUrl.isEmpty) {
      throw StateError('Cloudinary did not return a secure URL.');
    }
    return secureUrl;
  }

  void _setLoading(JobExecutionStep step, bool value) {
    final next = Set<JobExecutionStep>.from(state.loadingSteps);
    if (value) {
      next.add(step);
    } else {
      next.remove(step);
    }
    state = state.copyWith(loadingSteps: next);
  }

  void _setStepError(JobExecutionStep step, JobExecutionStepError error) {
    final nextErrors = Map<JobExecutionStep, JobExecutionStepError>.from(state.stepErrors)
      ..[step] = error;
    state = state.copyWith(stepErrors: nextErrors);
  }

  JobExecutionStep _photoStepFor(JobExecutionPhotoType type) {
    return type == JobExecutionPhotoType.before ? JobExecutionStep.beforePhotos : JobExecutionStep.afterPhotos;
  }

  JobExecutionState _replaceDrafts(JobExecutionPhotoType type, List<JobExecutionPhotoDraft> drafts) {
    return type == JobExecutionPhotoType.before
        ? state.copyWith(beforePhotos: drafts)
        : state.copyWith(afterPhotos: drafts);
  }
}
