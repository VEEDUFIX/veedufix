import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

enum WorkerOnboardingActionKind {
  idle,
  loading,
  savingProfile,
  uploadingDocument,
  savingSkills,
  submitting,
}

class WorkerOnboardingSkillItem {
  const WorkerOnboardingSkillItem({
    required this.categoryId,
    required this.categoryName,
    this.categorySlug,
    this.categoryIconUrl,
    this.hasCertificationDoc = false,
  });

  final String categoryId;
  final String categoryName;
  final String? categorySlug;
  final String? categoryIconUrl;
  /// True when the server has a certification document on file for this skill.
  /// The actual URL is never sent to the client; use the authenticated
  /// document-access endpoint if the document itself needs to be viewed.
  final bool hasCertificationDoc;

  factory WorkerOnboardingSkillItem.fromJson(Map<String, dynamic> json) {
    final category = json['category'] is Map<String, dynamic>
        ? json['category'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return WorkerOnboardingSkillItem(
      categoryId: json['categoryId'] as String? ?? category['id'] as String? ?? '',
      categoryName: category['name'] as String? ?? json['name'] as String? ?? '',
      categorySlug: category['slug'] as String?,
      categoryIconUrl: category['iconUrl'] as String?,
      // New field from the API; backward-compat: fall back to checking the
      // old certificationDocUrl field for responses from an older backend.
      hasCertificationDoc: json['hasCertificationDoc'] as bool? ??
          (json['certificationDocUrl'] as String?)?.isNotEmpty == true,
    );
  }
}

class WorkerOnboardingProfile {
  const WorkerOnboardingProfile({
    required this.onboardingStatus,
    required this.fullName,
    required this.gender,
    required this.dateOfBirth,
    required this.addressLine1,
    required this.alternatePhone,
    required this.city,
    required this.pincode,
    required this.aadhaarNumber,
    required this.hasAadhaarDoc,
    required this.hasAvailability,
    required this.upiId,
    required this.bankAccountNumber,
    required this.bankIfsc,
    required this.toolsOwned,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    required this.agreementAcceptedAt,
    required this.dataConsentAcceptedAt,
    required this.phone,
    required this.email,
    required this.rejectionReason,
    required this.skills,
  });

  final String onboardingStatus;
  final String? fullName;
  final String? gender;
  final DateTime? dateOfBirth;
  final String? addressLine1;
  final String? alternatePhone;
  final String? city;
  final String? pincode;
  final String? aadhaarNumber;
  /// True when the server has an Aadhaar document on file.
  /// The raw URL is never sent to the client; use the authenticated
  /// document-access endpoint if the document itself needs to be viewed.
  final bool hasAadhaarDoc;
  final bool hasAvailability;
  final String? upiId;
  final String? bankAccountNumber;
  final String? bankIfsc;
  final List<String> toolsOwned;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final DateTime? agreementAcceptedAt;
  final DateTime? dataConsentAcceptedAt;
  final String? phone;
  final String? email;
  final String? rejectionReason;
  final List<WorkerOnboardingSkillItem> skills;

  factory WorkerOnboardingProfile.fromJson(Map<String, dynamic> json) {
    List<String> decodeToolsOwned(dynamic value) {
      if (value is! List) {
        return const [];
      }
      return value.whereType<String>().map((item) => item.trim()).where((item) => item.isNotEmpty).toList(growable: false);
    }

    final user = json['user'] is Map<String, dynamic> ? json['user'] as Map<String, dynamic> : const <String, dynamic>{};

    return WorkerOnboardingProfile(
      onboardingStatus: json['onboardingStatus'] as String? ?? 'pending_documents',
      fullName: json['fullName'] as String?,
      gender: json['gender'] as String?,
      dateOfBirth: DateTime.tryParse(json['dateOfBirth'] as String? ?? ''),
      addressLine1: json['addressLine1'] as String?,
      alternatePhone: json['alternatePhone'] as String?,
      city: json['city'] as String?,
      pincode: json['pincode'] as String?,
      aadhaarNumber: json['aadhaarNumber'] as String?,
      // New field from the API; backward-compat: fall back to checking the
      // old aadhaarDocUrl field for responses from an older backend.
      hasAadhaarDoc: json['hasAadhaarDoc'] as bool? ??
          (json['aadhaarDocUrl'] as String?)?.isNotEmpty == true,
      hasAvailability: json['hasAvailability'] as bool? ?? false,
      upiId: json['upiId'] as String?,
      bankAccountNumber: json['bankAccountNumber'] as String?,
      bankIfsc: json['bankIfsc'] as String?,
      toolsOwned: decodeToolsOwned(json['toolsOwned']),
      emergencyContactName: json['emergencyContactName'] as String?,
      emergencyContactPhone: json['emergencyContactPhone'] as String?,
      agreementAcceptedAt: DateTime.tryParse(json['agreementAcceptedAt'] as String? ?? ''),
      dataConsentAcceptedAt: DateTime.tryParse(json['dataConsentAcceptedAt'] as String? ?? ''),
      phone: user['phone'] as String?,
      email: user['email'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
      skills: _decodeSkills(json['skills']),
    );
  }

  Set<String> get selectedCategoryIds =>
      skills.map((skill) => skill.categoryId).where((value) => value.isNotEmpty).toSet();

  String? maskedAadhaar() {
    final raw = aadhaarNumber?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    if (raw.isEmpty) {
      return null;
    }

    final last4 = raw.length >= 4 ? raw.substring(raw.length - 4) : raw.padLeft(4, '0');
    return 'XXXX-XXXX-$last4';
  }
}

class WorkerOnboardingDraft {
  const WorkerOnboardingDraft({
    this.fullName = '',
    this.gender,
    this.dateOfBirth,
    this.addressLine1 = '',
    this.alternatePhone = '',
    this.city = '',
    this.pincode = '',
    this.aadhaarNumber = '',
    this.upiId = '',
    this.bankAccountNumber = '',
    this.bankIfsc = '',
    this.toolsOwned = const <String>[],
    this.emergencyContactName = '',
    this.emergencyContactPhone = '',
    this.agreementAccepted = false,
    this.dataConsentAccepted = false,
    this.selectedCategoryIds = const <String>{},
    this.selectedServiceIds = const <String>{},
    this.certificationFiles = const <String, XFile>{},
    this.certificationUrls = const <String, bool>{},
    this.aadhaarDocumentFile,
    this.savedAadhaarMask,
  });

