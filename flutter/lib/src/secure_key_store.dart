import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kApiKeyStorageKey = 'misar_blog_api_key';

/// Wraps [FlutterSecureStorage] to persist the Misar.Blog `mbk_` key securely
/// in the platform keychain (iOS Keychain / Android Keystore).
class SecureKeyStore {
  final FlutterSecureStorage _storage;

  const SecureKeyStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Persists [apiKey] in the device secure keystore.
  Future<void> saveApiKey(String apiKey) =>
      _storage.write(key: _kApiKeyStorageKey, value: apiKey);

  /// Returns the stored API key, or `null` if none has been saved.
  Future<String?> loadApiKey() => _storage.read(key: _kApiKeyStorageKey);

  /// Deletes the stored API key (call on logout).
  Future<void> deleteApiKey() => _storage.delete(key: _kApiKeyStorageKey);
}
