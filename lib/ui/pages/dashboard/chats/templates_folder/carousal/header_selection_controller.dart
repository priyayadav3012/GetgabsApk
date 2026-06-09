import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

class HeaderSelectionController extends GetxController {
  // var selectedFilePath = ''.obs; // Observable to track the file path
  // var selectedFilePath = [].obs;
  List<String> selectedFilePath = <String>[].obs;
  var validateImageSelctionError = false.obs;
  var isHeaderType = ''.obs;
  var isVaribleTemplete = false.obs;
  int limit;
  HeaderSelectionController(this.limit);

  final ImagePicker _picker = ImagePicker();

  Future<void> selectFile(String fileType, int i) async {
    XFile? file;

    switch (fileType) {
      case 'image':
        file = await _picker.pickImage(source: ImageSource.gallery);
        if (file != null) {
          selectedFilePath.insert(i, file.path); // Update with image path
        }
        break;

      case 'video':
        file = await _picker.pickVideo(source: ImageSource.gallery);
        if (file != null) {
          selectedFilePath.insert(i, file.path); // Update with image path
        }
        break;

      case 'document':
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions:
              allowedExtensions, // Allowed file types for documents
        );
        if (result != null && result.files.single.path != null) {
          selectedFilePath.insert(i, file!.path); // Update with image path
        }
        break;

      default:
        print('Unknown file type');
        return;
    }

    if (file == null && selectedFilePath[i].isEmpty) {
      print('No file selected');
    }
  }

  @override
  void onInit() {
    super.onInit();
    for(int i =0; i<limit;i++){
     intilizeSelections(i);
     
    }
  }

  bool isFileSelected(int i) {
    return selectedFilePath[i].isNotEmpty; // Check if a file has been selected
  }

  void intilizeSelections(int i) {
    if (!isFileSelected(i)) {
      selectedFilePath.insert(i, '');
    }
  }

  void clearSelection(int i) {
    selectedFilePath[i] = ''; // Clear the file selection
  }

//docsssssssss

  //var selectedFilePath = ''.obs; // Reactive file path
  var allowedExtensions = [
    'pdf',
    'xlsx',
    'xls',
    'txt',
    'xlsm',
    'xlsb',
    'xltx',
    'doc',
    'docx',
    'csv',
    'avi',
    'ppt',
    'pptx',
    'avchd'
  ];

  Future<void> selectDocument(int i) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions, // Restrict to allowed file types
    );

    if (result != null) {
      selectedFilePath[i] = result.files.single.path!; // Get file path
      print('Selected file: ${selectedFilePath[i]}');
    } else {
      // User canceled the picker
      print('No file selected');
    }
  }
}
