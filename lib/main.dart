import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_gallery/photo_gallery.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:video_player/video_player.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<Album>? _albums;
  bool _loading = false;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  Timer? _connectivityTimer;
  bool _isUploading = false;
  String _response = 'No photos uploaded yet';
  List uploadedHashes = [];
  int photosUploaded = 0;
  int totalPhotos = 0;

  @override
  void initState() {
    super.initState();
    _loading = true;
    initAsync();

    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((result) {
      if (result == ConnectivityResult.wifi ||
          result == ConnectivityResult.mobile) {
        _checkAndUploadPhotos();
      }
    });

    _connectivityTimer = Timer.periodic(
        Duration(minutes: 5), (Timer t) => _checkAndUploadPhotos());
  }

  Future<void> initAsync() async {
    if (await _promptPermissionSetting()) {
      bool isConnected = await _checkConnectivity();
      if (isConnected) {
        List<Album> albums = await PhotoGallery.listAlbums();
        print("Found ${albums.length} albums");
        setState(() {
          _albums = albums;
          _loading = false;
        });
      } else {
        setState(() {
          _response = "No internet connection available";
        });
      }
    } else {
      setState(() {
        _response = "Permission not granted";
      });
    }
    setState(() {
      _loading = false;
    });
  }

  Future<bool> _checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult == ConnectivityResult.mobile ||
        connectivityResult == ConnectivityResult.wifi;
  }

  Future<bool> _promptPermissionSetting() async {
    var photosStatus = await Permission.photos.status;
    var storageStatus = await Permission.storage.status;
    print("Initial Photos Permission: $photosStatus");
    print("Initial Storage Permission: $storageStatus");

    if (!photosStatus.isGranted) {
      await Permission.photos.request();
    }
    if (!storageStatus.isGranted) {
      await Permission.storage.request();
    }

    photosStatus = await Permission.photos.status;
    if (photosStatus.isPermanentlyDenied) {
      // Open app settings
      openAppSettings();
    }

    photosStatus = await Permission.photos.status;
    storageStatus = await Permission.storage.status;
    print("Final Photos Permission: $photosStatus");
    print("Final Storage Permission: $storageStatus");

    return photosStatus.isGranted && storageStatus.isGranted;
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
        if (_albums != null) {
          for (var album in _albums!) {
            MediaPage mediaPage = await album.listMedia();
            List<Medium>? photos = mediaPage.items;
            totalPhotos += photos.length; // Update total photos count

            for (var photo in photos) {
              var file = await PhotoGallery.getFile(mediumId: photo.id);
              var request = http.MultipartRequest(
                'POST',
                Uri.parse('http://192.168.98.101:3000/upload'),
              );
              request.files
                  .add(await http.MultipartFile.fromPath('file', file.path));

              var res = await request.send();
              final resData = await res.stream.bytesToString();
              var data = json.decode(resData);
              if (data['fileHash'] != null) {
                uploadedHashes.add(data['fileHash']);
                photosUploaded++; // Increment the count of uploaded photos
              }

              setState(() {
                _response = '$photosUploaded of $totalPhotos uploaded';
              });
            }
          }
        }
      } catch (e) {
        print('Error uploading photos: $e');
      }
    } else {
      setState(() {
        _response = 'No internet connection available';
      });
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivityTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Implement your widget build method
    // This should return your app's home screen, handling _loading and displaying _albums
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Photo Backup'),
        ),
        body: Column(
          children: <Widget>[
            Text(_response),
            _loading
                ? CircularProgressIndicator()
                : _albums != null
                    ? _buildAlbumGrid(context)
                    : Text("No albums found or permission not granted."),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumGrid(BuildContext context) {
    // Wrap the GridView with an Expanded widget
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(5),
        child: GridView.count(
          shrinkWrap: true, // Add shrinkWrap to true if you still face issues
          physics: ScrollPhysics(), // Add physics property to enable scrolling
          crossAxisCount: 3,
          mainAxisSpacing: 5.0,
          crossAxisSpacing: 5.0,
          children: <Widget>[
            ...?_albums
                ?.map(
                  (album) => GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => AlbumPage(album)),
                    ),
                    child: Column(
                      children: <Widget>[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(5.0),
                          child: Container(
                            color: const Color.fromARGB(255, 17, 184, 67),
                            child: FadeInImage(
                              fit: BoxFit.cover,
                              placeholder: MemoryImage(kTransparentImage),
                              image: AlbumThumbnailProvider(
                                album: album,
                                highQuality: true,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          alignment: Alignment.topLeft,
                          padding: EdgeInsets.only(left: 2.0),
                          child: Text(
                            album.name ?? "Unnamed Album",
                            maxLines: 1,
                            textAlign: TextAlign.start,
                            style: TextStyle(
                              height: 1.2,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Container(
                          alignment: Alignment.topLeft,
                          padding: const EdgeInsets.only(left: 2.0),
                          child: Text(
                            album.count.toString(),
                            textAlign: TextAlign.start,
                            style: TextStyle(
                              height: 1.2,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ],
        ),
      ),
    );
  }
}

class AlbumPage extends StatefulWidget {
  final Album album;

  AlbumPage(Album album) : album = album;

  @override
  State<StatefulWidget> createState() => AlbumPageState();
}

class AlbumPageState extends State<AlbumPage> {
  List<Medium>? _media;

  @override
  void initState() {
    super.initState();
    initAsync();
  }

  void initAsync() async {
    MediaPage mediaPage = await widget.album.listMedia();
    setState(() {
      _media = mediaPage.items;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(widget.album.name ?? "Unnamed Album"),
        ),
        body: GridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: 1.0,
          crossAxisSpacing: 1.0,
          children: <Widget>[
            ...?_media?.map(
              (medium) => GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => ViewerPage(medium)),
                ),
                child: Stack(
                  children: [
                    Container(
                      color: const Color.fromARGB(255, 8, 210, 236),
                      child: FadeInImage(
                        fit: BoxFit.cover,
                        placeholder: MemoryImage(kTransparentImage),
                        image: ThumbnailProvider(
                          mediumId: medium.id,
                          mediumType: medium.mediumType,
                          highQuality: true,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 5,
                      right: 5,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ViewerPage extends StatelessWidget {
  final Medium medium;

  ViewerPage(Medium medium) : medium = medium;

  @override
  Widget build(BuildContext context) {
    DateTime? date = medium.creationDate ?? medium.modifiedDate;
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios),
          ),
          title: date != null ? Text(date.toLocal().toString()) : null,
        ),
        body: Container(
          alignment: Alignment.center,
          child: medium.mediumType == MediumType.image
              ? GestureDetector(
                  onTap: () async {
                    PhotoGallery.deleteMedium(mediumId: medium.id);
                  },
                  child: FadeInImage(
                    fit: BoxFit.cover,
                    placeholder: MemoryImage(kTransparentImage),
                    image: PhotoProvider(mediumId: medium.id),
                  ),
                )
              : VideoProvider(
                  mediumId: medium.id,
                ),
        ),
      ),
    );
  }
}

class VideoProvider extends StatefulWidget {
  final String mediumId;

  const VideoProvider({
    required this.mediumId,
  });

  @override
  _VideoProviderState createState() => _VideoProviderState();
}

class _VideoProviderState extends State<VideoProvider> {
  VideoPlayerController? _controller;
  File? _file;

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initAsync();
    });
    super.initState();
  }

  Future<void> initAsync() async {
    try {
      _file = await PhotoGallery.getFile(mediumId: widget.mediumId);
      _controller = VideoPlayerController.file(_file!);
      _controller?.initialize().then((_) {
        // Ensure the first frame is shown after the video is initialized, even before the play button has been pressed.
        setState(() {});
      });
    } catch (e) {
      print("Failed : $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return _controller == null || !_controller!.value.isInitialized
        ? Container()
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _controller!.value.isPlaying
                        ? _controller!.pause()
                        : _controller!.play();
                  });
                },
                child: Icon(
                  _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                ),
              ),
            ],
          );
  }
}
