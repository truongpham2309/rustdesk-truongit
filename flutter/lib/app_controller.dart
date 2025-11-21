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
  late final ApiClient _apiClient;
  RxString expiresAt = ''.obs;
  final _isInProgress = false.obs;


  String get kIdServer => dotenv.env['ID_SERVER'] ?? '';
  String get kRelayServer => dotenv.env['REPLAY_SERVER'] ?? '';
  String get kApiServer => dotenv.env['API_SERVER'] ?? '';
  String get kApiKey => dotenv.env['API_KEY'] ?? '';
  String get kServerLic => dotenv.env['SERVER_LIC'] ?? '';

  @override
  onInit() {
    super.onInit();
    _apiClient = ApiClient(baseUrl: kServerLic);
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
        key: ''
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
          Get.snackbar(translate("Warning"), apiResponse.message ?? translate("Invalid License."), colorText: Colors.amber, instantInit: true, snackPosition: SnackPosition.BOTTOM);
          break;
        case 'error':
          Get.snackbar(translate("Error"), apiResponse.message ?? translate("Server error"), colorText: Colors.red, instantInit: true, snackPosition: SnackPosition.BOTTOM);
          break;
        default:
          Get.snackbar(translate("Information"), apiResponse.message ?? translate("Unknown response"), colorText: Colors.orange, instantInit: true, snackPosition: SnackPosition.BOTTOM);
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
      if (err is Exception) {
        Get.snackbar(
          translate("Error"),
          err.toString().replaceFirst('Exception: ', ''),
          colorText: Colors.red,
          snackPosition: SnackPosition.BOTTOM,
          instantInit: true,
        );
      } else {
        Get.snackbar(translate("Error"), "Error: $err",
            colorText: Colors.red,
            instantInit: true,
            snackPosition: SnackPosition.BOTTOM
        );
      }
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
          Get.snackbar(translate("Successful"), apiResponse.message ?? "", colorText: Colors.green, instantInit: true, snackPosition: SnackPosition.BOTTOM);
          return (true, apiResponse.expiresAt);
        case 'invalid':
          Get.snackbar(translate("Warning"), apiResponse.message ?? translate("Invalid License."), colorText: Colors.amber, instantInit: true, snackPosition: SnackPosition.BOTTOM);
          break;
        case 'error':
          Get.snackbar(translate("Error"), apiResponse.message ?? translate("Server error"), colorText: Colors.red, instantInit: true, snackPosition: SnackPosition.BOTTOM);
          break;
        default:
          Get.snackbar(translate("Information"), apiResponse.message ?? translate("Unknown response"), colorText: Colors.orange, instantInit: true, snackPosition: SnackPosition.BOTTOM);
      }
    } catch (err) {
      if (err is Exception) {
        Get.snackbar(
          translate("Error"),
          err.toString().replaceFirst('Exception: ', ''),
          colorText: Colors.red,
          snackPosition: SnackPosition.BOTTOM,
          instantInit: true,
        );
      } else {
        Get.snackbar(translate("Error"), "Error: $err",
            colorText: Colors.red,
            instantInit: true,
            snackPosition: SnackPosition.BOTTOM
        );
      }
    }
    return (false, null);
  }

  void showDialogExpiredApiKey(){
    gFFI.dialogManager.show((setState, close, context) {
      return CustomAlertDialog(
        title: Text(translate("License expired")),
        content: Text(translate("The API key has expired. Please update to continue using the application.")),
        actions: [
          dialogButton(translate('Close'), onPressed: (){
            exit(0);
          }),
        ],
      );
    });
  }

  void showDialogRequestApiKey(){
    final keyCtrl = TextEditingController(text: "");

    gFFI.dialogManager.show((setState, close, context) {
      Widget buildField(String label, TextEditingController controller) {
        if (isDesktop) {
          return Row(
            children: [
              SizedBox(
                width: 120,
                child: Text(translate(label)),
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
          children: [Expanded(child: Text(translate('License Key Required')))],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 500),
          child: Form(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Obx(() => Column(
                      children: [
                        buildField(translate('Key'), keyCtrl),
                        if (_isInProgress.value)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: LinearProgressIndicator(),
                          ),
                      ],
                    )),
              ],
            ),
          ),
        ),
        actions: [
          dialogButton(translate('Cancel'), onPressed: () {
            exit(0);
          }, isOutline: true),
          dialogButton(
            translate('OK'),
            onPressed: (keyCtrl.text.trim().isEmpty || _isInProgress.value) ? null : () async{
              _isInProgress.value = true;
              try{
                String hardwareId = await platformFFI.getDeviceId();
                // Check api key is valid
                (bool isValid, String? expiresAt) values = await checkApiKey(keyCtrl.text.trim(), hardwareId);
                if(values.$1){
                  // Save config
                  bool result = await setServerConfig(null, null, ServerConfig(
                      idServer: kIdServer,
                      relayServer: kRelayServer,
                      apiServer: '',
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
                if (e is Exception) {
                  Get.snackbar(
                    translate("Error"),
                    e.toString().replaceFirst('Exception: ', ''),
                    colorText: Colors.red,
                    snackPosition: SnackPosition.BOTTOM,
                    instantInit: true,
                  );
                } else {
                  Get.snackbar(translate("Error"), "Error: $e",
                      colorText: Colors.red,
                      instantInit: true,
                      snackPosition: SnackPosition.BOTTOM
                  );
                }
              } finally {
                // Add a short delay to prevent rapid re-clicks
                await Future.delayed(const Duration(seconds: 1));
                _isInProgress.value = false;
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

  ApiClient({required String baseUrl}) {
    final options = BaseOptions(
      baseUrl: baseUrl,
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
      String errorMessage = translate("Connection or server response error");
      if (e.response != null) {
        errorMessage = e.response?.data['message'] ?? translate('Unknown server error');
      }
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception(translate("An unknown error has occurred. Please try again"));
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