  final String fullName;
  final String? gender;
  final DateTime? dateOfBirth;
  final String addressLine1;
  final String alternatePhone;
  final String city;
  final String pincode;
  final String aadhaarNumber;
  final String upiId;
  final String bankAccountNumber;
  final String bankIfsc;
  final List<String> toolsOwned;
  final String emergencyContactName;
  final String emergencyContactPhone;
  final bool agreementAccepted;
  final bool dataConsentAccepted;
  final Set<String> selectedCategoryIds;
  final Set<String> selectedServiceIds;
  final Map<String, XFile> certificationFiles;
  /// Maps categoryId → true for skills that have a certification document on
  /// the server. The raw URL is never sent to the client; use the
  /// authenticated document-access endpoint when the document must be viewed.
  final Map<String, bool> certificationUrls;
  final XFile? aadhaarDocumentFile;
  final String? savedAadhaarMask;

  WorkerOnboardingDraft copyWith({
    String? fullName,
    Object? gender = _unset,
    Object? dateOfBirth = _unset,
    String? addressLine1,
    String? alternatePhone,
    String? city,
    String? pincode,
    String? aadhaarNumber,
    String? upiId,
    String? bankAccountNumber,
    String? bankIfsc,
    List<String>? toolsOwned,
    String? emergencyContactName,
    String? emergencyContactPhone,
    bool? agreementAccepted,
    bool? dataConsentAccepted,
    Set<String>? selectedCategoryIds,
    Set<String>? selectedServiceIds,
    Map<String, XFile>? certificationFiles,
    Map<String, bool>? certificationUrls,
    Object? aadhaarDocumentFile = _unset,
    Object? savedAadhaarMask = _unset,
  }) {
    return WorkerOnboardingDraft(
      fullName: fullName ?? this.fullName,
      gender: identical(gender, _unset) ? this.gender : gender as String?,
      dateOfBirth: identical(dateOfBirth, _unset) ? this.dateOfBirth : dateOfBirth as DateTime?,
      addressLine1: addressLine1 ?? this.addressLine1,
      alternatePhone: alternatePhone ?? this.alternatePhone,
      city: city ?? this.city,
      pincode: pincode ?? this.pincode,
      aadhaarNumber: aadhaarNumber ?? this.aadhaarNumber,
      upiId: upiId ?? this.upiId,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankIfsc: bankIfsc ?? this.bankIfsc,
      toolsOwned: toolsOwned ?? this.toolsOwned,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
      agreementAccepted: agreementAccepted ?? this.agreementAccepted,
      dataConsentAccepted: dataConsentAccepted ?? this.dataConsentAccepted,
      selectedCategoryIds: selectedCategoryIds ?? this.selectedCategoryIds,
      selectedServiceIds: selectedServiceIds ?? this.selectedServiceIds,
      certificationFiles: certificationFiles ?? this.certificationFiles,
      certificationUrls: certificationUrls ?? this.certificationUrls,
      aadhaarDocumentFile: identical(aadhaarDocumentFile, _unset)
          ? this.aadhaarDocumentFile
          : aadhaarDocumentFile as XFile?,
      savedAadhaarMask: identical(savedAadhaarMask, _unset)
          ? this.savedAadhaarMask
          : savedAadhaarMask as String?,
    );
  }

