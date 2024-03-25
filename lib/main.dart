import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:photo_gallery/photo_gallery.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:video_player/video_player.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  List<Album>? _albums;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    isLoading = true;
    initAsync();
  }

  Future<void> initAsync() async {
    // checkAndroidVersion();
    if (await _promptPermissionSetting()) {
      //get the Albums
      List<Album> albums = await PhotoGallery.listAlbums();
      //print("Found ${albums.length} albums");
      setState(() {
        _albums = albums;
        isLoading = false;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('No Permission!'),
      ));
    }
    setState(() {
      isLoading = false;
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

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
          backgroundColor: Colors.grey[700],
          appBar: AppBar(
            title: const Text('Photoplicity'),
            backgroundColor: Colors.grey[700],
          ),
          body: isLoading
              ? const CircularProgressIndicator()
              : _albums != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceAround,
                                        children: [
                                          Text(
                                            'Done:',
                                            style:
                                                TextStyle(color: Colors.green),
                                          ),
                                          Text(
                                            '9000',
                                            style:
                                                TextStyle(color: Colors.green),
                                          )
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceAround,
                                        children: [
                                          Text(
                                            'Busy:',
                                            style:
                                                TextStyle(color: Colors.orange),
                                          ),
                                          Text(
                                            '9000',
                                            style:
                                                TextStyle(color: Colors.orange),
                                          )
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceAround,
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
                            padding: EdgeInsets.all(8.0),
                            child: SegmentedButtonSelection(),
                          ),
                          SizedBox(
                              height: MediaQuery.of(context).size.height - 280,
                              child: _buildAlbumGrid(context))
                        ])
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          "No albums found or permission not granted.",
                          textAlign: TextAlign.center,
                        ),
                        ElevatedButton(
                            onPressed: _promptPermissionSetting,
                            child: const Text('Get Permissions')),
                      ],
                    )),
    );
  }

  Widget _buildAlbumGrid(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2.5,
        mainAxisSpacing: 2.5,
        childAspectRatio: 1.0, // Ensures 1:1 aspect ratio for grid tiles
      ),
      itemCount: _albums?.length ?? 0, // Handle null with a fallback to 0
      itemBuilder: (context, index) {
        final album = _albums![index];
        return Stack(
          alignment: Alignment
              .bottomLeft, // Align text to the bottom left of the stack
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(5.0),
              child: FadeInImage(
                fit: BoxFit.cover,
                width:
                    double.infinity, // Ensures the image covers the tile width
                height:
                    double.infinity, // Ensures the image covers the tile height
                placeholder: MemoryImage(kTransparentImage),
                image: AlbumThumbnailProvider(
                  album: album,
                  highQuality: true,
                ),
              ),
            ),
            Container(
              // Semi-transparent overlay for text readability
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(5.0),
                  bottomRight: Radius.circular(5.0),
                ),
              ),
              child: Text(
                "${album.name ?? "Unnamed Album"} (${album.count})",
                style: const TextStyle(color: Colors.white, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    );
  }
}

class SegmentedButtonSelection extends StatefulWidget {
  const SegmentedButtonSelection({super.key});

  @override
  State<SegmentedButtonSelection> createState() =>
      _SegmentedButtonSelectionState();
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
        setState(() {
          // By default there is only a single segment that can be
          // selected at one time, so its value is always the first
          // item in the selected set.
          selectionView = newSelection.first;
        });
      },
    );
  }
}
