import 'package:dio/dio.dart';

class SavedAddressItem {
  const SavedAddressItem({
    required this.id,
    required this.label,
    required this.addressLine1,
    required this.city,
    required this.pincode,
    required this.lat,
    required this.lng,
    required this.isDefault,
    this.addressLine2,
    this.landmark,
  });

  final String id;
  final String label;
  final String addressLine1;
  final String? addressLine2;
  final String? landmark;
  final String city;
  final String pincode;
  final double lat;
  final double lng;
  final bool isDefault;

  factory SavedAddressItem.fromJson(Map<String, dynamic> json) {
    return SavedAddressItem(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      addressLine1: json['addressLine1'] as String? ?? '',
      addressLine2: json['addressLine2'] as String?,
      landmark: json['landmark'] as String?,
      city: json['city'] as String? ?? '',
      pincode: json['pincode'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'addressLine1': addressLine1,
      'addressLine2': addressLine2,
      'landmark': landmark,
      'city': city,
      'pincode': pincode,
      'lat': lat,
      'lng': lng,
      'isDefault': isDefault,
    };
  }

  String get displayAddress {
    final buffer = StringBuffer(addressLine1);
    if ((addressLine2 ?? '').trim().isNotEmpty) {
      buffer.write(', ${addressLine2!.trim()}');
    }
    if ((landmark ?? '').trim().isNotEmpty) {
      buffer.write(' - ${landmark!.trim()}');
    }
    buffer.write(', $city $pincode');
    return buffer.toString();
  }
}

class SavedAddressesApi {
  SavedAddressesApi(this._dio);

  final Dio _dio;

  Future<List<SavedAddressItem>> listAddresses() async {
    final response = await _dio.get<Map<String, dynamic>>('/customer/addresses');
    final data = response.data ?? <String, dynamic>{};
    final addresses = data['addresses'];
    if (addresses is! List) {
      return <SavedAddressItem>[];
    }
    return addresses
        .whereType<Map>()
        .map((item) => SavedAddressItem.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<SavedAddressItem> createAddress(Map<String, dynamic> payload) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/customer/addresses',
      data: payload,
    );
    return SavedAddressItem.fromJson(
      (response.data ?? <String, dynamic>{})['address'] as Map<String, dynamic>,
    );
  }

  Future<SavedAddressItem> updateAddress(String addressId, Map<String, dynamic> payload) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/customer/addresses/$addressId',
      data: payload,
    );
    return SavedAddressItem.fromJson(
      (response.data ?? <String, dynamic>{})['address'] as Map<String, dynamic>,
    );
  }

  Future<void> deleteAddress(String addressId) async {
    await _dio.delete<void>('/customer/addresses/$addressId');
  }

  Future<SavedAddressItem> setDefaultAddress(String addressId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/customer/addresses/$addressId/set-default',
    );
    return SavedAddressItem.fromJson(
      (response.data ?? <String, dynamic>{})['address'] as Map<String, dynamic>,
    );
  }

  Future<bool> isServiceablePincode({
    required String pincode,
    String? city,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/service-areas/check',
      queryParameters: {
        'pincode': pincode,
        if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
      },
    );
    return response.data?['serviceable'] == true;
  }
}
