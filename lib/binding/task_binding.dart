import 'package:get/get.dart';
import '../controller/task_controller.dart';

class TaskBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(TaskController());
  }
}