  bool get hasIdentityDocument => savedAadhaarMask != null;
}

class WorkerOnboardingState {
  const WorkerOnboardingState({
    this.profile,
    this.categories = const <CatalogCategory>[],
    this.draft = const WorkerOnboardingDraft(),
    this.currentStep = 0,
    this.isLoadingProfile = false,
    this.isLoadingCategories = false,
    this.isSavingProfile = false,
    this.isUploadingDocument = false,
    this.isSavingSkills = false,
    this.isSubmitting = false,
    this.isEditMode = false,
    this.errorMessage,
    this.submitError,
    this.missingFields = const <String>[],
  });

  final WorkerOnboardingProfile? profile;
  final List<CatalogCategory> categories;
  final WorkerOnboardingDraft draft;
  final int currentStep;
  final bool isLoadingProfile;
  final bool isLoadingCategories;
  final bool isSavingProfile;
  final bool isUploadingDocument;
  final bool isSavingSkills;
  final bool isSubmitting;
  final bool isEditMode;
  final String? errorMessage;
  final String? submitError;
  final List<String> missingFields;

  String get status => profile?.onboardingStatus ?? 'pending_documents';
  String? get rejectionReason => profile?.rejectionReason;

  bool get isBusy =>
      isLoadingProfile || isLoadingCategories || isSavingProfile || isUploadingDocument || isSavingSkills || isSubmitting;

  WorkerOnboardingState copyWith({
    Object? profile = _unset,
    List<CatalogCategory>? categories,
    WorkerOnboardingDraft? draft,
    int? currentStep,
    bool? isLoadingProfile,
    bool? isLoadingCategories,
    bool? isSavingProfile,
    bool? isUploadingDocument,
    bool? isSavingSkills,
    bool? isSubmitting,
    bool? isEditMode,
    Object? errorMessage = _unset,
    Object? submitError = _unset,
    List<String>? missingFields,
  }) {
    return WorkerOnboardingState(
      profile: identical(profile, _unset) ? this.profile : profile as WorkerOnboardingProfile?,
      categories: categories ?? this.categories,
      draft: draft ?? this.draft,
      currentStep: currentStep ?? this.currentStep,
      isLoadingProfile: isLoadingProfile ?? this.isLoadingProfile,
      isLoadingCategories: isLoadingCategories ?? this.isLoadingCategories,
      isSavingProfile: isSavingProfile ?? this.isSavingProfile,
      isUploadingDocument: isUploadingDocument ?? this.isUploadingDocument,
      isSavingSkills: isSavingSkills ?? this.isSavingSkills,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isEditMode: isEditMode ?? this.isEditMode,
      errorMessage: identical(errorMessage, _unset) ? this.errorMessage : errorMessage as String?,
      submitError: identical(submitError, _unset) ? this.submitError : submitError as String?,
      missingFields: missingFields ?? this.missingFields,
    );
  }
}

class WorkerOnboardingApi {
  WorkerOnboardingApi(this._dio);

  final Dio _dio;

  Future<WorkerOnboardingProfile> fetchStatus() async {
    final response = await _dio.get<Map<String, dynamic>>('/worker/onboarding/status');
    final payload = response.data ?? <String, dynamic>{};
    final profile = payload['profile'];
    if (profile is Map<String, dynamic>) {
      return WorkerOnboardingProfile.fromJson(profile);
    }
    throw StateError('Onboarding status response was malformed.');
  }

  Future<WorkerOnboardingProfile> updateProfile({
    String? fullName,
    String? gender,
    DateTime? dateOfBirth,
    String? addressLine1,
    String? alternatePhone,
    String? city,
    String? pincode,
    String? upiId,
    String? bankAccountNumber,
    String? bankIfsc,
    String? aadhaarNumber,
    List<String>? toolsOwned,
    String? emergencyContactName,
    String? emergencyContactPhone,
    bool? agreementAccepted,
    bool? dataConsentAccepted,
  }) async {
    final body = <String, dynamic>{};
    if (fullName != null) body['fullName'] = fullName;
    if (gender != null) body['gender'] = gender;
    if (dateOfBirth != null) body['dateOfBirth'] = dateOfBirth.toIso8601String();
    if (addressLine1 != null) body['addressLine1'] = addressLine1;
    if (alternatePhone != null) body['alternatePhone'] = alternatePhone;
    if (city != null) body['city'] = city;
    if (pincode != null) body['pincode'] = pincode;
    if (upiId != null) body['upiId'] = upiId;
    if (bankAccountNumber != null) body['bankAccountNumber'] = bankAccountNumber;
    if (bankIfsc != null) body['bankIfsc'] = bankIfsc;
    if (aadhaarNumber != null) body['aadhaarNumber'] = aadhaarNumber;
    if (toolsOwned != null) body['toolsOwned'] = toolsOwned;
    if (emergencyContactName != null) body['emergencyContactName'] = emergencyContactName;
    if (emergencyContactPhone != null) body['emergencyContactPhone'] = emergencyContactPhone;
    if (agreementAccepted != null) body['agreementAccepted'] = agreementAccepted;
    if (dataConsentAccepted != null) body['dataConsentAccepted'] = dataConsentAccepted;

    final response = await _dio.post<Map<String, dynamic>>(
      '/worker/onboarding/profile',
      data: body,
    );
    return _parseProfileResponse(response.data);
  }

