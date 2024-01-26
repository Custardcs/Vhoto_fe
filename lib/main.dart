import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: UploadScreen(),
    );
  }
}

class UploadScreen extends StatefulWidget {
  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final ImagePicker _picker = ImagePicker();
  String _response = '';

  Future<void> _uploadFile() async {
    if (await isConnected()) {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        var request = http.MultipartRequest(
            'POST', Uri.parse('http://192.168.98.101:3000/upload'));
        request.files
            .add(await http.MultipartFile.fromPath('file', image.path));
        var res = await request.send();
        final resData = await res.stream.bytesToString();
        setState(() {
          _response = resData;
        });
      } else {
        setState(() {
          _response = 'error';
        });
      }
    } else {
      setState(() {
        _response = 'No internet connection available';
      });
      //print('No internet connection available');
      // Handle the lack of connection
    }
  }

  Future<bool> isConnected() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.mobile ||
        connectivityResult == ConnectivityResult.wifi) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Upload File')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: _uploadFile,
              child: Text('Upload Image'),
            ),
            SizedBox(height: 20),
            Text(_response),
          ],
        ),
      ),
    );
  }
}
