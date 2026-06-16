import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Uploads images to iDrive e2 (S3-compatible) using AWS Signature Version 4.
///
/// Each object is uploaded with [x-amz-acl: public-read] so the stored URL
/// is permanently accessible without signed tokens, even on private-default
/// buckets.
class StorageService {
  late final String _accessKeyId;
  late final String _secretAccessKey;
  late final String _endpoint;
  late final String _bucketName;
  late final String _region;
  late final String _publicBaseUrl;

  StorageService() {
    _accessKeyId     = dotenv.env['IDRIVE_E2_ACCESS_KEY_ID']!;
    _secretAccessKey = dotenv.env['IDRIVE_E2_SECRET_ACCESS_KEY']!;
    _bucketName      = dotenv.env['IDRIVE_E2_BUCKET_NAME']!;
    _region          = dotenv.env['IDRIVE_E2_REGION'] ?? 'us-east-1';

    _endpoint = dotenv.env['IDRIVE_E2_ENDPOINT']!
        .replaceAll(RegExp(r'^https?://'), '')
        .replaceAll(RegExp(r'/$'), '');

    _publicBaseUrl = dotenv.env['IDRIVE_E2_PUBLIC_BASE_URL']!
        .replaceAll(RegExp(r'/$'), '');
  }

  // ── Public API ────────────────────────────────────────────────────────────

  Future<String> uploadFoodImage(String userId, Uint8List imageBytes) async {
    final objectKey =
        'food_logs/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _putObject(objectKey, imageBytes, 'image/jpeg');
    return objectKey;
  }

  // ── SigV4 PUT ─────────────────────────────────────────────────────────────

  Future<void> _putObject(
      String key, Uint8List body, String contentType) async {
    final now       = DateTime.now().toUtc();
    final dateStamp = _yyyymmdd(now);
    final amzDate   = _iso8601(now);
    final bodyHash  = sha256.convert(body).toString();

    final encodedKey   = key.split('/').map(Uri.encodeComponent).join('/');
    final canonicalUri = '/$_bucketName/$encodedKey';
    final uri          = Uri.https(_endpoint, canonicalUri);

    // ── 1. Headers to sign (sorted alphabetically by key) ──────────────────
    //
    // x-amz-acl: public-read  →  makes this object publicly readable
    // regardless of the bucket's default ACL.
    final headersToSign = <String, String>{
      'content-type'         : contentType,
      'host'                 : _endpoint,
      'x-amz-acl'           : 'public-read',
      'x-amz-content-sha256' : bodyHash,
      'x-amz-date'           : amzDate,
    };

    final sortedKeys    = headersToSign.keys.toList()..sort();
    final canonicalHdrs = sortedKeys.map((k) => '$k:${headersToSign[k]}\n').join();
    final signedHdrs    = sortedKeys.join(';');

    // ── 2. Canonical request ────────────────────────────────────────────────
    final canonicalRequest = [
      'PUT',
      canonicalUri,
      '',           // empty query string
      canonicalHdrs,
      signedHdrs,
      bodyHash,
    ].join('\n');

    // ── 3. String to sign ───────────────────────────────────────────────────
    final credentialScope = '$dateStamp/$_region/s3/aws4_request';
    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      credentialScope,
      sha256.convert(utf8.encode(canonicalRequest)).toString(),
    ].join('\n');

    // ── 4. Signing key ──────────────────────────────────────────────────────
    final kDate    = _hmac(utf8.encode('AWS4$_secretAccessKey'), dateStamp);
    final kRegion  = _hmac(kDate, _region);
    final kService = _hmac(kRegion, 's3');
    final kSigning = _hmac(kService, 'aws4_request');

    // ── 5. Signature ────────────────────────────────────────────────────────
    final signature = _hmac(kSigning, stringToSign)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    final authorization = 'AWS4-HMAC-SHA256 '
        'Credential=$_accessKeyId/$credentialScope, '
        'SignedHeaders=$signedHdrs, '
        'Signature=$signature';

    // ── 6. PUT ──────────────────────────────────────────────────────────────
    final response = await http.put(
      uri,
      headers: {
        ...headersToSign,
        'authorization': authorization,
      },
      body: body,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      developer.log(
        'StorageService: upload failed',
        error: '[${response.statusCode}] ${response.body}',
      );
      throw Exception(
          'iDrive e2 upload failed [${response.statusCode}]: ${response.body}');
    }
  }

  Future<String> getPrivateImageUrl(String objectKey, {int expiresInSeconds = 3600}) async {
    final now = DateTime.now().toUtc();
    final dateStamp = _yyyymmdd(now);
    final amzDate = _iso8601(now);

    final hostHeader = '$_bucketName.$_endpoint';
    final encodedKey = objectKey.split('/').map(Uri.encodeComponent).join('/');
    final canonicalUri = '/$encodedKey';

    final credentialScope = '$dateStamp/$_region/s3/aws4_request';

    final queryParameters = <String, String>{
      'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
      'X-Amz-Credential': '$_accessKeyId/$credentialScope',
      'X-Amz-Date': amzDate,
      'X-Amz-Expires': expiresInSeconds.toString(),
      'X-Amz-SignedHeaders': 'host',
    };

    final sortedParamKeys = queryParameters.keys.toList()..sort();
    final canonicalQueryString = sortedParamKeys
        .map((k) => '$k=${Uri.encodeComponent(queryParameters[k]!)}')
        .join('&');

    final canonicalRequest = [
      'GET',
      canonicalUri,
      canonicalQueryString,
      'host:$hostHeader\n',
      'host',
      'UNSIGNED-PAYLOAD',
    ].join('\n');

    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      credentialScope,
      sha256.convert(utf8.encode(canonicalRequest)).toString(),
    ].join('\n');

    final kDate = _hmac(utf8.encode('AWS4$_secretAccessKey'), dateStamp);
    final kRegion = _hmac(kDate, _region);
    final kService = _hmac(kRegion, 's3');
    final kSigning = _hmac(kService, 'aws4_request');

    final signature = _hmac(kSigning, stringToSign)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    final signedUrl = 'https://$hostHeader$canonicalUri?$canonicalQueryString&X-Amz-Signature=$signature';

    // ── TEST THE GET REQUEST ────────────────────────────────────────────────
    try {
      final testResponse = await http.get(Uri.parse(signedUrl));
      developer.log('=== IDrive e2 GET Test Response ===');
      developer.log('Target URL: $signedUrl');
      developer.log('Status Code: ${testResponse.statusCode}');
      developer.log('Headers: ${testResponse.headers}');
      developer.log('Body: ${testResponse.body.length > 200 ? testResponse.body.substring(0, 200) : testResponse.body}');
      developer.log('===================================');
    } catch (e) {
      developer.log('Failed to test GET URL connection', error: e);
    }
    // ────────────────────────────────────────────────────────────────────────

    return signedUrl;
  }
  // ── Helpers ───────────────────────────────────────────────────────────────

  List<int> _hmac(List<int> key, String data) =>
      Hmac(sha256, key).convert(utf8.encode(data)).bytes;

  String _yyyymmdd(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}'
      '${dt.month.toString().padLeft(2, '0')}'
      '${dt.day.toString().padLeft(2, '0')}';

  String _iso8601(DateTime dt) =>
      '${_yyyymmdd(dt)}T'
      '${dt.hour.toString().padLeft(2, '0')}'
      '${dt.minute.toString().padLeft(2, '0')}'
      '${dt.second.toString().padLeft(2, '0')}Z';
}