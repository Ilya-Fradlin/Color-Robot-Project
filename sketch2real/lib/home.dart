import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:mime/mime.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:picturegenerator/drawingarea.dart';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class Home extends StatefulWidget {
  final BluetoothDevice server;
  const Home({required this.server});
  @override
  _HomeState createState() => new _HomeState();
}

class _HomeState extends State<Home> {
  bool _loading = true;
  List<DrawingArea?> points_black = [];
  List<DrawingArea?> points_green = [];
  List<DrawingArea?> points_blue = [];
  List<DrawingArea?> points_red = [];
  Widget? imageOutput;
  ByteData imgBytes = ByteData(1024);
  var img1;
  BluetoothConnection? connection;
  bool get isConnected => (connection?.isConnected ?? false);
  bool canProceedSending = false;
  Color brushColor = Colors.black;

  @override
  void initState() {
    super.initState();
    print("check both connections addresses");
    print(widget.server.address);

    BluetoothConnection.toAddress(widget.server.address).then((_connection) {
      // BluetoothConnection.toAddress("00:21:04:08:3B:86").then((_connection) {
      print('Connected to the device');
      connection = _connection;
      // connection!.output.add(Uint8List.fromList(utf8.encode("T105" + "\r\n")));
      print("check connections equal");
      print(connection);
      setState(() {});
      //_sendMessage("T105");
      connection!.input!.listen(_onDataReceived).onDone(() {
        //Do nothing
        if (this.mounted) {
          setState(() {});
        }
      });
    }).catchError((error) {
      print('Cannot connect, exception occured');
      print(error);
    });
  }

  Future saveToImageWrapper(
      List<DrawingArea?> points_black,
      List<DrawingArea?> points_blue,
      List<DrawingArea?> points_green,
      List<DrawingArea?> points_red) async {
    for (int i = 0; i < points_black.length; ++i) {
      if (points_black[i] != null) {
        await saveToImage(points_black, Colors.black);
        break;
      }
    }
    _sendMessage("T104");
    await Future.delayed(Duration(seconds: 5));
    _sendMessage("C101");
    await Future.delayed(Duration(seconds: 5));
    for (int i = 0; i < points_blue.length; ++i) {
      if (points_blue[i] != null) {
        await saveToImage(points_blue, Colors.black);
        break;
      }
    }
    _sendMessage("T104");
    await Future.delayed(Duration(seconds: 5));
    _sendMessage("C101");
    await Future.delayed(Duration(seconds: 5));
    for (int i = 0; i < points_red.length; ++i) {
      if (points_red[i] != null) {
        await saveToImage(points_red, Colors.black);
        break;
      }
    }
    _sendMessage("T104");
    await Future.delayed(Duration(seconds: 5));
    _sendMessage("C101");
    await Future.delayed(Duration(seconds: 5));
    for (int i = 0; i < points_green.length; ++i) {
      if (points_green[i] != null) {
        await saveToImage(points_green, Colors.black);
        break;
      }
    }
    _sendMessage("T104");
    await Future.delayed(Duration(seconds: 5));
    _sendMessage("C101");
    await Future.delayed(Duration(seconds: 5));
  }

