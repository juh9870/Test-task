import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String UnsplashToken =
    'cf49c08b444ff4cb9e4d126b7e9f7513ba1ee58de7906e4360afc1a33d1bf4c0';

Future<List<Photo>> fetchRecent(int page) async {
  final response = await http.get(
      'https://api.unsplash.com/photos/?per_page=30&page=$page&client_id=' +
          UnsplashToken);

  if (response.statusCode == 200) {
    List<dynamic> list = jsonDecode(response.body);
    return [...list.map((e) => Photo.fromJson(e))];
  } else {
    throw Exception('Failed to load photos');
  }
}

class Author {
  final String name;
  final String profilePicture;

  Author({this.name, this.profilePicture});

  factory Author.fromJson(Map<String, dynamic> json) {
    return Author(
      name: json['name'],
      profilePicture: json['profile_image']['medium'],
    );
  }
}

class Photo {
  final String id;
  final String description;
  final String link;
  final String thumb;
  final Color color;

  final int width;
  final int height;

  final Author author;

  Photo(
      {this.id,
      this.description,
      this.link,
      this.thumb,
      this.width,
      this.height,
      this.color,
      this.author});

  double heightFromWidth(double width) {
    return this.height * (width / this.width);
  }

  String caption() {
    String caption = author.name;
    if (description != null) {
      caption += '\n' + description;
    }
    return caption;
  }

  factory Photo.fromJson(Map<String, dynamic> json) {
    var photo = Photo(
      id: json['id'],
      description: json['description'],
      link: json['urls']['raw'],
      thumb: json['urls']['small'],
      width: json['width'],
      height: json['height'],
      color: Color(int.parse(
          ('0xFF' + json['color']).replaceAll('#', '').toUpperCase())),
      author: Author.fromJson(json['user']),
    );
    return photo;
  }
}

void main() {
  runApp(MaterialApp(home: MainApp()));
  SystemChrome.setEnabledSystemUIOverlays([]);
}

class MainApp extends StatefulWidget {
  MainApp({Key key}) : super(key: key);

  @override
  _MainAppState createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  Future<List<Photo>> futurePhotos;
  List<Photo> photos;
  int curPage = 1;
  bool isPageLoading = false;
  ScrollController controller;
  StateSetter rebuildPictures;

  Widget createPhoto(Photo photo, double width, bool visible) {
    if (!visible) {
      return Container(
          width: width - 20,
          height: photo.heightFromWidth(width),
          margin: const EdgeInsets.all(10.0),
          color: photo.color,
          child: Center(
            child: SizedBox(
                width: 40, height: 40, child: CircularProgressIndicator()),
          ));
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => FullscreenImage(photo)));
      },
      child: Container(
        width: width,
        padding: const EdgeInsets.all(10.0),
        child: Stack(children: <Widget>[
          CachedNetworkImage(
            imageUrl: photo.thumb,
            width: width,
            height: photo.heightFromWidth(width),
            alignment: Alignment.topCenter,
            placeholder: (context, url) => Container(
                width: width,
                height: photo.heightFromWidth(width),
                color: photo.color,
                child: Center(
                    child: SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator()))),
          ),
          Container(
            color: Color(0x66000000),
            child: Row(
              children: [
                CachedNetworkImage(
                  imageUrl: photo.author.profilePicture,
                  width: 32,
                  height: 32,
                ),
                Expanded(
                  child: Text(
                    photo.caption(),
                    style: TextStyle(color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                )
              ],
            ),
          )
        ]),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    futurePhotos = fetchRecent(1);
    curPage = 2;
    photos = [];
    controller = new ScrollController();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Unsplash',
      home: Scaffold(
//        appBar: AppBar(
//          backgroundColor: Colors.black54,
//          title: Text('Unsplash'),
//        ),
        body: FutureBuilder<List<Photo>>(
          future: futurePhotos,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              photos = snapshot.data;
              return Container(
                  color: Colors.black26,
                  child: NotificationListener<ScrollEndNotification>(
                    onNotification: (notification) {
                      rebuildPictures(() {});
                      return true;
                    },
                    child: SingleChildScrollView(
                      controller: controller,
                      child: Column(
                        children: [
                          StatefulBuilder(
                              builder: (context, picturesStateSetter) {
                            rebuildPictures = picturesStateSetter;

                            double width = MediaQuery.of(context).size.width;
                            int nCols = (width / 400).ceil();
                            double imageSize = width / nCols;
                            List<Column> columns = [];
                            List<double> heights = [];

                            for (int i = 0; i < nCols; i++) {
                              columns.add(Column(
                                children: [],
                              ));
                              heights.add(0);
                            }

                            for (var entry in photos) {
                              int smallestCol =
                                  heights.indexOf(heights.reduce(min));
                              double imgHeight =
                                  entry.heightFromWidth(imageSize) + 20;

                              bool visible = (heights[smallestCol] + imgHeight >
                                      controller.offset &&
                                  heights[smallestCol] <
                                      controller.offset +
                                          MediaQuery.of(context).size.height);

                              columns[smallestCol]
                                  .children
                                  .add(createPhoto(entry, imageSize, visible));
                              heights[smallestCol] += imgHeight;
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: columns,
                            );
                          }),
                          () {
                            if (!isPageLoading) {
                              return ElevatedButton(
                                onPressed: () async {
                                  setState(() {
                                    isPageLoading = true;
                                  });
                                  List<Photo> newPage =
                                      await fetchRecent(curPage);
                                  photos.addAll(newPage);
                                  curPage++;
                                  setState(() {
                                    isPageLoading = false;
                                  });
                                },
                                child: Text("Load more"),
                              );
                            } else {
                              return ElevatedButton(
                                  onPressed: () {},
                                  child: CircularProgressIndicator(
                                    backgroundColor: Colors.white,
                                  ));
                            }
                          }(),
                        ],
                      ),
                    ),
                  ));
            } else if (snapshot.hasError) {
              return Text('${snapshot.error}');
            }

            return Container(
                color: Colors.black26,
                child: Center(child: CircularProgressIndicator()));
          },
        ),
      ),
    );
  }
}

class FullscreenImage extends StatelessWidget {
  final Photo photo;

  FullscreenImage(this.photo);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Unsplash',
      home: Scaffold(
        body: GestureDetector(
          onTap: () {
            Navigator.pop(context);
          },
          child: Container(
            color: photo.color,
            child: Stack(children: <Widget>[
              Center(
                child: CachedNetworkImage(
                  fit: BoxFit.cover,
                  imageUrl: photo.link,
                  progressIndicatorBuilder: (context, url, downloadProgress) =>
                      Container(
                          color: photo.color,
                          child: Center(
                              child: SizedBox(
                                  width: 128,
                                  height: 128,
                                  child: CircularProgressIndicator(
                                      value: downloadProgress.progress)))),
                  errorWidget: (context, url, error) => Icon(Icons.error),
                ),
              ),
              Container(
                alignment: Alignment.bottomCenter,
                child: Container(
                  color: Color(0x66000000),
                  child: Row(
                    children: [
                      CachedNetworkImage(
                        imageUrl: photo.author.profilePicture,
                        width: 64,
                        height: 64,
                      ),
                      Expanded(
                        child: Text(
                          photo.caption(),
                          style: TextStyle(color: Colors.white),
                          maxLines: 4,
                        ),
                      )
                    ],
                  ),
                ),
              )
            ]),
          ),
        ),
      ),
    );
  }
}
