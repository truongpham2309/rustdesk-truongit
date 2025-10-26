import 'dart:io';

import 'package:dio/dio.dart' as d;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'common.dart';
import 'models/platform_model.dart';

class AppController extends GetxController {
  static AppController get to => Get.find<AppController>();
  final ApiClient _apiClient = ApiClient();
  RxString expiresAt = ''.obs;


  String get kIdServer => dotenv.env['ID_SERVER'] ?? '';
  String get kRelayServer => dotenv.env['REPLAY_SERVER'] ?? '';
  String get kApiServer => dotenv.env['API_SERVER'] ?? '';
  String get kApiKey => dotenv.env['API_KEY'] ?? '';

  @override
  onInit() {
    super.onInit();
    checkApiKeyRequired();
  }

  Future checkApiKeyRequired() async{
    // Check if API key is required and not set
    ServerConfig? serverConfig = await getServerConfig();

    // Set default idServer (run once only)
    if(serverConfig?.idServer == null || serverConfig?.idServer.trim().isEmpty == true){
      serverConfig = ServerConfig(
        idServer: kIdServer,
        relayServer: kRelayServer,
        apiServer: kApiServer,
        key: kApiKey
      );
      await setServerConfig(null, null, serverConfig);
    }

    if(serverConfig == null || serverConfig.licenseKey.trim().isEmpty == true){
      // Show Dialog to input licenseKey
      showDialogRequestApiKey();
    } else {
      ApiResponse? apiResponse = await pingAuthentication(serverConfig);
      if(apiResponse?.status == 'invalid'){
        showDialogExpiredApiKey();
        expiresAt.value = '';
      }
    }
  }

  Future<ApiResponse?> pingAuthentication(ServerConfig serverConfig) async{
    try {
      final ApiResponse apiResponse = await _apiClient.check(
        licenseKey: serverConfig.licenseKey,
        hardwareId: serverConfig.hardwareId,
      );
      switch (apiResponse.status) {
        case 'invalid':
          Get.snackbar("Cảnh báo", apiResponse.message ?? "License không hợp lệ.", colorText: Colors.amber);
          break;
        case 'error':
          Get.snackbar("Lỗi", apiResponse.message ?? "Có lỗi từ máy chủ.", colorText: Colors.red);
          break;
        default:
          Get.snackbar("Thông báo", apiResponse.message ?? "Phản hồi không xác định.", colorText: Colors.orange);
      }
      if(apiResponse.expiresAt?.trim().isNotEmpty == true){
        if(serverConfig.expiresAt != apiResponse.expiresAt){
          // Update expiration
          serverConfig.expiresAt = apiResponse.expiresAt!;
          await setServerConfig(null, null, serverConfig);
        }
      }
      return apiResponse;
    } catch (err) {
      showToast("Error: $err");
    }
    return null;
  }

  Future<(bool, String?)> checkApiKey(String licenseKey, String hardwareId) async{
    try {
      final ApiResponse apiResponse = await _apiClient.check(
        licenseKey: licenseKey,
        hardwareId: hardwareId,
      );
      switch (apiResponse.status) {
        case 'valid':
          Get.snackbar("Thành công", apiResponse.message ?? "", colorText: Colors.green);
          return (true, apiResponse.expiresAt);
        case 'invalid':
          Get.snackbar("Cảnh báo", apiResponse.message ?? "License không hợp lệ.", colorText: Colors.amber);
          break;
        case 'error':
          Get.snackbar("Lỗi", apiResponse.message ?? "Có lỗi từ máy chủ.", colorText: Colors.red);
          break;
        default:
          Get.snackbar("Thông báo", apiResponse.message ?? "Phản hồi không xác định.", colorText: Colors.orange);
      }
    } catch (err) {
      showToast("Error: $err");
    }
    return (false, null);
  }

  void showDialogExpiredApiKey(){
    gFFI.dialogManager.show((setState, close, context) {
      return CustomAlertDialog(
        title: null,
        content: msgboxContent("info", "License Expired", "Api key is expired, please update to continue using the application."),
        actions: [
          dialogButton('Close', onPressed: (){
            exit(0);
          }),
        ],
      );
    });
  }

