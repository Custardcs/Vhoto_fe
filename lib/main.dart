//import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_gallery/photo_gallery.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  List<MediaItem> mediaItems = []; //main list
  List<MediaItem> filteredMediaItems = []; //filter list
  final Battery _battery = Battery(); //this is for the battery
  bool isLoading = false; // make sure it displays loading
  bool isCharging = false; //battery is charging
  bool _isUploading = false; //is uploading or in uploading state.

  Timer? _connectivityTimer;

  StreamSubscription<ConnectivityResult>? _connectivitySubscription; //the check connectivity

  @override
  void initState() {
    super.initState();
    isLoading = true;
    initAsync(); // check perms // get albums // set loading
    _checkBatteryState(); // check the battery

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      if (result == ConnectivityResult.wifi) {
        _checkAndUploadPhotos();
      } else {
        print('No wireless connection available 1');
      }
    });

    _connectivityTimer = Timer.periodic(const Duration(minutes: 1), (Timer t) => _checkAndUploadPhotos());
  }

  Future<void> initAsync() async {
    // checkAndroidVersion();
    if (await _promptPermissionSetting()) {
      //get the Albums
      List<Album> albumsList = await PhotoGallery.listAlbums();
      MediaPage mediaList = await albumsList[0].listMedia();
      //print("Found ${albums.length} albums");

      for (var i = 0; i < mediaList.items.length; i++) {
        final shaHash = await sha256Hash(mediaList.items[i].id);

        // var rng = Random();
        // int randomNumber = rng.nextInt(3) + 1;

        mediaItems.add(MediaItem(
          medium: mediaList.items[i],
          id: mediaList.items[i].id,
          hash: shaHash,
          status: 0,
        ));
      }

      setState(() {
        isLoading = false;
        filteredMediaItems = List.from(mediaItems);
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No Permission!')));
      }
    }
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _checkBatteryState() async {
    // Listen to the battery state
    _battery.onBatteryStateChanged.listen((BatteryState state) {
      if (state == BatteryState.charging) {
        // The device is charging
        print("Device is charging.");
        setState(() {
          isCharging = true;
        });
      } else {
        // The device is not charging
        print("Device is not charging.");
        setState(() {
          isCharging = false;
        });
      }
    });
  }

  Future<bool> _promptPermissionSetting() async {
    var storageStatus = await Permission.storage.status;
    print("Initial Storage Permission: $storageStatus");

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

  Future<bool> _checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult == ConnectivityResult.wifi;
  }

  Future<void> _checkAndUploadPhotos() async {
    bool isConnected = await _checkConnectivity();
    if (isConnected && isCharging && !_isUploading) {
      setState(() {
        _isUploading = true;
      });
      try {
        print('_sendToServer');
        await _sendToServer();
      } finally {
        setState(() {
          _isUploading = false;
        });
      }
    } else {
      print('No wireless connection available 2');
      print('No charging 2');
      print('No busy uploading already.');
    }
  }

  Future<void> _sendToServer() async {
    if (await _checkConnectivity()) {
      try {
        if (mediaItems.isNotEmpty) {
          for (var photo in mediaItems) {
            var file = await PhotoGallery.getFile(mediumId: photo.id);
            var request = http.MultipartRequest('POST', Uri.parse('http://192.168.98.246:3000/upload'));
            request.files.add(await http.MultipartFile.fromPath('file', file.path));

            var res = await request.send();
            final resData = await res.stream.bytesToString();
            var data = json.decode(resData);
            if (data['fileHash'] != null) {
              //set the value of the current item to done.
              photo.status = 1; // Update status to 1 (success)
              photo.hash = data['fileHash']; // Assuming you want to update the hash as well
            } else {
              //set the value of the current item to error.
              photo.status = 2; // Update status to 2 (error)
            }
          }
        }
      } catch (err) {
        print('err $err');
      } finally {
        setState(() {
          _isUploading = false;
        });
      }
    } else {
      print('No wireless connection available 3');
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
    return MaterialApp(
      home: Scaffold(
          backgroundColor: Colors.grey[700],
          appBar: AppBar(
            title: const Text('Photoplicity'),
            actions: [isCharging ? const Icon(color: Colors.green, Icons.battery_charging_full_sharp) : const Icon(color: Colors.red, Icons.battery_std_sharp)],
            backgroundColor: Colors.grey[700],
          ),
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : mediaItems.isNotEmpty
                  ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 8.0, right: 8.0),
                        child: Card.filled(
                            color: Color.fromARGB(255, 58, 58, 58),
                            child: SizedBox(
                              width: 300,
                              height: 100,
                              child: Center(
                                  child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      Text(
                                        'Done:',
                                        style: TextStyle(color: Colors.green),
                                      ),
                                      Text(
                                        '9000',
                                        style: TextStyle(color: Colors.green),
                                      )
                                    ],
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      Text(
                                        'Busy:',
                                        style: TextStyle(color: Colors.orange),
                                      ),
                                      Text(
                                        '9000',
                                        style: TextStyle(color: Colors.orange),
                                      )
                                    ],
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      Text(
                                        'Error:',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                      Text(
                                        '9000',
                                        style: TextStyle(color: Colors.red),
                                      )
                                    ],
                                  ),
                                ],
                              )),
                            )),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: SegmentedButtonSelection(
                          onSelectionChanged: filterMediaItems,
                        ),
                      ),
                      SizedBox(height: MediaQuery.of(context).size.height - 280, child: _buildPhotoGrid(context))
                    ])
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          "No albums found or permission not granted.",
                          textAlign: TextAlign.center,
                        ),
                        ElevatedButton(onPressed: _promptPermissionSetting, child: const Text('Get Permissions')),
                      ],
                    )),
    );
  }

  Widget _buildPhotoGrid(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2.5,
        mainAxisSpacing: 2.5,
        childAspectRatio: 1.0, // Ensures 1:1 aspect ratio for grid tiles
      ),
      itemCount: filteredMediaItems.length, // Use the first album's photos count or fallback to 0
      itemBuilder: (context, index) {
        final photo = filteredMediaItems[index];
        Color backgroundColor;
        String displayText;

        // Assuming `photo.status` holds the value for switch case
        switch (photo.status) {
          case 1:
            backgroundColor = const Color.fromRGBO(76, 175, 80, 0.5);
            displayText = "Done";
            break;
          case 2:
            backgroundColor = const Color.fromRGBO(255, 152, 0, 0.5);
            displayText = "Busy";
            break;
          case 3:
            backgroundColor = const Color.fromRGBO(244, 67, 54, 0.5);
            displayText = "Error";
            break;
          default:
            backgroundColor = const Color.fromRGBO(33, 150, 243, 0.5); // Default color
            displayText = "Waiting"; // Default text
        }

        return GestureDetector(
          onTap: () => {print('this is a photo id: ${photo.id}'), print('this is a photo hash: ${photo.hash}')},
          child: Stack(
            alignment: Alignment.bottomLeft,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(5.0),
                child: FadeInImage(
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  placeholder: MemoryImage(kTransparentImage),
                  image: ThumbnailProvider(
                    mediumId: photo.medium.id,
                    mediumType: photo.medium.mediumType,
                    highQuality: true,
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(5.0),
                    bottomRight: Radius.circular(5.0),
                  ),
                ),
                child: Text(
                  displayText,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void filterMediaItems(Selection selection) {
    List<MediaItem> filteredItems = [];

    switch (selection) {
      case Selection.all:
        filteredItems = List.from(mediaItems); // Copy all items
        break;
      case Selection.done:
        filteredItems = mediaItems.where((item) => item.status == 1).toList();
        break;
      case Selection.busy:
        filteredItems = mediaItems.where((item) => item.status == 2).toList();
        break;
      case Selection.error:
        filteredItems = mediaItems.where((item) => item.status == 3).toList();
        break;
    }

    setState(() {
      // Assuming you have a separate list to hold the filtered items
      filteredMediaItems = filteredItems;
    });
  }
}

class SegmentedButtonSelection extends StatefulWidget {
  final Function(Selection) onSelectionChanged;
  const SegmentedButtonSelection({super.key, required this.onSelectionChanged});

  @override
  State<SegmentedButtonSelection> createState() => _SegmentedButtonSelectionState();
}

enum Selection { all, done, busy, error }

class _SegmentedButtonSelectionState extends State<SegmentedButtonSelection> {
  Selection selectionView = Selection.all;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<Selection>(
      style: SegmentedButton.styleFrom(
        backgroundColor: Colors.grey[600],
        foregroundColor: Colors.white,
        selectedForegroundColor: Colors.white,
        selectedBackgroundColor: Colors.grey[800],
      ),
      segments: const <ButtonSegment<Selection>>[
        ButtonSegment<Selection>(
          value: Selection.all,
          label: Text('All'),
        ),
        ButtonSegment<Selection>(
          value: Selection.done,
          label: Text(
            'Done',
            style: TextStyle(color: Colors.green),
          ),
        ),
        ButtonSegment<Selection>(
          value: Selection.busy,
          label: Text(
            'Busy',
            style: TextStyle(color: Colors.orange),
          ),
        ),
        ButtonSegment<Selection>(
          value: Selection.error,
          label: Text(
            'Error',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
      selected: <Selection>{selectionView},
      onSelectionChanged: (Set<Selection> newSelection) {
        widget.onSelectionChanged(newSelection.first); // Call the callback
        setState(() {
          selectionView = newSelection.first;
        });
      },
    );
  }
}

class MediaItem {
  final Medium medium; // Assuming Medium is a predefined class
  final String id;
  String hash;
  int status;

  MediaItem({required this.medium, required this.id, required this.hash, required this.status});
}

Future<String> sha256Hash(String photoid) async {
  final file = await PhotoGallery.getFile(mediumId: photoid);
  final bytes = await file.readAsBytes();
  final digest = sha256.convert(bytes);
  return digest.toString();
}