  Future<WorkerOnboardingProfile> uploadDocument({
    required String docType,
    required String fileUrl,
    String? categoryId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/worker/onboarding/documents',
      data: {
        'docType': docType,
        'fileUrl': fileUrl,
        if (categoryId != null) 'categoryId': categoryId,
      },
    );
    return _parseProfileResponse(response.data);
  }

  Future<WorkerOnboardingProfile> addSkill(String categoryId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/worker/onboarding/skills',
      data: {
        'categoryId': categoryId,
      },
    );
    return _parseProfileResponse(response.data);
  }

  Future<WorkerOnboardingProfile> addService(String serviceId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/worker/onboarding/services',
      data: {
        'serviceId': serviceId,
      },
    );
    return _parseProfileResponse(response.data);
  }

  Future<WorkerOnboardingProfile> submitForReview() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/worker/onboarding/submit',
      data: const <String, dynamic>{},
    );
    return _parseProfileResponse(response.data);
  }

  Future<List<CatalogCategory>> fetchCategories() async {
    final response = await _dio.get<Map<String, dynamic>>('/catalog');
    final payload = response.data ?? <String, dynamic>{};
    final categories = payload['categories'];
    if (categories is! List) {
      return const <CatalogCategory>[];
    }

    final summaryCategories = categories.whereType<Map<String, dynamic>>().map(CatalogCategory.fromJson).toList(growable: false);
    final detailed = <CatalogCategory>[];
    for (final category in summaryCategories) {
      final detailResponse = await _dio.get<Map<String, dynamic>>('/catalog/categories/${category.slug}');
      final categoryJson = detailResponse.data?['category'];
      if (categoryJson is Map<String, dynamic>) {
        detailed.add(CatalogCategory.fromJson(categoryJson));
      } else {
        detailed.add(category);
      }
    }
    return detailed;
  }

  Future<String> uploadDocumentAsset({
    required XFile file,
    required String userId,
    required String type,
  }) async {
    final fileName = file.name.isNotEmpty ? file.name : 'document.jpg';
    return _retryTransient<String>(() async {
      final signatureResponse = await _dio.post<Map<String, dynamic>>(
        '/uploads/signature',
        data: {
          'bookingId': 'onboarding-$userId',
          'type': 'before',
        },
      );

      final payload = signatureResponse.data ?? <String, dynamic>{};
      final uploadUrl = payload['uploadUrl'] as String? ?? '';
      final folder = payload['folder'] as String? ?? '';
      final apiKey = payload['apiKey'] as String? ?? '';
      final timestamp = payload['timestamp'];
      final signature = payload['signature'] as String? ?? '';

      if (uploadUrl.isEmpty || apiKey.isEmpty || folder.isEmpty || signature.isEmpty) {
        throw StateError('Cloudinary signature response was incomplete.');
      }

      try {
        return await _uploadDirectToCloudinary(
          uploadUrl: uploadUrl,
          apiKey: apiKey,
          folder: folder,
          timestamp: timestamp,
          signature: signature,
          file: file,
          fileName: fileName,
        );
      } catch (_) {
        final fallback = await _dio.post<Map<String, dynamic>>(
          '/media/workers/document',
          data: FormData.fromMap({
            'type': type,
            'file': await MultipartFile.fromFile(file.path, filename: fileName),
          }),
          options: Options(
            contentType: Headers.multipartFormDataContentType,
            responseType: ResponseType.json,
          ),
        );
        final fallbackData = fallback.data ?? <String, dynamic>{};
        final document = fallbackData['document'];
        if (document is Map<String, dynamic>) {
          final url = document['url'] as String?;
          if (url != null && url.isNotEmpty) {
            return url;
          }
        }

        throw StateError('Cloudinary upload failed.');
      }
    });
  }

  Future<String> _uploadDirectToCloudinary({
    required String uploadUrl,
    required String apiKey,
    required String folder,
    required dynamic timestamp,
    required String signature,
    required XFile file,
    required String fileName,
  }) async {
    final uploadDio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
      ),
    );

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: fileName),
      'api_key': apiKey,
      'folder': folder,
      'timestamp': timestamp.toString(),
      'signature': signature,
    });

    final response = await uploadDio.post<Map<String, dynamic>>(
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

  WorkerOnboardingProfile _parseProfileResponse(Map<String, dynamic>? data) {
    final payload = data ?? <String, dynamic>{};
    final profile = payload['profile'];
    if (profile is Map<String, dynamic>) {
      return WorkerOnboardingProfile.fromJson(profile);
    }
    throw StateError('Onboarding response was malformed.');
  }
}

final workerOnboardingApiProvider = Provider<WorkerOnboardingApi>((ref) {
  return WorkerOnboardingApi(ref.watch(apiClientProvider).dio);
});

