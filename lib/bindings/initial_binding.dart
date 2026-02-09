import 'package:get/get.dart';
import '../data/services/api_service.dart';
import '../controllers/auth_controller.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(ApiService(), permanent: true);
    Get.put(AuthController(), permanent: true);
  }
}
