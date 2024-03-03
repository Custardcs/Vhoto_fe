import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:flutter/material.dart';
import 'package:photoclient/database_helper.dart';
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_gallery/photo_gallery.dart';
import 'package:transparent_image/transparent_image.dart';
// import 'package:video_player/video_player.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  //vars
  bool _isLoadingAlbums = false; //isloading // is working
  bool _isUploading = false; //is uploading
  // List<Album>? _albums; //albams
  List<ExtendedMedium>? _media; //media in an album
  String _response = ''; // notification
  StreamSubscription<ConnectivityResult>? _connectivitySubscription; // make sure we are connected
  Timer? _connectivityTimer; // check every so often
  Timer? _DBTimer; // check every so often
  List uploadedHashes = []; //this should be a database

  int totalSafePhotos = 0;
  int totalSafeVideos = 0;
  int totalFailPhotos = 0;
  int totalFailVideos = 0;

  @override
  void initState() {
    super.initState();
    _isLoadingAlbums = true;
    initGetAlbums();

    DatabaseHelper.instance.clearDatabase();

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      if (result == ConnectivityResult.wifi || result == ConnectivityResult.mobile) {
        _checkAndUploadPhotos();
      }
    });

    _connectivityTimer = Timer.periodic(Duration(minutes: 1), (Timer t) => _checkAndUploadPhotos());
    _DBTimer = Timer.periodic(Duration(minutes: 2), (Timer t) => initGetAlbums());
  }

  Future<void> initGetAlbums() async {
    if (await _promptPermissionSetting()) {
      List<Album> albums = await PhotoGallery.listAlbums();
      MediaPage mediaPage = await albums[0].listMedia();
      // Convert each Medium object to an ExtendedMedium object
      List<ExtendedMedium> extendedMedia = mediaPage.items.map((medium) => ExtendedMedium(medium: medium)).toList();
      setState(() {
        _media = extendedMedia;
      });
    } else {
      setState(() {
        _response = "Permission not granted";
      });
    }
    setState(() {
      _isLoadingAlbums = false;
    });
  }

  Future<bool> _checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult == ConnectivityResult.mobile || connectivityResult == ConnectivityResult.wifi;
  }

  Future<bool> _promptPermissionSetting() async {
    var storageStatus = await Permission.storage.status;
    //print("Initial Storage Permission: $storageStatus");

    if (!storageStatus.isGranted) {
      await Permission.storage.request();
    }

    storageStatus = await Permission.storage.status;
    if (storageStatus.isPermanentlyDenied) {
      // Open app settings
      openAppSettings();
    }

    storageStatus = await Permission.storage.status;
    //print("Final Storage Permission: $storageStatus");

    return storageStatus.isGranted;
  }

  Future<void> _checkAndUploadPhotos() async {
    bool isConnected = await _checkConnectivity();
    if (isConnected && !_isUploading) {
      _isUploading = true;
      try {
        await _uploadAllPhotos();
      } finally {
        _isUploading = false;
      }
    } else if (!isConnected) {
      setState(() {
        _response = 'No internet connection available';
      });
    }
  }

  Future<void> _uploadAllPhotos() async {
    if (await _checkConnectivity()) {
      try {
        if (_media != null) {
          var db = await DatabaseHelper.instance.queryAllRows();
          for (var photo in _media!) {
            print(db.length);
            if (_media!.length > db.length) {
              print("_media!.length ${_media!.length} db.length ${db.length} YES");
            } else if (db.length > _media!.length) {
              print("_media!.length ${_media!.length} db.length ${db.length} PROBLEM");
              //this should fix the local DB
              continue;
            } else {
              setState(() {
                photo.uploadStatus = UploadStatus.success;
              });
              print("_media!.length ${_media!.length} db.length ${db.length} NO");
              continue;
            }

            var file = await PhotoGallery.getFile(mediumId: photo.medium.id);
            var dbid;
            setState(() {
              photo.uploadStatus = UploadStatus.uploading;
            });
            //ADD TO LOCALDB
            DatabaseHelper.instance.insert({
              DatabaseHelper.columnHash: '',
              DatabaseHelper.columnPath: file.path,
              DatabaseHelper.columnUploaded: 0, // Assuming 0 is false and 1 is true
            }).then((id) {
              print('Inserted row id: $id');
              dbid = id;
            });
            //send to server
            var request = http.MultipartRequest('POST', Uri.parse('http://192.168.98.244:3000/upload'));
            request.files.add(await http.MultipartFile.fromPath('file', file.path));

            var res = await request.send();
            final resData = await res.stream.bytesToString();
            var data = json.decode(resData);
            if (data['fileHash'] != null) {
              print("fileHashfileHashfileHashfileHashfileHash");
              print(data);
              uploadedHashes.add(data['fileHash']);
              totalSafePhotos++; // Increment the count of uploaded photos
              DatabaseHelper.instance.updateUploadStatus(dbid, 1).then((updatedCount) {
                print('Updated $updatedCount row(s)');
              });
              setState(() {
                photo.uploadStatus = UploadStatus.success;
              });
            } else {
              setState(() {
                photo.uploadStatus = UploadStatus.failure;
              });
            }
          }
        } else {
          print('Error _media ==== null');
        }
      } catch (e) {
        print('Error uploading photos: $e');
      }
    } else {
      setState(() {
        _response = 'No Server Found';
      });
    }
  }

  // Stack _buildGridItem(Medium med, int index) {
  //   return Stack(
  //     alignment: Alignment.center,
  //     children: [
  //       ClipRRect(
  //         borderRadius: BorderRadius.circular(5.0),
  //         child: FadeInImage(
  //           fit: BoxFit.cover,
  //           width: double.infinity, // Ensures the image covers the tile width
  //           height: double.infinity, // Ensures the image covers the tile height
  //           placeholder: MemoryImage(kTransparentImage),
  //           image: ThumbnailProvider(
  //             mediumId: med.id,
  //             mediumType: med.mediumType,
  //             highQuality: true,
  //           ),
  //         ),
  //       ),
  //       index % 2 == 0
  //           ? Icon(
  //               Icons.check,
  //               color: Colors.white,
  //             )
  //           : Icon(Icons.close, color: Colors.white),
  //     ],
  //   );
  // }
  Stack _buildGridItem(ExtendedMedium extendedMed, int index) {
    Widget statusIcon;
    Widget c;
    switch (extendedMed.uploadStatus) {
      case UploadStatus.uploading:
        statusIcon = Icon(Icons.upload, color: Color.fromARGB(255, 201, 10, 90));
        break;
      case UploadStatus.success:
        statusIcon = Icon(Icons.check, color: Colors.green);
        break;
      case UploadStatus.failure:
        statusIcon = Icon(Icons.close, color: Colors.red);
        break;
      default:
        statusIcon = Icon(Icons.question_mark, color: Colors.blue); // No icon for pending status
    }

    c = Container(
        decoration:
            BoxDecoration(color: Color.fromRGBO(62, 62, 62, 1), borderRadius: BorderRadius.only(bottomLeft: Radius.circular(5))),
        child: statusIcon);

    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: FadeInImage(
            fit: BoxFit.cover,
            width: double.infinity, // Ensures the image covers the tile width
            height: double.infinity, // Ensures the image covers the tile height
            placeholder: MemoryImage(kTransparentImage),
            image: ThumbnailProvider(
              mediumId: extendedMed.medium.id,
              mediumType: extendedMed.medium.mediumType,
              highQuality: true,
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: c,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivityTimer?.cancel();
    _DBTimer?.cancel();
    super.dispose();
  }

  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Color.fromRGBO(62, 62, 62, 1),
        appBar: AppBar(
          title: Text(
            'Yaup',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Color.fromRGBO(62, 62, 62, 1),
        ),
        body: Column(
          children: [
            Center(
              child: Text(_response),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(color: Color.fromRGBO(127, 127, 127, 1), borderRadius: BorderRadius.circular(12)),
                height: 150,
                child: Row(
                  children: [
                    Expanded(
                      // This should be directly inside the Row
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ListView(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 8, right: 8),
                              child: Text(
                                'Safe',
                                style: TextStyle(
                                  color: Color.fromRGBO(137, 255, 118, 1),
                                ),
                              ),
                            ),
                            Row(children: [
                              Icon(Icons.image_outlined, color: Color.fromRGBO(137, 255, 118, 1)),
                              Text(
                                totalSafePhotos.toString(),
                                style: TextStyle(color: Color.fromRGBO(89, 89, 88, 1)),
                              ),
                            ]),
                            Row(children: [
                              Icon(Icons.video_file, color: Color.fromRGBO(137, 255, 118, 1)),
                              Text(
                                totalSafeVideos.toString(),
                                style: TextStyle(color: Color.fromRGBO(89, 89, 88, 1)),
                              ),
                            ]),
                            Padding(
                              padding: const EdgeInsets.only(left: 8, right: 8),
                              child: Text(
                                'Fail',
                                style: TextStyle(
                                  color: Color.fromRGBO(255, 118, 118, 1),
                                ),
                              ),
                            ),
                            Row(children: [
                              Icon(Icons.image_outlined, color: Color.fromRGBO(255, 118, 118, 1)),
                              Text(
                                totalFailPhotos.toString(),
                                style: TextStyle(color: Color.fromRGBO(89, 89, 88, 1)),
                              ),
                            ]),
                            Row(children: [
                              Icon(Icons.video_file, color: Color.fromRGBO(255, 118, 118, 1)),
                              Text(
                                totalFailVideos.toString(),
                                style: TextStyle(color: Color.fromRGBO(89, 89, 88, 1)),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    ),
                    // Oval Shape
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        width: 125,
                        height: 125, // Adjusted to match the circle's visual requirement
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Status Indicators

            // Grid of Squares
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                // child: GridView.builder(
                //   gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                //     crossAxisCount: 3,
                //     crossAxisSpacing: 5,
                //     mainAxisSpacing: 5,
                //   ),
                //   itemCount: 20,
                //   itemBuilder: (context, index) {
                //     return _buildGridItem(index);
                //   },
                // ),

                child: _isLoadingAlbums
                    ? const Center(child: CircularProgressIndicator())
                    : _media != null
                        ? GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 5,
                              mainAxisSpacing: 5,
                            ),
                            itemCount: _media?.length ?? 0,
                            itemBuilder: (context, index) {
                              final x = _media![index];
                              return _buildGridItem(x, index);
                            },
                          )
                        : const Text("No albums found or permission not granted."),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum UploadStatus { pending, uploading, success, failure }

class ExtendedMedium {
  final Medium medium; // Assuming `Medium` is your photo model
  UploadStatus uploadStatus;
  double uploadProgress;

  ExtendedMedium({required this.medium, this.uploadStatus = UploadStatus.pending, this.uploadProgress = 50.0});
}