final workerOnboardingStatusProvider = FutureProvider<WorkerOnboardingProfile?>((ref) async {
  try {
    return await ref.watch(workerOnboardingApiProvider).fetchStatus();
  } catch (_) {
    return null;
  }
});

final onboardingControllerProvider = StateNotifierProvider<WorkerOnboardingController, WorkerOnboardingState>((ref) {
  return WorkerOnboardingController(ref);
});

class WorkerOnboardingController extends StateNotifier<WorkerOnboardingState> {
  WorkerOnboardingController(this.ref) : super(const WorkerOnboardingState());

  final Ref ref;
  final ImagePicker _imagePicker = ImagePicker();

  WorkerOnboardingApi get _api => ref.read(workerOnboardingApiProvider);

  Future<void> bootstrap({
    bool editMode = false,
    int? step,
  }) async {
    if (state.isLoadingProfile || state.isLoadingCategories) {
      return;
    }

    state = state.copyWith(
      isLoadingProfile: true,
      isLoadingCategories: true,
      errorMessage: null,
      submitError: null,
      missingFields: const <String>[],
      isEditMode: editMode,
    );

    try {
      final results = await Future.wait([
        _api.fetchStatus(),
        _api.fetchCategories(),
      ]);

      final profile = results[0] as WorkerOnboardingProfile;
      final categories = results[1] as List<CatalogCategory>;
      state = state.copyWith(
        profile: profile,
        categories: categories,
        draft: _draftFromProfile(profile),
        currentStep: _resolveInitialStep(profile, editMode: editMode, step: step),
      );
    } catch (error) {
      state = state.copyWith(
        errorMessage: _readErrorMessage(error),
      );
    } finally {
      state = state.copyWith(
        isLoadingProfile: false,
        isLoadingCategories: false,
      );
    }
  }

  Future<void> refreshStatus() async {
    final profile = await _api.fetchStatus();
    state = state.copyWith(
      profile: profile,
      draft: _draftFromProfile(profile).copyWith(
        selectedCategoryIds: state.draft.selectedCategoryIds,
        selectedServiceIds: state.draft.selectedServiceIds,
        certificationFiles: state.draft.certificationFiles,
      ),
    );
  }

  void setStep(int step) {
    state = state.copyWith(currentStep: step.clamp(0, 7));
  }

  void nextStep() {
    setStep(state.currentStep + 1);
  }

  void previousStep() {
    setStep(state.currentStep - 1);
  }

  void setEditMode(bool editMode, {int? step}) {
    state = state.copyWith(
      isEditMode: editMode,
      currentStep: step ?? state.currentStep,
    );
  }

  void updatePersonalDetails({
    String? fullName,
    String? gender,
    DateTime? dateOfBirth,
    String? addressLine1,
    String? alternatePhone,
    String? city,
    String? pincode,
  }) {
    state = state.copyWith(
      draft: state.draft.copyWith(
        fullName: fullName,
        gender: gender,
        dateOfBirth: dateOfBirth,
        addressLine1: addressLine1,
        alternatePhone: alternatePhone,
        city: city,
        pincode: pincode,
      ),
    );
  }

  void updateIdentityDetails({
    String? aadhaarNumber,
    XFile? aadhaarDocumentFile,
    String? savedAadhaarMask,
  }) {
    state = state.copyWith(
      draft: state.draft.copyWith(
        aadhaarNumber: aadhaarNumber,
        aadhaarDocumentFile: aadhaarDocumentFile,
        savedAadhaarMask: savedAadhaarMask,
      ),
    );
  }

  void updateSkillsDetails({List<String>? toolsOwned}) {
    state = state.copyWith(
      draft: state.draft.copyWith(
        toolsOwned: toolsOwned,
      ),
    );
  }

  void setAadhaarDocumentFile(XFile? file) {
    state = state.copyWith(
      draft: state.draft.copyWith(aadhaarDocumentFile: file),
    );
  }

  void updateBankDetails({
    String? upiId,
    String? bankAccountNumber,
    String? bankIfsc,
  }) {
    state = state.copyWith(
      draft: state.draft.copyWith(
        upiId: upiId,
        bankAccountNumber: bankAccountNumber,
        bankIfsc: bankIfsc,
      ),
    );
  }

  void updateComplianceDetails({
    bool? agreementAccepted,
    bool? dataConsentAccepted,
  }) {
    state = state.copyWith(
      draft: state.draft.copyWith(
        agreementAccepted: agreementAccepted,
        dataConsentAccepted: dataConsentAccepted,
      ),
    );
  }

  void updateEmergencyContact({
    String? emergencyContactName,
    String? emergencyContactPhone,
  }) {
    state = state.copyWith(
      draft: state.draft.copyWith(
        emergencyContactName: emergencyContactName,
        emergencyContactPhone: emergencyContactPhone,
      ),
    );
  }

