import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mime/mime.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:picturegenerator/drawingarea.dart';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:file_picker/file_picker.dart';
import './SelectBondedDevicePage.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool _loading = true;
  List<DrawingArea?> points = [];
  Widget? imageOutput;
  ByteData imgBytes = ByteData(1024);
  var img1;
  BluetoothConnection? connection;

  void saveToImage(List<DrawingArea?> points) async {
    final recorder = ui.PictureRecorder();
    final canvas =
        Canvas(recorder, Rect.fromPoints(Offset(0.0, 0.0), Offset(200, 200)));
    Paint paint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5.0;

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

    fetchResponseFromDraw(file);

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

  void fetchResponseFromDraw(File imageFile) async {
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

      // uncomment after the testing of the sending ends
      if (connection == null) {
        final BluetoothDevice? selectedDevice =
            await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) {
              return SelectBondedDevicePage(checkAvailability: false);
            },
          ),
        );
        BluetoothConnection.toAddress(selectedDevice?.address)
            .then((_connection) {
          print('Connected to the device');
          setState(() {
            connection = _connection;
          });
        }).catchError((error) {
          print('Cannot connect, exception occured');
          print(error);
        });
      }
      final Map<String, dynamic> responseData = json.decode(response.body);
      String g_code = responseData['result'];

      //testing purpose delete afterwards
      // List myList = [
      //   "G01 X124 Y128",
      //   "G00 X68 Y87",
      //   "G01 X30 Y57",
      //   "G01 X156 Y200",
      //   "G00 X00 Y00"
      // ];
      await Future.delayed(Duration(seconds: 10));
      //String dataString = String.fromCharCodes(buffer)
      connection!.input!.listen(_onDataReceived);
      List myList = g_code.split("\n");
      for (int i = 0; i < myList.length; ++i) {
        String text = myList[i];
        _sendMessage(text, connection);
      }
    } catch (e) {
      print(' * ERROR: ' + e.toString());
      return null;
    }
  }

  void _onDataReceived(Uint8List data) {
    // Do Nothing on the recieved data
  }

  void _sendMessage(String text, BluetoothConnection? connection) async {
    text = text.trim();
    if (text.length > 0) {
      try {
        connection!.output.add(Uint8List.fromList(utf8.encode(text + "\r\n")));
        await connection.output.allSent;
      } catch (e) {
        // Ignore error, but notify state
        print("");
      }
    }
  }

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
                                  points.add(
                                    DrawingArea(
                                        point: details.localPosition,
                                        areaPaint: Paint()
                                          ..strokeCap = StrokeCap.round
                                          ..isAntiAlias = true
                                          ..color = Colors.black
                                          ..strokeWidth = 5.0),
                                  );
                                },
                              );
                            },
                            onPanUpdate: (details) {
                              this.setState(
                                () {
                                  points.add(
                                    DrawingArea(
                                        point: details.localPosition,
                                        areaPaint: Paint()
                                          ..strokeCap = StrokeCap.round
                                          ..isAntiAlias = true
                                          ..color = Colors.black
                                          ..strokeWidth = 5.0),
                                  );
                                },
                              );
                            },
                            onPanEnd: (details) {
                              this.setState(() {
                                points.add(null);
                              });
                            },
                            child: SizedBox.expand(
                                child: ClipRRect(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(20)),
                              child: CustomPaint(
                                  painter: MyCustomPainter(points: points)),
                            )),
                          ),
                        ),
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.80,
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
                              onPressed: () {
                                saveToImage(points);
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
                                  points.clear();
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
