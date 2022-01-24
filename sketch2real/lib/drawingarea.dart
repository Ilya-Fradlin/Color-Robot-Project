import 'dart:ui';

import 'package:flutter/material.dart';

class DrawingArea {
  Offset? point;
  Paint? areaPaint;

  DrawingArea({this.point, this.areaPaint});
}

class MyCustomPainter extends CustomPainter {
  List<DrawingArea?> points_black;
  List<DrawingArea?> points_green;
  List<DrawingArea?> points_red;
  List<DrawingArea?> points_blue;

  MyCustomPainter(
      {required List<DrawingArea?> points_black,
      required List<DrawingArea?> points_green,
      required List<DrawingArea?> points_blue,
      required List<DrawingArea?> points_red})
      : this.points_black = points_black.toList(),
        this.points_blue = points_blue.toList(),
        this.points_green = points_green.toList(),
        this.points_red = points_red.toList();

  @override
  void paint(Canvas canvas, Size size) {
    // TODO: implement paint
    Paint background = Paint()..color = Colors.white;
    Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(rect, background);
    canvas.clipRect(rect);

    for (int x = 0; x < points_black.length - 1; x++) {
      if (points_black[x] != null && points_black[x + 1] != null) {
        canvas.drawLine(points_black[x]!.point!, points_black[x + 1]!.point!,
            points_black[x]!.areaPaint!);
      } else if (points_black[x] != null && points_black[x + 1] == null) {
        canvas.drawPoints(PointMode.points, [points_black[x]!.point!],
            points_black[x]!.areaPaint!);
      }
    }
    for (int x = 0; x < points_green.length - 1; x++) {
      if (points_green[x] != null && points_green[x + 1] != null) {
        canvas.drawLine(points_green[x]!.point!, points_green[x + 1]!.point!,
            points_green[x]!.areaPaint!);
      } else if (points_green[x] != null && points_green[x + 1] == null) {
        canvas.drawPoints(PointMode.points, [points_green[x]!.point!],
            points_green[x]!.areaPaint!);
      }
    }
    for (int x = 0; x < points_blue.length - 1; x++) {
      if (points_blue[x] != null && points_blue[x + 1] != null) {
        canvas.drawLine(points_blue[x]!.point!, points_blue[x + 1]!.point!,
            points_blue[x]!.areaPaint!);
      } else if (points_blue[x] != null && points_blue[x + 1] == null) {
        canvas.drawPoints(PointMode.points, [points_blue[x]!.point!],
            points_blue[x]!.areaPaint!);
      }
    }
    for (int x = 0; x < points_red.length - 1; x++) {
      if (points_red[x] != null && points_red[x + 1] != null) {
        canvas.drawLine(points_red[x]!.point!, points_red[x + 1]!.point!,
            points_red[x]!.areaPaint!);
      } else if (points_red[x] != null && points_red[x + 1] == null) {
        canvas.drawPoints(PointMode.points, [points_red[x]!.point!],
            points_red[x]!.areaPaint!);
      }
    }
  }

  @override
  bool shouldRepaint(MyCustomPainter oldDelegate) {
    // TODO: implement shouldRepaint
    return (oldDelegate.points_black != points_black ||
        oldDelegate.points_blue != points_blue ||
        oldDelegate.points_red != points_red ||
        oldDelegate.points_green != points_green);
  }
}
