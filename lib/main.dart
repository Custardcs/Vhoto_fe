import 'dart:convert';

import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:photo_manager/photo_manager.dart';

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
  String _response = '';
  List<String> uploadedHashes = [];
  int totalPhotos = 0;
  int photosUploaded = 0;

  Future<bool> _requestPermission() async {
    var result = await PhotoManager.requestPermissionExtend();
    return result.isAuth;
  }

  Future<List<AssetEntity>> _fetchAllPhotos() async {
    if (!(await _requestPermission())) {
      return [];
    }

    // Obtain the album list
    List<AssetPathEntity> albums =
        await PhotoManager.getAssetPathList(onlyAll: true);
    List<AssetEntity> allPhotos = [];

    // Define the batch size
    int batchSize =
        500; // Adjust this number based on performance and memory usage
    int currentPage = 0;
    bool hasMore = true;

    while (hasMore) {
      List<AssetEntity> photos =
          await albums[0].getAssetListPaged(page: currentPage, size: batchSize);
      allPhotos.addAll(photos);

      // Check if there are more photos to fetch
      if (photos.length < batchSize) {
        hasMore = false;
      } else {
        currentPage++;
      }
    }

    return allPhotos;
  }

  Future<void> _uploadAllPhotos() async {
  if (await isConnected()) {
    List<AssetEntity> photos = await _fetchAllPhotos();
    totalPhotos = photos.length;  // Set the total number of photos

    for (var photo in photos) {
      var file = await photo.file;
      if (file != null) {
        var request = http.MultipartRequest(
            'POST', Uri.parse('http://192.168.98.101:3000/upload'));
        request.files.add(await http.MultipartFile.fromPath('file', file.path));

        var res = await request.send();
        final resData = await res.stream.bytesToString();
        var data = json.decode(resData);
        if (data['fileHash'] != null) {
          uploadedHashes.add(data['fileHash']);
          photosUploaded++;  // Increment the count of uploaded photos
        }
      }
      setState(() {
        _response = '$photosUploaded of $totalPhotos uploaded';
      });
    }
    setState(() {
      _response = 'All photos uploaded. Hashes: $uploadedHashes';
    });
  } else {
    setState(() {
      _response = 'No internet connection available';
    });
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
              onPressed: _uploadAllPhotos,
              child: Text('Upload All Images'),
            ),
            SizedBox(height: 20),
            Text(_response),
          ],
        ),
      ),
    );
  }
}