  Future saveToImage(List<DrawingArea?> points, Color color) async {
    final recorder = ui.PictureRecorder();
    final canvas =
        Canvas(recorder, Rect.fromPoints(Offset(0.0, 0.0), Offset(200, 200)));
    Paint paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.56;

    final paint2 = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;

    canvas.drawRect(Rect.fromLTWH(0, 0, 256, 256), paint2);

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!.point!, points[i + 1]!.point!, paint);
      }
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(256, 256);

    final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final listBytes = Uint8List.view(pngBytes!.buffer);

    File file = await writeBytes(listBytes);

    await fetchResponseFromDraw(file);

    setState(() {
      imgBytes = pngBytes;
    });
  }

  void loadImage(File file) {
    setState(() {
      img1 = Image.file(file);
    });
  }

  void pickImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    File? file;
    if (result != null) {
      // File file = File(result.files.single.path!);
      file = File(result.files.single.path!);
      loadImage(file);
      fetchResponse(file);
    } else {
      // User canceled the picker
      _loading = true;
      return;
    }
  }

  Future fetchResponseFromDraw(File imageFile) async {
    final mimeTypeData =
        lookupMimeType(imageFile.path, headerBytes: [0xFF, 0xD8])!.split('/');
    final imageUploadRequest = http.MultipartRequest(
        'POST',
        Uri.parse(
            'http://192.168.1.138:5000/generate')); //PUT YOUR OWN IP HERE, it may vary depending on your computer

    final file = await http.MultipartFile.fromPath('image', imageFile.path,
        contentType: MediaType(mimeTypeData[0], mimeTypeData[1]));

    imageUploadRequest.fields['ext'] = mimeTypeData[1];
    imageUploadRequest.files.add(file);

    try {
      canProceedSending = false;
      final streamedResponse = await imageUploadRequest.send();
      final response = await http.Response.fromStream(streamedResponse);

      final Map<String, dynamic> responseData = json.decode(response.body);
      String g_code = responseData['result'];

      List myList = g_code.split("\n");
      // List myList = ["T105", "T104", "T105", "T104"];
      for (int i = 0; i < myList.length; ++i) {
        String text = myList[i];
        // _sendMessage(text, connection);
        if (isConnected) {
          _sendMessage(text);
        }
        while (canProceedSending == false) {
          await Future.delayed(Duration(milliseconds: 10));
        }
        canProceedSending = false;
      }
    } catch (e) {
      print(' * ERROR: ' + e.toString());
      return null;
    }
  }

  void _onDataReceived(Uint8List data) {
    // Do Nothing on the recieved data
    String dataString = String.fromCharCodes(data);
    if (dataString.contains("17")) {
      canProceedSending = true;
    }
  }

  Future _sendMessage(String text) async {
    text = text.trim();
    if (text.length > 0) {
      try {
        // connection!.output.add(Uint8List.fromList(utf8.encode(text + "\r\n")));
        connection!.output.add(Uint8List.fromList(utf8.encode(text + "\r\n")));
        await connection!.output.allSent;
      } catch (e) {
        // Ignore error, but notify state
        print(e);
        setState(() {});
      }
    }
  }

  // Future _sendMessageWrapper(String text) async {
  //   _sendMessage(text);
  //   await Future.delayed(Duration(milliseconds: 300));
  // }

  void fetchResponse(File imageFile) async {
    final mimeTypeData =
        lookupMimeType(imageFile.path, headerBytes: [0xFF, 0xD8])!.split('/');
    final imageUploadRequest = http.MultipartRequest(
        'POST',
        Uri.parse(
            'http://192.168.1.138:5000/generate')); //PUT YOUR OWN IP HERE, it may vary depending on your computer

    final file = await http.MultipartFile.fromPath('image', imageFile.path,
        contentType: MediaType(mimeTypeData[0], mimeTypeData[1]));

    imageUploadRequest.fields['ext'] = mimeTypeData[1];
    imageUploadRequest.files.add(file);

    try {
      final streamedResponse = await imageUploadRequest.send();
      final response = await http.Response.fromStream(streamedResponse);

      print(' * STATUS CODE: ${response.statusCode}');

      final Map<String, dynamic> responseData = json.decode(response.body);
      String g_code = responseData['result'];

      print(g_code);
      // displayResponseImage(outputFile);

    } catch (e) {
      print(' * ERROR: ' + e.toString());
      return null;
    }
  }

  // void displayResponseImage(String fileName) async {
  //   setState(() {
  //     String outputFile = 'http://192.168.1.138:5000/download/' + fileName;
  //     imageOutput = Container(
  //         width: 256,
  //         height: 256,
  //         child: CachedNetworkImage(imageUrl: outputFile));
  //   });
  // }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();

    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/test.png');
  }

  Future<File> writeBytes(listBytes) async {
    final file = await _localFile;

    return file.writeAsBytes(listBytes, flush: true);
  }

  @override
  void dispose() {
    // Avoid memory leak (`setState` after dispose) and disconnect
    if (isConnected) {
      connection?.dispose();
      connection = null;
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  // Color(0xFFffd200),
                  // Color(0xFFF7971E),
                  Color.fromRGBO(138, 35, 135, 1.0),
                  Color.fromRGBO(233, 64, 87, 1.0),
                  Color.fromRGBO(242, 113, 33, 1.0)
                ],
              ),
            ),
          ),
          // SizedBox(height: 10),
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              child: Row(
                // crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // SizedBox(height: 200),
                  // Text(
                  //   'Sketch2Real',
                  //   style: TextStyle(
                  //     color: Colors.black,
                  //     fontSize: 50,
                  //   ),
                  // ),
                ],
              ),
            ),
          ),
          _loading == true
              ? Center(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Container(
                          width: 256,
                          height: 256,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.4),
                                  blurRadius: 5.0,
                                  spreadRadius: 1)
                            ],
                          ),
                          child: GestureDetector(
                            onPanDown: (details) {
                              this.setState(
                                () {
                                  if (brushColor == Colors.black) {
                                    points_black.add(
                                      DrawingArea(
                                          point: details.localPosition,
                                          areaPaint: Paint()
                                            ..strokeCap = StrokeCap.round
                                            ..isAntiAlias = true
                                            ..color = brushColor
                                            ..strokeWidth = 1.56),
                                    );
                                  }
                                  if (brushColor == Colors.blue.shade900) {
                                    points_blue.add(
                                      DrawingArea(
                                          point: details.localPosition,
                                          areaPaint: Paint()
                                            ..strokeCap = StrokeCap.round
                                            ..isAntiAlias = true
                                            ..color = brushColor
                                            ..strokeWidth = 1.56),
                                    );
                                  }
                                  if (brushColor == Colors.green) {
                                    points_green.add(
                                      DrawingArea(
                                          point: details.localPosition,
                                          areaPaint: Paint()
                                            ..strokeCap = StrokeCap.round
                                            ..isAntiAlias = true
                                            ..color = brushColor
                                            ..strokeWidth = 1.56),
                                    );
                                  }
                                  if (brushColor == Colors.red.shade900) {
                                    points_red.add(
                                      DrawingArea(
                                          point: details.localPosition,
                                          areaPaint: Paint()
                                            ..strokeCap = StrokeCap.round
                                            ..isAntiAlias = true
                                            ..color = brushColor
                                            ..strokeWidth = 1.56),
                                    );
                                  }
                                },
                              );
                            },
                            onPanUpdate: (details) {
                              this.setState(
                                () {
                                  if (brushColor == Colors.black) {
                                    points_black.add(
                                      DrawingArea(
                                          point: details.localPosition,
                                          areaPaint: Paint()
                                            ..strokeCap = StrokeCap.round
                                            ..isAntiAlias = true
                                            ..color = brushColor
                                            ..strokeWidth = 1.56),
                                    );
                                  }
                                  if (brushColor == Colors.blue.shade900) {
                                    points_blue.add(
                                      DrawingArea(
                                          point: details.localPosition,
                                          areaPaint: Paint()
                                            ..strokeCap = StrokeCap.round
                                            ..isAntiAlias = true
                                            ..color = brushColor
                                            ..strokeWidth = 1.56),
                                    );
                                  }
                                  if (brushColor == Colors.green) {
                                    points_green.add(
                                      DrawingArea(
                                          point: details.localPosition,
                                          areaPaint: Paint()
                                            ..strokeCap = StrokeCap.round
                                            ..isAntiAlias = true
                                            ..color = brushColor
                                            ..strokeWidth = 1.56),
                                    );
                                  }
                                  if (brushColor == Colors.red.shade900) {
                                    points_red.add(
                                      DrawingArea(
                                          point: details.localPosition,
                                          areaPaint: Paint()
                                            ..strokeCap = StrokeCap.round
                                            ..isAntiAlias = true
                                            ..color = brushColor
                                            ..strokeWidth = 1.56),
                                    );
                                  }
                                },
                              );
                            },
                            onPanEnd: (details) {
                              this.setState(() {
                                points_black.add(null);
                                points_blue.add(null);
                                points_red.add(null);
                                points_green.add(null);
                              });
                            },
                            child: SizedBox.expand(
                                child: ClipRRect(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(20)),
                              child: CustomPaint(
                                  painter: MyCustomPainter(
                                      points_black: points_black,
                                      points_blue: points_blue,
                                      points_red: points_red,
                                      points_green: points_green)),
                            )),
                          ),
                        ),
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.9,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.all(
                            Radius.circular(20.0),
                          ),
                        ),
                        child: Row(
                          // crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            IconButton(
                              icon: Icon(
                                Icons.save,
                                color: Colors.black,
                              ),
                              onPressed: () async {
                                await saveToImageWrapper(points_black,
                                    points_blue, points_green, points_red);
                                _loading = false;
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.layers_clear,
                                color: Colors.black,
                              ),
                              onPressed: () {
                                this.setState(() {
                                  points_black.clear();
                                  points_blue.clear();
                                  points_red.clear();
                                  points_green.clear();
                                });
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.camera_alt,
                                color: Colors.black,
                              ),
                              onPressed: () {
                                _loading = false;
                                pickImage();
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.brush_rounded,
                                color: Colors.blue.shade900,
                              ),
                              onPressed: () {
                                this.setState(() {
                                  brushColor = Colors.blue.shade900;
                                });
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.brush_rounded,
                                color: Colors.red.shade900,
                              ),
                              onPressed: () {
                                this.setState(() {
                                  brushColor = Colors.red.shade900;
                                });
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.brush_rounded,
                                color: Colors.green,
                              ),
                              onPressed: () {
                                this.setState(() {
                                  brushColor = Colors.green;
                                });
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.brush_rounded,
                                color: Colors.black,
                              ),
                              onPressed: () {
                                this.setState(() {
                                  brushColor = Colors.black;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : SafeArea(
                  child: Column(
                    children: <Widget>[
                      // img1,
                      SizedBox(
                        height: 10,
                      ),
                      Align(
                        alignment: Alignment.topLeft,
                        child: Container(
                          padding: EdgeInsets.only(left: 10),
                          child: IconButton(
                            icon: Icon(Icons.arrow_back_ios),
                            color: Colors.white,
                            onPressed: () {
                              setState(() {
                                _loading = true;
                              });
                            },
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 20,
                      ),
                      Container(
                        width: 256,
                        height: 256,
                        child: img1,
                      ),
                      SizedBox(height: 30),
                      Center(
                        child: Container(
                            height: 256, width: 256, child: imageOutput),
                      ),
                      // SizedBox(height: 30),
                      //      Center(
                      //         child: Image.memory(
                      //         Uint8List.view(imgBytes.buffer),
                      //         width: 256,
                      //         height: 256,
                      //       ))
                    ],
                  ),
                ),
        ],
      ),
    );
  }
}