  void toggleCategory(String categoryId, bool selected) {
    final nextSelection = Set<String>.from(state.draft.selectedCategoryIds);
    final nextServices = Set<String>.from(state.draft.selectedServiceIds);
    final category = _findCategory(categoryId);
    final serviceIds = _serviceIdsForCategory(category);
    if (selected) {
      nextSelection.add(categoryId);
      nextServices.addAll(serviceIds);
    } else {
      nextSelection.remove(categoryId);
      for (final serviceId in serviceIds) {
        nextServices.remove(serviceId);
      }
    }

    state = state.copyWith(
      draft: state.draft.copyWith(
        selectedCategoryIds: nextSelection,
        selectedServiceIds: nextServices,
      ),
    );
  }

  void toggleService(String serviceId, bool selected) {
    final nextCategories = Set<String>.from(state.draft.selectedCategoryIds);
    final nextServices = Set<String>.from(state.draft.selectedServiceIds);
    final service = _findService(serviceId);
    if (service == null) {
      return;
    }

    if (selected) {
      nextServices.add(serviceId);
      nextCategories.add(service.categoryId);
    } else {
      nextServices.remove(serviceId);
      final remainingForCategory = nextServices.any((id) => _findService(id)?.categoryId == service.categoryId);
      if (!remainingForCategory) {
        nextCategories.remove(service.categoryId);
      }
    }

    state = state.copyWith(
      draft: state.draft.copyWith(
        selectedCategoryIds: nextCategories,
        selectedServiceIds: nextServices,
      ),
    );
  }

  void setCertificationFile(String categoryId, XFile file) {
    final files = Map<String, XFile>.from(state.draft.certificationFiles)..[categoryId] = file;
    state = state.copyWith(
      draft: state.draft.copyWith(certificationFiles: files),
    );
  }

  void clearCertificationFile(String categoryId) {
    final files = Map<String, XFile>.from(state.draft.certificationFiles)..remove(categoryId);
    state = state.copyWith(
      draft: state.draft.copyWith(certificationFiles: files),
    );
  }

  Future<void> savePersonalDetails() async {
    state = state.copyWith(isSavingProfile: true, errorMessage: null);
    try {
      final alternatePhone = state.draft.alternatePhone.trim();
      final upiId = state.draft.upiId.trim();
      final bankAccountNumber = state.draft.bankAccountNumber.trim();
      final bankIfsc = state.draft.bankIfsc.trim();
      final aadhaarNumber = state.draft.aadhaarNumber.trim();
      final profile = await _api.updateProfile(
        fullName: state.draft.fullName.trim(),
        gender: state.draft.gender,
        dateOfBirth: state.draft.dateOfBirth,
        addressLine1: state.draft.addressLine1.trim(),
        alternatePhone: alternatePhone.isEmpty ? null : alternatePhone,
        city: state.draft.city.trim(),
        pincode: state.draft.pincode.trim(),
        upiId: upiId.isEmpty ? null : upiId,
        bankAccountNumber: bankAccountNumber.isEmpty ? null : bankAccountNumber,
        bankIfsc: bankIfsc.isEmpty ? null : bankIfsc,
        aadhaarNumber: aadhaarNumber.isEmpty ? null : aadhaarNumber,
      );
      state = state.copyWith(
        profile: profile,
        draft: _draftFromProfile(profile).copyWith(
          selectedCategoryIds: state.draft.selectedCategoryIds,
          selectedServiceIds: state.draft.selectedServiceIds,
          certificationFiles: state.draft.certificationFiles,
        ),
      );
    } catch (error) {
      state = state.copyWith(errorMessage: _readErrorMessage(error));
      rethrow;
    } finally {
      state = state.copyWith(isSavingProfile: false);
    }
  }

  Future<void> saveIdentityDocument(XFile documentFile) async {
    state = state.copyWith(isUploadingDocument: true, errorMessage: null);
    try {
      final userId = ref.read(authControllerProvider).valueOrNull?.user.id ?? 'worker';
      final fileUrl = await _api.uploadDocumentAsset(
        file: documentFile,
        userId: userId,
        type: 'aadhaar',
      );
      final profile = await _api.uploadDocument(
        docType: 'aadhaar',
        fileUrl: fileUrl,
      );
      state = state.copyWith(
        profile: profile,
        draft: _draftFromProfile(profile).copyWith(
          selectedCategoryIds: state.draft.selectedCategoryIds,
          selectedServiceIds: state.draft.selectedServiceIds,
          certificationFiles: state.draft.certificationFiles,
          aadhaarDocumentFile: null,
        ),
      );
    } catch (error) {
      state = state.copyWith(errorMessage: _readErrorMessage(error));
      rethrow;
    } finally {
      state = state.copyWith(isUploadingDocument: false);
    }
  }