  void showDialogRequestApiKey(){
    final keyCtrl = TextEditingController(text: "");
    var isInProgress = false;

    gFFI.dialogManager.show((setState, close, context) {
      Widget buildField(String label, TextEditingController controller) {
        if (isDesktop || isWeb) {
          return Row(
            children: [
              SizedBox(
                width: 120,
                child: Text(label),
              ),
              SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                    controller: controller,
                    onChanged: (value){
                      setState(() {
                        keyCtrl.text = value;
                      });
                    },
                    decoration: InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12))).workaroundFreezeLinuxMint(),
              ),
            ],
          );
        }

        return TextFormField(
            controller: controller,
            decoration: InputDecoration(
                labelText: label)).workaroundFreezeLinuxMint();
      }

      return CustomAlertDialog(
        title: Row(
          children: [
            Expanded(child: Text(translate('License Key Required'))),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 500),
          child: Form(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                buildField('Key', keyCtrl),
                if (isInProgress)
                  Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          // dialogButton('Cancel', onPressed: () {
          //   close();
          // }, isOutline: true),
          dialogButton(
            'OK',
            onPressed: keyCtrl.text.trim().isEmpty ? null : () async{
              setState(() {
                isInProgress = true;
              });
              try{
                String hardwareId = await platformFFI.getDeviceId();
                // Check api key is valid
                (bool isValid, String? expiresAt) values = await checkApiKey(keyCtrl.text.trim(), hardwareId);
                if(values.$1){
                  // Save config
                  bool result = await setServerConfig(null, null, ServerConfig(
                      idServer: kIdServer,
                      relayServer: kRelayServer,
                      apiServer: kApiServer,
                      key: kApiKey,
                      licenseKey: keyCtrl.text.trim(),
                      hardwareId: hardwareId,
                      expiresAt: values.$2
                  ));
                  if (result) {
                    AppController.to.expiresAt.value = values.$2 ?? '';
                    close();
                    showToast(translate('Successful'));
                  } else {
                    showToast(translate('Failed'));
                  }
                }
              } catch(e){
                showToast("Error: $e");
              } finally {
                setState(() {
                  isInProgress = false;
                });
              }
            },
          ),
        ],
      );
    });
  }
}

class ApiClient {
  late final Dio _dio;
  static const String _baseUrl = 'https://lic.truongit.net/api';

  ApiClient() {
    final options = BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Accept': 'application/json',
      },
    );
    _dio = Dio(options);
  }

  Future<ApiResponse> _post(String path, {required String licenseKey, required String hardwareId}) async {
    final formData = d.FormData.fromMap({
      'license_key': licenseKey.trim(),
      'hardware_id': hardwareId.trim(),
    });

    try {
      final response = await _dio.post(path, data: formData);
      return ApiResponse.fromJson(Map<String, dynamic>.from(response.data));
    } on DioException catch (e) {
      String errorMessage = "Lỗi kết nối hoặc máy chủ không phản hồi.";
      if (e.response != null) {
        errorMessage = "Lỗi máy chủ [${e.response?.statusCode}]: ${e.response?.data['message'] ?? 'Không có thông báo'}";
      }
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception("Đã xảy ra lỗi không xác định. Vui lòng thử lại.");
    }
  }

  Future<ApiResponse> ping({required String licenseKey, required String hardwareId}) {
    return _post('/ping.php', licenseKey: licenseKey, hardwareId: hardwareId);
  }

  Future<ApiResponse> check({required String licenseKey, required String hardwareId}) {
    return _post('/check.php', licenseKey: licenseKey, hardwareId: hardwareId);
  }
}

class ApiResponse {
  final String? status;
  final String? message;
  final String? expiresAt;

  ApiResponse({this.status, this.message, this.expiresAt});

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      status: json['status'],
      message: json['message'],
      expiresAt: json['expires_at'],
    );
  }
}