  Future<void> saveSkills() async {
    state = state.copyWith(isSavingSkills: true, errorMessage: null);
    try {
      await _api.updateProfile(
        toolsOwned: state.draft.toolsOwned,
      );

      var profile = state.profile;
      final userId = ref.read(authControllerProvider).valueOrNull?.user.id ?? 'worker';

      for (final serviceId in state.draft.selectedServiceIds) {
        profile = await _api.addService(serviceId);
      }

      final selectedServiceCategoryIds = <String>{
        for (final serviceId in state.draft.selectedServiceIds)
          if (_findService(serviceId) != null) _findService(serviceId)!.categoryId,
      };

      for (final categoryId in {
        ...state.draft.selectedCategoryIds,
        ...selectedServiceCategoryIds,
      }) {
        profile = await _api.addSkill(categoryId);
        final certificate = state.draft.certificationFiles[categoryId];
        if (certificate != null) {
          final uploadedUrl = await _api.uploadDocumentAsset(
            file: certificate,
            userId: userId,
            type: 'skill_certification',
          );
          profile = await _api.uploadDocument(
            docType: 'skill_certification',
            fileUrl: uploadedUrl,
            categoryId: categoryId,
          );
        }
      }

      if (profile != null) {
        state = state.copyWith(
          profile: profile,
          draft: _draftFromProfile(profile).copyWith(
            certificationFiles: state.draft.certificationFiles,
          ),
        );
      }
    } catch (error) {
      state = state.copyWith(errorMessage: _readErrorMessage(error));
      rethrow;
    } finally {
      state = state.copyWith(isSavingSkills: false);
    }
  }

  Future<void> saveBankDetails() async {
    await savePersonalDetails();
  }

  Future<void> saveComplianceDetails() async {
    state = state.copyWith(isSavingProfile: true, errorMessage: null);
    try {
      final profile = await _api.updateProfile(
        agreementAccepted: state.draft.agreementAccepted,
        dataConsentAccepted: state.draft.dataConsentAccepted,
      );
      state = state.copyWith(profile: profile);
    } catch (error) {
      state = state.copyWith(errorMessage: _readErrorMessage(error));
      rethrow;
    } finally {
      state = state.copyWith(isSavingProfile: false);
    }
  }

  Future<void> saveEmergencyContact() async {
    state = state.copyWith(isSavingProfile: true, errorMessage: null);
    try {
      final profile = await _api.updateProfile(
        emergencyContactName: state.draft.emergencyContactName.trim(),
        emergencyContactPhone: state.draft.emergencyContactPhone.trim(),
      );
      state = state.copyWith(profile: profile);
    } catch (error) {
      state = state.copyWith(errorMessage: _readErrorMessage(error));
      rethrow;
    } finally {
      state = state.copyWith(isSavingProfile: false);
    }
  }

  Future<WorkerOnboardingProfile?> submitForReview() async {
    state = state.copyWith(isSubmitting: true, errorMessage: null, submitError: null, missingFields: const <String>[]);
    try {
      final profile = await _api.submitForReview();
      state = state.copyWith(
        profile: profile,
        draft: _draftFromProfile(profile).copyWith(
          selectedCategoryIds: state.draft.selectedCategoryIds,
          selectedServiceIds: state.draft.selectedServiceIds,
          certificationFiles: state.draft.certificationFiles,
        ),
      );
      ref.invalidate(workerOnboardingStatusProvider);
      return profile;
    } catch (error) {
      final message = _readErrorMessage(error);
      final missingFields = _extractMissingFields(error);
      state = state.copyWith(
        submitError: message,
        missingFields: missingFields,
        currentStep: missingFields.isNotEmpty ? _stepForField(missingFields.first) : state.currentStep,
      );
      rethrow;
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }

  Future<void> loadCategories() async {
    if (state.categories.isNotEmpty) {
      return;
    }
    state = state.copyWith(isLoadingCategories: true);
    try {
      final categories = await _api.fetchCategories();
      state = state.copyWith(categories: categories);
    } finally {
      state = state.copyWith(isLoadingCategories: false);
    }
  }

  Future<void> pickAndSaveIdentityDocument() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (picked == null) {
      return;
    }
    await saveIdentityDocument(picked);
  }

  Future<void> pickAndSetCertificationFile(String categoryId) async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (picked == null) {
      return;
    }
    setCertificationFile(categoryId, picked);
  }

  CatalogCategory? _findCategory(String categoryId) {
    for (final category in state.categories) {
      if (category.id == categoryId) {
        return category;
      }
    }
    return null;
  }

  CatalogService? _findService(String serviceId) {
    for (final category in state.categories) {
      for (final subcategory in category.subcategories) {
        for (final service in subcategory.services) {
          if (service.id == serviceId) {
            return service;
          }
        }
      }
    }
    return null;
  }

  List<String> _serviceIdsForCategory(CatalogCategory? category) {
    if (category == null) {
      return const <String>[];
    }

    final result = <String>[];
    for (final subcategory in category.subcategories) {
      for (final service in subcategory.services) {
        result.add(service.id);
      }
    }
    return result;
  }

  WorkerOnboardingDraft _draftFromProfile(WorkerOnboardingProfile profile) {
    return WorkerOnboardingDraft(
      fullName: profile.fullName ?? '',
      gender: profile.gender,
      dateOfBirth: profile.dateOfBirth,
      addressLine1: profile.addressLine1 ?? '',
      alternatePhone: profile.alternatePhone ?? '',
      city: profile.city ?? '',
      pincode: profile.pincode ?? '',
      aadhaarNumber: '',
      upiId: profile.upiId ?? '',
      bankAccountNumber: profile.bankAccountNumber ?? '',
      bankIfsc: profile.bankIfsc ?? '',
      toolsOwned: profile.toolsOwned,
      emergencyContactName: profile.emergencyContactName ?? '',
      emergencyContactPhone: profile.emergencyContactPhone ?? '',
      agreementAccepted: profile.agreementAcceptedAt != null,
      dataConsentAccepted: profile.dataConsentAcceptedAt != null,
      selectedCategoryIds: profile.selectedCategoryIds,
      selectedServiceIds: state.draft.selectedServiceIds,
      aadhaarDocumentFile: state.draft.aadhaarDocumentFile,
      savedAadhaarMask: profile.maskedAadhaar(),
      certificationFiles: state.draft.certificationFiles,
      certificationUrls: _certificationUrlsFromProfile(profile),
    );
  }

  /// Returns a map of categoryId → hasCertificationDoc (bool) for skills
  /// that have a certification document on file.  The raw URL is never
  /// available on the client; use the authenticated document-access endpoint
  /// to retrieve the actual document when needed.
  Map<String, bool> _certificationUrlsFromProfile(WorkerOnboardingProfile profile) {
    final result = <String, bool>{};
    for (final skill in profile.skills) {
      if (skill.hasCertificationDoc) {
        result[skill.categoryId] = true;
      }
    }
    return result;
  }

  int _resolveInitialStep(WorkerOnboardingProfile profile, {required bool editMode, int? step}) {
    if (step != null) {
      return step.clamp(0, 7);
    }

    if (editMode) {
      return _stepForProfile(profile);
    }

    return _stepForProfile(profile);
  }

  int _stepForProfile(WorkerOnboardingProfile profile) {
    if (profile.fullName == null ||
        profile.dateOfBirth == null ||
        profile.addressLine1 == null ||
        profile.city == null ||
        profile.pincode == null) {
      return 0;
    }

    if (!profile.hasAadhaarDoc) {
      return 1;
    }

    if (profile.selectedCategoryIds.isEmpty) {
      return 2;
    }

    final hasUpi = profile.upiId != null && profile.upiId!.trim().isNotEmpty;
    final hasBankFallback = (profile.bankAccountNumber != null && profile.bankAccountNumber!.trim().isNotEmpty) &&
        (profile.bankIfsc != null && profile.bankIfsc!.trim().isNotEmpty);
    if (!hasUpi && !hasBankFallback) {
      return 3;
    }

    if (!profile.hasAvailability) {
      return 4;
    }

    if (profile.agreementAcceptedAt == null || profile.dataConsentAcceptedAt == null) {
      return 5;
    }

    if (profile.emergencyContactName == null || profile.emergencyContactPhone == null) {
      return 6;
    }

    return 7;
  }

  int _stepForField(String field) {
    switch (field) {
      case 'fullName':
      case 'dateOfBirth':
      case 'addressLine1':
      case 'city':
      case 'pincode':
        return 0;
      case 'aadhaarNumber':
      case 'hasAadhaarDoc':
        return 1;
      case 'skills':
        return 2;
      case 'upiId':
      case 'bankAccountNumber':
      case 'bankIfsc':
        return 3;
      case 'availability':
        return 4;
      case 'agreementAcceptedAt':
      case 'dataConsentAcceptedAt':
        return 5;
      case 'emergencyContactName':
      case 'emergencyContactPhone':
        return 6;
      default:
        return 0;
    }
  }

  List<String> _extractMissingFields(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final missingFields = data['missingFields'];
        if (missingFields is List) {
          return missingFields.whereType<String>().toList(growable: false);
        }
      }
    }
    return const <String>[];
  }

  String _readErrorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final message = data['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message;
        }
      }
      if (error.message != null && error.message!.trim().isNotEmpty) {
        return error.message!;
      }
    }
    return error.toString();
  }
}

Future<T> _retryTransient<T>(
  Future<T> Function() action, {
  int attempts = 3,
  Duration delay = const Duration(milliseconds: 500),
}) async {
  Object? lastError;
  for (var attempt = 1; attempt <= attempts; attempt++) {
    try {
      return await action();
    } catch (error) {
      lastError = error;
      if (attempt == attempts) {
        rethrow;
      }
      await Future.delayed(Duration(milliseconds: delay.inMilliseconds * attempt));
    }
  }
  throw lastError ?? StateError('Retry failed.');
}

List<WorkerOnboardingSkillItem> _decodeSkills(dynamic data) {
  if (data is! List) {
    return const <WorkerOnboardingSkillItem>[];
  }

  return data
      .whereType<Map<String, dynamic>>()
      .map(WorkerOnboardingSkillItem.fromJson)
      .toList(growable: false);
}

const Object _unset = Object();
